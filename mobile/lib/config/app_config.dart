import 'package:flutter/foundation.dart';

/// Application configuration constants
class AppConfig {
  // ============================================
  // Backend API Configuration
  // ============================================

  /// Backend server port
  static const int _backendPort =
      int.fromEnvironment('BACKEND_PORT', defaultValue: 8000);

  /// Development server hosts for different testing scenarios
  // static const String _devHostPhysical = '10.223.167.22'; // Use --dart-define=BACKEND_HOST=... instead
  // Uncomment and use these when testing on emulator/simulator:
  // static const String _devHostEmulator = '10.0.2.2'; // Android emulator
  // static const String _devHostSimulator = 'localhost'; // iOS simulator

  /// Production server host (update when deploying)
  static const String _prodHost = 'your-production-server.com';

  /// Get backend host from environment variables or default to emulator
  ///
  /// Usage:
  /// flutter run --dart-define=BACKEND_HOST=192.168.1.50
  static String _getBackendHost() {
    // 1. Check for command-line override
    const envHost = String.fromEnvironment('BACKEND_HOST');
    if (envHost.isNotEmpty) {
      return envHost;
    }

    // 2. Default behavior based on build mode
    if (kDebugMode) {
      // Android Emulator uses 10.0.2.2 to access host localhost
      if (defaultTargetPlatform == TargetPlatform.android) {
        return '10.0.2.2';
      }
      // Windows/macOS/Linux/iOS Simulator use standard localhost
      return '127.0.0.1';
    }

    // 3. Production fallback
    return _prodHost;
  }

  /// Base URL for REST API
  static String get baseUrl => 'http://${_getBackendHost()}:$_backendPort';

  /// WebSocket URL for real-time communication
  static String get wsUrl => 'ws://${_getBackendHost()}:$_backendPort';

  // API Endpoints
  static const String healthEndpoint = '/health';
  static const String wsEndpoint = '/ws';

  // Supported Languages
  static const List<String> supportedLanguages = ['he', 'en', 'ru'];

  static const Map<String, String> languageNames = {
    'he': 'עברית',
    'en': 'English',
    'ru': 'Русский',
  };

  // Audio Configuration
  static const int audioSampleRate = 16000;
  static const int audioChannels = 1; // Mono
  static const int audioBitRate = 16;
  static const int audioChunkDurationMs = 200; // 200ms chunks

  // Call Configuration
  static const int maxParticipants = 4;
  static const Duration callTimeout = Duration(hours: 2);

  // Connection Configuration
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 5);
  static const int maxReconnectAttempts = 3;

  // UI Configuration
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const double borderRadius = 12.0;

  // Storage Keys
  static const String userIdKey = 'user_id';
  static const String userTokenKey = 'user_token';
  static const String primaryLanguageKey = 'primary_language';
  static const String themeKey = 'theme_mode';
}
