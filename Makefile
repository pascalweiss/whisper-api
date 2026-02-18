.PHONY: help build dev start stop test clean format lint audit docker-build docker-run docker-down download-model

# Auto-detect GPU features by platform
UNAME_S := $(shell uname -s)
CARGO_FEATURES :=
ifeq ($(UNAME_S),Darwin)
    CARGO_FEATURES := --features metal
endif
ifdef CUDA
    CARGO_FEATURES := --features cuda
endif

help:
	@echo "Whisper Rust API - Available Commands"
	@echo ""
	@echo "Development:"
	@echo "  make dev           Run with auto-reload (requires cargo-watch)"
	@echo "  make build         Build release binary"
	@echo "  make format        Format code"
	@echo "  make lint          Run clippy linter"
	@echo "  make audit         Check for security vulnerabilities"
	@echo ""
	@echo "Running:"
	@echo "  make start         Start the server"
	@echo "  make stop          Stop the server"
	@echo "  make test          Run tests"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-build  Build Docker image"
	@echo "  make docker-run    Run Docker container"
	@echo "  make docker-down   Stop Docker container"
	@echo ""
	@echo "Setup:"
	@echo "  make download-model Download whisper model"
	@echo "  make clean         Clean build artifacts"

build:
	cargo build --release $(CARGO_FEATURES)

dev:
	./run/dev.sh

start:
	./run/start.sh

stop:
	./run/stop.sh

test:
	./run/test.sh

format:
	cargo fmt

lint:
	cargo clippy --all-targets --all-features -- -D warnings

audit:
	cargo audit

clean:
	cargo clean
	rm -f .server.pid

download-model:
	./run/download-model.sh

docker-build:
	docker build -t whisper-rust-api .

docker-run:
	docker-compose up -d

docker-down:
	docker-compose down

docker-logs:
	docker-compose logs -f

# Install cargo-watch for auto-reload
install-tools:
	cargo install cargo-watch
	cargo install cargo-audit
