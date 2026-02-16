#!/bin/bash
# Run tests and generate coverage report

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_DIR"

echo "🧪 Running tests..."
RUST_BACKTRACE=1 cargo test --verbose

echo ""
echo "✅ Tests completed"
