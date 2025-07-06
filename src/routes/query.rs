use crate::models::QueryPrompt;
use crate::services::QueryService;
use actix_web::{web, HttpResponse, Result};

pub async fn query_metrics(
    service: web::Data<QueryService>,
    query: web::Query<QueryPrompt>,
) -> Result<HttpResponse> {
    match service.execute_query(query.into_inner()).await {
        Ok(metrics) => Ok(HttpResponse::Ok().json(metrics)),
        Err(e) => {
            log::error!("Failed to execute query: {e}");
            Ok(HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to execute query"
            })))
        }
    }
}
