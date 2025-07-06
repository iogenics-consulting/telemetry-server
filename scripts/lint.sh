#!/bin/bash
set -e

echo "Running clippy..."
cargo clippy -- -D warnings

echo "Running rustfmt check..."
cargo fmt -- --check

echo "Linting completed successfully!" 