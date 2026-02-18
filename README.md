# Whisper Rust API

![Rust](https://img.shields.io/badge/Rust-1.70%2B-orange)
![Version](https://img.shields.io/badge/version-0.2.0-blue)
![Docker](https://img.shields.io/badge/Docker-ready-brightgreen)
![License](https://img.shields.io/badge/License-MIT-green)

A speech-to-text transcription API powered by [OpenAI's Whisper](https://openai.com/research/whisper) model. Convert audio files to text with high accuracy.

## What it does

This API transcribes audio files to text. Simply upload an audio file and get back the transcribed text along with segment-level details including timestamps.

## Quick Start

### Prerequisites

- A machine with ffmpeg installed (for audio format support)
- 2GB+ of disk space for the model file

### Setup and Run

1. **Clone and navigate to the project**
   ```bash
   git clone <repository-url>
   cd whisper-rust-api
   ```

2. **Download the transcription model**
   ```bash
   make download-model
   ```

3. **Configure (optional)**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` if you need to change the port or other settings.

4. **Start the API**
   ```bash
   make start
   ```

The API is now running at `http://localhost:8000`

## Using the API

### Transcribe Audio

Upload an audio file to be transcribed:

```bash
curl -X POST --data-binary @audio.mp3 http://localhost:8000/transcribe
```

Supported formats: WAV, MP3, M4A, FLAC, OGG, and more.

**Response:**
```json
{
  "result": {
    "text": "Hello world. How are you today?",
    "segments": [
      { "id": 0, "start": 0, "end": 1500, "text_start": 0, "text_end": 12 },
      { "id": 1, "start": 1500, "end": 3200, "text_start": 12, "text_end": 31 }
    ]
  },
  "processing_time_ms": 1234
}
```

Each segment includes audio timestamps (`start`/`end` in milliseconds) and character offsets (`text_start`/`text_end`) into the full `text` string.

### Check API Status

```bash
curl http://localhost:8000/health
```

Response:
```json
{
  "status": "ok",
  "version": "0.2.0"
}
```

### Get API Info

```bash
curl http://localhost:8000/info
```

Shows the current model, configuration, and available endpoints.

### List Available Models

```bash
curl http://localhost:8000/models
```

Lists model files found in the configured model directory and indicates whether the configured model exists.

## Helper Scripts

Run `make help` to see all available commands:

```
make start         # Start the API server
make stop          # Stop the API server
make dev           # Run with auto-reload for development
make build         # Build the application
make test          # Run tests
make clean         # Clean up build files
make docker-run    # Run in Docker
make docker-down   # Stop Docker container
make docker-logs   # View Docker logs
```

## Deployment Options

### Local Installation

Requires Rust to be installed. Then:

```bash
make build
make start
```

### Docker

The easiest way to deploy:

```bash
make docker-run
```

Or use Docker Compose directly:

```bash
docker-compose up -d
```

To stop:

```bash
make docker-down
```

## Configuration

Create a `.env` file (copy from `.env.example`) to customize:

| Setting | Default | Purpose |
|---------|---------|---------|
| `WHISPER_PORT` | 8000 | Port the API listens on |
| `WHISPER_HOST` | 0.0.0.0 | Host address |
| `WHISPER_THREADS` | 4 | Number of CPU threads to use |
| `WHISPER_MODEL` | `./models/ggml-base.en.bin` | Path to the model file |
| `RUST_LOG` | info | Logging detail (debug, info, warn, error) |

### Model Selection

The default model (`base.en`) is optimized for English and is ~140MB.

For other languages or different accuracy/speed tradeoffs, download a different model from [Hugging Face](https://huggingface.co/ggerganov/whisper.cpp):

- **tiny.en** (75MB) - Fastest, English only
- **base.en** (140MB) - Default, English only
- **small.en** (466MB) - Better accuracy, English only
- **medium.en** (1.5GB) - High accuracy, English only
- **tiny** (75MB) - Supports 99 languages
- **base** (140MB) - Supports 99 languages
- **small** (466MB) - Supports 99 languages

To use a different model:

```bash
# Download the model
wget -O models/ggml-small.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin

# Update .env
echo "WHISPER_MODEL=./models/ggml-small.en.bin" >> .env

# Restart the API
make stop
make start
```

## Troubleshooting

### "Model file not found" error

Run `make download-model` to download the default model.

### "ffmpeg not found" error

Install ffmpeg:

```bash
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt-get install ffmpeg

# Fedora
sudo dnf install ffmpeg
```

### Port 8000 is already in use

Change the port in `.env`:
```
WHISPER_PORT=8001
```

### Transcription is slow

- Use a smaller model (e.g., `tiny.en` instead of `base.en`)
- Increase `WHISPER_THREADS` in `.env` (if your CPU has multiple cores)
- Ensure no other heavy processes are running

### Out of memory errors

Use a smaller model:
```
WHISPER_MODEL=./models/ggml-tiny.en.bin
```

## Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/transcribe` | Upload audio and get transcription |
| GET | `/health` | Check if API is running |
| GET | `/info` | Get API information and configuration |
| GET | `/models` | List available model files in model directory |

## Performance Tips

- **Audio format**: WAV files process faster than MP3 (no conversion needed)
- **File size**: Smaller audio files process faster
- **Threads**: More threads = faster processing on multi-core systems (up to CPU core count)
- **Model size**: Smaller models are faster but less accurate

## Need Help?

- Check the Docker logs: `make docker-logs`
- Review the configuration in `.env`
- Ensure the model file was downloaded: `ls models/ggml-*.bin`
- Verify ffmpeg is installed: `ffmpeg -version`
