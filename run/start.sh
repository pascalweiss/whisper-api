#!/bin/bash
# Start the Whisper Rust API server

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${PROJECT_DIR}/.server.pid"

# Check if server is already running
if [ -f "$PID_FILE" ]; then
    EXISTING_PID=$(cat "$PID_FILE")
    if kill -0 "$EXISTING_PID" 2>/dev/null; then
        echo "❌ Server is already running (PID: $EXISTING_PID)"
        exit 1
    else
        # PID file exists but process is not running, clean it up
        rm "$PID_FILE"
    fi
fi

echo "🚀 Building Whisper Rust API..."
cd "$PROJECT_DIR"
cargo build --release

echo "🚀 Starting Whisper Rust API server..."

# Start server in background
RUST_LOG=info cargo run --release &
SERVER_PID=$!

# Save PID
echo $SERVER_PID > "$PID_FILE"

echo "✅ Server started with PID: $SERVER_PID"
echo "📍 API available at: http://localhost:8000"
echo "📊 Health check: curl http://localhost:8000/health"
echo "📝 Transcribe: curl -X POST -F 'file=@audio.wav' http://localhost:8000/transcribe"
echo ""
echo "To stop the server, run: ./run/stop.sh"
