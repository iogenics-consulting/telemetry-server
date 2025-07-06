#!/bin/bash
set -e

echo "Running tests..."
cargo test -- --nocapture

echo "Tests completed successfully!" 