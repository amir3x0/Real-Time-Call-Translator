import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';

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
  String? _userId;
  String? _callId;
  bool _isConnected = false;

  /// Stream of control messages (JSON)
  Stream<WSMessage> get messages =>
      _messageController?.stream ?? const Stream.empty();

  /// Stream of incoming audio data
  Stream<Uint8List> get audioStream =>
      _audioController?.stream ?? const Stream.empty();

  /// Whether connected to WebSocket
  bool get isConnected => _isConnected;

  /// Current session ID
  String? get sessionId => _sessionId;

  /// Current call ID
  String? get callId => _callId;

  /// Connect to a call session
  ///
  /// Parameters:
  /// - sessionId: Call session ID from startCall response
  /// - callId: Call ID (optional, for database reference)
  /// - token: JWT Token for authentication
  Future<bool> connect(String sessionId,
      {String? callId, String? token}) async {
    if (_isConnected) {
      await disconnect();
    }

    try {
      // Get user ID and token from storage
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString(AppConfig.userIdKey);

      // Use provided token or fallback to storage
      final authToken = token ?? prefs.getString(AppConfig.userTokenKey);

      if (_userId == null) {
        debugPrint('[WebSocketService] No user ID found');
        return false;
      }

      if (authToken == null) {
        debugPrint('[WebSocketService] No auth token found');
        return false;
      }

      _sessionId = sessionId;
      _callId = callId;

      // Build WebSocket URL with query parameters
      // backend expects /ws/{session_id}?token={token}
      final wsUrl =
          '${AppConfig.wsUrl}${AppConfig.wsEndpoint}/$sessionId?token=$authToken';

      if (callId != null) {
        // Add call_id if available (though backend might not check it if not in params explicitly)
        // Adding it anyway for completeness if backend updates
      }

      debugPrint(
          '[WebSocketService] Connecting directly to session: $sessionId');

      // Create WebSocket connection
      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        pingInterval: const Duration(seconds: 10),
      );

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
      return true;
    } catch (e) {
      debugPrint('[WebSocketService] Connection error: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Disconnect from the WebSocket
  Future<void> disconnect() async {
    debugPrint('[WebSocketService] Disconnecting...');

    _stopHeartbeat();

    // Send leave message before closing
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'leave'}));
        await Future.delayed(const Duration(milliseconds: 100));
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
    _userId = null;

    debugPrint('[WebSocketService] Disconnected');
  }

  /// Send audio data to other participants
  void sendAudio(Uint8List audioData) {
    if (!_isConnected || _channel == null) return;

    try {
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
      const Duration(seconds: 30),
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
      final audioData = Uint8List.fromList(message);
      _audioController?.add(audioData);
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

    _messageController?.add(WSMessage(
      type: WSMessageType.callEnded,
      data: {'reason': 'connection_closed'},
    ));
  }
}

/// Mock WebSocket service for testing/development
class MockWebSocketService extends WebSocketService {
  Timer? _mockTimer;
  final List<String> _mockTranscripts = [
    'שלום, מה שלומך?',
    'Hello, how are you?',
    'Привет, как дела?',
    'התרגום עובד מצוין',
    'The translation is working great',
  ];
  int _transcriptIndex = 0;

  @override
  Future<bool> connect(String sessionId,
      {String? callId, String? token}) async {
    await Future.delayed(const Duration(milliseconds: 500));

    _messageController = StreamController<WSMessage>.broadcast();
    _audioController = StreamController<Uint8List>.broadcast();
    _isConnected = true;
    _sessionId = sessionId;
    _callId = callId;

    // Send connected message
    _messageController?.add(WSMessage(
      type: WSMessageType.connected,
      data: {
        'session_id': sessionId,
        'call_id': callId ?? 'mock_call',
        'call_language': 'he',
        'participant_language': 'he',
        'dubbing_required': false,
      },
    ));

    // Start mock transcription
    _startMockTranscription();

    return true;
  }

  void _startMockTranscription() {
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isConnected) return;

      _messageController?.add(WSMessage(
        type: WSMessageType.transcript,
        data: {
          'text': _mockTranscripts[_transcriptIndex % _mockTranscripts.length],
          'speaker_id': 'mock_speaker',
          'language': _transcriptIndex % 2 == 0 ? 'he' : 'en',
        },
      ));

      _transcriptIndex++;
    });
  }

  @override
  Future<void> disconnect() async {
    _mockTimer?.cancel();
    _mockTimer = null;
    await super.disconnect();
  }

  @override
  void sendAudio(Uint8List audioData) {
    // Mock: Echo back after delay
    if (_isConnected) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _audioController?.add(audioData);
      });
    }
  }
}
