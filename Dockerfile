# Multi-stage Rust build for whisper-rust-api

# Stage 1: Builder
FROM rust:latest as builder

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

# Build application
RUN cargo build --release

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
