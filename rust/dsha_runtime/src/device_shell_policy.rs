// 版权来源：DSHA（MIT）com.deepseekharness.app.util.DeviceShellPolicy —— 现代化重构，行为契约不变。
//! 设备命令默认拒绝：只接受可完整识别的单条 argv，不执行用户提供的 shell 程序。
//!
//! 错误文案契约（deny 前缀 `[POLICY_BLOCKED] ` 逐字）与白名单集合逐条保留。
//! 接线缝（原版静态工具类，接线轮移植）：SmsQuery.validate / WebProcSel.parsePid /
//! SelfPackageIdentity.validName —— 见 [SmsQueryValidator] 等 trait。

use crate::device_file_operations::DevicePolicy;
use std::collections::HashSet;
use std::io;

/// 计划类别（原版 `Kind`）。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Read,
    File,
    Stop,
    SensitiveRead,
    VirtualScreen,
    Deny,
}

/// 设备命令计划（原版 `Plan`）。
#[derive(Debug, Clone)]
pub struct Plan {
    pub kind: Kind,
    pub argv: Vec<String>,
    pub operands: Vec<String>,
    pub reason: String,
}

impl Plan {
    pub fn allowed(&self) -> bool {
        self.kind != Kind::Deny
    }

    pub fn command(&self) -> &str {
        self.argv.first().map(|s| s.as_str()).unwrap_or("")
    }
}

/// `content` 查询校验（原版 `SmsQuery.validate`；接线缝）。
pub trait SmsQueryValidator {
    /// 返回拒绝理由即 deny；Ok = 通过。
    fn validate(&self, args: &[String]) -> Result<(), String>;
}

/// 进程 PID 解析（原版 `WebProcSel.parsePid`；<0 = 无效，接线缝）。
pub trait PidParser {
    fn parse_pid(&self, target: &str) -> i64;
}

/// 自包名合法判定（原版 `SelfPackageIdentity.validName`；接线缝）。
pub trait PackageNameValidator {
    fn valid_name(&self, name: &str) -> bool;
}

fn set(words: &str) -> HashSet<String> {
    words.split(' ').map(|s| s.to_string()).collect()
}

fn read_set() -> HashSet<String> {
    set("id whoami pwd uname getprop getenforce ps pidof ls cat head tail wc grep stat readlink realpath df du free uptime printenv echo printf md5sum sha1sum sha256sum sha512sum true false")
}

fn block_set() -> HashSet<String> {
    set("dd mkfs mke2fs mkfs.ext4 mkfs.f2fs fdisk sfdisk cfdisk parted sgdisk blockdev losetup wipefs setenforce chcon restorecon setprop mount umount unmount fastboot flash flash_image format erase wipe recovery reboot shutdown poweroff halt bootctl boot_control lpmake lpflash update_engine_client avbctl dmctl fsck tune2fs")
}

fn file_set() -> HashSet<String> {
    set("mkdir touch cp mv rm rmdir rename")
}

fn content_read_set() -> HashSet<String> {
    set("cat head tail wc grep stat readlink realpath du ls find md5sum sha1sum sha256sum sha512sum")
}

const PROTECTED: [&str; 4] = ["/dcim", "/pictures", "/android/data", "/android/obb"];
const SMS_PROVIDER: &str = "com.android.providers.telephony";
const SMS_READ_ROOTS: [&str; 7] = [
    "/data/data/com.android.providers.telephony",
    "/data/user/*/com.android.providers.telephony",
    "/data/user_de/*/com.android.providers.telephony",
    "/data_mirror/data_ce/*/*/com.android.providers.telephony",
    "/data_mirror/data_de/*/*/com.android.providers.telephony",
    "/mnt/expand/*/user/*/com.android.providers.telephony",
    "/mnt/expand/*/user_de/*/com.android.providers.telephony",
];
const ALIASES: [&str; 4] =
    ["/sdcard", "/mnt/sdcard", "/storage/self/primary", "/mnt/user/0/primary"];
const TEMPORARY: &str = "/data/local/tmp";

/// ADB 客户端使用由原生侧提供的同一份目录规则，不再维护另一份路径黑名单。
pub fn path_rules() -> Vec<(&'static str, String)> {
    vec![
        ("protected", PROTECTED.join(",")),
        ("aliases", ALIASES.join(",")),
        ("smsProvider", SMS_PROVIDER.to_string()),
        ("smsReadRoots", SMS_READ_ROOTS.join(",")),
        ("storage", "^/storage/(?:emulated/[0-9]+|[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4})(/.*)?$".to_string()),
        ("temporary", TEMPORARY.to_string()),
    ]
}

fn plan(kind: Kind, args: Vec<String>, paths: Vec<String>) -> Plan {
    Plan { kind, argv: args, operands: paths, reason: String::new() }
}

fn deny(reason: &str) -> Plan {
    Plan {
        kind: Kind::Deny,
        argv: Vec::new(),
        operands: Vec::new(),
        reason: format!("[POLICY_BLOCKED] {reason}"),
    }
}

/// 设备命令检查（原版 `inspect`）。
pub fn inspect(
    command: &str,
    sms: &dyn SmsQueryValidator,
    pids: &dyn PidParser,
) -> Plan {
    let mut args = match split(command) {
        Ok(args) => args,
        Err(reason) => return deny(&reason),
    };
    if args.is_empty() {
        return deny("命令为空");
    }
    let mut name = match executable(&args[0]) {
        Some(name) => name.to_string(),
        None => return deny("只允许系统目录中的已识别命令"),
    };
    if name == "toybox" {
        if args.len() < 2 {
            return deny("缺少 toybox 子命令");
        }
        args.remove(0);
        name = args[0].clone();
        if name.contains('/') {
            return deny("不支持嵌套执行器");
        }
    }
    args[0] = name.clone();
    if block_set().contains(&name) || name.starts_with("mkfs.") || name.starts_with("fsck.") {
        return deny(&format!("禁止设备分区、SELinux、系统属性、挂载或刷机操作：{name}"));
    }
    if read_set().contains(&name) {
        return plan(Kind::Read, args, Vec::new());
    }
    if name == "content" {
        return match sms.validate(&args) {
            Ok(()) => plan(Kind::SensitiveRead, args, Vec::new()),
            Err(reason) => deny(&reason),
        };
    }
    if name == "date" {
        for arg in &args[1..] {
            if arg != "-u" && arg != "-R" && arg != "-I" && !arg.starts_with('+') {
                return deny("date 只允许读取时间");
            }
        }
        return plan(Kind::Read, args, Vec::new());
    }
    if name == "settings" {
        let mut i = 1;
        if args.len() > 3 && args[i] == "--user" {
            if !user_id(&args[i + 1]) {
                return deny("无法识别用户编号");
            }
            i += 2;
        }
        if args.len() <= i + 1 || !set("system secure global").contains(&args[i + 1]) {
            return deny("无法识别 settings 参数");
        }
        if (args[i] == "get" && args.len() == i + 3)
            || (args[i] == "list" && args.len() == i + 2)
        {
            return plan(Kind::Read, args, Vec::new());
        }
        return deny("系统设置只允许 get/list，禁止写入");
    }
    if name == "pm" {
        if args.len() == 3 && set("path dump").contains(&args[1]) && package_name(&args[2]) {
            return plan(Kind::Read, args, Vec::new());
        }
        if args.len() >= 3
            && args[1] == "list"
            && set("packages permissions features libraries users instrumentation permission-groups")
                .contains(&args[2])
        {
            let mut i = 3;
            while i < args.len() {
                let arg = &args[i];
                if arg == "--user" {
                    i += 1;
                    if i >= args.len() || !user_id(&args[i]) {
                        return deny("无法识别用户编号");
                    }
                } else if arg.starts_with('-')
                    && !set("-f -d -e -s -3 -i -U -u -g -a --show-versioncode").contains(arg)
                {
                    return deny("未识别的 pm 选项");
                } else if !arg.starts_with('-')
                    && !arg.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '.')
                {
                    return deny("无法识别应用筛选条件");
                }
                i += 1;
            }
            return plan(Kind::Read, args, Vec::new());
        }
        return deny("pm 只允许查询；安装、卸载、清数据和授权不开放给设备命令");
    }
    if name == "dumpsys" {
        if args.len() == 2
            && set("-l battery power display connectivity wifi cpuinfo meminfo package window activity input sensorservice diskstats thermalservice")
                .contains(&args[1])
        {
            return plan(Kind::Read, args, Vec::new());
        }
        if args.len() == 3
            && ((args[1] == "activity"
                && set("activities processes top recents").contains(&args[2]))
                || (args[1] == "window" && set("windows displays").contains(&args[2]))
                || (set("package meminfo").contains(&args[1]) && package_name(&args[2])))
        {
            return plan(Kind::Read, args, Vec::new());
        }
        return deny("未识别的 dumpsys 参数；禁止用诊断命令改设备状态");
    }
    if name == "find" {
        return inspect_find(args);
    }
    if name == "logcat" {
        return inspect_logcat(args);
    }
    if name == "am" && args.len() == 2 && args[1] == "get-current-user" {
        return plan(Kind::Read, args, Vec::new());
    }
    // app_process 可加载任意 DEX。窄口径的受管虚拟屏启动器有独立类型化入口，
    // 永不作为 shell 命令接受。
    if name == "app_process" {
        return deny("app_process 仅允许原生受管虚拟屏入口");
    }
    if name == "am" && args.len() == 3 && set("force-stop kill").contains(&args[1]) && package_name(&args[2]) {
        let operands = vec![args[2].clone()];
        return plan(Kind::Stop, args, operands);
    }
    if name == "kill" || name == "killall" || name == "pkill" {
        let mut i = 1;
        if args.len() > i && set("-9 -15 -KILL -TERM -SIGKILL -SIGTERM").contains(&args[i]) {
            i += 1;
        }
        if name == "pkill" && args.len() > i && args[i] == "-x" {
            i += 1;
        }
        if i >= args.len() {
            return deny("缺少进程目标");
        }
        let targets: Vec<String> = args[i..].to_vec();
        for target in &targets {
            if name == "kill" {
                if pids.parse_pid(target) < 0 {
                    return deny("只接受正数 PID，禁止整组或全部进程信号");
                }
            } else if !package_name(target) {
                return deny("按名称结束应用必须使用完整包名，禁止模糊匹配");
            }
        }
        return plan(Kind::Stop, args, targets);
    }
    if file_set().contains(&name) {
        return inspect_file(args);
    }
    deny(&format!("不认识的命令不执行：{name}"))
}

/// 受管 FILE helper 已持有 argv；文件名中的引号只是数据，不再往返 shell 字符串。
pub fn inspect_file_arguments(input: &[String]) -> Plan {
    if input.is_empty() || input.len() > 128 {
        return deny("FILE_ARGUMENTS_INVALID");
    }
    let mut args = input.to_vec();
    let mut length = 0;
    for value in &args {
        length += value.chars().count() + 1;
        if length > 8192 {
            return deny("FILE_ARGUMENTS_LIMIT");
        }
        if value.chars().any(|c| (c as u32) < 32 || c as u32 == 127) {
            return deny("FILE_ARGUMENTS_CONTROL_CHARACTER");
        }
    }
    let name = match executable(&args[0]) {
        Some(name) if file_set().contains(name) => name.to_string(),
        _ => return deny("FILE_OPERATION_REQUIRED"),
    };
    args[0] = name;
    inspect_file(args)
}

/// 只读退出核验只能绑定调用方持有的出生身份，不能通过此入口发信号。
pub fn inspect_virtual_screen_probe(
    command: &str,
    installed_apk_path: &str,
    expected_package: &str,
    packages: &dyn PackageNameValidator,
) -> Plan {
    let mut args = match split(command) {
        Ok(args) => args,
        Err(reason) => return deny(&reason),
    };
    if args.len() != 9
        || executable(&args[0]) != Some("app_process")
        || !canonical_apk_path(installed_apk_path)
        || !packages.valid_name(expected_package)
        || args[1] != format!("-Djava.class.path={installed_apk_path}")
        || args[2] != "/system/bin"
        || args[3] != "com.deepseekharness.app.vscreen.VirtualScreenCore"
        || args[4] != "--probe-exit"
        || args[5] != "--identity"
        || !valid_virtual_screen_identity(&args[6])
        || args[7] != "--package"
        || args[8] != *expected_package
    {
        return deny("VSCREEN_PROBE_IDENTITY_UNVERIFIED");
    }
    args[0] = "app_process".to_string();
    plan(Kind::VirtualScreen, args, Vec::new())
}

/// 虚拟屏身份串：5 段（displayId:stableId:flags:uuid:uuid）严格核验。
fn valid_virtual_screen_identity(value: &str) -> bool {
    if value.len() > 160 {
        return false;
    }
    let fields: Vec<&str> = value.split(':').collect();
    if fields.len() != 5 {
        return false;
    }
    let uuid_re = |s: &str| {
        s.len() == 36
            && s.bytes().enumerate().all(|(i, b)| match i {
                8 | 13 | 18 | 23 => b == b'-',
                _ => b.is_ascii_hexdigit() && (b.is_ascii_digit() || b.is_ascii_lowercase()),
            })
    };
    let first_ok = fields[0].len() <= 10
        && fields[0].bytes().all(|b| b.is_ascii_digit())
        && fields[0].as_bytes()[0] != b'0'
        && fields[0].parse::<i64>().map(|v| v > 1 && v <= i32::MAX as i64).unwrap_or(false);
    let second_ok = fields[1].len() <= 19
        && fields[1].bytes().all(|b| b.is_ascii_digit())
        && fields[1].as_bytes()[0] != b'0'
        && fields[1].parse::<i64>().map(|v| v > 0).unwrap_or(false);
    let third_ok = fields[2].len() <= 10
        && fields[2].bytes().all(|b| b.is_ascii_digit())
        && (fields[2] == "0"
            || fields[2].as_bytes()[0] != b'0' && fields[2].parse::<i64>().is_ok())
        && fields[2].parse::<i64>().map(|v| v <= i32::MAX as i64).unwrap_or(false);
    first_ok && second_ok && third_ok && uuid_re(fields[3]) && uuid_re(fields[4])
}

/// Android package-manager 路径语法；保持纯函数让所有传输通道共用同一规则。
pub fn canonical_apk_path(path: &str) -> bool {
    if !path.starts_with("/data/app/")
        || !path.ends_with(".apk")
        || path.contains('\\')
        || path.contains('\0')
        || path.chars().any(|c| c.is_whitespace())
    {
        return false;
    }
    if path.split('/').any(|part| part == "." || part == "..") {
        return false;
    }
    !path.contains("//")
}

/// Root 读取/复制路径不得暴露短信存储。
pub fn root_read_paths(plan: &Plan) -> Vec<String> {
    if plan.kind == Kind::File && plan.command() == "cp" {
        return plan.operands[..plan.operands.len().saturating_sub(1)].to_vec();
    }
    if plan.kind != Kind::Read || !content_read_set().contains(plan.command()) {
        return Vec::new();
    }
    let mut paths = Vec::new();
    let mut after_separator = false;
    for arg in &plan.argv[1..] {
        let mut arg = arg.clone();
        if !after_separator && arg == "--" {
            after_separator = true;
            continue;
        }
        if !after_separator && arg.starts_with('-') {
            if arg.starts_with("--") && arg.contains('=') {
                arg = arg[arg.find('=').unwrap() + 1..].to_string();
            } else if arg.len() > 2 && arg.as_bytes()[2] == b'/' {
                arg = arg[2..].to_string();
            } else {
                continue;
            }
        }
        if arg.starts_with('/') || arg.contains('/') || !arg.starts_with('-') {
            paths.push(arg);
        }
    }
    if paths.is_empty() && plan.command() == "du" {
        paths.push(".".to_string());
    }
    if paths.is_empty() && plan.command() == "ls" && root_read_may_descend(plan) {
        paths.push(".".to_string());
    }
    paths
}

/// 递归读/复制祖先可能枚举或暴露短信 provider 树。
pub fn root_read_may_descend(plan: &Plan) -> bool {
    let command = plan.command();
    if plan.kind == Kind::File && command == "cp" {
        for arg in &plan.argv {
            if arg == "--" {
                break;
            }
            if arg.starts_with('-') && (arg.contains('R') || arg.contains('r')) {
                return true;
            }
        }
        return false;
    }
    if plan.kind != Kind::Read {
        return false;
    }
    if command == "find" || command == "du" {
        return true;
    }
    if command == "ls" || command == "grep" {
        for arg in &plan.argv {
            if arg == "-R" || arg == "-r" || arg == "--recursive" {
                return true;
            }
            if arg.starts_with('-')
                && !arg.starts_with("--")
                && (arg.contains('R') || arg.contains('r'))
            {
                return true;
            }
        }
    }
    false
}

/// 受保护路径与祖先共用发送给 ADB 的唯一根表，避免跨语言追加路径时漂移。
pub fn sms_provider_path(raw: &str) -> bool {
    let path = normalize(raw).to_lowercase();
    if path.is_empty() {
        return false;
    }
    let parts: Vec<&str> = if path == "/" { Vec::new() } else { path[1..].split('/').collect() };
    for root in SMS_READ_ROOTS {
        let pattern: Vec<&str> = root[1..].split('/').collect();
        if parts.len() >= pattern.len() && sms_prefix(&parts, &pattern, pattern.len()) {
            return true;
        }
    }
    false
}

pub fn sms_provider_descendant(raw: &str) -> bool {
    let path = normalize(raw).to_lowercase();
    if path.is_empty() {
        return false;
    }
    let parts: Vec<&str> = if path == "/" { Vec::new() } else { path[1..].split('/').collect() };
    for root in SMS_READ_ROOTS {
        let pattern: Vec<&str> = root[1..].split('/').collect();
        if sms_prefix(&parts, &pattern, parts.len().min(pattern.len())) {
            return true;
        }
    }
    false
}

fn sms_prefix(parts: &[&str], pattern: &[&str], count: usize) -> bool {
    (0..count).all(|i| pattern[i] == "*" || pattern[i] == parts[i])
}

fn inspect_file(mut args: Vec<String>) -> Plan {
    let name = args[0].clone();
    let flags = match name.as_str() {
        "cp" => "Rrfnpv",
        "mv" => "fnv",
        "rm" => "rfRdv",
        "mkdir" => "pv",
        "rmdir" => "v",
        "touch" => "c",
        _ => "",
    };
    let mut paths = Vec::new();
    let mut options = true;
    for i in 1..args.len() {
        let arg = args[i].clone();
        if options && arg == "--" {
            options = false;
            continue;
        }
        if options && arg.starts_with('-') {
            if arg.len() < 2 {
                return deny("未识别的文件操作参数");
            }
            for c in arg[1..].chars() {
                if !flags.contains(c) {
                    return deny("未识别的文件操作选项");
                }
            }
        } else {
            if !absolute_path(&arg) || has_glob(&arg) || arg.split('/').any(|p| p == "..") {
                return deny("写操作必须使用明确的绝对路径，禁止通配符或上级跳转");
            }
            paths.push(arg);
        }
    }
    let minimum = if matches!(name.as_str(), "cp" | "mv" | "rename") { 2 } else { 1 };
    if paths.len() < minimum || (name == "rename" && paths.len() != 2) {
        return deny("文件操作参数不完整");
    }
    // 复制只读取源文件；目标、移动源、删除等均必须在普通可写目录。
    let writes: Vec<String> = if name == "cp" {
        vec![paths[paths.len() - 1].clone()]
    } else {
        paths.clone()
    };
    for path in &writes {
        if !write_allowed(path) {
            return deny(&format!("受保护目录只读：{path}"));
        }
    }
    if name == "rename" {
        args[0] = "mv".to_string();
    }
    plan(Kind::File, args, paths)
}

fn inspect_find(args: Vec<String>) -> Plan {
    if args.len() < 2 || !absolute_path(&args[1]) {
        return deny("find 需要明确的读取目录");
    }
    let mut i = 2;
    while i < args.len() {
        let arg = &args[i];
        if set("-print -print0 -ls -empty").contains(arg) {
            i += 1;
            continue;
        }
        if set("-name -iname -path -type -maxdepth -mindepth -size -mtime -mmin").contains(arg) {
            i += 2;
            continue;
        }
        return deny("find 只允许读取条件，禁止 exec/delete 等动作");
    }
    plan(Kind::Read, args, Vec::new())
}

fn inspect_logcat(args: Vec<String>) -> Plan {
    let mut finite = false;
    let mut i = 1;
    while i < args.len() {
        let arg = &args[i];
        if arg == "-d" {
            finite = true;
            i += 1;
            continue;
        }
        if arg == "-t" {
            i += 1;
            if i >= args.len() || !numeric(&args[i], 1, 5) {
                return deny("无效日志行数");
            }
            finite = true;
            i += 1;
            continue;
        }
        if arg == "-v" || arg == "-b" {
            i += 1;
            if i >= args.len()
                || !args[i]
                    .chars()
                    .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == ',')
            {
                return deny("无效日志参数");
            }
            i += 1;
            continue;
        }
        if log_filter(arg) {
            i += 1;
            continue;
        }
        return deny("logcat 只允许读取，禁止清日志、写文件和修改缓冲区");
    }
    if finite {
        plan(Kind::Read, args, Vec::new())
    } else {
        deny("读取日志请指定 -d 或 -t 行数")
    }
}

/// `[A-Za-z0-9_.*-]+:[VDIWEFS]`。
fn log_filter(arg: &str) -> bool {
    match arg.rsplit_once(':') {
        Some((tag, level)) => {
            level.len() == 1
                && "VDIWEFS".contains(level)
                && !tag.is_empty()
                && tag
                    .chars()
                    .all(|c| c.is_ascii_alphanumeric() || matches!(c, '_' | '.' | '*' | '-'))
        }
        None => false,
    }
}

pub fn package_name(name: &str) -> bool {
    name == "android"
        || (!name.is_empty()
            && name.chars().next().unwrap().is_ascii_alphabetic()
            && name.split('.').count() >= 2
            && name
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '.')
            && name.split('.').all(|p| !p.is_empty()))
}

pub fn absolute_path(path: &str) -> bool {
    path.starts_with('/') && !path.contains('\0')
}

pub fn has_glob(path: &str) -> bool {
    path.contains('*') || path.contains('?') || path.contains('[') || path.contains(']')
}

/// 路径归一（别名折叠 + 运行时挂载前缀）。
pub fn normalize(path: &str) -> String {
    if !absolute_path(path) {
        return String::new();
    }
    let mut parts: Vec<&str> = Vec::new();
    for part in path.split('/') {
        if part.is_empty() || part == "." {
            continue;
        }
        if part == ".." {
            parts.pop();
        } else {
            parts.push(part);
        }
    }
    let normal = format!("/{}", parts.join("/"));
    for alias in ALIASES {
        if within(&normal, alias) {
            return format!("/storage/emulated/0{}", &normal[alias.len()..]);
        }
    }
    for mount in ["default", "read", "write", "full"] {
        let prefix = format!("/mnt/runtime/{mount}/emulated/");
        if normal.starts_with(&prefix) {
            return format!("/storage/emulated/{}", &normal[prefix.len()..]);
        }
    }
    normal
}

fn within(path: &str, root: &str) -> bool {
    path == root || path.starts_with(&format!("{root}/"))
}

pub fn write_allowed(raw: &str) -> bool {
    if !absolute_path(raw) || has_glob(raw) || raw.split('/').any(|p| p == "..") {
        return false;
    }
    let path = normalize(raw);
    let lower = path.to_lowercase();
    if path.starts_with("/data/local/tmp/") {
        return true;
    }
    let suffix = match storage_suffix(&path) {
        Some(suffix) if suffix != "/" => suffix.to_lowercase(),
        _ => return false,
    };
    for protected in PROTECTED {
        if within(&suffix, protected) || within(protected, &suffix) {
            return false;
        }
    }
    !lower.ends_with("/.")
}

/// STORAGE 正则的手写等价：返回组(1)（`/…` 后缀或 None）。
fn storage_suffix(path: &str) -> Option<&str> {
    let rest = path.strip_prefix("/storage/")?;
    let (id, tail) = match rest.split_once('/') {
        Some((id, _)) => (id, Some(&rest[id.len()..])),
        None => (rest, None),
    };
    let id_ok = if let Some(num) = id.strip_prefix("emulated/") {
        !num.is_empty() && num.bytes().all(|b| b.is_ascii_digit())
    } else {
        id.len() == 9
            && id.bytes().enumerate().all(|(i, b)| {
                (i == 4 && b == b'-') || b.is_ascii_hexdigit()
            })
    };
    if id_ok {
        tail
    } else {
        None
    }
}

/// `/system/bin/<name>` → name；其他含 `/` 一律拒绝。
fn executable(name: &str) -> Option<&str> {
    if !name.contains('/') {
        return Some(name);
    }
    if name.starts_with("/system/bin/") && name.matches('/').count() == 2 {
        Some(&name[12..])
    } else {
        None
    }
}

fn user_id(value: &str) -> bool {
    value == "current" || numeric(value, 1, 20)
}

fn numeric(value: &str, min_len: usize, max_len: usize) -> bool {
    !value.is_empty()
        && value.len() >= min_len
        && value.len() <= max_len
        && value.bytes().all(|b| b.is_ascii_digit())
}

/// 单条 argv 分词（引号内为数据；禁脚本/管道/重定向/变量/控制字符）。
/// 错误文案契约：`命令为空或过长`/`禁止多行脚本或控制字符`/
/// `禁止变量、命令展开和转义脚本`/`禁止脚本、管道、重定向、变量或嵌套命令；请分条执行`/
/// `引号不完整`/`参数过多`。
pub fn split(command: &str) -> Result<Vec<String>, String> {
    if command.is_empty() || command.chars().count() > 8192 {
        return Err("命令为空或过长".to_string());
    }
    let mut result = Vec::new();
    let mut word = String::new();
    let mut quote: Option<char> = None;
    let mut present = false;
    for c in command.chars() {
        let code = c as u32;
        if (code < 32 && c != '\t') || code == 127 {
            return Err("禁止多行脚本或控制字符".to_string());
        }
        if let Some(q) = quote {
            if c == q {
                quote = None;
            } else {
                if q == '"' && (c == '$' || c == '`' || c == '\\') {
                    return Err("禁止变量、命令展开和转义脚本".to_string());
                }
                word.push(c);
            }
        } else if c == '\'' || c == '"' {
            quote = Some(c);
            present = true;
        } else if c.is_whitespace() {
            if present {
                result.push(std::mem::take(&mut word));
                present = false;
            }
        } else {
            if ";&|><$`(){}\\#".contains(c) {
                return Err("禁止脚本、管道、重定向、变量或嵌套命令；请分条执行".to_string());
            }
            word.push(c);
            present = true;
        }
    }
    if quote.is_some() {
        return Err("引号不完整".to_string());
    }
    if present {
        result.push(word);
    }
    if result.len() > 128 {
        return Err("参数过多".to_string());
    }
    Ok(result)
}

/// `DevicePolicy` 实现（device_file_operations 执行器共用同一规则面）。
pub struct DeviceShellPolicy;

impl DevicePolicy for DeviceShellPolicy {
    fn normalize(&self, raw: &str) -> io::Result<String> {
        Ok(normalize(raw))
    }

    fn write_allowed(&self, path: &str) -> bool {
        write_allowed(path)
    }
}
