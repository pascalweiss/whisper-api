use crate::AppState;
use axum::{extract::State, Json};
use serde_json::json;
use std::sync::Arc;

/// Get API information and configuration
pub async fn get_info(State(state): State<Arc<AppState>>) -> Json<serde_json::Value> {
    Json(json!({
        "name": "Whisper Rust API",
        "version": env!("CARGO_PKG_VERSION"),
        "model_path": state.config.model_path.display().to_string(),
        "threads": state.config.threads,
        "endpoints": {
            "POST /transcribe": "Transcribe audio file",
            "GET /health": "Health check",
            "GET /info": "API information",
            "GET /models": "List available model files"
        }
    }))
}
