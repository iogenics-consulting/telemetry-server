use crate::models::{CreateMetricRequest, MetricFilter, UpdateMetricRequest};
use crate::services::TelemetryService;
use actix_web::{web, HttpResponse, Result};

pub async fn create_metric(
    service: web::Data<TelemetryService>,
    request: web::Json<CreateMetricRequest>,
) -> Result<HttpResponse> {
    match service.create_metric(request.into_inner()).await {
        Ok(metric) => Ok(HttpResponse::Created().json(metric)),
        Err(e) => {
            log::error!("Failed to create metric: {e}");
            Ok(HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to create metric"
            })))
        }
    }
}

pub async fn get_metrics(
    service: web::Data<TelemetryService>,
    query: web::Query<MetricFilter>,
) -> Result<HttpResponse> {
    match service.get_metrics(query.into_inner()).await {
        Ok(metrics) => Ok(HttpResponse::Ok().json(metrics)),
        Err(e) => {
            log::error!("Failed to get metrics: {e}");
            Ok(HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to get metrics"
            })))
        }
    }
}

pub async fn update_metric(
    service: web::Data<TelemetryService>,
    path: web::Path<String>,
    request: web::Json<UpdateMetricRequest>,
) -> Result<HttpResponse> {
    let id = path.into_inner();

    match service.update_metric(&id, request.into_inner()).await {
        Ok(Some(metric)) => Ok(HttpResponse::Ok().json(metric)),
        Ok(None) => Ok(HttpResponse::NotFound().json(serde_json::json!({
            "error": "Metric not found"
        }))),
        Err(e) => {
            log::error!("Failed to update metric: {e}");
            Ok(HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update metric"
            })))
        }
    }
}

pub async fn delete_metric(
    service: web::Data<TelemetryService>,
    path: web::Path<String>,
) -> Result<HttpResponse> {
    let id = path.into_inner();

    match service.delete_metric(&id).await {
        Ok(true) => Ok(HttpResponse::NoContent().finish()),
        Ok(false) => Ok(HttpResponse::NotFound().json(serde_json::json!({
            "error": "Metric not found"
        }))),
        Err(e) => {
            log::error!("Failed to delete metric: {e}");
            Ok(HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to delete metric"
            })))
        }
    }
}
