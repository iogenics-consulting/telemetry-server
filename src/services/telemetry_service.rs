use crate::db::{MongoDb, RedisDb};
use crate::models::{CreateMetricRequest, Metric, MetricFilter, UpdateMetricRequest};
use bson::{doc, oid::ObjectId, DateTime};
use futures::stream::TryStreamExt;
use mongodb::options::FindOptions;
use redis::AsyncCommands;
use serde_json;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Clone)]
pub struct TelemetryService {
    mongo: MongoDb,
    redis: RedisDb,
}

impl TelemetryService {
    pub fn new(mongo: MongoDb, redis: RedisDb) -> Self {
        Self { mongo, redis }
    }

    pub async fn create_metric(
        &self,
        request: CreateMetricRequest,
    ) -> Result<Metric, Box<dyn std::error::Error>> {
        let metric = Metric {
            id: None,
            name: request.name,
            tags: request.tags,
            value: request.value,
            timestamp: DateTime::from_millis(
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_millis() as i64,
            ),
        };

        let collection = self.mongo.metrics_collection();
        let insert_result = collection.insert_one(&metric, None).await?;

        let mut created_metric = metric.clone();
        created_metric.id = Some(insert_result.inserted_id.as_object_id().unwrap());

        Ok(created_metric)
    }

    pub async fn get_metrics(
        &self,
        filter: MetricFilter,
    ) -> Result<Vec<Metric>, Box<dyn std::error::Error>> {
        let cache_key = format!("metrics:{filter:?}");

        let mut conn = self.redis.conn.clone();
        if let Ok(cached) = conn.get::<_, String>(&cache_key).await {
            if let Ok(metrics) = serde_json::from_str::<Vec<Metric>>(&cached) {
                log::debug!("Cache hit for key: {cache_key}");
                return Ok(metrics);
            }
        }

        let mut query = doc! {};

        if let Some(name) = &filter.name {
            query.insert("name", name);
        }

        if let Some(tags) = &filter.tags {
            query.insert("tags", doc! { "$in": tags });
        }

        if filter.start_date.is_some() || filter.end_date.is_some() {
            let mut date_filter = doc! {};

            if let Some(start) = filter.start_date {
                if let Ok(start_date) = chrono::DateTime::parse_from_rfc3339(&start) {
                    date_filter
                        .insert("$gte", DateTime::from_millis(start_date.timestamp_millis()));
                }
            }

            if let Some(end) = filter.end_date {
                if let Ok(end_date) = chrono::DateTime::parse_from_rfc3339(&end) {
                    date_filter.insert("$lte", DateTime::from_millis(end_date.timestamp_millis()));
                }
            }

            if !date_filter.is_empty() {
                query.insert("timestamp", date_filter);
            }
        }

        let find_options = FindOptions::builder()
            .sort(doc! { "timestamp": -1 })
            .build();

        let collection = self.mongo.metrics_collection();
        let cursor = collection.find(query, find_options).await?;
        let metrics: Vec<Metric> = cursor.try_collect().await?;

        let serialized = serde_json::to_string(&metrics)?;
        let _: () = conn.set_ex(&cache_key, serialized, 300).await?;

        Ok(metrics)
    }

    pub async fn update_metric(
        &self,
        id: &str,
        request: UpdateMetricRequest,
    ) -> Result<Option<Metric>, Box<dyn std::error::Error>> {
        let object_id = ObjectId::parse_str(id)?;

        let mut update_doc = doc! {};

        if let Some(name) = request.name {
            update_doc.insert("name", name);
        }

        if let Some(tags) = request.tags {
            update_doc.insert("tags", tags);
        }

        if let Some(value) = request.value {
            update_doc.insert("value", value);
        }

        if update_doc.is_empty() {
            return Ok(None);
        }

        let collection = self.mongo.metrics_collection();
        let filter = doc! { "_id": object_id };
        let update = doc! { "$set": update_doc };
        let options = mongodb::options::FindOneAndUpdateOptions::builder()
            .return_document(mongodb::options::ReturnDocument::After)
            .build();

        let result = collection
            .find_one_and_update(filter, update, options)
            .await?;

        Ok(result)
    }

    pub async fn delete_metric(&self, id: &str) -> Result<bool, Box<dyn std::error::Error>> {
        let object_id = ObjectId::parse_str(id)?;

        let collection = self.mongo.metrics_collection();
        let filter = doc! { "_id": object_id };

        let result = collection.delete_one(filter, None).await?;

        Ok(result.deleted_count > 0)
    }
}
