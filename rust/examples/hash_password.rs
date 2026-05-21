use bcrypt::{hash, DEFAULT_COST};
use std::fs::File;
use std::io::Write;

fn main() {
    let password = "admin123";
    match hash(password, DEFAULT_COST) {
        Ok(h) => {
            println!("Password: {}", password);
            println!("Bcrypt hash: {}", h);
            
            // 同时写入文件，方便 PowerShell 读取
            let mut file = File::create("hash_output.txt").unwrap();
            writeln!(file, "{}", h).unwrap();
            println!("Hash also saved to hash_output.txt");
        }
        Err(e) => eprintln!("Error: {}", e),
    }
}
