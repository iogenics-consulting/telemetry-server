use dotenv::dotenv;
use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    pub app_env: String,
    pub mongo_uri: String,
    pub redis_uri: String,
    pub port: String,
    pub database_name: String,
}

impl Config {
    pub fn from_env() -> Result<Self, env::VarError> {
        let environment = env::var("ENVIRONMENT").unwrap_or_else(|_| "local".to_string());

        let env_file = format!(".env.{environment}");
        if std::path::Path::new(&env_file).exists() {
            dotenv::from_filename(&env_file).ok();
        } else {
            dotenv().ok();
        }

        let app_env = env::var("APP_ENV").unwrap_or_else(|_| "dev".to_string());
        let mongo_uri = env::var("MONGO_URI")?;
        let redis_uri = env::var("REDIS_URI")?;
        let port = env::var("PORT").unwrap_or_else(|_| "8080".to_string());
        let database_name = format!("telemetry_server_{app_env}");

        Ok(Config {
            app_env,
            mongo_uri,
            redis_uri,
            port,
            database_name,
        })
    }
}
