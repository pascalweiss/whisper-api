use crate::{error::{AppError, AppResult}, whisper::TranscriptionResult, AppState};
use axum::{
    body::Bytes,
    extract::{FromRequest, Multipart, Query, Request, State},
    http::{header::CONTENT_TYPE, StatusCode},
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
    request: Request,
) -> AppResult<impl IntoResponse> {
    let start_time = std::time::Instant::now();

    let content_type = request
        .headers()
        .get(CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("")
        .to_string();

    let body = if content_type.starts_with("multipart/form-data") {
        extract_multipart_audio(request).await?
    } else {
        Bytes::from_request(request, &())
            .await
            .map_err(|e| AppError::InvalidInput(format!("Failed to read request body: {}", e)))?
    };

    // Validate input
    if body.is_empty() {
        return Err(AppError::InvalidInput(
            "Empty audio data. Use: curl -X POST -F file=@audio.mp3 http://localhost:8000/transcribe".to_string(),
        ));
    }

    // Create temporary file for audio
    let mut temp_file = NamedTempFile::new().map_err(|e| {
        AppError::FileError(format!("Failed to create temp file: {}", e))
    })?;

    // Write audio data to temp file
    temp_file
        .write_all(&body)
        .map_err(|e| AppError::FileError(format!("Failed to write audio: {}", e)))?;

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

async fn extract_multipart_audio(request: Request) -> AppResult<Bytes> {
    let mut multipart = Multipart::from_request(request, &())
        .await
        .map_err(|e| AppError::InvalidInput(format!("Invalid multipart request: {}", e)))?;

    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|e| AppError::InvalidInput(format!("Failed to read multipart field: {}", e)))?
    {
        let data = field
            .bytes()
            .await
            .map_err(|e| AppError::InvalidInput(format!("Failed to read field data: {}", e)))?;
        if !data.is_empty() {
            return Ok(data);
        }
    }

    Err(AppError::InvalidInput(
        "No audio file found in multipart request".to_string(),
    ))
}
