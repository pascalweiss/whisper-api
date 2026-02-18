#!/bin/bash
# Download the model referenced by WHISPER_MODEL.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_MODEL_PATH="./models/ggml-large-v3-turbo.bin"

resolve_model_path() {
    if [[ -n "${WHISPER_MODEL:-}" ]]; then
        echo "${WHISPER_MODEL}"
        return
    fi

    if [[ -f "${PROJECT_DIR}/.env" ]]; then
        local env_model
        env_model=$(grep -E '^[[:space:]]*WHISPER_MODEL=' "${PROJECT_DIR}/.env" | tail -n 1 | cut -d '=' -f 2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        if [[ -n "${env_model}" ]]; then
            echo "${env_model}"
            return
        fi
    fi

    if [[ -f "${PROJECT_DIR}/docker-compose.yml" ]]; then
        local compose_model
        compose_model=$(grep -E '^[[:space:]]*WHISPER_MODEL:[[:space:]]*' "${PROJECT_DIR}/docker-compose.yml" | tail -n 1 | cut -d ':' -f 2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        if [[ -n "${compose_model}" ]]; then
            echo "${compose_model}"
            return
        fi
    fi

    echo "${DEFAULT_MODEL_PATH}"
}

MODEL_PATH="$(resolve_model_path)"
MODEL_FILE="$(basename "${MODEL_PATH}")"

if [[ "${MODEL_FILE}" != ggml-*.bin ]]; then
    echo "⚠️  Model filename does not match whisper.cpp ggml pattern: ${MODEL_FILE}"
fi

# For absolute container-style paths (e.g. /app/models/...), download into local ./models.
if [[ "${MODEL_PATH}" = /* ]]; then
    TARGET_PATH="${PROJECT_DIR}/models/${MODEL_FILE}"
else
    TARGET_PATH="${PROJECT_DIR}/${MODEL_PATH}"
fi

TARGET_DIR="$(dirname "${TARGET_PATH}")"
DOWNLOAD_URL="${WHISPER_MODEL_URL:-https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${MODEL_FILE}}"

mkdir -p "${TARGET_DIR}"

echo "🎯 Resolved model path: ${MODEL_PATH}"
echo "📥 Download target: ${TARGET_PATH}"
echo "🌐 Download URL: ${DOWNLOAD_URL}"

if [[ -f "${TARGET_PATH}" ]]; then
    echo "✅ Model already exists at ${TARGET_PATH}"
    exit 0
fi

if command -v curl >/dev/null 2>&1; then
    curl -fL "${DOWNLOAD_URL}" -o "${TARGET_PATH}"
elif command -v wget >/dev/null 2>&1; then
    wget -O "${TARGET_PATH}" "${DOWNLOAD_URL}"
else
    echo "❌ Neither curl nor wget is installed"
    exit 1
fi

echo "✅ Model downloaded to ${TARGET_PATH}"
