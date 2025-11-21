/// Application configuration constants
class AppConfig {
  // Backend API Configuration
  static const String baseUrl = 'http://localhost:8000';
  static const String wsUrl = 'ws://localhost:8000';
  
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
