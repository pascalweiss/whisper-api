use axum::{
    extract::DefaultBodyLimit,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use std::sync::Arc;
use tower_http::cors::CorsLayer;
use tracing_subscriber;

mod api;
mod config;
mod error;
mod whisper;

use config::Config;
use whisper::WhisperContext;

pub struct AppState {
    config: Config,
    whisper: Arc<WhisperContext>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("whisper_rust_api=debug".parse()?),
        )
        .init();

    // Load configuration
    let config = Config::load()?;
    tracing::info!("Configuration loaded: {:?}", config);

    // Initialize Whisper context
    let whisper = Arc::new(WhisperContext::new(&config.model_path)?);
    tracing::info!("Whisper model loaded from: {}", config.model_path.display());

    let state = AppState { config, whisper };

    // Build router
    let app = Router::new()
        .route("/health", get(health_check))
        .route("/transcribe", post(api::transcribe::transcribe))
        .route("/info", get(api::info::get_info))
        .route("/models", get(api::models::list_models))
        .layer(DefaultBodyLimit::max(100 * 1024 * 1024))
        .layer(CorsLayer::permissive())
        .with_state(Arc::new(state));

    // Start server
    let listener = tokio::net::TcpListener::bind(&format!("{}:{}", "0.0.0.0", "8000")).await?;

    let server_addr = listener.local_addr()?;
    tracing::info!("🚀 Server listening on http://{}", server_addr);

    axum::serve(listener, app).await?;

    Ok(())
}

async fn health_check() -> impl IntoResponse {
    Json(serde_json::json!({
        "status": "ok",
        "version": env!("CARGO_PKG_VERSION")
    }))
}
