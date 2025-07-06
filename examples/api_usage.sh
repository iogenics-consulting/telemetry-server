#!/bin/bash

# Example usage of the Telemetry Server API

BASE_URL="http://localhost:8080"

echo "1. Health check:"
curl -s "$BASE_URL/health" | jq

echo -e "\n2. Version info:"
curl -s "$BASE_URL/version" | jq

echo -e "\n3. Create a metric:"
RESPONSE=$(curl -s -X POST "$BASE_URL/metrics" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "cpu_usage",
    "tags": ["server-1", "production"],
    "value": 75.5
  }')

echo "$RESPONSE" | jq

METRIC_ID=$(echo "$RESPONSE" | jq -r '._id."$oid"')
echo "Created metric with ID: $METRIC_ID"

echo -e "\n4. Get all metrics:"
curl -s "$BASE_URL/metrics" | jq

echo -e "\n5. Update the metric:"
curl -s -X PUT "$BASE_URL/metrics/$METRIC_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "value": 80.2
  }' | jq

echo -e "\n6. Query metrics with natural language:"
curl -s "$BASE_URL/query?prompt=top+5+cpu_usage+metrics+today" | jq

echo -e "\n7. Delete the metric:"
curl -s -X DELETE "$BASE_URL/metrics/$METRIC_ID"
echo "Metric deleted"