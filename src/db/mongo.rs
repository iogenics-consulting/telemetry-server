use crate::config::Config;
use crate::models::Metric;
use bson::doc;
use mongodb::{options::ClientOptions, Client, Collection, Database, IndexModel};

#[derive(Clone)]
pub struct MongoDb {
    pub client: Client,
    pub database: Database,
}

impl MongoDb {
    pub async fn connect(config: &Config) -> Result<Self, mongodb::error::Error> {
        let client_options = ClientOptions::parse(&config.mongo_uri).await?;
        let client = Client::with_options(client_options)?;

        // Test connection with ping
        client
            .database("admin")
            .run_command(doc! {"ping": 1}, None)
            .await?;

        log::info!("Connected to MongoDB successfully");

        let database = client.database(&config.database_name);
        let mongo_db = MongoDb { client, database };

        // Create indexes - handle authentication errors gracefully
        match mongo_db.create_indexes().await {
            Ok(_) => log::info!("MongoDB indexes created successfully"),
            Err(e) => {
                log::warn!("Failed to create indexes: {}. Indexes will be created on first authenticated operation.", e);
            }
        }

        Ok(mongo_db)
    }

    pub fn metrics_collection(&self) -> Collection<Metric> {
        self.database.collection::<Metric>("metrics")
    }

    async fn create_indexes(&self) -> Result<(), mongodb::error::Error> {
        let collection = self.metrics_collection();

        // Index on name
        let name_index = IndexModel::builder().keys(doc! { "name": 1 }).build();

        // Index on tags
        let tags_index = IndexModel::builder().keys(doc! { "tags": 1 }).build();

        // Index on timestamp
        let timestamp_index = IndexModel::builder().keys(doc! { "timestamp": -1 }).build();

        // Compound index on name and timestamp
        let compound_index = IndexModel::builder()
            .keys(doc! { "name": 1, "timestamp": -1 })
            .build();

        // TTL index to automatically delete old metrics after 30 days
        let mut ttl_options = mongodb::options::IndexOptions::default();
        ttl_options.expire_after = Some(std::time::Duration::from_secs(2592000));

        let ttl_index = IndexModel::builder()
            .keys(doc! { "timestamp": 1 })
            .options(ttl_options)
            .build();

        collection
            .create_indexes(
                vec![
                    name_index,
                    tags_index,
                    timestamp_index,
                    compound_index,
                    ttl_index,
                ],
                None,
            )
            .await?;

        log::info!("MongoDB indexes created successfully");

        Ok(())
    }
}
