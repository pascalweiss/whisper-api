use clap::Parser;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Parser, Serialize, Deserialize)]
#[command(name = "Whisper Rust API")]
#[command(about = "High-performance transcription API powered by whisper.cpp", long_about = None)]
pub struct Config {
    /// Path to the whisper.cpp model file
    #[arg(short, long, default_value = "./models/ggml-base.en.bin", env = "WHISPER_MODEL")]
    pub model_path: PathBuf,

    /// Server host address
    #[arg(long, default_value = "0.0.0.0", env = "WHISPER_HOST")]
    pub host: String,

    /// Server port
    #[arg(long, default_value = "8000", env = "WHISPER_PORT")]
    pub port: u16,

    /// Number of threads for inference
    #[arg(long, default_value = "4", env = "WHISPER_THREADS")]
    pub threads: i32,

    /// Log level
    #[arg(long, default_value = "info", env = "RUST_LOG")]
    pub log_level: String,
}

impl Config {
    /// Load configuration from command line arguments and environment variables
    pub fn load() -> anyhow::Result<Self> {
        dotenv::dotenv().ok();
        Ok(Self::parse())
    }
}
