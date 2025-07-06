#!/bin/bash
set -e

# Ensure we're on main branch
if [[ $(git branch --show-current) != "main" ]]; then
    echo "Error: Must be on main branch to publish"
    exit 1
fi

# Ensure working directory is clean
if [[ -n $(git status -s) ]]; then
    echo "Error: Working directory is not clean"
    exit 1
fi

# Run tests
./scripts/test.sh

# Run linting
./scripts/lint.sh

# Build release
./scripts/build.sh

echo "Publishing to crates.io..."
cargo publish

echo "Package published successfully!" 