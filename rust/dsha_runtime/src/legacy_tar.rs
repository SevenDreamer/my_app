// 版权来源：DSHA（MIT）com.deepseekharness.app.backup.{LegacyTarReader,StrictGzipInputStream}
// —— 现代化重构，行为契约不变。
//! 历史 tar/gzip 的宿主只读层。返回受限成员流，不按归档路径直接创建文件，也不执行内容。
//! gzip 为 RFC 1952 单成员严格读取器：校验 CRC/ISIZE 并拒绝尾随垃圾
//!（常见 GZIPInputStream 对尾部宽松接受，这里不放行）。
//!
//! 错误代号契约（逐字）：`GZIP_HEADER`/`GZIP_FLAGS`/`GZIP_HEADER_CRC`/`GZIP_METADATA_LIMIT`/
//! `GZIP_TRUNCATED`/`GZIP_TRAILER`/`GZIP_TRAILING_DATA`/`GZIP_DEFLATE`、
//! `TAR_*` 系、`ARCHIVE_LIMIT`/`ENTRY_LIMIT`/`DUPLICATE_PATH`/`PAX_*`/`LINK_FORMAT`。

use crate::code_error;
use crate::control::BackupControl;
use crate::limits;
use flate2::{Crc, Decompress, FlushDecompress, Status};
use std::collections::HashMap;
use std::collections::HashSet;
use std::io::{self, Read};

/// 归档成员（mode 截到 0777）。
#[derive(Debug, Clone)]
pub struct Member {
    pub path: String,
    pub kind: EntryKind,
    pub target: String,
    pub size: i64,
    pub mode: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EntryKind {
    File,
    Directory,
    Link,
    Hardlink,
}

impl EntryKind {
    pub fn wire(self) -> &'static str {
        match self {
            EntryKind::File => "FILE",
            EntryKind::Directory => "DIRECTORY",
            EntryKind::Link => "LINK",
            EntryKind::Hardlink => "HARDLINK",
        }
    }
}

impl Member {
    /// 默认权限：DIRECTORY=0700，其余 0600（原版同）。
    pub fn new(path: String, kind: EntryKind, target: String, size: i64) -> Self {
        let mode = if kind == EntryKind::Directory { 0o700 } else { 0o600 };
        Member { path, kind, target, size, mode }
    }

    pub fn with_mode(mut self, mode: i64) -> Self {
        self.mode = (mode & 0o777) as u32;
        self
    }
}

/// 成员访问器：data 为限长成员正文流（未读完由读取器排空）。
pub trait Visitor {
    fn entry(&mut self, entry: &Member, data: &mut dyn Read) -> io::Result<()>;
}

/// 读取入口（总限额 = [limits::BYTES]）。
pub fn read(
    raw: &mut dyn Read,
    visitor: &mut dyn Visitor,
    control: &BackupControl,
) -> io::Result<()> {
    read_with_limit(raw, visitor, control, limits::BYTES as i64)
}

/// 签名 Linux 资产：大小写敏感（原版 `readTrustedAssets`）。
pub fn read_trusted_assets(
    raw: &mut dyn Read,
    visitor: &mut dyn Visitor,
    control: &BackupControl,
) -> io::Result<()> {
    read_internal(raw, visitor, control, limits::BYTES as i64, true)
}

pub fn read_with_limit(
    raw: &mut dyn Read,
    visitor: &mut dyn Visitor,
    control: &BackupControl,
    byte_limit: i64,
) -> io::Result<()> {
    read_internal(raw, visitor, control, byte_limit, false)
}

struct Limited<'a> {
    input: &'a mut dyn Read,
    left: i64,
    control: &'a BackupControl,
}

impl Read for Limited<'_> {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        self.control.check()?;
        if buf.is_empty() || self.left == 0 {
            return Ok(0); // Rust Read 的 EOF；原版返回 -1
        }
        let max = self.left.min(buf.len() as i64) as usize;
        let n = self.input.read(&mut buf[..max])?;
        if n == 0 {
            return Err(code_error("TAR_TRUNCATED"));
        }
        self.left -= n as i64;
        Ok(n)
    }
}

fn read_internal(
    raw: &mut dyn Read,
    visitor: &mut dyn Visitor,
    control: &BackupControl,
    byte_limit: i64,
    case_sensitive: bool,
) -> io::Result<()> {
    if byte_limit < 0 || byte_limit > limits::BYTES as i64 + 256 * 1024 * 1024 {
        return Err(code_error("ARCHIVE_LIMIT"));
    }
    // 预读 2 字节嗅探 gzip 魔数（1f 8b），随后整链回放。
    let mut head = [0u8; 2];
    let mut n = 0usize;
    while n < 2 {
        let got = raw.read(&mut head[n..])?;
        if got == 0 {
            break;
        }
        n += got;
    }
    let gzip = n == 2 && head[0] == 31 && head[1] == 139;
    let mut chained = (&head[..n]).chain(raw);
    let mut decoded: Box<dyn Read> = if gzip {
        Box::new(StrictGzip::new(&mut chained)?)
    } else {
        Box::new(chained)
    };

    let mut header = [0u8; 512];
    let mut buffer = [0u8; 65536];
    let (mut total, mut metadata, mut path_bytes) = (0i64, 0i64, 0i64);
    let (mut count, mut headers) = (0i64, 0i64);
    let mut names: HashSet<String> = HashSet::new();
    let (mut long_name, mut long_link): (Option<String>, Option<String>) = (None, None);
    let mut pax: HashMap<String, String> = HashMap::new();
    let mut pax_active = false;
    loop {
        control.check()?;
        headers += 1;
        if headers > limits::ENTRIES as i64 * 4 {
            return Err(code_error("TAR_HEADER_LIMIT"));
        }
        exact(decoded.as_mut(), &mut header)?;
        if zero(&header) {
            let mut second_block = [0u8; 512];
            exact(decoded.as_mut(), &mut second_block)?;
            if !zero(&second_block) {
                return Err(code_error("TAR_END"));
            }
            // 一直读到外层 EOF，强制 GZIP 校验 CRC 和截断；只允许零填充，拒绝拼接另一个归档。
            let mut tail = 0i64;
            loop {
                control.check()?;
                let got = decoded.read(&mut buffer)?;
                if got == 0 {
                    break;
                }
                tail = limits::add(tail, got as i64, 1024 * 1024)?;
                if buffer[..got].iter().any(|b| *b != 0) {
                    return Err(code_error("TAR_TRAILING_DATA"));
                }
            }
            if long_name.is_some() || long_link.is_some() || pax_active {
                return Err(code_error("TAR_METADATA_WITHOUT_ENTRY"));
            }
            return Ok(());
        }
        let checksum = number(&header, 148, 8)?;
        let mut sum: i64 = 0;
        for (i, b) in header.iter().enumerate() {
            sum += if (148..156).contains(&i) { 32 } else { (b & 255) as i64 };
        }
        if checksum != sum {
            return Err(code_error("TAR_CHECKSUM"));
        }
        let mut name = text(&header, 0, 100)?;
        let prefix = text(&header, 345, 155)?;
        let mut target = text(&header, 157, 100)?;
        if !prefix.is_empty() {
            name = format!("{prefix}/{name}");
        }
        let typeflag = header[156] & 255;
        let mut size = number(&header, 124, 12)?;
        if size > byte_limit {
            return Err(code_error("ARCHIVE_LIMIT"));
        }
        if matches!(typeflag, b'L' | b'K' | b'x' | b'g') {
            if size > limits::MANIFEST as i64 {
                return Err(code_error("TAR_METADATA_LIMIT"));
            }
            metadata = limits::add(metadata, size, limits::METADATA as i64)?;
            let mut bytes = vec![0u8; size as usize];
            exact(decoded.as_mut(), &mut bytes)?;
            padding(decoded.as_mut(), size, &mut buffer)?;
            if typeflag == b'L' {
                long_name = Some(terminated(&bytes)?);
            } else if typeflag == b'K' {
                long_link = Some(terminated(&bytes)?);
            } else {
                let values = pax_records(&bytes)?;
                if typeflag == b'g' {
                    if values.contains_key("path")
                        || values.contains_key("linkpath")
                        || values.contains_key("size")
                    {
                        return Err(code_error("TAR_GLOBAL_PATH"));
                    }
                } else {
                    if pax_active {
                        return Err(code_error("TAR_DUPLICATE_PAX"));
                    }
                    pax = values;
                    pax_active = true;
                }
            }
            continue;
        }
        if let Some(long) = long_name.take() {
            name = long;
        }
        if let Some(long) = long_link.take() {
            target = long;
        }
        if pax_active {
            if let Some(v) = pax.get("path") {
                name = v.clone();
            }
            if let Some(v) = pax.get("linkpath") {
                target = v.clone();
            }
            if let Some(v) = pax.get("size") {
                size = v.parse().map_err(|_| code_error("TAR_SIZE"))?;
            }
            pax.clear();
            pax_active = false;
        }
        while name.starts_with("./") {
            name = name[2..].to_string();
        }
        if name.ends_with('/') {
            name.pop();
        }
        if name.is_empty() || name == "." {
            if typeflag != b'5' || size != 0 {
                return Err(code_error("TAR_ROOT"));
            }
            continue;
        }
        limits::path(&name)?;
        let key = if case_sensitive {
            name.clone()
        } else {
            limits::collision_key("legacy", &name)?
        };
        if !names.insert(key.clone()) {
            return Err(code_error("DUPLICATE_PATH"));
        }
        // 签名 Ubuntu 归档当前约 76,500 个 Linux 条目、13.7 MiB 路径字符；
        // 用户归档维持原 8 MiB 上限。
        path_bytes = limits::add(
            path_bytes,
            key.encode_utf16().count() as i64 * 2,
            (if case_sensitive { 32 } else { 8 }) * 1024 * 1024,
        )?;
        count += 1;
        if count > limits::ENTRIES as i64 {
            return Err(code_error("ENTRY_LIMIT"));
        }
        let kind = match typeflag {
            0 | b'0' | b'7' => EntryKind::File,
            b'5' => EntryKind::Directory,
            b'2' => EntryKind::Link,
            b'1' => EntryKind::Hardlink,
            _ => {
                return Err(code_error(format!(
                    "TAR_SPECIAL_FILE:{name}:type={typeflag}"
                )))
            }
        };
        if (kind != EntryKind::File && size != 0) || size < 0 {
            return Err(code_error(format!(
                "TAR_SPECIAL_FILE:{name}:type={typeflag}"
            )));
        }
        total = limits::add(total, size, byte_limit)?;
        if target.len() > 2048 || target.contains('\0') {
            return Err(code_error("LINK_FORMAT"));
        }
        let mode = number(&header, 100, 8)?;
        if mode > 0o7777 {
            return Err(code_error("TAR_MODE"));
        }
        {
            let mut limited = Limited { input: decoded.as_mut(), left: size, control };
            visitor.entry(
                &Member { path: name, kind, target, size, mode: (mode & 0o777) as u32 },
                &mut limited,
            )?;
            // 排空成员正文（未读完也必须走完，保持流位）。
            loop {
                let got = limited.read(&mut buffer)?;
                if got == 0 {
                    break;
                }
            }
        }
        padding(decoded.as_mut(), size, &mut buffer)?;
        control.report("LEGACY_VERIFYING", count, total)?;
    }
}

// ── 严格 gzip（RFC 1952 单成员；deflate 芯 = flate2/miniz，包络逐字移植）────

struct StrictGzip<'a> {
    raw: &'a mut dyn Read,
    dec: Decompress,
    pending: Vec<u8>,
    pos: usize,
    size: u64,
    crc: Crc,
    finished: bool,
}

impl<'a> StrictGzip<'a> {
    fn new(raw: &'a mut dyn Read) -> io::Result<Self> {
        let mut g = StrictGzip {
            raw,
            dec: Decompress::new(true),
            pending: Vec::new(),
            pos: 0,
            size: 0,
            crc: Crc::new(),
            finished: false,
        };
        let mut header_crc = Crc::new();
        if g.header_byte(&mut header_crc)? != 31
            || g.header_byte(&mut header_crc)? != 139
            || g.header_byte(&mut header_crc)? != 8
        {
            return Err(code_error("GZIP_HEADER"));
        }
        let flags = g.header_byte(&mut header_crc)?;
        if flags & 0xe0 != 0 {
            return Err(code_error("GZIP_FLAGS"));
        }
        for _ in 0..6 {
            g.header_byte(&mut header_crc)?;
        }
        if flags & 4 != 0 {
            let length = g.header_byte(&mut header_crc)? | (g.header_byte(&mut header_crc)? << 8);
            for _ in 0..length {
                g.header_byte(&mut header_crc)?;
            }
        }
        if flags & 8 != 0 {
            g.terminated(&mut header_crc)?;
        }
        if flags & 16 != 0 {
            g.terminated(&mut header_crc)?;
        }
        if flags & 2 != 0 {
            let expected = g.byte_value()? | (g.byte_value()? << 8);
            if expected != (header_crc.sum() & 65535) {
                return Err(code_error("GZIP_HEADER_CRC"));
            }
        }
        Ok(g)
    }

    /// 读原始 1 字节（先 pending 后 raw）；None = EOF。
    fn byte_opt(&mut self) -> io::Result<Option<u32>> {
        if self.pos < self.pending.len() {
            let b = self.pending[self.pos];
            self.pos += 1;
            return Ok(Some(b as u32));
        }
        let mut b = [0u8; 1];
        if self.raw.read(&mut b)? == 0 {
            return Ok(None);
        }
        Ok(Some(b[0] as u32))
    }

    fn byte_value(&mut self) -> io::Result<u32> {
        self.byte_opt()?.ok_or_else(|| code_error("GZIP_TRUNCATED"))
    }

    fn header_byte(&mut self, crc: &mut Crc) -> io::Result<u32> {
        let value = self.byte_value()?;
        crc.update(&[value as u8]);
        Ok(value)
    }

    fn terminated(&mut self, crc: &mut Crc) -> io::Result<()> {
        for _ in 0..8192 {
            if self.header_byte(crc)? == 0 {
                return Ok(());
            }
        }
        Err(code_error("GZIP_METADATA_LIMIT"))
    }

    fn little(&mut self) -> io::Result<u32> {
        Ok(self.byte_value()?
            | (self.byte_value()? << 8)
            | (self.byte_value()? << 16)
            | (self.byte_value()? << 24))
    }
}

impl Read for StrictGzip<'_> {
    fn read(&mut self, out: &mut [u8]) -> io::Result<usize> {
        if out.is_empty() || self.finished {
            return Ok(0);
        }
        loop {
            if self.pos >= self.pending.len() {
                let mut chunk = vec![0u8; 65536];
                let got = self.raw.read(&mut chunk)?;
                if got == 0 {
                    return Err(code_error("GZIP_TRUNCATED"));
                }
                chunk.truncate(got);
                self.pending = chunk;
                self.pos = 0;
            }
            let before_in = self.dec.total_in();
            let before_out = self.dec.total_out();
            let status = self
                .dec
                .decompress(&self.pending[self.pos..], out, FlushDecompress::None)
                .map_err(|_| code_error("GZIP_DEFLATE"))?;
            self.pos += (self.dec.total_in() - before_in) as usize;
            let produced = (self.dec.total_out() - before_out) as usize;
            if produced > 0 {
                self.size = limits::add(
                    self.size as i64,
                    produced as i64,
                    limits::BYTES as i64 + 256 * 1024 * 1024,
                )? as u64;
                self.crc.update(&out[..produced]);
                return Ok(produced);
            }
            match status {
                Status::StreamEnd => {
                    // 尾部 CRC32 + ISIZE（可能仍在 pending 中），随后必须 EOF。
                    let crc = self.little()?;
                    let isize = self.little()?;
                    if crc != self.crc.sum() || isize != (self.size & 0xffffffff) as u32 {
                        return Err(code_error("GZIP_TRAILER"));
                    }
                    if self.byte_opt()?.is_some() {
                        return Err(code_error("GZIP_TRAILING_DATA"));
                    }
                    self.finished = true;
                    return Ok(0);
                }
                Status::BufError => {
                    // 输入有余却无进展 = 停滞（对齐原版 GZIP_STALLED）。
                    return Err(code_error("GZIP_STALLED"));
                }
                Status::Ok => continue, // 有消耗无产出，继续喂
            }
        }
    }
}

// ── 二进制辅助（原版 text/terminated/zero/exact/padding/number/pax）────────

fn text(bytes: &[u8], at: usize, size: usize) -> io::Result<String> {
    let mut end = at;
    while end < at + size && bytes[end] != 0 {
        end += 1;
    }
    let raw = &bytes[at..end];
    let value = std::str::from_utf8(raw).map_err(|_| code_error("TAR_ENCODING"))?;
    if value.contains('\u{FFFD}') {
        return Err(code_error("TAR_ENCODING"));
    }
    Ok(value.to_string())
}

fn terminated(value: &[u8]) -> io::Result<String> {
    let result = text(value, 0, value.len())?;
    if result.len() > 2048 {
        return Err(code_error("TAR_PATH_LIMIT"));
    }
    Ok(result)
}

fn zero(bytes: &[u8]) -> bool {
    bytes.iter().all(|b| *b == 0)
}

fn exact(input: &mut dyn Read, buf: &mut [u8]) -> io::Result<()> {
    let mut at = 0;
    while at < buf.len() {
        let got = input.read(&mut buf[at..])?;
        if got == 0 {
            return Err(code_error("TAR_TRUNCATED"));
        }
        at += got;
    }
    Ok(())
}

fn padding(input: &mut dyn Read, size: i64, buffer: &mut [u8; 65536]) -> io::Result<()> {
    let pad = ((512 - size % 512) % 512) as usize;
    exact(input, &mut buffer[..pad])
}

fn number(data: &[u8], start: usize, length: usize) -> io::Result<i64> {
    let mut value: i64 = 0;
    if data[start] & 0x80 != 0 {
        if data[start] & 0x40 != 0 {
            return Err(code_error("TAR_NUMBER"));
        }
        value = (data[start] & 0x7f) as i64;
        for i in start + 1..start + length {
            if value > (limits::BYTES as i64 + 257 * 1024 * 1024) / 256 {
                return Err(code_error("TAR_NUMBER"));
            }
            value = value * 256 + (data[i] & 255) as i64;
        }
        return Ok(value);
    }
    // 等同原有 NUL→空格和 String.trim，只在首尾忽略 ASCII 控制/空白。
    let (mut at, mut end) = (start, start + length);
    while at < end && (data[at] & 255) <= 32 {
        at += 1;
    }
    while end > at && (data[end - 1] & 255) <= 32 {
        end -= 1;
    }
    while at < end {
        let digit = (data[at] & 255) as i64 - i64::from(b'0');
        if !(0..=7).contains(&digit) || value > (i64::MAX - digit) / 8 {
            return Err(code_error("TAR_NUMBER"));
        }
        value = value * 8 + digit;
        at += 1;
    }
    Ok(value)
}

fn pax_records(data: &[u8]) -> io::Result<HashMap<String, String>> {
    let mut out: HashMap<String, String> = HashMap::new();
    let mut at = 0usize;
    while at < data.len() {
        let mut space = at;
        while space < data.len() && data[space] != b' ' {
            space += 1;
        }
        if space - at > 12 || space == data.len() {
            return Err(code_error("PAX_FORMAT"));
        }
        let length: usize = std::str::from_utf8(&data[at..space])
            .ok()
            .and_then(|s| s.parse().ok())
            .ok_or_else(|| code_error("PAX_FORMAT"))?;
        if length < space - at + 3 || length > data.len() - at || data[at + length - 1] != b'\n' {
            return Err(code_error("PAX_FORMAT"));
        }
        let record = std::str::from_utf8(&data[space + 1..at + length - 1])
            .map_err(|_| code_error("PAX_FORMAT"))?;
        let equals = record.find('=').ok_or_else(|| code_error("PAX_FORMAT"))?;
        if equals < 1 {
            return Err(code_error("PAX_FORMAT"));
        }
        let (key, value) = (&record[..equals], &record[equals + 1..]);
        if key.starts_with("GNU.sparse") || out.insert(key.to_string(), value.to_string()).is_some()
        {
            return Err(code_error("PAX_UNSUPPORTED"));
        }
        at += length;
    }
    Ok(out)
}
