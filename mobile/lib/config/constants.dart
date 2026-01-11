class AppConstants {
  // Audio Configuration
  static const int audioSendIntervalMs =
      60; // Reduced from 300ms for lower latency
  static const int audioMinChunkSize =
      1920; // ~60ms at 16kHz (was 6400 for 200ms)
  static const int audioMaxBufferSize =
      12; // Drop old chunks if buffer grows too large
  static const int audioMinBufferSize =
      1; // Wait for 1 chunk before playing (low latency)
  static const int audioSampleRate = 16000;
  static const int audioBufferSize = 8192;

  // API Configuration
  static const int apiTimeoutSeconds = 30;

  // Call Configuration
  static const int defaultMaxParticipants = 4;
}
