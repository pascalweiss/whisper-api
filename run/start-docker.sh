#!/bin/bash
# Start the Whisper Rust API server in Podman/Docker container

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER_NAME="whisper-api"
IMAGE_NAME="localhost/whisper-rust-api:latest"
CONTAINER_ID_FILE="${PROJECT_DIR}/.container.id"

# Determine which container runtime to use
if command -v podman &> /dev/null; then
    RUNTIME="podman"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
    IMAGE_NAME="whisper-rust-api:latest"  # Docker uses docker.io registry by default
else
    echo "❌ Neither podman nor docker is installed"
    exit 1
fi

echo "🔧 Using runtime: $RUNTIME"

# Check if container is already running
if $RUNTIME ps --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container is already running"
    exit 1
fi

# Check if container exists but is stopped
if $RUNTIME ps -a --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "🔄 Starting existing container..."
    $RUNTIME start "$CONTAINER_NAME"
    CONTAINER_ID=$($RUNTIME ps --filter "name=${CONTAINER_NAME}" --format "{{.ID}}")
    echo "$CONTAINER_ID" > "$CONTAINER_ID_FILE"
    echo "✅ Container started"
else
    # Check if image exists
    if ! $RUNTIME images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_NAME}$"; then
        echo "❌ Container image not found: ${IMAGE_NAME}"
        echo "Please build the image first: $RUNTIME build -t ${IMAGE_NAME} -f Dockerfile ."
        exit 1
    fi

    echo "🚀 Starting Whisper Rust API container..."

    # Start container with models directory mounted
    CONTAINER_ID=$($RUNTIME run -d \
        --name "$CONTAINER_NAME" \
        -p 8000:8000 \
        -v "${PROJECT_DIR}/models:/app/models:ro" \
        -e RUST_LOG=info \
        "$IMAGE_NAME")

    echo "$CONTAINER_ID" > "$CONTAINER_ID_FILE"

    echo "✅ Container started with ID: $CONTAINER_ID"
fi

# Wait for container to be ready
echo "⏳ Waiting for server to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Server is ready!"
        echo "📍 API available at: http://localhost:8000"
        echo "📊 Health check: curl http://localhost:8000/health"
        echo "📝 Transcribe: curl -X POST -F 'file=@audio.wav' http://localhost:8000/transcribe"
        echo ""
        echo "To stop the container, run: ./run/stop-docker.sh"
        echo "To view logs, run: $RUNTIME logs ${CONTAINER_NAME}"
        exit 0
    fi
    sleep 1
done

echo "❌ Server failed to start within 30 seconds"
echo "Check logs with: $RUNTIME logs ${CONTAINER_NAME}"
exit 1
