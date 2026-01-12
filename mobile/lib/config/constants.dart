class AppConstants {
  // === OUTGOING AUDIO (Microphone → Backend) ===
  static const int audioSendIntervalMs =
      100; // How often we send to server (aligned with backend)
  static const int audioMinChunkSize =
      3200; // Minimum bytes to send (~100ms at 16kHz)
  static const int audioSampleRate = 16000; // Sample rate for recording

  // === INCOMING AUDIO (Backend → Speaker) ===
  static const int audioMaxBufferSize = 12; // Jitter buffer: max chunks to keep
  static const int audioMinBufferSize =
      1; // Jitter buffer: min chunks before playing
  static const int audioBufferSize = 8192; // FlutterSound internal buffer size

  // API Configuration
  static const int apiTimeoutSeconds = 30;

  // Call Configuration
  static const int defaultMaxParticipants = 4;
}
