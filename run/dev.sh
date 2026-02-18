#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Whisper API - Unified Development CLI
# ============================================================================
# A single CLI for building, running, and managing the Whisper API.
#
# Usage:
#   ./run/dev.sh [command]
#
# Commands:
#   start            Start the API server locally (with Metal GPU on macOS)
#   stop             Stop the local server
#   dev              Run in development mode with auto-reload
#   docker-build     Build the Docker/Podman image
#   docker-start     Start in Docker/Podman container
#   docker-stop      Stop the Docker/Podman container
#   docker-logs      View Docker/Podman container logs
#   download-model   Download the whisper model
#   test             Run tests
#   doctor           Check development environment
#   help             Show this help
#
# With no arguments, an interactive fzf menu is shown.
#
# Examples:
#   ./run/dev.sh                  # Interactive menu
#   ./run/dev.sh start            # Start locally with GPU
#   ./run/dev.sh docker-start     # Start in container
#   ./run/dev.sh doctor           # Check environment
# ============================================================================

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# State
PID_FILE="$root_dir/.server.pid"
CONTAINER_NAME="whisper-api"
CACHE_DIR="$root_dir/run/.cache"
DEFAULT_MODEL_PATH="./models/ggml-large-v3-turbo.bin"

mkdir -p "$CACHE_DIR"

# Load .env if exists
if [[ -f "$root_dir/.env" ]]; then
    set -a
    source "$root_dir/.env"
    set +a
fi

# ============================================================================
# Helper Functions
# ============================================================================

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_fzf() {
    if ! command -v fzf >/dev/null 2>&1; then
        log_error "fzf is required for interactive selection"
        echo "Install with: brew install fzf"
        exit 1
    fi
}

detect_runtime() {
    if command -v podman &>/dev/null; then
        echo "podman"
    elif command -v docker &>/dev/null; then
        echo "docker"
    else
        echo ""
    fi
}

get_image_name() {
    local runtime="$1"
    if [[ "$runtime" == "podman" ]]; then
        echo "localhost/whisper-rust-api:latest"
    else
        echo "whisper-rust-api:latest"
    fi
}

detect_cargo_features() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "--features metal"
    else
        echo ""
    fi
}

is_local_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

is_docker_running() {
    local runtime
    runtime=$(detect_runtime)
    [[ -z "$runtime" ]] && return 1
    $runtime ps --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER_NAME}$"
}

resolve_model_path() {
    if [[ -n "${WHISPER_MODEL:-}" ]]; then
        echo "${WHISPER_MODEL}"
        return
    fi

    if [[ -f "$root_dir/.env" ]]; then
        local env_model
        env_model=$(grep -E '^[[:space:]]*WHISPER_MODEL=' "$root_dir/.env" 2>/dev/null | tail -n 1 | cut -d '=' -f 2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        if [[ -n "${env_model}" ]]; then
            echo "${env_model}"
            return
        fi
    fi

    echo "${DEFAULT_MODEL_PATH}"
}

print_help() {
    cat << 'HELP'
Whisper API - Unified Development CLI

Usage:
  ./run/dev.sh [command]

Commands:
  start            Start the API server locally (with Metal GPU on macOS)
  stop             Stop the local server
  dev              Run in development mode with auto-reload
  docker-build     Build the Docker/Podman image
  docker-start     Start in Docker/Podman container
  docker-stop      Stop the Docker/Podman container
  docker-logs      View Docker/Podman container logs
  download-model   Download the whisper model
  test             Run tests
  doctor           Check development environment
  help             Show this help

With no arguments, an interactive fzf menu is shown.

Examples:
  ./run/dev.sh                  # Interactive menu
  ./run/dev.sh start            # Start locally with GPU
  ./run/dev.sh docker-start     # Start in container
  ./run/dev.sh doctor           # Check environment
HELP
}

# ============================================================================
# Commands
# ============================================================================

cmd_start() {
    if is_local_running; then
        local pid
        pid=$(cat "$PID_FILE")
        log_warn "Server is already running (PID: $pid)"
        exit 1
    fi

    local features
    features=$(detect_cargo_features)

    log_info "Building Whisper API... ${features:+(${features})}"
    cargo build --release $features

    log_info "Starting server..."
    RUST_LOG=info cargo run --release $features &
    local pid=$!
    echo "$pid" > "$PID_FILE"

    log_success "Server started (PID: $pid)"
    echo "API: http://localhost:8000"
    echo "Stop: ./run/dev.sh stop"
}

cmd_stop() {
    if [[ ! -f "$PID_FILE" ]]; then
        log_warn "Server is not running (no PID file)"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")

    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
        log_warn "Server process not found (PID: $pid)"
        rm -f "$PID_FILE"
        return 0
    fi

    log_info "Stopping server (PID: $pid)..."
    kill "$pid"

    for _ in {1..10}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            log_success "Server stopped"
            rm -f "$PID_FILE"
            return 0
        fi
        sleep 1
    done

    log_warn "Force killing..."
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    log_success "Server force-stopped"
}

cmd_dev() {
    if ! command -v cargo-watch &>/dev/null; then
        log_info "Installing cargo-watch..."
        cargo install cargo-watch
    fi

    local features
    features=$(detect_cargo_features)

    log_info "Starting development server (auto-reload)... ${features:+(${features})}"
    RUST_LOG=debug cargo watch -x "run --release $features" -i target
}

cmd_docker_build() {
    local runtime
    runtime=$(detect_runtime)
    if [[ -z "$runtime" ]]; then
        log_error "Neither podman nor docker is installed"
        exit 1
    fi

    local image_name
    image_name=$(get_image_name "$runtime")

    log_info "Using runtime: $runtime"

    # Git-based change detection for skipping unnecessary builds
    if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
        local cache_key stamp_file head_rev status new_fp old_fp=""
        cache_key=$(printf '%s' "$runtime|$image_name|Dockerfile" | shasum -a 256 | awk '{print $1}')
        stamp_file="$CACHE_DIR/docker-build-${cache_key}.stamp"
        head_rev=$(git rev-parse --verify HEAD 2>/dev/null || echo 'no-head')
        status=$(git status --porcelain=v1 --untracked-files=no)
        new_fp=$(printf '%s\n%s\n%s\n' "$head_rev" "$status" "Dockerfile" | shasum -a 256 | awk '{print $1}')
        [[ -f "$stamp_file" ]] && old_fp=$(cat "$stamp_file")

        if [[ "$new_fp" == "$old_fp" ]]; then
            log_success "No changes detected. Skipping image build."
            return 0
        fi

        log_info "Changes detected. Building image..."
        $runtime build -t "$image_name" -f Dockerfile .
        printf '%s' "$new_fp" > "$stamp_file"
    else
        $runtime build -t "$image_name" -f Dockerfile .
    fi

    log_success "Build complete: $image_name"
}

cmd_docker_start() {
    local runtime
    runtime=$(detect_runtime)
    if [[ -z "$runtime" ]]; then
        log_error "Neither podman nor docker is installed"
        exit 1
    fi

    local image_name
    image_name=$(get_image_name "$runtime")
    local model_path="${WHISPER_MODEL:-/app/models/ggml-large-v3-turbo.bin}"
    local model_file
    model_file=$(basename "$model_path")
    local host_model_path="$root_dir/models/$model_file"

    log_info "Using runtime: $runtime"

    # Check podman VM memory for large models
    if [[ "$runtime" == "podman" && "$model_file" == "ggml-large-v3-turbo.bin" ]]; then
        local mem_mb_raw mem_mb mem_total min_mem
        mem_mb_raw=$($runtime machine inspect podman-machine-default --format '{{.Resources.Memory}}' 2>/dev/null || true)
        mem_mb=$(printf '%s' "${mem_mb_raw}" | tr -dc '0-9')
        [[ -z "$mem_mb" ]] && mem_mb=0
        mem_total=$((mem_mb * 1024 * 1024))
        min_mem=$((4 * 1024 * 1024 * 1024))
        if (( mem_total < min_mem )); then
            log_error "Podman VM memory too low for ${model_file}."
            echo "Fix: podman machine stop && podman machine set --memory 6144 && podman machine start"
            exit 1
        fi
    fi

    # Download model if missing
    if [[ ! -f "$host_model_path" ]]; then
        log_warn "Model not found: $host_model_path"
        WHISPER_MODEL="$model_path" cmd_download_model
    fi

    # Check if already running
    if is_docker_running; then
        log_error "Container is already running"
        exit 1
    fi

    # Remove stopped container
    if $runtime ps -a --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Removing existing stopped container..."
        $runtime rm "$CONTAINER_NAME" >/dev/null
    fi

    # Check image exists
    if ! $runtime images --format "{{.Repository}}:{{.Tag}}" 2>&1 | grep -q "^${image_name}$"; then
        log_error "Image not found: $image_name"
        echo "Build it first: ./run/dev.sh docker-build"
        exit 1
    fi

    log_info "Starting container..."
    $runtime run -d \
        --name "$CONTAINER_NAME" \
        -p 8000:8000 \
        -v "$root_dir/models:/app/models:ro" \
        -e RUST_LOG=info \
        -e WHISPER_MODEL="$model_path" \
        "$image_name" >/dev/null

    # Wait for health check
    log_info "Waiting for server..."
    for _ in {1..60}; do
        if curl -s http://localhost:8000/health >/dev/null 2>&1; then
            log_success "Server is ready!"
            echo "API: http://localhost:8000"
            echo "Logs: ./run/dev.sh docker-logs"
            echo "Stop: ./run/dev.sh docker-stop"
            return 0
        fi
        sleep 1
    done

    log_error "Server failed to start within 60 seconds"
    echo "Check logs: ./run/dev.sh docker-logs"
    exit 1
}

cmd_docker_stop() {
    local runtime
    runtime=$(detect_runtime)
    if [[ -z "$runtime" ]]; then
        log_error "Neither podman nor docker is installed"
        exit 1
    fi

    if ! is_docker_running; then
        log_warn "Container is not running"
        return 0
    fi

    log_info "Stopping container..."
    $runtime stop "$CONTAINER_NAME" >/dev/null
    log_success "Container stopped"
}

cmd_docker_logs() {
    local runtime
    runtime=$(detect_runtime)
    if [[ -z "$runtime" ]]; then
        log_error "Neither podman nor docker is installed"
        exit 1
    fi

    $runtime logs -f "$CONTAINER_NAME"
}

cmd_download_model() {
    local model_path
    model_path=$(resolve_model_path)
    local model_file
    model_file=$(basename "$model_path")

    # For absolute container-style paths, download into local ./models
    local target_path
    if [[ "$model_path" = /* ]]; then
        target_path="$root_dir/models/$model_file"
    else
        target_path="$root_dir/$model_path"
    fi

    local download_url="${WHISPER_MODEL_URL:-https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${model_file}}"

    mkdir -p "$(dirname "$target_path")"

    if [[ -f "$target_path" ]]; then
        log_success "Model already exists: $target_path"
        return 0
    fi

    log_info "Downloading: $download_url"
    log_info "Target: $target_path"

    if command -v curl >/dev/null 2>&1; then
        curl -fL "$download_url" -o "$target_path"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$target_path" "$download_url"
    else
        log_error "Neither curl nor wget is installed"
        exit 1
    fi

    log_success "Model downloaded: $target_path"
}

cmd_test() {
    log_info "Running tests..."
    RUST_BACKTRACE=1 cargo test --verbose
    log_success "Tests completed"
}

cmd_doctor() {
    echo "Whisper API - Environment Check"
    echo ""

    # Rust
    if command -v cargo >/dev/null 2>&1; then
        echo -e "${GREEN}+${NC} cargo: $(cargo --version)"
    else
        echo -e "${RED}x${NC} cargo not found (install Rust: https://rustup.rs)"
    fi

    # ffmpeg
    if command -v ffmpeg >/dev/null 2>&1; then
        echo -e "${GREEN}+${NC} ffmpeg: $(ffmpeg -version 2>&1 | head -1)"
    else
        echo -e "${RED}x${NC} ffmpeg not found (brew install ffmpeg)"
    fi

    # fzf
    if command -v fzf >/dev/null 2>&1; then
        echo -e "${GREEN}+${NC} fzf: $(fzf --version 2>&1 | head -1)"
    else
        echo -e "${YELLOW}~${NC} fzf not found (optional, brew install fzf)"
    fi

    # Container runtime
    local runtime
    runtime=$(detect_runtime)
    if [[ -n "$runtime" ]]; then
        echo -e "${GREEN}+${NC} container runtime: $runtime"
    else
        echo -e "${YELLOW}~${NC} no container runtime (optional)"
    fi

    # GPU
    echo ""
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo -e "${GREEN}+${NC} macOS detected: Metal GPU acceleration available for local builds"
    else
        echo -e "${BLUE}i${NC} Linux detected: use CUDA=1 make build for NVIDIA GPU support"
    fi

    # Model
    echo ""
    local model_path
    model_path=$(resolve_model_path)
    local model_file
    model_file=$(basename "$model_path")
    local host_path="$root_dir/models/$model_file"
    if [[ -f "$host_path" ]]; then
        local size
        size=$(du -h "$host_path" | cut -f1)
        echo -e "${GREEN}+${NC} model: $model_file ($size)"
    else
        echo -e "${RED}x${NC} model not found: $host_path"
        echo "  Run: ./run/dev.sh download-model"
    fi

    # Running services
    echo ""
    if is_local_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo -e "${GREEN}+${NC} local server: running (PID $pid)"
    else
        echo -e "${YELLOW}~${NC} local server: stopped"
    fi

    if [[ -n "$runtime" ]]; then
        if is_docker_running; then
            echo -e "${GREEN}+${NC} docker container: running"
        else
            echo -e "${YELLOW}~${NC} docker container: stopped"
        fi
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    local command="${1:-}"

    if [[ "$command" == "-h" || "$command" == "--help" || "$command" == "help" ]]; then
        print_help
        exit 0
    fi

    # Interactive fzf menu when no command given
    if [[ -z "$command" ]]; then
        check_fzf

        local header="Whisper API"
        is_local_running && header+=" | Local: running"
        is_docker_running && header+=" | Docker: running"

        local selection
        selection=$(printf '%s\n' \
            "Start local server" \
            "Stop local server" \
            "Development mode (auto-reload)" \
            "Build Docker image" \
            "Start Docker container" \
            "Stop Docker container" \
            "View Docker logs" \
            "Download model" \
            "Run tests" \
            "Check environment" \
            | fzf --height=40% --reverse \
                  --header="$header" \
                  --prompt="Action > ") || exit 0

        case "$selection" in
            "Start local server")              command="start" ;;
            "Stop local server")               command="stop" ;;
            "Development mode (auto-reload)")  command="dev" ;;
            "Build Docker image")              command="docker-build" ;;
            "Start Docker container")          command="docker-start" ;;
            "Stop Docker container")           command="docker-stop" ;;
            "View Docker logs")                command="docker-logs" ;;
            "Download model")                  command="download-model" ;;
            "Run tests")                       command="test" ;;
            "Check environment")               command="doctor" ;;
            *)                                 exit 0 ;;
        esac
    fi

    case "$command" in
        start)          cmd_start ;;
        stop)           cmd_stop ;;
        dev)            cmd_dev ;;
        docker-build)   cmd_docker_build ;;
        docker-start)   cmd_docker_start ;;
        docker-stop)    cmd_docker_stop ;;
        docker-logs)    cmd_docker_logs ;;
        download-model) cmd_download_model ;;
        test)           cmd_test ;;
        doctor)         cmd_doctor ;;
        *)
            log_error "Unknown command: $command"
            print_help
            exit 1
            ;;
    esac
}

main "$@"
