# Multi-stage Rust build for whisper-rust-api
#
# GPU Note: This container builds CPU-only by default. Apple Metal GPU is NOT
# available inside Linux containers (Docker/Podman run a Linux VM on macOS,
# which has no access to the Metal framework). For GPU-accelerated transcription:
#   - macOS: Run natively with `./run/dev.sh start` (Metal is auto-enabled)
#   - Linux + NVIDIA: Build with `docker build --build-arg GPU_FEATURES=cuda .`

# Stage 1: Builder
FROM rust:latest as builder

# GPU acceleration: set to "cuda" for NVIDIA GPU support, or leave empty for CPU-only.
# "metal" is NOT supported in containers (see note above).
ARG GPU_FEATURES=""

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    pkg-config \
    libssl-dev \
    clang \
    libclang-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy Cargo files
COPY Cargo.toml Cargo.lock* ./

# Copy source code
COPY src ./src

# Build application (pass --features cuda via GPU_FEATURES for NVIDIA GPU support)
RUN if [ -n "$GPU_FEATURES" ]; then \
        cargo build --release --features "$GPU_FEATURES"; \
    else \
        cargo build --release; \
    fi

# Stage 2: Runtime
FROM debian:testing

WORKDIR /app

# Install runtime dependencies (including ffmpeg for audio format conversion)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    ca-certificates \
    curl \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy binary from builder
COPY --from=builder /app/target/release/whisper-rust-api /app/

# Create models directory
RUN mkdir -p /app/models

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Environment
ENV RUST_LOG=info
ENV WHISPER_HOST=0.0.0.0
ENV WHISPER_PORT=8000

# Run application
ENTRYPOINT ["/app/whisper-rust-api"]
CMD []
