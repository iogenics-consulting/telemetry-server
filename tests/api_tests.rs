use actix_web::{test, App};
use serde_json::Value;
use telemetry_server::{health_check, version};

#[actix_rt::test]
async fn test_health_check() {
    let app = test::init_service(App::new().service(health_check)).await;

    let req = test::TestRequest::get().uri("/health").to_request();
    let resp = test::call_service(&app, req).await;
    assert!(resp.status().is_success());

    let body: Value = test::read_body_json(resp).await;
    assert_eq!(body["status"], "healthy");
}

#[actix_rt::test]
async fn test_version() {
    let app = test::init_service(App::new().service(version)).await;

    let req = test::TestRequest::get().uri("/version").to_request();
    let resp = test::call_service(&app, req).await;
    assert!(resp.status().is_success());

    let body: Value = test::read_body_json(resp).await;
    assert!(body["version"].is_string());
    assert!(body["build_date"].is_string());
}
