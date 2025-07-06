use actix_web::{get, HttpResponse, Responder};
use serde::Serialize;

pub mod config;
pub mod db;
pub mod models;
pub mod routes;
pub mod services;

#[derive(Serialize)]
struct HealthResponse {
    status: String,
}

#[derive(Serialize)]
struct VersionResponse {
    version: String,
    build_date: String,
}

#[get("/health")]
pub async fn health_check() -> impl Responder {
    let response = HealthResponse {
        status: "healthy".to_string(),
    };
    HttpResponse::Ok().json(response)
}

#[get("/version")]
pub async fn version() -> impl Responder {
    let response = VersionResponse {
        version: env!("CARGO_PKG_VERSION").to_string(),
        build_date: env!("BUILD_DATE").to_string(),
    };
    HttpResponse::Ok().json(response)
}
