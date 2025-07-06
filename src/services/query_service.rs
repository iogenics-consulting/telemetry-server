use crate::models::{AggregationType, Metric, ParsedQuery, QueryPrompt, TimeRange};
use crate::services::TelemetryService;
use chrono::{Duration, Utc};
use regex::Regex;

#[derive(Clone)]
pub struct QueryService {
    telemetry_service: TelemetryService,
}

impl QueryService {
    pub fn new(telemetry_service: TelemetryService) -> Self {
        Self { telemetry_service }
    }

    pub fn parse_prompt(&self, prompt: &str) -> ParsedQuery {
        let prompt_lower = prompt.to_lowercase();

        let metric_name = self.extract_metric_name(&prompt_lower);
        let tags = self.extract_tags(&prompt_lower);
        let time_range = self.extract_time_range(&prompt_lower);
        let aggregation = self.extract_aggregation(&prompt_lower);
        let limit = self.extract_limit(&prompt_lower);

        ParsedQuery {
            metric_name,
            tags,
            time_range,
            aggregation,
            limit,
        }
    }

    fn extract_metric_name(&self, prompt: &str) -> Option<String> {
        let patterns = vec![
            r"metric[s]?\s+(?:named?|called?)\s+(\w+)",
            r"(\w+)\s+metric[s]?",
            r"event[s]?\s+(?:named?|called?)\s+(\w+)",
        ];

        for pattern in patterns {
            if let Ok(re) = Regex::new(pattern) {
                if let Some(captures) = re.captures(prompt) {
                    if let Some(name) = captures.get(1) {
                        return Some(name.as_str().to_string());
                    }
                }
            }
        }

        None
    }

    fn extract_tags(&self, prompt: &str) -> Option<Vec<String>> {
        let patterns = vec![
            r"tag[s]?\s+(?:=|:)\s*\[([^\]]+)\]",
            r"tagged?\s+with\s+(\w+(?:\s*,\s*\w+)*)",
        ];

        for pattern in patterns {
            if let Ok(re) = Regex::new(pattern) {
                if let Some(captures) = re.captures(prompt) {
                    if let Some(tags_str) = captures.get(1) {
                        let tags: Vec<String> = tags_str
                            .as_str()
                            .split(',')
                            .map(|s| s.trim().to_string())
                            .filter(|s| !s.is_empty())
                            .collect();

                        if !tags.is_empty() {
                            return Some(tags);
                        }
                    }
                }
            }
        }

        None
    }

    fn extract_time_range(&self, prompt: &str) -> Option<TimeRange> {
        let now = Utc::now();

        if prompt.contains("today") {
            return Some(TimeRange {
                start: Some(now.date_naive().and_hms_opt(0, 0, 0).unwrap().and_utc()),
                end: Some(now),
            });
        }

        if prompt.contains("yesterday") {
            let yesterday = now - Duration::days(1);
            return Some(TimeRange {
                start: Some(
                    yesterday
                        .date_naive()
                        .and_hms_opt(0, 0, 0)
                        .unwrap()
                        .and_utc(),
                ),
                end: Some(
                    yesterday
                        .date_naive()
                        .and_hms_opt(23, 59, 59)
                        .unwrap()
                        .and_utc(),
                ),
            });
        }

        if let Ok(re) = Regex::new(r"last\s+(\d+)\s+(hour|day|week|month)s?") {
            if let Some(captures) = re.captures(prompt) {
                if let (Some(num_str), Some(unit)) = (captures.get(1), captures.get(2)) {
                    if let Ok(num) = num_str.as_str().parse::<i64>() {
                        let duration = match unit.as_str() {
                            "hour" => Duration::hours(num),
                            "day" => Duration::days(num),
                            "week" => Duration::weeks(num),
                            "month" => Duration::days(num * 30),
                            _ => return None,
                        };

                        return Some(TimeRange {
                            start: Some(now - duration),
                            end: Some(now),
                        });
                    }
                }
            }
        }

        None
    }

    fn extract_aggregation(&self, prompt: &str) -> Option<AggregationType> {
        if let Ok(re) = Regex::new(r"top\s+(\d+)") {
            if let Some(captures) = re.captures(prompt) {
                if let Some(num_str) = captures.get(1) {
                    if let Ok(num) = num_str.as_str().parse::<usize>() {
                        return Some(AggregationType::Top(num));
                    }
                }
            }
        }

        if prompt.contains("average") || prompt.contains("avg") {
            return Some(AggregationType::Average);
        }

        if prompt.contains("sum") || prompt.contains("total") {
            return Some(AggregationType::Sum);
        }

        if prompt.contains("count") || prompt.contains("number") {
            return Some(AggregationType::Count);
        }

        None
    }

    fn extract_limit(&self, prompt: &str) -> Option<i64> {
        if let Ok(re) = Regex::new(r"limit\s+(\d+)") {
            if let Some(captures) = re.captures(prompt) {
                if let Some(num_str) = captures.get(1) {
                    if let Ok(num) = num_str.as_str().parse::<i64>() {
                        return Some(num);
                    }
                }
            }
        }

        None
    }

    pub async fn execute_query(
        &self,
        prompt: QueryPrompt,
    ) -> Result<Vec<Metric>, Box<dyn std::error::Error>> {
        let parsed = self.parse_prompt(&prompt.prompt);

        let mut filter = crate::models::MetricFilter {
            name: parsed.metric_name,
            tags: parsed.tags,
            start_date: None,
            end_date: None,
        };

        if let Some(time_range) = parsed.time_range {
            filter.start_date = time_range.start.map(|dt| dt.to_rfc3339());
            filter.end_date = time_range.end.map(|dt| dt.to_rfc3339());
        }

        let mut metrics = self.telemetry_service.get_metrics(filter).await?;

        if let Some(aggregation) = parsed.aggregation {
            metrics = self.apply_aggregation(metrics, aggregation);
        }

        if let Some(limit) = parsed.limit {
            metrics.truncate(limit as usize);
        }

        Ok(metrics)
    }

    fn apply_aggregation(
        &self,
        mut metrics: Vec<Metric>,
        aggregation: AggregationType,
    ) -> Vec<Metric> {
        match aggregation {
            AggregationType::Top(n) => {
                metrics.sort_by(|a, b| b.value.partial_cmp(&a.value).unwrap());
                metrics.truncate(n);
                metrics
            }
            _ => metrics,
        }
    }
}
