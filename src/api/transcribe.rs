use crate::{error::AppResult, whisper::TranscriptionResult, AppState};
use axum::{
    body::Bytes,
    extract::{Query, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use std::io::Write;
use std::sync::Arc;
use tempfile::NamedTempFile;

#[derive(serde::Deserialize)]
pub struct TranscribeQuery {
    pub language: Option<String>,
}

#[derive(serde::Serialize)]
pub struct TranscribeResponse {
    pub result: TranscriptionResult,
    pub processing_time_ms: u128,
}

/// Transcribe audio from multipart form data or raw bytes
pub async fn transcribe(
    State(state): State<Arc<AppState>>,
    Query(query): Query<TranscribeQuery>,
    body: Bytes,
) -> AppResult<impl IntoResponse> {
    let start_time = std::time::Instant::now();

    // Validate input
    if body.is_empty() {
        return Err(crate::error::AppError::InvalidInput(
            "Empty audio data".to_string(),
        ));
    }

    // Create temporary file for audio
    let mut temp_file = NamedTempFile::new().map_err(|e| {
        crate::error::AppError::FileError(format!("Failed to create temp file: {}", e))
    })?;

    // Write audio data to temp file
    temp_file
        .write_all(&body)
        .map_err(|e| crate::error::AppError::FileError(format!("Failed to write audio: {}", e)))?;

    // Transcribe
    let result = state
        .whisper
        .transcribe_file(temp_file.path(), query.language.as_deref())
        .await?;

    let processing_time_ms = start_time.elapsed().as_millis();

    tracing::info!(
        "Transcription completed in {}ms: {} characters",
        processing_time_ms,
        result.text.len()
    );

    Ok((
        StatusCode::OK,
        Json(TranscribeResponse {
            result,
            processing_time_ms,
        }),
    ))
}
