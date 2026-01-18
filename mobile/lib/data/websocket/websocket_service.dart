import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../../config/app_config.dart';
import '../../config/constants.dart';

/// Message types for WebSocket communication
enum WSMessageType {
  connected,
  heartbeat,
  heartbeatAck,
  mute,
  muteAck,
  leave,
  ping,
  pong,
  participantJoined,
  participantLeft,
  muteStatusChanged,
  callEnded,
  transcript,
  transcriptionUpdate,
  translation,
  interimTranscript, // Real-time typing indicator captions
  audio,
  incomingCall,
  userStatusChanged,
  contactRequest,
  error,
}

/// WebSocket message data
class WSMessage {
  final WSMessageType type;
  final Map<String, dynamic>? data;
  final Uint8List? audioData;

  WSMessage({
    required this.type,
    this.data,
    this.audioData,
  });

  factory WSMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final type = _parseMessageType(typeStr);
    return WSMessage(type: type, data: json);
  }

  static WSMessageType _parseMessageType(String? type) {
    switch (type) {
      case 'connected':
        return WSMessageType.connected;
      case 'heartbeat':
        return WSMessageType.heartbeat;
      case 'heartbeat_ack':
        return WSMessageType.heartbeatAck;
      case 'mute':
        return WSMessageType.mute;
      case 'mute_ack':
        return WSMessageType.muteAck;
      case 'pong':
        return WSMessageType.pong;
      case 'participant_joined':
        return WSMessageType.participantJoined;
      case 'participant_left':
        return WSMessageType.participantLeft;
      case 'mute_status_changed':
        return WSMessageType.muteStatusChanged;
      case 'call_ended':
        return WSMessageType.callEnded;
      case 'transcript':
        return WSMessageType.transcript;
      case 'transcription_update':
        return WSMessageType.transcriptionUpdate;
      case 'translation':
        return WSMessageType.translation;
      case 'interim_transcript':
        return WSMessageType.interimTranscript;
      case 'audio':
        return WSMessageType.audio;
      case 'incoming_call':
        return WSMessageType.incomingCall;
      case 'user_status_changed':
        return WSMessageType.userStatusChanged;
      case 'contact_request':
        return WSMessageType.contactRequest;
      case 'error':
        return WSMessageType.error;
      default:
        return WSMessageType.error;
    }
  }
}

/// WebSocket service for real-time call communication
///
/// Handles:
/// - Connection to call session
/// - Sending/receiving audio data
/// - Heartbeat for connection status
/// - Control messages (mute, leave, etc.)
class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<WSMessage>? _messageController;
  StreamController<Uint8List>? _audioController;
  Timer? _heartbeatTimer;
  String? _sessionId;
  String? _callId;
  bool _isConnected = false;
  bool _intentionalDisconnect = false;

  // Issue A Fix: Reconnection state
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = AppConstants.wsMaxReconnectAttempts;

  // Store connection params for reconnect
  String? _userId;
  String? _token;

  /// Stream of control messages (JSON)
  Stream<WSMessage> get messages =>
      _messageController?.stream ?? const Stream.empty();

  /// Stream of incoming audio data
  Stream<Uint8List> get audioStream =>
      _audioController?.stream ?? const Stream.empty();

  /// Whether connected to WebSocket
  bool get isConnected => _isConnected;

  /// Issue A: Whether attempting to reconnect
  bool get isReconnecting => _isReconnecting;

  /// Current session ID
  String? get sessionId => _sessionId;

  /// Current call ID
  String? get callId => _callId;

  /// Connect to a call session
  ///
  /// Parameters:
  /// - sessionId: Call session ID from startCall response
  /// - userId: Current User ID
  /// - token: JWT Token for authentication
  /// - callId: Call ID (optional, for database reference)
  Future<bool> connect(
    String sessionId, {
    required String userId,
    required String token,
    String? callId,
  }) async {
    if (_isConnected) {
      await disconnect();
    }

    try {
      _userId = userId;
      _token = token;
      _sessionId = sessionId;
      _callId = callId;
      _reconnectAttempts = 0; // Reset on fresh connect

      // Build WebSocket URL with query parameters
      // backend expects /ws/{session_id}?token={token}
      final wsUrl =
          '${AppConfig.wsUrl}${AppConfig.wsEndpoint}/$sessionId?token=$token';

      if (callId != null) {
        // Add call_id if available (though backend might not check it if not in params explicitly)
        // Adding it anyway for completeness if backend updates
      }

      debugPrint(
          '[WebSocketService] Connecting directly to session: $sessionId');

      // Create WebSocket connection
      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        pingInterval:
            const Duration(seconds: AppConstants.wsPingIntervalSeconds),
      );

      // ⭐ FIX: Wait for connection with timeout - fail fast on unreachable server
      try {
        await _channel!.ready.timeout(
          const Duration(seconds: AppConstants.wsConnectTimeoutSeconds),
          onTimeout: () {
            throw TimeoutException(
              'WebSocket connection timeout after ${AppConstants.wsConnectTimeoutSeconds}s',
            );
          },
        );
      } catch (e) {
        debugPrint('[WebSocketService] Connection failed: $e');
        await _channel?.sink.close();
        _channel = null;
        rethrow;
      }

      // Initialize stream controllers
      _messageController = StreamController<WSMessage>.broadcast();
      _audioController = StreamController<Uint8List>.broadcast();

      // Listen to incoming messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      _isConnected = true;

      // Start heartbeat
      _startHeartbeat();

      debugPrint('[WebSocketService] Connected to session $sessionId');

      // TEST BINARY TRANSMISSION
      sendTestBinary();

      return true;
    } catch (e) {
      debugPrint('[WebSocketService] Connection error: $e');
      _isConnected = false;

      // ⭐ FIX: Clean up partially created resources to prevent memory leaks
      await _messageController?.close();
      _messageController = null;
      await _audioController?.close();
      _audioController = null;
      await _channel?.sink.close();
      _channel = null;
      _sessionId = null;
      _callId = null;

      return false;
    }
  }

  void sendTestBinary() {
    if (_isConnected && _channel != null) {
      debugPrint('[WebSocketService] Sending TEST BINARY packet (4 bytes)');
      _channel!.sink.add(Uint8List.fromList([1, 2, 3, 4]));
    }
  }

  /// Disconnect from the WebSocket
  Future<void> disconnect() async {
    debugPrint(
        '[WebSocketService] Disconnecting... from:\n${StackTrace.current}');

    _intentionalDisconnect = true; // Mark as intentional to prevent callEnded
    _stopHeartbeat();

    // Send leave message before closing
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'leave'}));
        await Future.delayed(
            const Duration(milliseconds: AppConstants.wsCloseDelayMs));
      } catch (_) {}
    }

    await _channel?.sink.close();
    _channel = null;

    await _messageController?.close();
    _messageController = null;

    await _audioController?.close();
    _audioController = null;

    _isConnected = false;
    _sessionId = null;
    _callId = null;
    // _userId = null;

    debugPrint('[WebSocketService] Disconnected');
  }

  /// Send audio data to other participants
  void sendAudio(Uint8List audioData) {
    if (!_isConnected || _channel == null) return;

    try {
      // Changed to Base64 JSON to avoid binary transport issues
      _channel!.sink.add(audioData);
    } catch (e) {
      debugPrint('[WebSocketService] Error sending audio: $e');
    }
  }

  /// Send a JSON message
  void sendMessage(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) return;

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('[WebSocketService] Error sending message: $e');
    }
  }

  /// Send mute status change
  void setMuted(bool muted) {
    sendMessage({'type': 'mute', 'muted': muted});
  }

  /// Send heartbeat
  void _sendHeartbeat() {
    sendMessage({'type': 'heartbeat'});
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: AppConstants.wsHeartbeatIntervalSeconds),
      (_) => _sendHeartbeat(),
    );
    // Send initial heartbeat
    _sendHeartbeat();
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Handle incoming WebSocket message
  void _handleMessage(dynamic message) {
    debugPrint('[WebSocketService] Msg Type: ${message.runtimeType}');
    if (message is String) {
      // JSON message
      try {
        final json = jsonDecode(message) as Map<String, dynamic>;
        final wsMessage = WSMessage.fromJson(json);
        _messageController?.add(wsMessage);

        // Log message type for debugging
        debugPrint('[WebSocketService] Received message: ${json['type']}');
      } catch (e) {
        debugPrint('[WebSocketService] Error parsing JSON: $e');
      }
    } else if (message is List<int>) {
      // Binary audio data
      debugPrint(
          '[WebSocketService] Received audio chunk: ${message.length} bytes');
      final audioData = Uint8List.fromList(message);

      // Debug: Check if audio controller exists and has listeners
      if (_audioController == null) {
        debugPrint(
            '[WebSocketService] ⚠️ _audioController is NULL! Audio will be lost!');
      } else if (_audioController!.isClosed) {
        debugPrint(
            '[WebSocketService] ⚠️ _audioController is CLOSED! Audio will be lost!');
      } else {
        debugPrint(
            '[WebSocketService] ✅ Adding audio to stream (hasListener: ${_audioController!.hasListener})');
        _audioController!.add(audioData);
      }
    }
  }

  /// Handle WebSocket error
  void _handleError(dynamic error) {
    debugPrint('[WebSocketService] Error: $error');
    _messageController?.add(WSMessage(
      type: WSMessageType.error,
      data: {'error': error.toString()},
    ));
  }

  /// Handle WebSocket connection closed
  void _handleDone() {
    debugPrint('[WebSocketService] Connection closed');
    _isConnected = false;
    _stopHeartbeat();

    // Don't reconnect if this was intentional or if it's the lobby
    if (_intentionalDisconnect || _sessionId == 'lobby') {
      _intentionalDisconnect = false;
      debugPrint('[WebSocketService] Intentional disconnect, not reconnecting');
      return;
    }

    // Issue A Fix: Attempt reconnect for call sessions
    if (_sessionId != null && _userId != null && _token != null) {
      _attemptReconnect();
    } else {
      // Can't reconnect - missing params
      _messageController?.add(WSMessage(
        type: WSMessageType.callEnded,
        data: {'reason': 'connection_closed'},
      ));
    }
  }

  /// Calculate exponential backoff delay: 2s, 4s, 8s...
  Duration _getBackoffDelay(int attempt) {
    // Exponential backoff: baseDelay * 2^attempt (capped at 8s)
    final seconds = AppConstants.wsReconnectDelaySeconds * (1 << attempt);
    final cappedSeconds = seconds > 8 ? 8 : seconds;
    return Duration(seconds: cappedSeconds);
  }

  /// Issue A Fix: Attempt to reconnect with exponential backoff (2-4-8s)
  Future<void> _attemptReconnect() async {
    if (_isReconnecting) return; // Already trying

    _isReconnecting = true;
    debugPrint(
        '[WebSocketService] 🔄 Attempting to reconnect (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');

    // Notify UI that we're reconnecting
    _messageController?.add(WSMessage(
      type: WSMessageType.error,
      data: {'error': 'reconnecting', 'attempt': _reconnectAttempts + 1},
    ));

    while (
        _reconnectAttempts < _maxReconnectAttempts && !_intentionalDisconnect) {
      // ⭐ Exponential backoff: 2s → 4s → 8s
      final backoffDelay = _getBackoffDelay(_reconnectAttempts);
      debugPrint(
          '[WebSocketService] Waiting ${backoffDelay.inSeconds}s before attempt ${_reconnectAttempts + 1}...');
      await Future.delayed(backoffDelay);
      _reconnectAttempts++;

      debugPrint('[WebSocketService] Reconnect attempt $_reconnectAttempts...');

      final success = await connect(
        _sessionId!,
        userId: _userId!,
        token: _token!,
        callId: _callId,
      );

      if (success) {
        debugPrint('[WebSocketService] ✅ Reconnected successfully!');
        _isReconnecting = false;
        _reconnectAttempts = 0;
        return;
      }
    }

    // All attempts failed - end the call
    debugPrint(
        '[WebSocketService] ❌ Reconnect failed after $_maxReconnectAttempts attempts');
    _isReconnecting = false;
    _messageController?.add(WSMessage(
      type: WSMessageType.callEnded,
      data: {'reason': 'reconnect_failed'},
    ));
  }
}
