import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Heartbeat Service - Maintains WebSocket connection and sends periodic heartbeats
/// to keep user status as 'online' in real-time
class HeartbeatService {
  static const int _heartbeatInterval = 30; // seconds
  
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  String? _userId;
  String? _sessionId;
  bool _isActive = false;

  /// Singleton instance
  static final HeartbeatService _instance = HeartbeatService._internal();
  factory HeartbeatService() => _instance;
  HeartbeatService._internal();

  /// Start heartbeat service with WebSocket connection
  Future<void> start({
    required String wsUrl,
    required String userId,
    required String sessionId,
  }) async {
    if (_isActive) {
      debugPrint('[HeartbeatService] Already active, stopping previous connection');
      await stop();
    }

    _userId = userId;
    _sessionId = sessionId;
    _isActive = true;

    try {
      // Establish WebSocket connection with user_id query parameter
      final uri = Uri.parse('$wsUrl?user_id=$userId');
      _channel = WebSocketChannel.connect(uri);

      debugPrint('[HeartbeatService] Connected to WebSocket: $wsUrl');

      // Listen for messages from server
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['type'] == 'heartbeat_ack') {
            debugPrint('[HeartbeatService] Heartbeat acknowledged');
          }
        },
        onError: (error) {
          debugPrint('[HeartbeatService] WebSocket error: $error');
          _reconnect();
        },
        onDone: () {
          debugPrint('[HeartbeatService] WebSocket closed');
          if (_isActive) {
            _reconnect();
          }
        },
      );

      // Start sending heartbeats
      _startHeartbeat();
    } catch (e) {
      debugPrint('[HeartbeatService] Failed to connect: $e');
      _isActive = false;
    }
  }

  /// Stop heartbeat service
  Future<void> stop() async {
    debugPrint('[HeartbeatService] Stopping heartbeat service');
    _isActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _channel?.sink.close();
    _channel = null;
  }

  /// Start periodic heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: _heartbeatInterval),
      (timer) {
        _sendHeartbeat();
      },
    );
    
    // Send initial heartbeat immediately
    _sendHeartbeat();
  }

  /// Send heartbeat message to server
  void _sendHeartbeat() {
    if (_channel != null && _isActive) {
      try {
        final message = jsonEncode({
          'type': 'heartbeat',
          'user_id': _userId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _channel!.sink.add(message);
        debugPrint('[HeartbeatService] Heartbeat sent');
      } catch (e) {
        debugPrint('[HeartbeatService] Failed to send heartbeat: $e');
      }
    }
  }

  /// Reconnect WebSocket after connection loss
  Future<void> _reconnect() async {
    if (!_isActive) return;

    debugPrint('[HeartbeatService] Reconnecting in 5 seconds...');
    await Future.delayed(Duration(seconds: 5));

    if (_isActive && _userId != null && _sessionId != null) {
      // Reconstruct WebSocket URL
      final wsUrl = 'ws://localhost:8000/ws/$_sessionId';
      await start(
        wsUrl: wsUrl,
        userId: _userId!,
        sessionId: _sessionId!,
      );
    }
  }

  /// Send audio data over WebSocket
  void sendAudio(List<int> audioBytes) {
    if (_channel != null && _isActive) {
      _channel!.sink.add(audioBytes);
    }
  }

  /// Check if service is currently active
  bool get isActive => _isActive;
}
