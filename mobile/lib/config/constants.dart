/// Application-wide constants for configuration and tuning.
///
/// This file centralizes all magic numbers and configuration values
/// to enable easy tuning and maintain consistency across the app.
class AppConstants {
  // ============================================================
  // AUDIO - OUTGOING (Microphone → Backend)
  // ============================================================

  /// How often we send audio chunks to server (ms)
  /// Increased from 100ms for lower network overhead
  static const int audioSendIntervalMs = 150;

  /// Minimum bytes to send per chunk (~150ms at 16kHz mono 16-bit)
  /// Formula: 16000 Hz × 2 bytes × 0.15s = 4800 bytes
  static const int audioMinChunkSize = 4800;

  /// Sample rate for recording (Hz)
  static const int audioSampleRate = 16000;

  /// Bit rate for voice recordings (bps)
  static const int voiceRecordingBitRate = 128000;

  // ============================================================
  // AUDIO - INCOMING (Backend → Speaker)
  // ============================================================

  /// Jitter buffer: max chunks to keep (~1.2s at 150ms chunks)
  /// Reduced from 12 for lower latency
  static const int audioMaxBufferSize = 8;

  /// Jitter buffer: min chunks before starting playback
  static const int audioMinBufferSize = 1;

  /// FlutterSound internal buffer size (bytes)
  static const int audioBufferSize = 8192;

  /// Playback timer interval for audio processing (ms)
  static const int audioPlaybackTimerMs = 150;

  // ============================================================
  // AUDIO - MOCK/TESTING
  // ============================================================

  /// Mock audio chunk generation interval (ms)
  static const int audioMockChunkIntervalMs = 200;

  /// Mock audio chunk size (bytes)
  static const int audioMockChunkSize = 1600;

  /// Mock playback simulation delay (ms)
  static const int audioMockPlaybackDelayMs = 300;

  // ============================================================
  // WEBSOCKET CONFIGURATION
  // ============================================================

  /// Delay before attempting WebSocket reconnection (seconds)
  static const int wsReconnectDelaySeconds = 2;

  /// WebSocket ping interval to keep connection alive (seconds)
  static const int wsPingIntervalSeconds = 10;

  /// Delay before closing WebSocket connection (ms)
  static const int wsCloseDelayMs = 100;

  /// Heartbeat message interval (seconds)
  static const int wsHeartbeatIntervalSeconds = 30;

  /// Max reconnection attempts before giving up
  static const int wsMaxReconnectAttempts = 3;

  // ============================================================
  // API CONFIGURATION
  // ============================================================

  /// Default API request timeout (seconds)
  static const int apiTimeoutSeconds = 30;

  /// Quick API request timeout for connection tests (seconds)
  static const int apiQuickTimeoutSeconds = 5;

  // ============================================================
  // CALL CONFIGURATION
  // ============================================================

  /// Maximum participants allowed in a call
  static const int defaultMaxParticipants = 4;

  /// Incoming call auto-reject timeout (seconds)
  static const int incomingCallTimeoutSeconds = 30;

  /// Call duration display update interval (seconds)
  static const int callDurationTimerSeconds = 1;

  /// Incoming call countdown timer interval (seconds)
  static const int incomingCallCountdownSeconds = 1;

  // ============================================================
  // CAPTIONS & TRANSCRIPTION
  // ============================================================

  /// How long caption bubbles stay visible (seconds)
  static const int captionBubbleDisplayDurationSeconds = 4;

  /// Maximum transcription entries to keep in history
  static const int maxTranscriptionEntries = 100;

  // ============================================================
  // VOICE RECORDING
  // ============================================================

  /// Maximum voice recording duration for voice samples (seconds)
  static const int maxVoiceRecordingSeconds = 30;

  /// Recording timer UI update interval (ms)
  static const int recordTimerUpdateIntervalMs = 50;

  // ============================================================
  // UI - ANIMATION DURATIONS
  // ============================================================

  /// Standard button press animation (ms)
  static const int buttonAnimationDurationMs = 200;

  /// FlashBar notification display time (seconds)
  static const int flashBarDisplayDurationSeconds = 3;

  /// FlashBar slide animation duration (ms)
  static const int flashBarAnimationDurationMs = 400;

  /// Voice visualizer wave animation (ms)
  static const int voiceVisualizerAnimationDurationMs = 180;

  /// Recording button pulse animation cycle (seconds)
  static const int pulseAnimationDurationSeconds = 2;

  /// Recording button state transition (ms)
  static const int recordingButtonAnimationMs = 250;

  /// Caption bubble fade animation (ms)
  static const int captionBubbleAnimationMs = 250;

  /// Network status indicator animation (ms)
  static const int networkIndicatorAnimationMs = 600;

  /// Participant card speaking indicator animation (ms)
  static const int participantCardAnimationMs = 1500;

  /// Participant status pulse animation (ms)
  static const int participantStatusAnimationMs = 2000;

  /// Grid item stagger animation (ms)
  static const int gridItemAnimationMs = 300;

  /// Settings screen button animation (ms)
  static const int settingsButtonAnimationMs = 200;

  /// Call screen transition animation (ms)
  static const int callScreenTransitionMs = 300;

  /// Call control button animation (ms)
  static const int callControlAnimationMs = 200;

  /// Contact card tap animation (ms)
  static const int contactCardAnimationMs = 200;

  /// Particle selection animation (ms)
  static const int participantSelectionAnimationMs = 200;

  // ============================================================
  // UI - BACKGROUND ANIMATIONS
  // ============================================================

  /// Login screen gradient animation cycle (seconds)
  static const int loginScreenAnimationSeconds = 10;

  /// Register screen gradient animation cycle (seconds)
  static const int registerScreenAnimationSeconds = 10;

  /// Voice register screen animation cycle (seconds)
  static const int voiceRegisterAnimationSeconds = 10;

  /// Home screen carousel/background animation (seconds)
  static const int homeScreenAnimationSeconds = 12;

  /// Shared gradient background animation (seconds)
  static const int gradientAnimationSeconds = 10;

  /// Call action feedback animation (seconds)
  static const int callActionAnimationSeconds = 2;

  // ============================================================
  // UI - DEBOUNCE & DELAYS
  // ============================================================

  /// Search input debounce delay (ms)
  static const int searchDebounceDelayMs = 250;

  /// Settings action delay (ms)
  static const int settingsDelayMs = 300;

  /// Home button animation (ms)
  static const int homeButtonAnimationMs = 200;

  /// Staggered list animation delay factor per item (ms)
  static const int staggeredAnimationDelayFactorMs = 50;

  // ============================================================
  // UI - LAYOUT
  // ============================================================

  /// FAB position above bottom navigation bar (pixels)
  static const double fabPositionAboveNavBarPx = 110;

  /// Participant grid strip height (pixels)
  static const double participantGridStripHeightPx = 120;

  // ============================================================
  // MOCK DATA (Testing/Development)
  // ============================================================

  /// Mock transcription generation interval (seconds)
  static const int mockTranscriptionIntervalSeconds = 3;

  /// Mock speaking state change interval (seconds)
  static const int mockSpeakingChangeIntervalSeconds = 5;

  /// Mock connection simulation delay (ms)
  static const int mockConnectionDelayMs = 500;

  /// Mock API response delay (ms)
  static const int mockApiDelayMs = 300;

  /// Mock API long response delay (ms)
  static const int mockApiLongDelayMs = 500;
}
