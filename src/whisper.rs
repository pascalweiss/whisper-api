use crate::error::{AppError, AppResult};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Mutex;
use whisper_rs::{WhisperContext as WhisperCtx, WhisperContextParameters};

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
    pub text_start: usize,
    pub text_end: usize,
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
        let context = WhisperCtx::new_with_params(
            path.to_string_lossy().as_ref(),
            WhisperContextParameters::default(),
        )
        .map_err(|e| AppError::WhisperError(format!("Failed to initialize model: {:?}", e)))?;

        tracing::info!("Whisper model initialized successfully");

        Ok(WhisperContext {
            context: Mutex::new(context),
        })
    }

    /// Transcribe audio from bytes.
    /// If `language` is `None`, Whisper will auto-detect the language.
    pub fn transcribe(
        &self,
        audio: &[u8],
        language: Option<&str>,
    ) -> AppResult<TranscriptionResult> {
        // Convert audio bytes to f32 samples
        // Note: This assumes 16-bit PCM WAV format
        let samples = self.bytes_to_samples(audio)?;

        // Run inference
        let mut params =
            whisper_rs::FullParams::new(whisper_rs::SamplingStrategy::Greedy { best_of: 1 });

        params.set_language(language);
        params.set_print_realtime(false);
        params.set_print_progress(false);
        params.set_print_timestamps(false);
        params.set_print_special(false);

        let context = self.context.lock().map_err(|e| {
            AppError::InternalError(format!("Failed to acquire context lock: {}", e))
        })?;

        let mut state = context.create_state().map_err(|e| {
            AppError::WhisperError(format!("Failed to create whisper state: {:?}", e))
        })?;

        state
            .full(params, &samples)
            .map_err(|e| AppError::WhisperError(format!("Transcription failed: {:?}", e)))?;

        // Extract results
        let mut full_text = String::new();
        let mut segments = Vec::new();

        let num_segments = state.full_n_segments();

        for i in 0..num_segments {
            let seg = state.get_segment(i).ok_or_else(|| {
                AppError::WhisperError(format!("Failed to get segment {}", i))
            })?;

            let segment_text = seg
                .to_str_lossy()
                .map_err(|e| {
                    AppError::WhisperError(format!("Failed to get segment text: {:?}", e))
                })?
                .to_string();
            let start = seg.start_timestamp();
            let end = seg.end_timestamp();

            let text_start = full_text.len();
            full_text.push_str(&segment_text);
            let text_end = full_text.len();

            segments.push(Segment {
                id: i as i32,
                start,
                end,
                text_start,
                text_end,
            });
        }

        Ok(TranscriptionResult {
            text: full_text,
            segments,
        })
    }

    /// Transcribe from audio file.
    /// If `language` is `None`, Whisper will auto-detect the language.
    pub async fn transcribe_file(
        &self,
        file_path: &Path,
        language: Option<&str>,
    ) -> AppResult<TranscriptionResult> {
        // Convert to WAV if needed (MP3, M4A, etc.)
        let wav_path = self.ensure_wav_format(file_path).await?;

        let audio_data = tokio::fs::read(&wav_path)
            .await
            .map_err(|e| AppError::FileError(format!("Failed to read audio file: {}", e)))?;

        // Clean up temporary converted file if it was created
        if wav_path != file_path {
            let _ = tokio::fs::remove_file(&wav_path).await;
        }

        self.transcribe(&audio_data, language)
    }

    /// Ensure the audio file is in WAV format, converting if necessary
    async fn ensure_wav_format(&self, file_path: &Path) -> AppResult<PathBuf> {
        // Detect WAV format from file magic bytes instead of extension
        if Self::is_wav_file(file_path)? {
            return Ok(file_path.to_path_buf());
        }

        // Need to convert to WAV using ffmpeg
        if !Self::is_ffmpeg_available() {
            return Err(AppError::InvalidInput(
                "Non-WAV audio format detected and ffmpeg is not installed. \
                 Either send WAV audio or install ffmpeg for format conversion."
                    .to_string(),
            ));
        }

        // Create temporary WAV file
        let temp_dir = std::env::temp_dir();
        let temp_wav = temp_dir.join(format!("whisper_convert_{}.wav", uuid::Uuid::new_v4()));

        // Convert using ffmpeg
        let output = Command::new("ffmpeg")
            .args(&[
                "-i",
                file_path.to_string_lossy().as_ref(),
                "-acodec",
                "pcm_s16le",
                "-ar",
                "16000",
                "-ac",
                "1",
                "-y", // Overwrite output file
                temp_wav.to_string_lossy().as_ref(),
            ])
            .output()
            .map_err(|e| {
                AppError::FileError(format!(
                    "Failed to convert audio with ffmpeg: {}. Make sure ffmpeg is installed.",
                    e
                ))
            })?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(AppError::FileError(format!(
                "Audio conversion failed. If using curl, make sure to use \
                 -F file=@<path> or --data-binary @<path> instead of -d: {}",
                stderr
            )));
        }

        Ok(temp_wav)
    }

    /// Check if a file is WAV format by reading magic bytes
    fn is_wav_file(file_path: &Path) -> AppResult<bool> {
        use std::io::Read;
        let mut file = std::fs::File::open(file_path)
            .map_err(|e| AppError::FileError(format!("Failed to open audio file: {}", e)))?;
        let mut header = [0u8; 12];
        let bytes_read = file
            .read(&mut header)
            .map_err(|e| AppError::FileError(format!("Failed to read audio header: {}", e)))?;
        Ok(bytes_read >= 12 && &header[0..4] == b"RIFF" && &header[8..12] == b"WAVE")
    }

    /// Check if ffmpeg is available
    fn is_ffmpeg_available() -> bool {
        Command::new("ffmpeg")
            .arg("-version")
            .output()
            .map(|output| output.status.success())
            .unwrap_or(false)
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
