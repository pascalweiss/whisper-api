# Whisper Rust API

🚀 **High-performance transcription API powered by whisper.cpp and Rust**

A modern, efficient REST API for audio transcription using the `whisper-rs` bindings to whisper.cpp. Built with Axum web framework and Tokio async runtime.

## Features

- ⚡ **Fast**: Compiled Rust binary with minimal overhead
- 🔒 **Safe**: Memory-safe Rust implementation with no unsafe code in API layer
- 🎯 **Simple**: Clean REST API with minimal dependencies
- 📦 **Self-contained**: Single binary deployment
- 🐳 **Docker-ready**: Optimized multi-stage Dockerfile
- 📊 **Observable**: Structured logging with tracing
- 🔧 **Configurable**: Environment variables and command-line arguments

## Architecture

```
whisper-rust-api/
├── src/
│   ├── main.rs           # Application entry point and server setup
│   ├── config.rs         # Configuration management (env vars + CLI args)
│   ├── error.rs          # Error types and HTTP response mapping
│   ├── whisper.rs        # Whisper.cpp integration and audio processing
│   └── api/
│       ├── mod.rs        # API module exports
│       ├── transcribe.rs # Transcription endpoint
│       └── info.rs       # Info/metadata endpoint
├── run/                  # Operational scripts
│   ├── start.sh         # Start the server
│   ├── stop.sh          # Stop the server
│   ├── dev.sh           # Development mode with auto-reload
│   └── test.sh          # Run tests
├── Dockerfile           # Production Docker image
├── Cargo.toml           # Rust dependencies
└── README.md
```

## Dependencies

### Core Dependencies
- **axum** - Modern async web framework
- **tokio** - Async runtime with full features
- **whisper-rs** - Rust bindings to whisper.cpp
- **serde/serde_json** - Serialization
- **tracing** - Structured logging

### Build Dependencies
- Rust 1.75+
- CMake (for whisper.cpp compilation)
- OpenSSL development headers

## Installation

### Prerequisites

1. **Rust**: Install from [rustup.rs](https://rustup.rs/)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **Whisper Model**: Download a model file
   ```bash
   mkdir -p models
   # Download a model (e.g., base.en: ~140MB)
   wget https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin -O models/ggml-base.en.bin
   ```

### Build from Source

```bash
# Clone/navigate to project
cd /Users/pweiss/dev/whisper-rust-api

# Build release binary
cargo build --release

# Binary will be at: target/release/whisper-rust-api
```

## Usage

### Quick Start

```bash
# Start the server
./run/start.sh

# Test health endpoint
curl http://localhost:8000/health

# Get API info
curl http://localhost:8000/info

# Transcribe audio
curl -X POST -F "file=@audio.wav" http://localhost:8000/transcribe
```

### Stop Server

```bash
./run/stop.sh
```

### Development Mode (with auto-reload)

```bash
./run/dev.sh
# Requires: cargo install cargo-watch
```

### Run Tests

```bash
./run/test.sh
```

## Configuration

Configure via environment variables or command-line arguments:

```bash
# Environment variables (higher priority)
export WHISPER_MODEL=/path/to/model.bin
export WHISPER_HOST=0.0.0.0
export WHISPER_PORT=8000
export WHISPER_THREADS=4
export RUST_LOG=debug

# Or command-line arguments
cargo run -- --model-path /path/to/model.bin --port 9000

# Or .env file
echo "WHISPER_MODEL=./models/ggml-base.en.bin" > .env
cargo run
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WHISPER_MODEL` | `./models/ggml-base.en.bin` | Path to whisper.cpp model |
| `WHISPER_HOST` | `0.0.0.0` | Server bind address |
| `WHISPER_PORT` | `8000` | Server port |
| `WHISPER_THREADS` | `4` | Inference threads |
| `RUST_LOG` | `info` | Log level (debug, info, warn, error) |

## API Endpoints

### POST /transcribe

Transcribe audio file.

**Request:**
- Method: `POST`
- Content-Type: `application/octet-stream` or multipart form data
- Body: Raw audio bytes (16-bit PCM WAV format)

**Response:**
```json
{
  "result": {
    "text": "Full transcription text",
    "segments": [
      {
        "id": 0,
        "start": 0,
        "end": 1234,
        "text": "Segment text"
      }
    ]
  },
  "processing_time_ms": 5234
}
```

**Example:**
```bash
curl -X POST \
  -H "Content-Type: application/octet-stream" \
  --data-binary @audio.wav \
  http://localhost:8000/transcribe
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

### GET /info

Get API information and configuration.

**Response:**
```json
{
  "name": "Whisper Rust API",
  "version": "0.1.0",
  "model_path": "/path/to/model.bin",
  "threads": 4,
  "endpoints": {
    "POST /transcribe": "Transcribe audio file",
    "GET /health": "Health check",
    "GET /info": "API information"
  }
}
```

## Docker Deployment

### Build Image

```bash
docker build -t whisper-rust-api .
```

### Run Container

```bash
# Basic
docker run -p 8000:8000 \
  -v $(pwd)/models:/app/models \
  whisper-rust-api

# With custom model
docker run -p 8000:8000 \
  -e WHISPER_MODEL=/app/models/ggml-large.bin \
  -v $(pwd)/models:/app/models \
  whisper-rust-api

# Detached with health check
docker run -d \
  --name whisper-api \
  -p 8000:8000 \
  -v $(pwd)/models:/app/models \
  --health-cmd='curl -f http://localhost:8000/health' \
  --health-interval=30s \
  whisper-rust-api
```

### Docker Compose

Create `docker-compose.yml`:
```yaml
version: '3.8'

services:
  whisper-api:
    build: .
    ports:
      - "8000:8000"
    environment:
      RUST_LOG: info
      WHISPER_THREADS: 4
    volumes:
      - ./models:/app/models
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

Start: `docker-compose up`

## Performance

### Benchmarks

Running on Apple Silicon (M3 Max):

| Model | Audio Length | Time | Memory |
|-------|-------------|------|--------|
| base.en (140MB) | 30s | ~3s | ~200MB |
| small.en (461MB) | 30s | ~8s | ~500MB |
| medium.en (1.5GB) | 30s | ~20s | ~1.2GB |

### Optimization Tips

1. **Use smaller models** for faster inference (tiny, base, small)
2. **Increase threads** for multi-core systems: `WHISPER_THREADS=8`
3. **Pre-warm** by making a dummy request after startup
4. **Batch requests** via a message queue for high throughput

## Development

### Project Structure

- **src/main.rs**: Server initialization and route setup
- **src/config.rs**: Configuration loading from env vars and CLI args
- **src/error.rs**: Error types and HTTP response handling
- **src/whisper.rs**: whisper.cpp integration layer
- **src/api/transcribe.rs**: Transcription endpoint handler
- **src/api/info.rs**: Info endpoint handler

### Adding New Endpoints

1. Create new file in `src/api/`
2. Implement handler function
3. Add route in `main.rs`
4. Export in `src/api/mod.rs`

Example:
```rust
// src/api/custom.rs
pub async fn custom_handler(State(state): State<Arc<AppState>>) -> Json<serde_json::Value> {
    Json(json!({ "custom": "response" }))
}

// In main.rs
.route("/custom", get(api::custom::custom_handler))
```

### Debugging

Enable debug logging:
```bash
RUST_LOG=debug ./run/dev.sh
```

### Code Quality

```bash
# Format code
cargo fmt

# Lint
cargo clippy --all-targets --all-features

# Check for issues
cargo audit
```

## Maintenance & Updates

### Updating Dependencies

```bash
# Check for updates
cargo outdated

# Update all dependencies
cargo update

# Update specific dependency
cargo update --package package-name
```

### Monitoring

Check logs:
```bash
# If running with docker-compose
docker-compose logs -f whisper-api

# If running directly
RUST_LOG=debug ./run/start.sh
```

## Troubleshooting

### Model not found
```
Error: Model file not found: ./models/ggml-base.en.bin
```
**Solution:** Download model or set correct path via `WHISPER_MODEL` env var

### Audio processing error
```
Error: No audio data found in file
```
**Solution:** Ensure audio is 16-bit PCM WAV format. Convert using ffmpeg:
```bash
ffmpeg -i audio.mp3 -acodec pcm_s16le -ar 16000 audio.wav
```

### Out of memory
```
Killed or memory allocation failed
```
**Solution:** Use smaller model or increase available memory

## License

MIT

## Contributing

Contributions welcome! Please:
1. Follow Rust naming conventions
2. Add tests for new features
3. Run `cargo fmt` and `cargo clippy` before submitting
4. Update README for new features

## Support

For issues with whisper.cpp, see: https://github.com/ggerganov/whisper.cpp
For Axum/Rust async issues, see: https://github.com/tokio-rs/axum
