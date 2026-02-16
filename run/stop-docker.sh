#!/bin/bash
# Stop the Whisper Rust API Podman/Docker container

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER_NAME="whisper-api"
CONTAINER_ID_FILE="${PROJECT_DIR}/.container.id"

# Determine which container runtime to use
if command -v podman &> /dev/null; then
    RUNTIME="podman"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
else
    echo "❌ Neither podman nor docker is installed"
    exit 1
fi

echo "🔧 Using runtime: $RUNTIME"

# Check if container is running
if ! $RUNTIME ps --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container is not running"
    rm -f "$CONTAINER_ID_FILE"
    exit 1
fi

echo "🛑 Stopping container..."

# Stop the container
$RUNTIME stop "$CONTAINER_NAME"

# Clean up ID file
rm -f "$CONTAINER_ID_FILE"

echo "✅ Container stopped successfully"
echo ""
echo "To remove the container completely, run: $RUNTIME rm ${CONTAINER_NAME}"
echo "To start again, run: ./run/start-docker.sh"
