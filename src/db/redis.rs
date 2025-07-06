use crate::config::Config;
use redis::{aio::ConnectionManager, Client};

#[derive(Clone)]
pub struct RedisDb {
    pub conn: ConnectionManager,
}

impl RedisDb {
    pub async fn connect(config: &Config) -> Result<Self, redis::RedisError> {
        let client = Client::open(config.redis_uri.as_str())?;
        let conn = ConnectionManager::new(client).await?;

        log::info!("Connected to Redis successfully");

        Ok(RedisDb { conn })
    }
}
