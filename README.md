# Telemetry Server

A fast, scalable telemetry server built in Rust, designed to collect, query, and manage metrics in real-time.

## Features

- High-performance REST API built with Actix-web
- MongoDB for flexible metric storage with automatic indexing
- Redis caching for hot queries
- Natural language query interface
- Rate limiting and request batching
- Docker support
- Comprehensive test suite

## Prerequisites

- [Rust](https://rustup.rs/) (1.74 or higher)
- Docker (for MongoDB and Redis)
- Cargo (comes with Rust)

## Installation

1. Install Rust if you haven't already:

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. Clone the repository and navigate to the project directory:
   ```bash
   git clone https://www.github.com/shincylabs/
   cd telemetry-server
   ```

## Quick Start

1. Start local MongoDB and Redis services:
   ```bash
   ./scripts/start-local-services.sh
   ```

2. Copy environment configuration:
   ```bash
   cp .env.sample .env
   ```

3. Run the server:
   ```bash
   cargo run
   ```

The server will start on `http://localhost:8080` by default.

### Using Docker Compose

```bash
docker-compose up
```

## API Endpoints

### Health & Version
- `GET /health` - Health check endpoint
- `GET /version` - Get server version information

### Metrics CRUD
- `GET /metrics?filters=` - List metrics with optional filters
- `POST /metrics` - Create a new metric
- `PUT /metrics/{id}` - Update a metric
- `DELETE /metrics/{id}` - Delete a metric

### Query Interface
- `GET /query?prompt=` - Natural language query interface

Example queries:
- `what are the top 5 events today`
- `metrics named cpu_usage from last 24 hours`
- `average memory_usage tagged with production`

## Configuration

All configuration is managed through environment files:
- `.env` - Default configuration
- `.env.{environment}` - Environment-specific configuration

Key configuration variables:
```env
APP_ENV=dev
MONGO_URI=mongodb://localhost:27017
REDIS_URI=redis://localhost:6379
PORT=8080
ENVIRONMENT=local
```

## Running Tests

Run the complete test suite:
```bash
./scripts/run-tests.sh
```

This will:
1. Start local MongoDB and Redis
2. Start the test server
3. Run all tests
4. Clean up services

## Performance Targets

| Operation | P95 Latency | P99 Latency |
|-----------|-------------|-------------|
| Read Metrics | < 30ms | < 50ms |
| Query API | < 100ms | < 200ms |
| Write Metric | < 25ms | < 40ms |
| Update Metric | < 30ms | < 50ms |
| Delete Metric | < 20ms | < 40ms |

## Development Scripts

### Core Scripts
- `./scripts/build.sh` - Build the project
- `./scripts/test.sh` - Run tests
- `./scripts/lint.sh` - Run linting
- `./scripts/clean.sh` - Clean build artifacts
- `./scripts/run-tests.sh` - Run complete test suite

### Service Management
- `./scripts/start-local-services.sh` - Start MongoDB and Redis with:
  - Auto-start Docker if not running (macOS/Linux)
  - Port conflict detection and resolution
  - Self-healing for stopped containers
  - Interactive options for handling conflicts
- `./scripts/stop-local-services.sh` - Stop MongoDB and Redis gracefully
- `./scripts/start-local-services-alt-ports.sh` - Start services on alternative ports:
  - MongoDB on port 27018 (instead of 27017)
  - Redis on port 6380 (instead of 6379)
  - Useful when default ports are in use
- `./scripts/health-check.sh` - Check system health and service status
- `./scripts/check-ports.sh` - Check which processes are using required ports

### Handling Port Conflicts

If you encounter port conflicts, you have several options:

1. **Use the interactive script**: `./scripts/start-local-services.sh` will detect conflicts and offer options
2. **Use alternative ports**: Run `./scripts/start-local-services-alt-ports.sh` and use `.env.local`
3. **Stop conflicting containers**: The script can identify and stop conflicting Docker containers
4. **Check port usage**: Run `./scripts/check-ports.sh` to see what's using the ports

## License

This project is licensed under the MIT License - see the LICENSE file for details.
