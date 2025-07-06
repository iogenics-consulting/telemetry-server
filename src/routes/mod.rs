pub mod metrics;
pub mod query;

use actix_web::web;

pub fn configure_routes(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/metrics")
            .route("", web::get().to(metrics::get_metrics))
            .route("", web::post().to(metrics::create_metric))
            .route("/{id}", web::put().to(metrics::update_metric))
            .route("/{id}", web::delete().to(metrics::delete_metric)),
    )
    .service(web::resource("/query").route(web::get().to(query::query_metrics)));
}
