use bson::{oid::ObjectId, DateTime};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Metric {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<ObjectId>,
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tags: Option<Vec<String>>,
    pub value: f64,
    pub timestamp: DateTime,
}

#[derive(Debug, Deserialize)]
pub struct MetricFilter {
    pub name: Option<String>,
    pub tags: Option<Vec<String>>,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateMetricRequest {
    pub name: String,
    pub tags: Option<Vec<String>>,
    pub value: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdateMetricRequest {
    pub name: Option<String>,
    pub tags: Option<Vec<String>>,
    pub value: Option<f64>,
}
