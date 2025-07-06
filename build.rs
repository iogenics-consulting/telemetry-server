use std::time::SystemTime;

fn main() {
    let now = SystemTime::now();
    let datetime = chrono::DateTime::<chrono::Utc>::from(now);
    let build_date = datetime.format("%Y-%m-%d %H:%M:%S UTC").to_string();

    println!("cargo:rustc-env=BUILD_DATE={build_date}");
    println!("cargo:rerun-if-changed=build.rs");
}
