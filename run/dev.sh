#!/bin/bash
# Development mode - rebuilds and restarts on file changes

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔧 Whisper Rust API - Development Mode"
echo "📁 Project directory: $PROJECT_DIR"
echo ""
echo "⚠️  Make sure cargo-watch is installed:"
echo "   cargo install cargo-watch"
echo ""
echo "🚀 Starting development server (will restart on file changes)..."
echo ""

cd "$PROJECT_DIR"

# Check if cargo-watch is installed
if ! command -v cargo-watch &> /dev/null; then
    echo "❌ cargo-watch not found. Installing..."
    cargo install cargo-watch
fi

# Run with auto-reload
RUST_LOG=debug cargo watch -x 'run --release' -i target
