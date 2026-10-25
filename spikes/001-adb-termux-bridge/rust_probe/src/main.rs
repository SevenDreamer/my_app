//! 001b 探针：adb_client 走 ADBServer 模式执行命令，与 adb CLI 比对等价性。
//! 命门假设：app 内的 adb_client 可完全替代 adb CLI（配对、连接、shell）。
//! 用法: rust_probe <serial> <命令...>（不带 shell 前缀，如 `getprop ro.product.model`）

use adb_client::{ADBDeviceExt, ADBServer};
use std::env;
use std::io::stdout;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("用法: {} <serial> <命令...>（不带 shell 前缀）", args[0]);
        std::process::exit(2);
    }
    let serial = &args[1];
    let cmd: Vec<&str> = args[2..].iter().map(String::as_str).collect();

    // 连本地 adb server（Termux 场景换成 127.0.0.1:5037 同一地址）
    let mut server = ADBServer::default();

    // 子命令：pair <ip:port> <code> / connect <ip:port>（验证 crate 的配对/连接 API）
    if serial == "pair" || serial == "connect" {
        let addr: std::net::SocketAddrV4 = match args[2].parse() {
            Ok(a) => a,
            Err(e) => {
                eprintln!("❌ 地址格式应为 ip:port: {e}");
                std::process::exit(2);
            }
        };
        let r = if serial == "pair" {
            let code = match args.get(3) {
                Some(c) => c.clone(),
                None => {
                    eprintln!("用法: {} pair <ip:port> <6位配对码>", args[0]);
                    std::process::exit(2);
                }
            };
            server.pair(addr, code)
        } else {
            server.connect_device(addr)
        };
        match r {
            Ok(()) => println!("✅ {serial} 成功"),
            Err(e) => {
                eprintln!("❌ {serial} 失败: {e}");
                std::process::exit(1);
            }
        }
        return;
    }

    // 与 `adb devices` 等价性检查
    match server.devices() {
        Ok(list) => {
            println!("devices: {:?}", list.iter().map(|d| d.identifier.clone()).collect::<Vec<_>>());
        }
        Err(e) => {
            eprintln!("❌ devices 失败（adb server 没起？）: {e}");
            std::process::exit(1);
        }
    }

    let mut device = match server.get_device_by_name(serial) {
        Ok(d) => d,
        Err(e) => {
            eprintln!("❌ 找不到设备 {serial}: {e}");
            std::process::exit(1);
        }
    };

    // 与 `adb -s <serial> shell <cmd>` 等价
    match device.shell_command(&cmd, &mut stdout()) {
        Ok(()) => println!("\n✅ shell_command 执行成功（与 CLI 等价性成立）"),
        Err(e) => {
            eprintln!("\n❌ shell_command 失败: {e}");
            std::process::exit(1);
        }
    }
}
