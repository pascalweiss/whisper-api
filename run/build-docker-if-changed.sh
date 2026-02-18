#!/bin/bash
# Build the container image only when tracked source changes are detected.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${PROJECT_DIR}/run/.cache"
mkdir -p "${CACHE_DIR}"

# Determine runtime and image naming (mirrors run/start-docker.sh)
if command -v podman &> /dev/null; then
    RUNTIME="podman"
    IMAGE_NAME="localhost/whisper-rust-api:latest"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
    IMAGE_NAME="whisper-rust-api:latest"
else
    echo "❌ Neither podman nor docker is installed"
    exit 1
fi

# Allow override when needed
IMAGE_NAME="${IMAGE_NAME_OVERRIDE:-$IMAGE_NAME}"

echo "🔧 Using runtime: $RUNTIME"
echo "🏷️  Image: $IMAGE_NAME"

if ! command -v git &> /dev/null; then
    echo "❌ git is required for change detection"
    exit 1
fi

cd "$PROJECT_DIR"

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Not inside a git repository: $PROJECT_DIR"
    exit 1
fi

CACHE_KEY=$(printf '%s' "$RUNTIME|$IMAGE_NAME|Dockerfile" | shasum -a 256 | awk '{print $1}')
STAMP_FILE="${CACHE_DIR}/docker-build-${CACHE_KEY}.stamp"

HEAD_REV="$(git rev-parse --verify HEAD 2>/dev/null || echo 'no-head')"
STATUS="$(git status --porcelain=v1 --untracked-files=no)"
NEW_FINGERPRINT="$(printf '%s\n%s\n%s\n' "$HEAD_REV" "$STATUS" "Dockerfile" | shasum -a 256 | awk '{print $1}')"

OLD_FINGERPRINT=""
if [[ -f "$STAMP_FILE" ]]; then
    OLD_FINGERPRINT="$(cat "$STAMP_FILE")"
fi

if [[ "$NEW_FINGERPRINT" == "$OLD_FINGERPRINT" ]]; then
    echo "✅ No tracked changes detected. Skipping image build."
    exit 0
fi

echo "🔨 Changes detected. Building image..."
$RUNTIME build -t "$IMAGE_NAME" -f Dockerfile .

printf '%s' "$NEW_FINGERPRINT" > "$STAMP_FILE"
echo "✅ Build complete."
