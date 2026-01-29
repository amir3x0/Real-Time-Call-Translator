/// Authentication Service - User login, registration, and session management.
///
/// Handles all authentication-related API calls to the backend:
/// - Login with phone/password
/// - User registration
/// - Fetching current user profile
/// - Updating user preferences (language, theme)
/// - Logout and token management
///
/// Tokens are stored in SharedPreferences for persistence across app restarts.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../../models/user.dart';
import 'base_api_service.dart';

/// Service for user authentication and profile management.
class AuthService extends BaseApiService {
  Future<User> login(String phone, String password) async {
    final resp = await post('/api/auth/login', body: {
      'phone': phone,
      'password': password,
    });

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConfig.userTokenKey, token);
        await prefs.setString(AppConfig.userIdKey, data['user_id'] as String);
      }
      return User(
        id: data['user_id'] as String,
        phone: phone,
        fullName: data['full_name'] ?? 'User',
        primaryLanguage: data['primary_language'] ?? 'he',
        themePreference: data['theme_preference'] ?? 'light',
        createdAt: DateTime.now(),
      );
    }

    final error = jsonDecode(resp.body)['detail'] ?? 'Login failed';
    throw Exception(error);
  }

  Future<User> register(String phone, String fullName, String password,
      String primaryLanguage) async {
    final resp = await post('/api/auth/register', body: {
      'phone': phone,
      'full_name': fullName,
      'password': password,
      'primary_language': primaryLanguage,
    });

    if (resp.statusCode == 201 || resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      final userId = data['user_id'] as String?;
      final prefs = await SharedPreferences.getInstance();
      if (token != null) await prefs.setString(AppConfig.userTokenKey, token);
      if (userId != null) await prefs.setString(AppConfig.userIdKey, userId);

      return User(
        id: userId ?? '',
        phone: phone,
        fullName: fullName,
        primaryLanguage: primaryLanguage,
        createdAt: DateTime.now(),
      );
    }

    final error = jsonDecode(resp.body)['detail'] ?? 'Registration failed';
    throw Exception(error);
  }

  Future<User?> me() async {
    try {
      final resp = await get('/api/auth/me');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return User(
          id: data['id'] as String,
          phone: (data['phone'] ?? '') as String,
          fullName: data['full_name'] ?? 'User',
          primaryLanguage: data['primary_language'] ?? 'he',
          themePreference: data['theme_preference'] ?? 'light',
          isOnline: data['is_online'] ?? false,
          hasVoiceSample: data['has_voice_sample'] ?? false,
          voiceModelTrained: data['voice_model_trained'] ?? false,
          createdAt: DateTime.now(),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> logout() async {
    try {
      await post('/api/auth/logout');
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.userTokenKey);
    await prefs.remove(AppConfig.userIdKey);
  }

  Future<User> updateUserLanguage(String language) async {
    final resp = await patch('/api/auth/profile', body: {
      'primary_language': language,
    });

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return User(
        id: data['id'] as String,
        phone: (data['phone'] ?? '') as String,
        fullName: data['full_name'] ?? 'User',
        primaryLanguage: data['primary_language'] ?? 'he',
        themePreference: data['theme_preference'] ?? 'light',
        isOnline: data['is_online'] ?? false,
        hasVoiceSample: data['has_voice_sample'] ?? false,
        voiceModelTrained: data['voice_model_trained'] ?? false,
        createdAt: DateTime.now(),
      );
    }

    final error =
        jsonDecode(resp.body)['detail'] ?? 'Failed to update language';
    throw Exception(error);
  }

  Future<void> updateThemePreference(String theme) async {
    final resp = await patch('/api/auth/profile', body: {
      'theme_preference': theme,
    });

    if (resp.statusCode != 200) {
      final error = jsonDecode(resp.body)['detail'] ?? 'Failed to update theme';
      throw Exception(error);
    }
  }
}
