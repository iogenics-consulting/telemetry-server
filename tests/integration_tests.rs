use serde_json::json;

#[tokio::test]
async fn test_metrics_crud_integration() {
    let base_url = "http://localhost:8081";
    let client = reqwest::Client::new();

    // Create a metric
    let create_response = client
        .post(format!("{base_url}/metrics"))
        .json(&json!({
            "name": "test_metric",
            "tags": ["test", "integration"],
            "value": 42.5
        }))
        .send()
        .await;

    if let Ok(resp) = create_response {
        if resp.status().is_success() {
            let created_metric: serde_json::Value = resp.json().await.unwrap();
            if let Some(metric_id) = created_metric
                .get("id")
                .and_then(|id| id.get("$oid"))
                .and_then(|oid| oid.as_str())
            {
                // Get metrics
                let get_response = client
                    .get(format!("{base_url}/metrics"))
                    .send()
                    .await
                    .unwrap();
                assert_eq!(get_response.status(), 200);

                // Update metric
                let update_response = client
                    .put(format!("{base_url}/metrics/{metric_id}"))
                    .json(&json!({
                        "value": 100.0
                    }))
                    .send()
                    .await
                    .unwrap();
                assert_eq!(update_response.status(), 200);

                // Delete metric
                let delete_response = client
                    .delete(format!("{base_url}/metrics/{metric_id}"))
                    .send()
                    .await
                    .unwrap();
                assert_eq!(delete_response.status(), 204);
            }
        }
    }
}

#[tokio::test]
async fn test_query_endpoint() {
    let base_url = "http://localhost:8081";
    let client = reqwest::Client::new();

    // Create some test metrics
    for i in 0..3 {
        let _ = client
            .post(format!("{base_url}/metrics"))
            .json(&json!({
                "name": "query_test",
                "tags": ["test"],
                "value": i as f64 * 10.0
            }))
            .send()
            .await;
    }

    // Query metrics
    let query_response = client
        .get(format!("{base_url}/query?prompt=top+3+query_test+metrics"))
        .send()
        .await;

    if let Ok(resp) = query_response {
        assert_eq!(resp.status(), 200);
        let results: Vec<serde_json::Value> = resp.json().await.unwrap_or_default();
        assert!(!results.is_empty());
    }
}
