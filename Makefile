.PHONY: help build dev start stop test clean format lint audit docker-build docker-start docker-stop docker-logs download-model

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
	@echo "  make start           Start the server locally"
	@echo "  make stop            Stop the local server"
	@echo "  make dev             Run with auto-reload (requires cargo-watch)"
	@echo "  make build           Build release binary"
	@echo "  make test            Run tests"
	@echo ""
	@echo "  make docker-build    Build Docker image"
	@echo "  make docker-start    Start Docker container"
	@echo "  make docker-stop     Stop Docker container"
	@echo "  make docker-logs     View Docker logs"
	@echo ""
	@echo "  make download-model  Download whisper model"
	@echo "  make format          Format code"
	@echo "  make lint            Run clippy linter"
	@echo "  make clean           Clean build artifacts"
	@echo ""
	@echo "Or use the interactive CLI: ./run/dev.sh"

build:
	cargo build --release $(CARGO_FEATURES)

start:
	./run/dev.sh start

stop:
	./run/dev.sh stop

dev:
	./run/dev.sh dev

test:
	./run/dev.sh test

docker-build:
	./run/dev.sh docker-build

docker-start:
	./run/dev.sh docker-start

docker-stop:
	./run/dev.sh docker-stop

docker-logs:
	./run/dev.sh docker-logs

download-model:
	./run/dev.sh download-model

format:
	cargo fmt

lint:
	cargo clippy --all-targets --all-features -- -D warnings

audit:
	cargo audit

clean:
	cargo clean
	rm -f .server.pid

install-tools:
	cargo install cargo-watch
	cargo install cargo-audit
