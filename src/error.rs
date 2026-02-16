use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("Whisper error: {0}")]
    WhisperError(String),

    #[error("Model not found: {0}")]
    ModelNotFound(String),

    #[error("Invalid input: {0}")]
    InvalidInput(String),

    #[error("File processing error: {0}")]
    FileError(String),

    #[error("Internal server error: {0}")]
    InternalError(String),

    #[error("{0}")]
    Other(#[from] anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_message) = match self {
            AppError::WhisperError(ref msg) => (StatusCode::INTERNAL_SERVER_ERROR, msg.clone()),
            AppError::ModelNotFound(ref msg) => (StatusCode::NOT_FOUND, msg.clone()),
            AppError::InvalidInput(ref msg) => (StatusCode::BAD_REQUEST, msg.clone()),
            AppError::FileError(ref msg) => (StatusCode::BAD_REQUEST, msg.clone()),
            AppError::InternalError(ref msg) => (StatusCode::INTERNAL_SERVER_ERROR, msg.clone()),
            AppError::Other(ref err) => (StatusCode::INTERNAL_SERVER_ERROR, err.to_string()),
        };

        let body = Json(json!({
            "error": error_message,
            "status": status.as_u16(),
        }));

        (status, body).into_response()
    }
}

pub type AppResult<T> = Result<T, AppError>;
