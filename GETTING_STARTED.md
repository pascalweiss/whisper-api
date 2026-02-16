# Getting Started: Whisper Rust API

## Quick Comparison

### Original C++ Application
- **Setup Time**: 30+ minutes (CMake, vcpkg bootstrap, dependencies)
- **Build Time**: 15+ minutes first build
- **Docker Time**: 15-20 minutes
- **Code Base**: ~15,000+ lines across multiple binaries
- **Learning Curve**: Requires C++, CMake, vcpkg knowledge
- **Deployment**: Multiple binaries, complex Docker setup

### Rust API (This Project)
- **Setup Time**: 5 minutes (download model, run)
- **Build Time**: 2-3 minutes (cargo cached compilation)
- **Docker Time**: 3-5 minutes (with Docker layer caching)
- **Code Base**: ~400 lines of pure Rust
- **Learning Curve**: Learn Rust async/web concepts
- **Deployment**: Single binary, simple Docker

## 5-Minute Quick Start

```bash
# 1. Go to the project
cd /Users/pweiss/dev/whisper-rust-api

# 2. Download a model (one-time setup)
make download-model

# 3. Start the server
make start

# 4. In another terminal, test it
curl http://localhost:8000/health

# 5. Transcribe audio
curl -X POST --data-binary @audio.wav http://localhost:8000/transcribe

# 6. Stop when done
make stop
```

## Installation & Setup

### Prerequisites

1. **Rust** (if not already installed)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   ```

2. **Model File** (required, one-time download)
   ```bash
   make download-model
   # Downloads to: models/ggml-base.en.bin (~140MB)
   ```

### Verify Installation

```bash
# Check Rust version
rustc --version

# Build project
make build
# Output: target/release/whisper-rust-api (~10MB binary)

# Run tests
make test
```

## Running the API

### Standard Mode
```bash
make start
# Server runs in background, PID saved to .server.pid
# Access at: http://localhost:8000
```

### Development Mode (Auto-reload)
```bash
make dev
# Server restarts automatically on file changes
# Requires: cargo install cargo-watch
```

### Docker
```bash
# Build image
make docker-build

# Run in Docker
make docker-run
# Server available at: http://localhost:8000

# View logs
make docker-logs

# Stop
make docker-down
```

## API Usage

### Endpoints

**Transcribe Audio**
```bash
# From file
curl -X POST \
  --data-binary @audio.wav \
  http://localhost:8000/transcribe | jq .

# Response:
{
  "result": {
    "text": "hello world this is a test",
    "segments": [
      {
        "id": 0,
        "start": 0,
        "end": 1234,
        "text": "hello world"
      }
    ]
  },
  "processing_time_ms": 3456
}
```

**Health Check**
```bash
curl http://localhost:8000/health

# Response:
{
  "status": "ok",
  "version": "0.1.0"
}
```

**API Info**
```bash
curl http://localhost:8000/info

# Response:
{
  "name": "Whisper Rust API",
  "version": "0.1.0",
  "model_path": "./models/ggml-base.en.bin",
  "threads": 4,
  "endpoints": { ... }
}
```

## Configuration

### Environment Variables
```bash
# Model path
export WHISPER_MODEL=./models/ggml-small.en.bin

# Server config
export WHISPER_HOST=0.0.0.0
export WHISPER_PORT=8000

# Performance
export WHISPER_THREADS=8

# Logging
export RUST_LOG=debug

# Run
make start
```

### Using .env File
```bash
# Copy example
cp .env.example .env

# Edit
nano .env

# Will be loaded automatically on start
make start
```

## Troubleshooting

### Issue: "Model not found"
```bash
# Solution: Download model
make download-model

# Or set correct path
export WHISPER_MODEL=/path/to/model.bin
make start
```

### Issue: "Port 8000 in use"
```bash
# Use different port
export WHISPER_PORT=9000
make start

# Or stop existing server
make stop
```

### Issue: Build fails with "whisper-rs not found"
```bash
# Update Rust and dependencies
rustup update
cargo update
make clean
make build
```

### Issue: Audio "has no data"
```bash
# Ensure audio is 16-bit PCM WAV
# Convert with ffmpeg:
ffmpeg -i audio.mp3 -acodec pcm_s16le -ar 16000 audio.wav

# Then transcribe
curl -X POST --data-binary @audio.wav http://localhost:8000/transcribe
```

## Common Tasks

### Code Quality
```bash
# Format code
make format

# Lint
make lint

# Security audit
make audit
```

### Testing
```bash
# Run unit tests
make test

# Run with verbose output
cargo test -- --nocapture
```

### Building
```bash
# Development build (faster compilation)
cargo build

# Release build (optimized, smaller)
make build
# Binary: target/release/whisper-rust-api

# Check compilation (no actual build)
cargo check
```

### Docker Operations
```bash
# Build image
make docker-build

# Run image
make docker-run

# View running containers
docker ps

# View logs
make docker-logs

# Stop and remove
make docker-down

# Enter shell in container
docker-compose exec whisper-api sh
```

## Comparing with Original C++ Application

### Development Workflow

**Original (C++)**
```bash
# Complex setup
cd /Users/pweiss/dev/whisper-cpp-server
cmake -B cmake-build-release
cmake --build cmake-build-release
./cmake-build-release/whisper_http_server_base_httplib \
  -m models/ggml-base.en.bin \
  --host 0.0.0.0 --port 8000

# Docker (complicated)
podman build -f Dockerfile.production -t whisper-cpp-server
podman run -p 8000:8000 -v models:/models whisper-cpp-server
```

**New (Rust)**
```bash
# Simple setup
cd /Users/pweiss/dev/whisper-rust-api
make download-model
make start

# Docker (simple)
make docker-build
make docker-run
```

### Maintenance Comparison

**Updating Dependencies**

*Original C++*
```bash
# Edit vcpkg.json, update baseline, resolve CMake issues...
# Rebuild everything (15+ minutes)
# Hope nothing broke
```

*Rust API*
```bash
# cargo update
# Rebuild (2-3 minutes, cached)
# Compile errors tell you exactly what needs fixing
```

### Code Organization

**Original C++**: Multiple binaries (httplib, uwebsockets, SDL2), scattered logic
```
whisper-cpp-server/
├── whisper_http_server_base_httplib.cpp (300+ lines)
├── whisper_server_base_on_uwebsockets.cpp
├── common/common.cpp
├── common/common-m4a.cpp
├── handler/inference_handler.cpp
├── ...  (many more files)
```

**Rust API**: Clean, modular structure
```
whisper-rust-api/
├── src/main.rs (73 lines)
├── src/api/transcribe.rs (61 lines)
├── src/whisper.rs (151 lines)
├── src/config.rs (36 lines)
└── src/error.rs (50 lines)
Total: 392 lines of Rust
```

## Next Steps

1. **Explore the Code**
   ```bash
   cat README.md              # Full documentation
   cat ARCHITECTURE.md        # Design decisions
   cat run/QUICK_START.md    # Quick reference
   ```

2. **Try Transcription**
   ```bash
   # Get sample audio or create one
   make start
   curl -X POST --data-binary @audio.wav http://localhost:8000/transcribe
   make stop
   ```

3. **Customize**
   - Add authentication
   - Add request queuing
   - Modify error handling
   - Add metrics
   - See ARCHITECTURE.md for ideas

4. **Deploy**
   ```bash
   make docker-build
   docker push my-registry/whisper-api
   # Deploy with docker-compose or Kubernetes
   ```

## Support Resources

- **Rust Learning**: https://doc.rust-lang.org/book/
- **Axum Framework**: https://github.com/tokio-rs/axum
- **whisper-rs**: https://github.com/tazz4843/whisper-rs
- **whisper.cpp**: https://github.com/ggerganov/whisper.cpp
- **Project README**: `README.md`
- **Quick Start**: `run/QUICK_START.md`

## Key Advantages Summary

✅ **Fast Setup**: 5 minutes vs 30+ minutes
✅ **Quick Builds**: 2-3 min vs 15+ minutes
✅ **Single Binary**: Deploy easily
✅ **Type Safety**: Errors caught at compile time
✅ **Clean Code**: ~400 lines vs 15,000+
✅ **Easy Maintenance**: Update deps in minutes
✅ **Better Docs**: Comprehensive guides
✅ **Ready to Deploy**: Docker, compose, scripts included

## Support

For issues:
1. Check `run/QUICK_START.md` for common solutions
2. Check logs: `RUST_LOG=debug make start`
3. Check dependencies: `cargo audit`
4. See README.md troubleshooting section
