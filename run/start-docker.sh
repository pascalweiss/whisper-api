#!/bin/bash
# Start the Whisper Rust API server in Podman/Docker container

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER_NAME="whisper-api"
IMAGE_NAME="localhost/whisper-rust-api:latest"
CONTAINER_ID_FILE="${PROJECT_DIR}/.container.id"
MODEL_PATH="${WHISPER_MODEL:-/app/models/ggml-large-v3-turbo.bin}"
MODEL_FILE="$(basename "$MODEL_PATH")"
HOST_MODEL_PATH="${PROJECT_DIR}/models/${MODEL_FILE}"

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
echo "🎯 Model path in container: $MODEL_PATH"

# If Podman VM memory is too low for large-v3-turbo, fail early with guidance.
if [[ "$RUNTIME" == "podman" && "$MODEL_FILE" == "ggml-large-v3-turbo.bin" ]]; then
    MEM_MB_RAW="$($RUNTIME machine inspect podman-machine-default --format '{{.Resources.Memory}}' 2>/dev/null || true)"
    MEM_MB="$(printf '%s' "${MEM_MB_RAW}" | tr -dc '0-9')"
    if [[ -z "${MEM_MB}" ]]; then
        MEM_MB=0
    fi
    MEM_TOTAL=$((MEM_MB * 1024 * 1024))
    MIN_MEM=$((4 * 1024 * 1024 * 1024))
    if (( MEM_TOTAL < MIN_MEM )); then
        echo "❌ Podman memory is too low for ${MODEL_FILE} (${MEM_TOTAL} bytes detected)."
        echo "The turbo model needs >3.3GB model memory plus runtime overhead."
        echo "Fix:"
        echo "  podman machine stop"
        echo "  podman machine set --memory 6144"
        echo "  podman machine start"
        exit 1
    fi
fi

# Ensure the referenced model exists locally; auto-download if missing.
if [[ ! -f "$HOST_MODEL_PATH" ]]; then
    echo "⬇️  Model not found locally: $HOST_MODEL_PATH"
    echo "Attempting to download model..."
    WHISPER_MODEL="$MODEL_PATH" "${PROJECT_DIR}/run/download-model.sh"
fi

# Check if container is already running
if $RUNTIME ps --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container is already running"
    exit 1
fi

# Remove any stopped container so startup always reflects latest image/env.
if $RUNTIME ps -a --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "🧹 Removing existing stopped container..."
    $RUNTIME rm "$CONTAINER_NAME" >/dev/null
fi

# Check if image exists
IMAGES_OUTPUT=$($RUNTIME images --format "{{.Repository}}:{{.Tag}}" 2>&1)
echo "DEBUG images output: $(echo "$IMAGES_OUTPUT" | head -3)"
if ! echo "$IMAGES_OUTPUT" | grep -q "^${IMAGE_NAME}$"; then
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
    -e WHISPER_MODEL="$MODEL_PATH" \
    "$IMAGE_NAME")

echo "$CONTAINER_ID" > "$CONTAINER_ID_FILE"

echo "✅ Container started with ID: $CONTAINER_ID"

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
