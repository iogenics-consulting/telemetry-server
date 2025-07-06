## 📦 Project: `telemetry-server`

A fast, scalable telemetry server built in **Rust**, designed to collect, query, and manage metrics in real-time.

---

## 🛠️ Stack

| Component        | Technology                |
| ---------------- | ------------------------- |
| Language         | Rust (`actix-web`)        |
| Database         | MongoDB (`mongodb` crate) |
| Cache            | Redis (`redis` crate)     |
| API Type         | REST (via `actix-web`)    |
| Containerization | Docker                    |

---

## 📁 Directory Structure

```
telemetry-server/
├── src/
│   ├── main.rs
│   ├── config.rs
│   ├── db/
│   │   ├── mongo.rs
│   │   └── redis.rs
│   ├── models/
│   │   ├── metric.rs
│   │   └── query.rs
│   ├── routes/
│   │   ├── metrics.rs
│   │   └── query.rs
│   └── services/
│       ├── telemetry_service.rs
│       └── query_service.rs
├── Dockerfile
├── .env
└── Cargo.toml
```

---

## 🔐 Configuration (via `.env`)

```env
APP_ENV=dev
MONGO_URI=mongodb://username:password@host:port
REDIS_URI=redis://localhost:6379
PORT=8080
```

MongoDB will use: `telemetry_server_${APP_ENV}`

---

## 🧩 Data Models

### `Metric`

```rust
use serde::{Serialize, Deserialize};
use bson::DateTime;

#[derive(Debug, Serialize, Deserialize)]
pub struct Metric {
    pub id: Option<bson::oid::ObjectId>,
    pub name: String,
    pub tags: Option<Vec<String>>,
    pub value: f64,
    pub timestamp: DateTime,
}
```

### `QueryPrompt`

```rust
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct QueryPrompt {
    pub prompt: String,
}
```

---

## 🌐 REST API Endpoints

### CRUD: `/metrics`

| Method | Endpoint            | Description                                                       |
| ------ | ------------------- | ----------------------------------------------------------------- |
| GET    | `/metrics?filters=` | List metrics with optional filters (e.g. name, tags, date range). |
| POST   | `/metrics`          | Create a new metric.                                              |
| PUT    | `/metrics/{id}`     | Update a metric.                                                  |
| DELETE | `/metrics/{id}`     | Delete a metric.                                                  |

### Query Interface

- `GET /query?prompt=what+are+the+top+5+events+today`

Parses natural-language-like prompts using heuristics or keyword matching to perform DB queries.

---

## ⚙️ Performance Features

- Actix Web for async concurrency and blazing speed.
- MongoDB: fast insert-heavy workloads, good for semi-structured metrics.
- Redis: caches hot queries and computed results.
- Connection pooling for Mongo/Redis.
- Rate limiting & request batching (optionally via middleware).
- Tag- or label-based metric indexing.

---

## 🐳 Dockerfile

```Dockerfile
FROM rust:1.74 as builder

WORKDIR /app
COPY . .
RUN apt-get update && apt-get install -y pkg-config libssl-dev
RUN cargo build --release

FROM debian:bullseye-slim
WORKDIR /app
COPY --from=builder /app/target/release/telemetry-server .
COPY .env .
CMD ["./telemetry-server"]
```

---

## 🧠 Why MongoDB?

Pros:

- Flexible schema – ideal for varying metrics.
- Native support for date-based queries and secondary indexes.
- Fast insert performance.
- Scales with sharding for large event volumes.

Cons:

- Limited for complex aggregations (can be offloaded to Redis or handled in memory).
- Needs TTL/index tuning to maintain performance at scale.

✅ **MongoDB is suitable if metrics are event-like or log-like.** For high-frequency time-series data, InfluxDB/TimescaleDB may be considered in future.

---

Here’s a breakdown of **target latency metrics** for the `telemetry-server`, aligned with its high-performance, scalable design in Rust:

---

## ⏱️ **Target Latency Metrics**

| Operation Type              | Endpoint(s)             | Target P95 Latency | Target P99 Latency | Notes                                                             |
| --------------------------- | ----------------------- | ------------------ | ------------------ | ----------------------------------------------------------------- |
| 🔍 **Read: Fetch Metrics**  | `GET /metrics?filters=` | **< 30ms**         | **< 50ms**         | Redis-cached, index-backed Mongo queries.                         |
| 🧠 **Query Prompt API**     | `GET /query?prompt=`    | **< 100ms**        | **< 200ms**        | Includes basic parsing, fallback to DB or cache.                  |
| ✏️ **Write: Insert Metric** | `POST /metrics`         | **< 25ms**         | **< 40ms**         | Write to MongoDB with minimal processing.                         |
| 🛠️ **Update Metric**        | `PUT /metrics/{id}`     | **< 30ms**         | **< 50ms**         | Index-based update on. `_id`                                      |
| ❌ **Delete Metric**        | `DELETE /metrics/{id}`  | **< 20ms**         | **< 40ms**         | Soft or hard. delete                                              |
| 📦 **Cold Start API**       | Any                     | **< 500ms**        | **< 800ms**        | After container start, once Redis/Mongo connection pools warm up. |

---

## 📊 System-Level Performance Goals

- **Throughput:**
  ≥ 10,000 requests/sec under load (via load balancing + Actix concurrency).

- **Redis Cache Hit Rate:**
  ≥ 90% for `GET /metrics` for recent/filtered queries.

- **Mongo Insert Performance:**
  ≥ 100k events/minute (shardable).

---

## 🧪 Benchmarking Setup

We recommend load-testing with tools like:

- [`wrk`](https://github.com/wg/wrk) or [`wrk2`](https://github.com/giltene/wrk2).
- [`k6`](https://k6.io/) for scenario-based metrics.
- Custom Rust test runner for tail latency validation.

Example test:

```bash
wrk -t4 -c100 -d30s --latency http://localhost:8080/metrics
```

## Configuration

- All configuration will be managed in the .env file.
- ENVIRONMENT="local,dev,test,staging,prod" will be used and the corresponding env file will be `.env.${envirionment}`.
- If environment-specific env is not found, fallback to `.env`.
- Refer to `env.sample` file for which variables to add.
- Add a script for spinning up MongoDB database and Redis instance locally.

---

## Workflow

1. Write the code.
2. Write the tests.
3. Start server, run the tests.
4. Shut the server, fix failing tests.
5. Repeat the Steps 1-4 till build, lint, validate and tests pass and changes are done.

**NOTE:** Write a script if needed to start a test server instance with `.env.test` and run the tests then stop the server.

## 📌 Enhancements (Future Ideas)

- WebSocket / SSE support for live metric updates.
- LLM plugin for smart querying.
- OpenTelemetry SDK integration.
- Aggregation APIs (e.g. top-k, percentile over time).
- RBAC / API key auth.
