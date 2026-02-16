#!/bin/bash
# Stop the Whisper Rust API server

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${PROJECT_DIR}/.server.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "❌ Server is not running (no PID file found)"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ! kill -0 "$PID" 2>/dev/null; then
    echo "❌ Server process not found (PID: $PID)"
    rm "$PID_FILE"
    exit 1
fi

echo "🛑 Stopping server (PID: $PID)..."
kill "$PID"

# Wait for process to exit
for i in {1..10}; do
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "✅ Server stopped successfully"
        rm "$PID_FILE"
        exit 0
    fi
    sleep 1
done

# Force kill if still running
echo "⚠️  Forcing kill..."
kill -9 "$PID" 2>/dev/null || true
rm "$PID_FILE"
echo "✅ Server force-stopped"
