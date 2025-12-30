import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/api/api_service.dart';
import '../models/call.dart';

/// Handles incoming call state and lifecycle.
///
/// Manages:
/// - Incoming call notifications
/// - Accept/reject actions
/// - Call timeout
class IncomingCallHandler {
  final ApiService _apiService;
  final VoidCallback _notifyListeners;

  // State
  Call? _incomingCall;
  CallStatus? _incomingCallStatus;
  String? _incomingCallerName;
  Timer? _callTimeoutTimer;

  IncomingCallHandler(this._apiService, this._notifyListeners);

  Call? get incomingCall => _incomingCall;
  CallStatus? get incomingCallStatus => _incomingCallStatus;
  String? get incomingCallerName => _incomingCallerName;

  /// Handle an incoming call notification
  void handleIncomingCall(Map<String, dynamic>? callData) {
    if (callData == null) return;

    try {
      _incomingCall = Call(
        id: callData['call_id'] as String? ?? '',
        sessionId: '',
        status: CallStatus.ringing,
        callLanguage: callData['call_language'] as String? ?? 'he',
        callerUserId: callData['caller_id'] as String?,
        createdBy: callData['caller_id'] as String? ?? '',
        createdAt: DateTime.now(),
      );
      _incomingCallerName = callData['caller_name'] as String?;
      _incomingCallStatus = CallStatus.ringing;
      _startCallTimeout();
      _notifyListeners();
    } catch (e) {
      debugPrint('[IncomingCallHandler] Error parsing incoming call: $e');
    }
  }

  void _startCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_incomingCall != null) {
        rejectIncomingCall();
      }
    });
  }

  /// Accept the incoming call
  ///
  /// Returns call data from API if successful, null otherwise
  Future<Map<String, dynamic>?> acceptIncomingCall() async {
    if (_incomingCall == null) return null;

    try {
      final callData = await _apiService.acceptCall(_incomingCall!.id);
      _clearIncomingCall();
      return callData;
    } catch (e) {
      debugPrint('[IncomingCallHandler] Error accepting call: $e');
      _clearIncomingCall();
      return null;
    }
  }

  /// Reject the incoming call
  Future<void> rejectIncomingCall() async {
    if (_incomingCall == null) return;

    try {
      await _apiService.rejectCall(_incomingCall!.id);
    } catch (e) {
      debugPrint('[IncomingCallHandler] Error rejecting call: $e');
    }

    _clearIncomingCall();
  }

  void _clearIncomingCall() {
    _incomingCall = null;
    _incomingCallStatus = null;
    _incomingCallerName = null;
    _callTimeoutTimer?.cancel();
    _notifyListeners();
  }

  /// Dispose resources
  void dispose() {
    _callTimeoutTimer?.cancel();
  }
}
