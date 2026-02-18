# Quick Start Guide

## One-Time Setup

```bash
# Download the configured model (required)
./run/download-model.sh

# Copy env example
cp .env.example .env
```

## Start/Stop Server

```bash
# Start the server
./run/start.sh

# In another terminal, test it
curl http://localhost:8000/health

# Stop when done
./run/stop.sh
```

## Transcribe Audio

```bash
# Transcribe a WAV file
curl -X POST \
  --data-binary @audio.wav \
  http://localhost:8000/transcribe | jq .

# Or with a form field
curl -X POST -F "file=@audio.wav" \
  http://localhost:8000/transcribe | jq .
```

## Development

```bash
# Auto-reloading development mode (requires cargo-watch)
./run/dev.sh

# Run tests
./run/test.sh

# Format code
cargo fmt

# Lint
cargo clippy
```

## Docker

```bash
# Build image
docker build -t whisper-rust-api .

# Run container
docker run -p 8000:8000 \
  -v $(pwd)/models:/app/models \
  whisper-rust-api

# Test container
curl http://localhost:8000/health
```

## Common Issues

**Model not found:**
```bash
# Check that model file exists
ls -lh models/ggml-base.en.bin

# Download if missing
wget https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin \
  -O models/ggml-base.en.bin
```

**Audio format error:**
```bash
# Convert MP3 to WAV with ffmpeg
ffmpeg -i audio.mp3 -acodec pcm_s16le -ar 16000 audio.wav
```

**Port 8000 in use:**
```bash
# Use different port
WHISPER_PORT=9000 ./run/start.sh

# Or kill existing process
./run/stop.sh
```

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/transcribe` | POST | Transcribe audio |
| `/health` | GET | Health check |
| `/info` | GET | API info |
| `/models` | GET | List available model files |

## Environment Variables

- `WHISPER_MODEL` - Path to model (default: ./models/ggml-base.en.bin)
- `WHISPER_HOST` - Server host (default: 0.0.0.0)
- `WHISPER_PORT` - Server port (default: 8000)
- `WHISPER_THREADS` - Inference threads (default: 4)
- `RUST_LOG` - Log level (debug/info/warn/error)

## Available Models

Whisper models at [HuggingFace](https://huggingface.co/ggerganov/whisper.cpp):

- **tiny** (31MB) - Fastest, lowest quality
- **base** (140MB) - Good balance
- **small** (461MB) - Better quality
- **medium** (1.5GB) - High quality
- **large** (2.9GB) - Highest quality

Download format: `ggml-{MODEL}.bin` for English, `ggml-{MODEL}-q5_0.bin` for quantized
