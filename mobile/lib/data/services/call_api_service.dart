/// Call API Service - Call lifecycle management via REST API.
///
/// Handles all call-related API operations:
/// - Starting calls with multiple participants
/// - Accepting/rejecting incoming calls
/// - Ending calls and leaving active calls
/// - Muting/unmuting during calls
/// - Fetching call history and pending calls
///
/// Note: Real-time audio/translation uses WebSocket (see websocket_service.dart).
/// This service handles the REST API for call state management.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/user.dart';
import 'base_api_service.dart';

/// Service for call management via REST API.
class CallApiService extends BaseApiService {
  Future<Map<String, dynamic>> startCall(
      List<String> participantUserIds) async {
    final resp = await post('/api/calls/start', body: {
      'participant_user_ids': participantUserIds,
      'skip_contact_validation': true,
    });

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to start call: ${resp.body}');
  }

  Future<Map<String, dynamic>> initiateQuickCall(User currentUser) async {
    return startCall([currentUser.id]);
  }

  Future<void> endCall(String callId) async {
    await post('/api/calls/$callId/end');
  }

  Future<void> leaveCall(String callId) async {
    await post('/api/calls/$callId/leave');
  }

  Future<void> muteCall(String callId, bool muted) async {
    await post('/api/calls/$callId/mute', body: {'muted': muted});
  }

  Future<List<Map<String, dynamic>>> getCallHistory() async {
    try {
      final resp = await get('/api/calls/history');
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
    try {
      final resp = await get('/api/calls/pending');
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
    final resp = await post('/api/calls/$callId/accept');
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to accept call: ${resp.body}');
  }

  Future<void> rejectCall(String callId) async {
    final resp = await post('/api/calls/$callId/reject');
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Failed to reject call: ${resp.body}');
    }
  }

  Future<void> resetCallState() async {
    final resp = await post('/api/calls/debug/reset_state');
    if (resp.statusCode != 200) {
      throw Exception('Failed to reset state: ${resp.body}');
    }
  }
}
