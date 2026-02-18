use crate::{
    error::{AppError, AppResult},
    AppState,
};
use axum::{extract::State, Json};
use serde::Serialize;
use serde_json::json;
use std::{fs, path::PathBuf, sync::Arc};

#[derive(Debug, Serialize)]
struct ModelEntry {
    name: String,
    path: String,
    size_bytes: u64,
}

/// List available model files in the configured model directory.
pub async fn list_models(State(state): State<Arc<AppState>>) -> AppResult<Json<serde_json::Value>> {
    let configured_model = state.config.model_path.clone();
    let model_dir = configured_model
        .parent()
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("./models"));

    let entries = fs::read_dir(&model_dir).map_err(|e| {
        AppError::InternalError(format!(
            "Failed to read model directory {}: {}",
            model_dir.display(),
            e
        ))
    })?;

    let mut models: Vec<ModelEntry> = Vec::new();

    for entry in entries {
        let entry = entry.map_err(|e| {
            AppError::InternalError(format!(
                "Failed to read model directory entry in {}: {}",
                model_dir.display(),
                e
            ))
        })?;

        let path = entry.path();
        if !path.is_file() {
            continue;
        }

        let Some(name) = path.file_name().and_then(|n| n.to_str()).map(String::from) else {
            continue;
        };

        if !name.starts_with("ggml-") || !name.ends_with(".bin") {
            continue;
        }

        let metadata = entry.metadata().map_err(|e| {
            AppError::InternalError(format!(
                "Failed to read metadata for {}: {}",
                path.display(),
                e
            ))
        })?;

        models.push(ModelEntry {
            name,
            path: path.display().to_string(),
            size_bytes: metadata.len(),
        });
    }

    models.sort_by(|a, b| a.name.cmp(&b.name));

    Ok(Json(json!({
        "configured_model_path": configured_model.display().to_string(),
        "configured_model_exists": configured_model.is_file(),
        "model_directory": model_dir.display().to_string(),
        "models": models,
        "count": models.len()
    })))
}
