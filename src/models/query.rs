use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct QueryPrompt {
    pub prompt: String,
}

#[derive(Debug)]
pub struct ParsedQuery {
    pub metric_name: Option<String>,
    pub tags: Option<Vec<String>>,
    pub time_range: Option<TimeRange>,
    pub aggregation: Option<AggregationType>,
    pub limit: Option<i64>,
}

#[derive(Debug)]
pub struct TimeRange {
    pub start: Option<chrono::DateTime<chrono::Utc>>,
    pub end: Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Debug)]
pub enum AggregationType {
    Top(usize),
    Average,
    Sum,
    Count,
}
