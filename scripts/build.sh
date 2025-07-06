#!/bin/bash
set -e

echo "Building telemetry-server..."
cargo build --release

echo "Build completed successfully!" 