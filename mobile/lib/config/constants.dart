class AppConstants {
  // === OUTGOING AUDIO (Microphone → Backend) ===
  static const int audioSendIntervalMs =
      150; // How often we send to server (increased from 100ms for lower network overhead)
  static const int audioMinChunkSize =
      4800; // Minimum bytes to send (~150ms at 16kHz, 16000 Hz × 2 bytes × 0.15s)
  static const int audioSampleRate = 16000; // Sample rate for recording

  // === INCOMING AUDIO (Backend → Speaker) ===
  static const int audioMaxBufferSize = 8; // Jitter buffer: max chunks to keep (~1.2s at 150ms chunks, reduced from 12 for lower latency)
  static const int audioMinBufferSize =
      1; // Jitter buffer: min chunks before playing
  static const int audioBufferSize = 8192; // FlutterSound internal buffer size

  // API Configuration
  static const int apiTimeoutSeconds = 30;

  // Call Configuration
  static const int defaultMaxParticipants = 4;
}
