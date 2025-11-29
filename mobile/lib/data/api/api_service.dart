import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.userIdKey);
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
      throw Exception('Login failed: ${resp.body}');
    } catch (e) {
      // Fallback mock for development
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
  }

  Future<User> register(String phone, String fullName, String password, String primaryLanguage) async {
    try {
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
        // Fetch full profile
        final meUser = await me();
        if (meUser != null) return meUser;
        // Fallback minimal
        return User(
          id: userId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          phone: phone,
          fullName: fullName,
          primaryLanguage: primaryLanguage,
          supportedLanguages: [primaryLanguage],
          createdAt: DateTime.now(),
        );
      }
      throw Exception('Registration failed: ${resp.body}');
    } catch (e) {
      // Fallback mock
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
  }

  Future<User?> me() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final resp = await http.get(
        _uri('/api/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return User.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  // ============================================
  // CONTACTS ENDPOINTS
  // ============================================

  Future<List<Map<String, dynamic>>> getContacts() async {
    try {
      final token = await _getToken();
      final resp = await http.get(
        _uri('/api/contacts'),
        headers: _authHeaders(token),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final contacts = (data['contacts'] as List).cast<Map<String, dynamic>>();
        return contacts
            .map((c) => {
                  'id': c['user_id'] ?? c['id'],
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

  Future<List<User>> searchUsers(String query) async {
    try {
      final token = await _getToken();
      final resp = await http.get(
        _uri('/api/users/search', {'query': query}),
        headers: _authHeaders(token),
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

  Future<bool> addContact(String userId) async {
    try {
      final token = await _getToken();
      final resp = await http.post(
        _uri('/api/contacts/add'),
        headers: _authHeaders(token),
        body: jsonEncode({'contact_user_id': userId}),
      );
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Create a new contact (alias for legacy compatibility)
  /// Returns the created contact data as a Map
  Future<Map<String, dynamic>> createContact(
    String name,
    String language, {
    String? phone,
  }) async {
    try {
      final token = await _getToken();
      final resp = await http.post(
        _uri('/api/contacts/add'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'contact_name': name,
          'primary_language': language,
          if (phone != null) 'phone': phone,
        }),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to create contact: ${resp.body}');
    } catch (_) {
      // Mock fallback
      return {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'phone': phone ?? '',
        'language': language,
        'status': 'offline',
      };
    }
  }

  Future<void> deleteContact(String id) async {
    try {
      final token = await _getToken();
      final resp = await http.delete(
        _uri('/api/contacts/$id'),
        headers: _authHeaders(token),
      );
      if (resp.statusCode == 204 || resp.statusCode == 200) return;
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // ============================================
  // CALL MANAGEMENT ENDPOINTS
  // ============================================

  /// Start a new call with specified participants
  /// 
  /// Returns call info including:
  /// - call_id: Unique call identifier
  /// - session_id: WebSocket session identifier
  /// - call_language: Language of the call (caller's primary language)
  /// - websocket_url: URL to connect via WebSocket
  /// - participants: List of participant info with dubbing requirements
  Future<Map<String, dynamic>> startCall(List<String> participantUserIds) async {
    try {
      final token = await _getToken();
      final resp = await http.post(
        _uri('/api/calls/start'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'participant_user_ids': participantUserIds,
          'skip_contact_validation': false,
        }),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return {
          'call_id': data['call_id'],
          'session_id': data['session_id'],
          'call_language': data['call_language'],
          'websocket_url': data['websocket_url'],
          'participants': (data['participants'] as List).map((p) => {
            'id': p['id'],
            'user_id': p['user_id'],
            'full_name': p['full_name'],
            'phone': p['phone'],
            'primary_language': p['primary_language'],
            'target_language': p['target_language'],
            'speaking_language': p['speaking_language'],
            'dubbing_required': p['dubbing_required'],
            'use_voice_clone': p['use_voice_clone'],
            'voice_clone_quality': p['voice_clone_quality'],
          }).toList(),
        };
      }
      throw Exception('Failed to start call: ${resp.body}');
    } catch (e) {
      // Fallback mock for development
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      return {
        'call_id': 'mock_call_$sessionId',
        'session_id': sessionId,
        'call_language': 'he',
        'websocket_url': '${AppConfig.wsUrl}/$sessionId',
        'participants': participantUserIds.map((id) => {
          'id': 'p$id',
          'user_id': id,
          'full_name': 'Mock User $id',
          'phone': '052-000-000$id',
          'primary_language': 'he',
          'target_language': 'en',
          'speaking_language': 'he',
          'dubbing_required': true,
          'use_voice_clone': false,
          'voice_clone_quality': null,
        }).toList(),
      };
    }
  }

  /// End an active call
  Future<Map<String, dynamic>> endCall(String callId) async {
    try {
      final token = await _getToken();
      final resp = await http.post(
        _uri('/api/calls/end'),
        headers: _authHeaders(token),
        body: jsonEncode({'call_id': callId}),
      );
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    
    return {
      'call_id': callId,
      'status': 'ended',
      'message': 'Call ended',
    };
  }

  /// Join an existing call
  Future<Map<String, dynamic>> joinCall(String callId) async {
    try {
      final token = await _getToken();
      final resp = await http.post(
        _uri('/api/calls/$callId/join'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    
    return {'message': 'Joined call', 'call_id': callId};
  }

  /// Leave an active call
  Future<Map<String, dynamic>> leaveCall(String callId) async {
    try {
      final token = await _getToken();
      final resp = await http.post(
        _uri('/api/calls/$callId/leave'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    
    return {'message': 'Left call', 'call_id': callId};
  }

  /// Toggle mute status in a call
  Future<bool> toggleMute(String callId, bool muted) async {
    try {
      final token = await _getToken();
      final resp = await http.post(
        _uri('/api/calls/$callId/mute', {'muted': muted.toString()}),
        headers: _authHeaders(token),
      );
      
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get call details
  Future<Map<String, dynamic>?> getCall(String callId) async {
    try {
      final token = await _getToken();
      final resp = await http.get(
        _uri('/api/calls/$callId'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Get call history
  Future<List<Map<String, dynamic>>> getCallHistory({int limit = 20}) async {
    try {
      final token = await _getToken();
      final resp = await http.get(
        _uri('/api/calls/history', {'limit': limit.toString()}),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['calls'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  // ============================================
  // VOICE SAMPLE ENDPOINTS
  // ============================================

  /// Upload a voice sample for voice cloning
  Future<Map<String, dynamic>> uploadVoiceSample(
    String filePath,
    String language,
    String textContent,
  ) async {
    try {
      final token = await _getToken();
      final file = File(filePath);
      
      final request = http.MultipartRequest(
        'POST',
        _uri('/api/voice/upload'),
      );
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      request.fields['language'] = language;
      request.fields['text_content'] = textContent;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      
      final response = await request.send();
      final respBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        return jsonDecode(respBody) as Map<String, dynamic>;
      }
      throw Exception('Upload failed: $respBody');
    } catch (e) {
      // Mock fallback
      return {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'user_id': await _getUserId() ?? 'unknown',
        'language': language,
        'text_content': textContent,
        'file_path': '/mock/voice_samples/${DateTime.now().millisecondsSinceEpoch}.wav',
        'is_processed': false,
        'used_for_training': false,
      };
    }
  }

  /// Get voice recordings list
  Future<List<Map<String, dynamic>>> getVoiceRecordings() async {
    try {
      final token = await _getToken();
      final resp = await http.get(
        _uri('/api/voice/recordings'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['recordings'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  /// Get voice status for current user
  Future<Map<String, dynamic>> getVoiceStatus() async {
    try {
      final token = await _getToken();
      final resp = await http.get(
        _uri('/api/voice/status'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    
    return {
      'has_voice_sample': false,
      'voice_model_trained': false,
      'recordings_count': 0,
      'training_ready': false,
    };
  }

  /// Trigger voice model training
  Future<Map<String, dynamic>> trainVoiceModel() async {
    try {
      final token = await _getToken();
      final resp = await http.post(
        _uri('/api/voice/train'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      throw Exception('Training failed: ${resp.body}');
    } catch (e) {
      return {
        'message': 'Voice model training queued',
        'status': 'pending',
      };
    }
  }

  /// Get detailed training status
  Future<Map<String, dynamic>> getTrainingStatus() async {
    try {
      final token = await _getToken();
      final resp = await http.get(
        _uri('/api/voice/training-status'),
        headers: _authHeaders(token),
      );
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    
    return {
      'voice_model_trained': false,
      'ready_for_training': false,
      'samples_needed': 2,
    };
  }

  /// Delete a voice recording
  Future<void> deleteVoiceRecording(String recordingId) async {
    try {
      final token = await _getToken();
      await http.delete(
        _uri('/api/voice/recordings/$recordingId'),
        headers: _authHeaders(token),
      );
    } catch (_) {}
  }

  /// Delete a voice sample (alias for deleteVoiceRecording)
  Future<void> deleteVoiceSample(String userId) async {
    await deleteVoiceRecording(userId);
  }
}
