/// Settings Provider - App preferences and theme management.
///
/// Manages user preferences:
/// - Theme mode (light/dark) with local persistence and server sync
/// - App language setting
///
/// Theme is persisted locally for instant startup and synced to server
/// for cross-device consistency.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/services/auth_service.dart';

/// Provider for app settings and theme management.
class SettingsProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light; // Default to light
  bool _isInitialized = false;
  String _appLanguage = 'en';
  final AuthService _authService = AuthService();

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isInitialized => _isInitialized;
  String get appLanguage => _appLanguage;

  /// Initialize from local storage (call on app start)
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeKey);
    _themeMode = stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _isInitialized = true;
    notifyListeners();
  }

  /// Apply theme from server (call after login)
  /// Server preference takes priority over local
  void applyServerTheme(String? themePreference) {
    final newMode = themePreference == 'dark' ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode != newMode) {
      _themeMode = newMode;
      _persistLocally();
      notifyListeners();
    }
  }

  /// Set theme (user action) - updates local + server
  Future<void> setTheme(ThemeMode mode, {bool syncToServer = true}) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    await _persistLocally();
    notifyListeners();

    if (syncToServer) {
      try {
        await _authService.updateThemePreference(
          mode == ThemeMode.dark ? 'dark' : 'light',
        );
      } catch (e) {
        debugPrint('Failed to sync theme to server: $e');
        // Theme is still saved locally, so user experience is preserved
      }
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme({bool syncToServer = true}) async {
    final newMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setTheme(newMode, syncToServer: syncToServer);
  }

  /// Persist theme to local storage
  Future<void> _persistLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
  }

  /// Set app language (legacy - kept for compatibility)
  void setLanguage(String langCode) {
    _appLanguage = langCode;
    notifyListeners();
  }
}
