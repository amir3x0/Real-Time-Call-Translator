import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application configuration constants
class AppConfig {
  // ============================================
  // Backend API Configuration
  // ============================================

  /// Default backend server port
  static const int _defaultBackendPort =
      int.fromEnvironment('BACKEND_PORT', defaultValue: 8000);

  /// Runtime cached values (loaded from SharedPreferences at startup)
  static String? _runtimeHost;
  static int? _runtimePort;

  /// Production server host (update when deploying)
  static const String _prodHost = 'your-production-server.com';

  /// Storage key for custom backend host
  static const String backendHostKey = 'backend_host';

  /// Storage key for custom backend port
  static const String backendPortKey = 'backend_port';

  /// Initialize AppConfig by loading runtime values from SharedPreferences.
  /// Must be called before runApp() in main.dart.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _runtimeHost = prefs.getString(backendHostKey);
    _runtimePort = prefs.getInt(backendPortKey);
  }

  /// Set custom backend host (saves to SharedPreferences and updates cache)
  static Future<void> setBackendHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(backendHostKey, host);
    _runtimeHost = host;
  }

  /// Set custom backend port (saves to SharedPreferences and updates cache)
  static Future<void> setBackendPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(backendPortKey, port);
    _runtimePort = port;
  }

  /// Clear custom backend configuration (revert to defaults)
  static Future<void> clearBackendConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(backendHostKey);
    await prefs.remove(backendPortKey);
    _runtimeHost = null;
    _runtimePort = null;
  }

  /// Get the currently configured backend host
  static String get currentHost => _getBackendHost();

  /// Get the currently configured backend port
  static int get currentPort => _runtimePort ?? _defaultBackendPort;

  /// Check if a custom (runtime) host is configured
  static bool get hasCustomHost => _runtimeHost != null && _runtimeHost!.isNotEmpty;

  /// Get backend host with priority: runtime override > compile-time > default
  ///
  /// Priority order:
  /// 1. Runtime override (from SharedPreferences, set via UI)
  /// 2. Compile-time override (flutter run --dart-define=BACKEND_HOST=...)
  /// 3. Default based on platform/build mode
  static String _getBackendHost() {
    // 1. Check for runtime override (UI configured)
    if (_runtimeHost != null && _runtimeHost!.isNotEmpty) {
      return _runtimeHost!;
    }

    // 2. Check for compile-time override
    const envHost = String.fromEnvironment('BACKEND_HOST');
    if (envHost.isNotEmpty) {
      return envHost;
    }

    // 3. Default behavior based on build mode
    if (kDebugMode) {
      // Android Emulator uses 10.0.2.2 to access host localhost
      if (defaultTargetPlatform == TargetPlatform.android) {
        return '10.0.2.2';
      }
      // Windows/macOS/Linux/iOS Simulator use standard localhost
      return '127.0.0.1';
    }

    // 4. Production fallback
    return _prodHost;
  }

  /// Base URL for REST API
  static String get baseUrl => 'http://${_getBackendHost()}:$currentPort';

  /// WebSocket URL for real-time communication
  static String get wsUrl => 'ws://${_getBackendHost()}:$currentPort';

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
