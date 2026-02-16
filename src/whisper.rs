use crate::error::{AppError, AppResult};
use std::path::Path;
use std::sync::Mutex;
use whisper_rs::WhisperContext as WhisperCtx;

/// Wrapper around whisper.cpp context with thread-safe initialization
pub struct WhisperContext {
    context: Mutex<WhisperCtx>,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct TranscriptionResult {
    pub text: String,
    pub segments: Vec<Segment>,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct Segment {
    pub id: i32,
    pub start: i64,
    pub end: i64,
    pub text: String,
}

impl WhisperContext {
    /// Create a new Whisper context from a model file
    pub fn new<P: AsRef<Path>>(model_path: P) -> AppResult<Self> {
        let path = model_path.as_ref();

        // Check if model file exists
        if !path.exists() {
            return Err(AppError::ModelNotFound(format!(
                "Model file not found: {}",
                path.display()
            )));
        }

        // Initialize whisper context
        let context = WhisperCtx::new(path.to_string_lossy().as_ref())
            .map_err(|e| AppError::WhisperError(format!("Failed to initialize model: {:?}", e)))?;

        tracing::info!("Whisper model initialized successfully");

        Ok(WhisperContext {
            context: Mutex::new(context),
        })
    }

    /// Transcribe audio from bytes
    pub fn transcribe(&self, audio: &[u8]) -> AppResult<TranscriptionResult> {
        // Convert audio bytes to f32 samples
        // Note: This assumes 16-bit PCM WAV format
        let samples = self.bytes_to_samples(audio)?;

        // Run inference
        let mut params = whisper_rs::FullParams::new(whisper_rs::SamplingStrategy::Greedy {
            best_of: 1,
        });

        params.set_language(Some("en"));
        params.set_print_realtime(false);
        params.set_print_progress(false);
        params.set_print_timestamps(false);
        params.set_print_special(false);

        let mut context = self
            .context
            .lock()
            .map_err(|e| AppError::InternalError(format!("Failed to acquire context lock: {}", e)))?;

        context
            .full(params, &samples)
            .map_err(|e| AppError::WhisperError(format!("Transcription failed: {:?}", e)))?;

        // Extract results
        let mut full_text = String::new();
        let mut segments = Vec::new();

        let num_segments = context.full_n_segments();

        for i in 0..num_segments {
            let segment_text = context
                .full_get_segment_text(i)
                .map_err(|e| AppError::WhisperError(format!("Failed to get segment text: {:?}", e)))?;
            let start = context.full_get_segment_t0(i);
            let end = context.full_get_segment_t1(i);

            full_text.push_str(&segment_text);

            segments.push(Segment {
                id: i as i32,
                start,
                end,
                text: segment_text,
            });
        }

        Ok(TranscriptionResult {
            text: full_text,
            segments,
        })
    }

    /// Transcribe from audio file
    pub async fn transcribe_file(&self, file_path: &Path) -> AppResult<TranscriptionResult> {
        let audio_data = tokio::fs::read(file_path)
            .await
            .map_err(|e| AppError::FileError(format!("Failed to read audio file: {}", e)))?;

        self.transcribe(&audio_data)
    }

    /// Convert raw audio bytes to f32 samples
    /// Assumes 16-bit PCM WAV format
    fn bytes_to_samples(&self, audio_bytes: &[u8]) -> AppResult<Vec<f32>> {
        // Skip WAV header (44 bytes for standard WAV)
        let data_start = if audio_bytes.len() > 44
            && &audio_bytes[0..4] == b"RIFF"
            && &audio_bytes[8..12] == b"WAVE"
        {
            44
        } else {
            0
        };

        if audio_bytes.len() <= data_start {
            return Err(AppError::InvalidInput("Audio file too small".to_string()));
        }

        let audio_data = &audio_bytes[data_start..];
        let samples: Vec<f32> = audio_data
            .chunks_exact(2)
            .map(|chunk| {
                let sample = i16::from_le_bytes([chunk[0], chunk[1]]) as f32 / 32768.0;
                sample.clamp(-1.0, 1.0)
            })
            .collect();

        if samples.is_empty() {
            return Err(AppError::InvalidInput(
                "No audio data found in file".to_string(),
            ));
        }

        Ok(samples)
    }
}
