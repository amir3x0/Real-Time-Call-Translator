import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../../models/user.dart';

class ApiService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.userTokenKey);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: query);
  }

  Future<User> login(String phone, String password) async {
    // Try real backend first
    try {
      final resp = await http.post(
        _uri('/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'password': password}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = data['token'] as String?;
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConfig.userTokenKey, token);
          await prefs.setString(AppConfig.userIdKey, data['user_id'] as String);
        }
        // Fetch /auth/me for full user profile if needed; else construct minimal
        return User(
          id: data['user_id'] as String,
          phone: phone,
          fullName: data['full_name'] ?? 'User',
          primaryLanguage: data['primary_language'] ?? 'he',
          languageCode: data['language_code'],
          supportedLanguages: const ['he'],
          status: data['status'] ?? 'online',
          createdAt: DateTime.now(),
        );
      }
    } catch (_) {
      // fall back to mock below
    }

    // Mock fallback
    await Future.delayed(const Duration(seconds: 1));
    return User(
      id: '1',
      phone: phone,
      fullName: 'Mock User',
      primaryLanguage: 'he',
      supportedLanguages: ['he', 'en'],
      createdAt: DateTime.now(),
      avatarUrl: 'https://i.pravatar.cc/150?img=11',
    );
  }

  Future<User> register(String phone, String fullName, String password, String primaryLanguage) async {
    // Mock register flow
    await Future.delayed(const Duration(seconds: 1));
    return User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      phone: phone,
      fullName: fullName,
      primaryLanguage: primaryLanguage,
      supportedLanguages: [primaryLanguage],
      createdAt: DateTime.now(),
      avatarUrl: 'https://i.pravatar.cc/150?img=12',
    );
  }

  // Mock Contacts endpoints
  Future<List<Map<String, dynamic>>> getContacts() async {
    // Try backend
    try {
      final token = await _getToken();
      final resp = await http.get(
        _uri('/api/contacts'),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final contacts = (data['contacts'] as List).cast<Map<String, dynamic>>();
        return contacts
            .map((c) => {
                  'id': c['id'],
                  'name': c['full_name'],
                  'phone': c['phone'],
                  'language': c['primary_language'],
                  'status': 'offline',
                })
            .toList();
      }
    } catch (_) {}

    // Fallback mock
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {'id': 'c1', 'name': 'Daniel Fraimovich', 'phone': '052-123-4567', 'language': 'ru', 'status': 'Online'},
      {'id': 'c2', 'name': 'Dr. Dan Lemberg', 'phone': '054-987-6543', 'language': 'he', 'status': 'Away'},
      {'id': 'c3', 'name': 'John Doe', 'phone': '058-555-1234', 'language': 'en', 'status': 'Offline'},
    ];
  }

  Future<Map<String, dynamic>> createContact(String name, String language, {required String phone}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'phone': phone,
      'language': language,
      'status': 'Offline',
    };
  }

  Future<void> deleteContact(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return;
  }

  // Real: search users in database
  Future<List<User>> searchUsers(String query) async {
    try {
      final token = await _getToken();
      final resp = await http.get(
        _uri('/api/users/search', {'query': query}),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final results = (data['results'] as List).cast<Map<String, dynamic>>();
        return results
            .map((u) => User(
                  id: u['id'] as String,
                  phone: u['phone'] as String,
                  fullName: u['full_name'] as String,
                  primaryLanguage: u['primary_language'] as String,
                  supportedLanguages: const ['he'],
                  createdAt: DateTime.now(),
                ))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // Real: add contact by user id
  Future<bool> addContact(String userId) async {
    try {
      final token = await _getToken();
      final resp = await http.post(
        _uri('/api/contacts/add'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'contact_user_id': userId}),
      );
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // Mock Voice sample endpoints
  Future<Map<String, dynamic>> uploadVoiceSample(String userId, String filePath) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {'success': true, 'path': '/mock/voice_samples/$userId.wav'};
  }

  Future<void> deleteVoiceSample(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return;
  }

  Future<Map<String, dynamic>> startCall(List<String> participantUserIds) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().toIso8601String();
    return {
      'session_id': sessionId,
      'websocket_url': 'ws://10.0.2.2:8000/ws/$sessionId',
      'participants': participantUserIds.map((id) => {
            'id': 'p$id',
            'user_id': id,
            'display_name': 'Mock User $id',
            'phone': '052-000-000$id',
            'target_language': 'en',
            'speaking_language': 'en',
            'joined_at': now,
            'created_at': now,
          }).toList(),
    };
  }
}