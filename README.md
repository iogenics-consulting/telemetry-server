# Telemetry Server

A simple Rust-based telemetry server for performance and scale.

## Prerequisites

- [Rust](https://rustup.rs/) (latest stable version).
- Cargo (comes with Rust) — on Mac `brew install rust`.

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

## Available Scripts

The following scripts are available in the `scripts` directory:

- `./scripts/build.sh` - Builds the project in release mode
- `./scripts/test.sh` - Runs all tests
- `./scripts/lint.sh` - Runs clippy and rustfmt checks
- `./scripts/clean.sh` - Cleans build artifacts
- `./scripts/publish.sh` - Publishes the package to crates.io

## Development

1. Build the project:

   ```bash
   ./scripts/build.sh
   ```

2. Run tests:

   ```bash
   ./scripts/test.sh
   ```

3. Run linting:
   ```bash
   ./scripts/lint.sh
   ```

## Running the Server

To run the server:

```bash
cargo run
```

By default, the server runs on `http://127.0.0.1:8080`. You can change the port by setting the `PORT` environment variable:

```bash
PORT=3000 cargo run
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
