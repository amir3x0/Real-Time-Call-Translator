"""
Application-wide constants for configuration and tuning.

This file centralizes all magic numbers and configuration values
to enable easy tuning and maintain consistency across the backend.

Note: Environment-dependent settings (DB, Redis, API keys) belong in settings.py.
This file is for operational parameters that rarely change between environments.
"""

# ==============================================================================
# AUDIO CONFIGURATION
# ==============================================================================

# Sample rate for all audio processing (Hz)
AUDIO_SAMPLE_RATE: int = 16000

# Bytes per sample (16-bit PCM = 2 bytes)
AUDIO_BYTES_PER_SAMPLE: int = 2

# Bytes per second of audio (sample_rate * bytes_per_sample)
AUDIO_BYTES_PER_SECOND: int = AUDIO_SAMPLE_RATE * AUDIO_BYTES_PER_SAMPLE

# ==============================================================================
# AUDIO PROCESSING - BUFFERS & CHUNKS
# ==============================================================================

# Max spectral history buffer size (~400ms at 16kHz stereo)
SPECTRAL_HISTORY_MAX_BYTES: int = 12800

# Minimum bytes required for FFT analysis (~100ms at 16kHz mono 16-bit)
MIN_ANALYSIS_BYTES: int = 3200

# Maximum segments to keep in buffer before cleanup
MAX_BUFFER_SEGMENTS: int = 10

# ==============================================================================
# AUDIO PROCESSING - THRESHOLDS
# ==============================================================================

# Silence detection threshold in seconds (optimized for better sentence boundaries)
SILENCE_THRESHOLD_SEC: float = 0.40

# RMS threshold for detecting silence (lower = more sensitive)
RMS_SILENCE_THRESHOLD: int = 300

# Minimum audio length before processing (seconds, reduced for faster response)
MIN_AUDIO_LENGTH_SEC: float = 0.4

# Time window for merging adjacent segments (seconds)
SEGMENT_MERGE_TIME_WINDOW_SEC: float = 1.0

# Minimum words to keep segments separate
MIN_WORDS_TO_KEEP_SEPARATE: int = 5

# ==============================================================================
# AUDIO PROCESSING - FFT SPEECH DETECTION
# ==============================================================================

# FFT frequency bins for speech detection (Hz)
FFT_SPEECH_FREQ_MIN: int = 80
FFT_SPEECH_FREQ_MAX: int = 4000
FFT_NOISE_FREQ_MIN: int = 5000

# Speech/noise energy ratio threshold for voice activity detection
SPEECH_NOISE_RATIO_THRESHOLD: float = 2.0

# ==============================================================================
# CONTEXT-AWARE TRANSLATION
# ==============================================================================

# Max characters for translation context window (increased for better context)
TRANSLATION_CONTEXT_MAX_CHARS: int = 350

# Context snippet length for context-aware translation (increased for richer context)
CONTEXT_SNIPPET_MAX_CHARS: int = 250

# ==============================================================================
# CONTEXT RESOLVER (Gemini LLM)
# ==============================================================================

# Enable/disable context resolution (can be toggled without code changes)
CONTEXT_RESOLUTION_ENABLED: bool = True

# Gemini model to use (flash = fast/cheap, pro = better quality)
GEMINI_MODEL_NAME: str = "gemini-1.5-flash"

# Gemini generation parameters
GEMINI_TEMPERATURE: float = 0.1  # Low creativity for accuracy
GEMINI_MAX_OUTPUT_TOKENS: int = 256
GEMINI_TOP_P: float = 0.8

# Context resolution timeout (seconds) - fallback to original if exceeded
CONTEXT_RESOLUTION_TIMEOUT_SEC: float = 2.0

# Minimum context length to trigger resolution (chars)
CONTEXT_MIN_LENGTH_FOR_RESOLUTION: int = 10

# Minimum input length to trigger resolution (words)
CONTEXT_MIN_WORDS_FOR_RESOLUTION: int = 2

# Maximum output/input length ratio (sanity check)
CONTEXT_MAX_OUTPUT_RATIO: float = 2.0

# ==============================================================================
# INTERIM CAPTION STREAMING
# ==============================================================================

# Minimum interval between interim caption publishes (milliseconds)
INTERIM_PUBLISH_INTERVAL_MS: int = 150

# Streaming STT session timeout (seconds)
STREAMING_STT_TIMEOUT_SEC: float = 30.0

# Minimum characters before publishing interim caption (avoid single chars)
INTERIM_MIN_CHARS_TO_PUBLISH: int = 3

# Maximum interim text length before truncation
INTERIM_MAX_TEXT_LENGTH: int = 200

# Deduplication window for identical interim results (seconds)
INTERIM_DEDUP_WINDOW_SEC: float = 0.5

# ==============================================================================
# TIMING & DELAYS - AUDIO WORKER
# ==============================================================================

# Audio queue read timeout (seconds) - how long to wait for new audio
AUDIO_QUEUE_READ_TIMEOUT_SEC: float = 0.15

# Max accumulated audio time before forced processing (seconds, increased for more context)
MAX_ACCUMULATED_AUDIO_TIME_SEC: float = 1.2

# Message deduplication TTL (seconds)
MESSAGE_DEDUP_TTL_SEC: float = 30.0

# Transcript publish deduplication TTL (seconds)
# Prevents same transcript from being published by both streaming and batch pipelines
TRANSCRIPT_PUBLISH_DEDUP_TTL_SEC: float = 5.0

# Audio content deduplication TTL (seconds)
# Prevents duplicate audio chunks from being processed multiple times
AUDIO_CONTENT_DEDUP_TTL_SEC: float = 5.0

# Error recovery sleep duration (seconds)
ERROR_RECOVERY_SLEEP_SEC: float = 0.5

# Graceful shutdown timeout (seconds)
GRACEFUL_SHUTDOWN_TIMEOUT_SEC: float = 0.5

# ==============================================================================
# TIMING & DELAYS - REDIS STREAMS
# ==============================================================================

# Redis stream block timeout (milliseconds)
REDIS_STREAM_BLOCK_MS: int = 500

# Redis stream message count per read
REDIS_STREAM_MESSAGE_COUNT: int = 10

# ==============================================================================
# TIMING & DELAYS - WEBSOCKET
# ==============================================================================

# WebSocket message receive timeout (seconds)
WEBSOCKET_MESSAGE_TIMEOUT_SEC: float = 35.0

# ==============================================================================
# GCP API CONFIGURATION
# ==============================================================================

# Speech-to-Text sample rate (must match AUDIO_SAMPLE_RATE)
GCP_STT_SAMPLE_RATE_HZ: int = 16000

# Text-to-Speech sample rate
GCP_TTS_SAMPLE_RATE_HZ: int = 16000

# TTS speaking rate (1.0 = normal speed)
TTS_SPEAKING_RATE: float = 1.0

# TTS pitch offset (0.0 = no change)
TTS_PITCH: float = 0.0

# ==============================================================================
# GCP API TIMEOUTS
# ==============================================================================

# Speech-to-Text API timeout (seconds)
GCP_STT_TIMEOUT_SEC: float = 7.0

# Translation API timeout (seconds)
GCP_TRANSLATE_TIMEOUT_SEC: float = 5.0

# Text-to-Speech API timeout (seconds)
GCP_TTS_TIMEOUT_SEC: float = 10.0

# ==============================================================================
# USER STATUS & HEARTBEAT
# ==============================================================================

# Heartbeat send interval (seconds)
HEARTBEAT_INTERVAL_SEC: int = 30

# Redis heartbeat key TTL (seconds)
HEARTBEAT_TTL_SEC: int = 60

# Status cleanup/sync interval (seconds)
STATUS_CLEANUP_INTERVAL_SEC: int = 120

# Grace period before marking user offline (seconds)
OFFLINE_GRACE_PERIOD_SEC: float = 5.0

# ==============================================================================
# DATABASE CONNECTION POOL
# ==============================================================================

# SQLAlchemy connection pool size
DB_POOL_SIZE: int = 10

# SQLAlchemy max overflow connections
DB_POOL_MAX_OVERFLOW: int = 20

# ==============================================================================
# TTS CACHE
# ==============================================================================

# Maximum entries in TTS audio cache
TTS_CACHE_MAX_SIZE: int = 100

# Cache key hash truncation length
CACHE_KEY_HASH_LENGTH: int = 16

# ==============================================================================
# API PAGINATION & LIMITS
# ==============================================================================

# Default call history pagination limit
DEFAULT_CALL_HISTORY_LIMIT: int = 20

# Default user search result limit
DEFAULT_USER_SEARCH_LIMIT: int = 20

# ==============================================================================
# CALL CONFIGURATION
# ==============================================================================

# Minimum participants for a call
MIN_CALL_PARTICIPANTS: int = 1

# Maximum participants per call
MAX_CALL_PARTICIPANTS: int = 4

# ==============================================================================
# METRICS & MONITORING
# ==============================================================================

# Prometheus metrics server port
METRICS_SERVER_PORT: int = 8001

# ==============================================================================
# VALIDATION CONSTRAINTS
# ==============================================================================

# Phone number validation
PHONE_MIN_LENGTH: int = 6
PHONE_MAX_LENGTH: int = 20

# Full name validation
FULLNAME_MIN_LENGTH: int = 1
FULLNAME_MAX_LENGTH: int = 255

# ==============================================================================
# VOICE TRAINING
# ==============================================================================

# Minimum voice samples required for training
MIN_VOICE_SAMPLES_FOR_TRAINING: int = 2

# Voice quality threshold (0-100)
VOICE_QUALITY_THRESHOLD: int = 40

# ==============================================================================
# LANGUAGE DEFAULTS
# ==============================================================================

# Default participant language code
DEFAULT_PARTICIPANT_LANGUAGE: str = "en-US"

# Default call language code
DEFAULT_CALL_LANGUAGE: str = "en"

# Language code expansion map (short code -> full locale)
LANGUAGE_CODE_MAP: dict[str, str] = {
    "en": "en-US",
    "he": "he-IL",
    "ru": "ru-RU",
    "es": "es-ES",
    "fr": "fr-FR",
    "de": "de-DE",
    "it": "it-IT",
    "pt": "pt-BR",
    "zh": "zh-CN",
    "ja": "ja-JP",
    "ko": "ko-KR",
    "ar": "ar-SA",
}

# Supported languages for the application
SUPPORTED_LANGUAGES: list[str] = ["en", "he", "ru"]
