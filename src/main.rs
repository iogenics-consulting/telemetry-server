use actix_governor::{Governor, GovernorConfigBuilder};
use actix_web::{middleware, web, App, HttpServer};
use telemetry_server::{
    config::Config,
    db::{MongoDb, RedisDb},
    health_check, routes,
    services::{QueryService, TelemetryService},
    version,
};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init_from_env(env_logger::Env::new().default_filter_or("info"));

    let config = Config::from_env().expect("Failed to load configuration");

    let mongo = MongoDb::connect(&config)
        .await
        .expect("Failed to connect to MongoDB");

    let redis = RedisDb::connect(&config)
        .await
        .expect("Failed to connect to Redis");

    let telemetry_service = TelemetryService::new(mongo.clone(), redis.clone());
    let query_service = QueryService::new(telemetry_service.clone());

    let bind_address = format!("0.0.0.0:{}", config.port);

    log::info!("Starting server at: {bind_address}");
    log::info!(
        "Server version: {version} (built on {build_date})",
        version = env!("CARGO_PKG_VERSION"),
        build_date = env!("BUILD_DATE")
    );
    log::info!("Environment: {}", config.app_env);
    log::info!("Database: {}", config.database_name);

    // Configure rate limiting
    let governor_conf = GovernorConfigBuilder::default()
        .per_second(100)
        .burst_size(200)
        .finish()
        .unwrap();

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(telemetry_service.clone()))
            .app_data(web::Data::new(query_service.clone()))
            .wrap(middleware::Logger::default())
            .wrap(Governor::new(&governor_conf))
            .service(health_check)
            .service(version)
            .configure(routes::configure_routes)
    })
    .bind(&bind_address)?
    .run()
    .await
}
