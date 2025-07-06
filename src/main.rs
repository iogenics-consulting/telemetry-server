use actix_web::{App, HttpServer};
use std::env;
use telemetry_server::{health_check, version};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init_from_env(env_logger::Env::new().default_filter_or("info"));

    let port = env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let bind_address = format!("127.0.0.1:{port}");

    log::info!("Starting server at: {bind_address}");
    log::info!(
        "Server version: {version} (built on {build_date})",
        version = env!("CARGO_PKG_VERSION"),
        build_date = env!("BUILD_DATE")
    );

    HttpServer::new(|| App::new().service(health_check).service(version))
        .bind(&bind_address)?
        .run()
        .await
}
