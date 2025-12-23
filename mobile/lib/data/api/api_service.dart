import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../../models/user.dart';

/// API Service for Real-Time Call Translator backend
/// 
/// Implements endpoints for:
/// - Authentication (login, register, me)
/// - Contacts management
/// - Call management (start, end, join, leave)
/// - Voice sample management
class ApiService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.userTokenKey);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: query);
  }

  Map<String, String> _authHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ============================================
  // AUTHENTICATION ENDPOINTS
  // ============================================

  Future<User> login(String phone, String password) async {
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
      return User(
        id: data['user_id'] as String,
        phone: phone,
        fullName: data['full_name'] ?? 'User',
        primaryLanguage: data['primary_language'] ?? 'he',
        createdAt: DateTime.now(),
      );
    }
    
    final error = jsonDecode(resp.body)['detail'] ?? 'Login failed';
    throw Exception(error);
  }

  Future<User> register(String phone, String fullName, String password, String primaryLanguage) async {
    final resp = await http.post(
      _uri('/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'full_name': fullName,
        'password': password,
        'primary_language': primaryLanguage,
      }),
    );
    
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

  Future<User?> getCurrentUser() async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final resp = await http.get(
        _uri('/api/auth/me'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return User(
          id: data['id'] as String,
          phone: (data['phone'] ?? '') as String,
          fullName: data['full_name'] ?? 'User',
          primaryLanguage: data['primary_language'] ?? 'he',
          isOnline: data['is_online'] ?? false,
          hasVoiceSample: data['has_voice_sample'] ?? false,
          voiceModelTrained: data['voice_model_trained'] ?? false,
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Error getting current user: $e');
    }
    return null;
  }

  /// Alias for getCurrentUser
  Future<User?> me() async => getCurrentUser();

  Future<void> logout() async {
    try {
      final token = await _getToken();
      if (token != null) {
        await http.post(
          _uri('/api/auth/logout'),
          headers: _authHeaders(token),
        );
      }
    } catch (e) {
      debugPrint('Logout error: $e');
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.userTokenKey);
    await prefs.remove(AppConfig.userIdKey);
  }

  /// Update user's primary language
  Future<User> updateUserLanguage(String language) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');
    
    final resp = await http.patch(
      _uri('/api/auth/profile'),
      headers: _authHeaders(token),
      body: jsonEncode({'primary_language': language}),
    );
    
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return User(
        id: data['id'] as String,
        phone: (data['phone'] ?? '') as String,
        fullName: data['full_name'] ?? 'User',
        primaryLanguage: data['primary_language'] ?? 'he',
        isOnline: data['is_online'] ?? false,
        hasVoiceSample: data['has_voice_sample'] ?? false,
        voiceModelTrained: data['voice_model_trained'] ?? false,
        createdAt: DateTime.now(),
      );
    }
    
    final error = jsonDecode(resp.body)['detail'] ?? 'Failed to update language';
    throw Exception(error);
  }

  // ============================================
  // CONTACTS ENDPOINTS
  // ============================================

  Future<Map<String, dynamic>> getContacts() async {
    final token = await _getToken();
    
    try {
      final resp = await http.get(
        _uri('/api/contacts'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
        // Fallback for compatibility if old list format
        if (data is List) {
          return {'contacts': List<Map<String, dynamic>>.from(data)};
        }
      }
    } catch (e) {
      debugPrint('Error getting contacts: $e');
    }
    return {'contacts': []};
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final token = await _getToken();
    
    try {
      final resp = await http.get(
        _uri('/api/contacts/search', {'q': query}),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map && data['users'] != null) {
          return List<Map<String, dynamic>>.from(data['users']);
        }
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> addContact(String contactUserId) async {
    final token = await _getToken();
    
    final resp = await http.post(
      _uri('/api/contacts/add/$contactUserId'),
      headers: _authHeaders(token),
    );
    
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    
    throw Exception('Failed to add contact');
  }

  Future<void> deleteContact(String contactId) async {
    final token = await _getToken();
    
    await http.delete(
      _uri('/api/contacts/$contactId'),
      headers: _authHeaders(token),
    );
  }

  Future<void> acceptContactRequest(String requestId) async {
    final token = await _getToken();
    
    final resp = await http.post(
      _uri('/api/contacts/$requestId/accept'),
      headers: _authHeaders(token),
    );
    
    if (resp.statusCode != 200) {
      throw Exception('Failed to accept request: ${resp.body}');
    }
  }

  Future<void> rejectContactRequest(String requestId) async {
    final token = await _getToken();
    
    final resp = await http.post(
      _uri('/api/contacts/$requestId/reject'),
      headers: _authHeaders(token),
    );
    
    if (resp.statusCode != 200) {
      throw Exception('Failed to reject request: ${resp.body}');
    }
  }

  // ============================================
  // CALL ENDPOINTS
  // ============================================

  Future<Map<String, dynamic>> startCall(List<String> participantUserIds) async {
    final token = await _getToken();
    
    final resp = await http.post(
      _uri('/api/calls/start'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'participant_user_ids': participantUserIds,
        'skip_contact_validation': true, // For demo
      }),
    );
    
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    
    throw Exception('Failed to start call: ${resp.body}');
  }

  Future<void> endCall(String callId) async {
    final token = await _getToken();
    
    await http.post(
      _uri('/api/calls/$callId/end'),
      headers: _authHeaders(token),
    );
  }

  Future<void> leaveCall(String callId) async {
    final token = await _getToken();
    
    await http.post(
      _uri('/api/calls/$callId/leave'),
      headers: _authHeaders(token),
    );
  }

  Future<void> muteCall(String callId, bool muted) async {
    final token = await _getToken();
    
    await http.post(
      _uri('/api/calls/$callId/mute'),
      headers: _authHeaders(token),
      body: jsonEncode({'muted': muted}),
    );
  }

  Future<List<Map<String, dynamic>>> getCallHistory() async {
    final token = await _getToken();
    
    try {
      final resp = await http.get(
        _uri('/api/calls/history'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map && data['calls'] != null) {
          return List<Map<String, dynamic>>.from(data['calls']);
        }
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('Error getting call history: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getPendingCalls() async {
    final token = await _getToken();
    
    try {
      final resp = await http.get(
        _uri('/api/calls/pending'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('Error getting pending calls: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> acceptCall(String callId) async {
    final token = await _getToken();
    
    final resp = await http.post(
      _uri('/api/calls/$callId/accept'),
      headers: _authHeaders(token),
    );
    
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    
    throw Exception('Failed to accept call: ${resp.body}');
  }

  Future<void> rejectCall(String callId) async {
    final token = await _getToken();
    
    final resp = await http.post(
      _uri('/api/calls/$callId/reject'),
      headers: _authHeaders(token),
    );
    
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Failed to reject call: ${resp.body}');
    }
  }

  // ============================================
  // VOICE SAMPLE ENDPOINTS
  // ============================================

  Future<Map<String, dynamic>> uploadVoiceSample(String filePath, String language, String textContent) async {
    final token = await _getToken();
    
    var request = http.MultipartRequest('POST', _uri('/api/voice/upload'));
    // Don't add Content-Type header for multipart - it's set automatically
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['language'] = language;
    request.fields['text_content'] = textContent;
    
    // Explicitly set content type for WAV audio file
    final file = await http.MultipartFile.fromPath(
      'file',
      filePath,
      contentType: MediaType('audio', 'wav'),
    );
    request.files.add(file);
    
    debugPrint('[API] Uploading voice to: ${_uri('/api/voice/upload')}');
    
    final streamedResponse = await request.send();
    final resp = await http.Response.fromStream(streamedResponse);
    
    debugPrint('[API] Upload response: ${resp.statusCode} - ${resp.body}');
    
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    
    throw Exception('Failed to upload voice sample: ${resp.body}');
  }

  Future<List<Map<String, dynamic>>> getVoiceRecordings() async {
    final token = await _getToken();
    
    try {
      final resp = await http.get(
        _uri('/api/voice/recordings'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map && data['recordings'] != null) {
          return List<Map<String, dynamic>>.from(data['recordings']);
        }
      }
    } catch (e) {
      debugPrint('Error getting voice recordings: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getVoiceStatus() async {
    final token = await _getToken();
    
    try {
      final resp = await http.get(
        _uri('/api/voice/status'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting voice status: $e');
    }
    
    return {
      'has_voice_sample': false,
      'voice_model_trained': false,
      'voice_quality_score': null,
      'recordings_count': 0,
    };
  }

  Future<void> deleteVoiceRecording(String recordingId) async {
    final token = await _getToken();
    
    await http.delete(
      _uri('/api/voice/recordings/$recordingId'),
      headers: _authHeaders(token),
    );
  }

  /// Alias for deleteVoiceRecording for compatibility
  Future<void> deleteVoiceSample(String recordingId) async {
    return deleteVoiceRecording(recordingId);
  }

  Future<Map<String, dynamic>> trainVoiceModel() async {
    final token = await _getToken();
    
    final resp = await http.post(
      _uri('/api/voice/train'),
      headers: _authHeaders(token),
    );
    
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    
    throw Exception('Failed to start training');
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  Future<bool> checkHealth() async {
    try {
      final resp = await http.get(_uri('/health'));
      return resp.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Legacy compatibility method
  Future<Map<String, dynamic>> createContact(String name, String language, {String? phone}) async {
    // This would need a user search first in real implementation
    throw UnimplementedError('Use searchUsers + addContact instead');
  }
}
