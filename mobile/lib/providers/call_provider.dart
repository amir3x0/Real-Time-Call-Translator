import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/websocket/websocket_service.dart';
import '../data/services/call_api_service.dart';
import '../models/call.dart';
import '../models/live_caption.dart';
import '../models/participant.dart';
import 'audio_controller.dart';
import 'caption_manager.dart';

/// Managed Active Call Sessions.
///
/// Responsibilities:
/// - Connects to specific Call Session WebSocket
/// - Handles Audio/Microphone
/// - Handles Transcripts
/// - Handles Participant Updates
class CallProvider with ChangeNotifier {
  CallStatus _status = CallStatus.pending;
  List<CallParticipant> _participants = [];
  String? _activeSessionId;
  String _liveTranscription = "";
  String? _activeSpeakerId;

  bool _disposed = false;

  // Services
  final WebSocketService _wsService;
  final CallApiService _apiService;
  StreamSubscription<WSMessage>? _wsSub;

  // Helpers
  late final AudioController _audioController;
  late final CaptionManager _captionManager;

  CallProvider({
    required WebSocketService wsService,
    required CallApiService apiService,
  })  : _wsService = wsService,
        _apiService = apiService {
    _audioController = AudioController(_wsService, notifyListeners);
    _captionManager = CaptionManager(notifyListeners, () => _disposed);
  }

  // === Getters ===

  CallStatus get status => _status;
  String? get activeSessionId => _activeSessionId;
  List<CallParticipant> get participants => List.unmodifiable(_participants);
  String get liveTranscription => _liveTranscription;
  List<LiveCaptionData> get captionBubbles => _captionManager.captionBubbles;
  String? get activeSpeakerId => _activeSpeakerId;
  bool get isMuted => _audioController.isMuted;
  bool get isSpeakerOn => _audioController.isSpeakerOn;

  // === Testing helpers ===

  @visibleForTesting
  void setParticipantsForTesting(List<CallParticipant> participants) {
    _participants = participants;
    notifyListeners();
  }

  @visibleForTesting
  void setStatusForTesting(CallStatus status) {
    _status = status;
    notifyListeners();
  }

  // === Call Lifecycle ===

  /// Starts a real call by calling backend API and connecting to WebSocket
  Future<void> startCall(List<String> participantUserIds) async {
    _status = CallStatus.initiating; // New status for UI feedback?
    notifyListeners();

    try {
      final resp = await _apiService.startCall(participantUserIds);
      final sessionId = resp['session_id'] as String;
      final parts = resp['participants'] as List<dynamic>;

      _participants = parts
          .map((p) => CallParticipant.fromJson(Map<String, dynamic>.from(p)))
          .toList();
      _status = CallStatus.active;
      _activeSessionId = sessionId;

      // Connect to WS
      await _joinCallSession(sessionId);

      notifyListeners();
    } catch (e) {
      _status = CallStatus.ended; // Or error
      notifyListeners();
      rethrow;
    }
  }

  /// Join an existing call session (e.g. accepting an incoming call)
  Future<void> joinCall(
      String sessionId, List<CallParticipant> participants) async {
    _activeSessionId = sessionId;
    _participants = participants;
    _status = CallStatus.active;

    await _joinCallSession(sessionId);
    notifyListeners();
  }

  Future<void> _joinCallSession(String sessionId) async {
    await _wsSub?.cancel();
    await _wsService.connect(sessionId);
    _wsSub = _wsService.messages.listen(_handleWebSocketMessage);

    // Initialize Audio
    await _audioController.initAudio();
  }

  void endCall() {
    debugPrint('[CallProvider] endCall called');
    _audioController.dispose();
    _status = CallStatus.ended;
    _participants = [];
    _activeSessionId = null;
    _wsSub?.cancel();
    _wsService.disconnect();
    _captionManager.clearBubbles();
    notifyListeners();
  }

  // === Audio Controls ===

  void toggleMute() => _audioController.toggleMute();

  Future<void> toggleSpeaker() => _audioController.toggleSpeaker();

  // === WebSocket Message Handling ===

  void _handleWebSocketMessage(WSMessage message) {
    switch (message.type) {
      case WSMessageType.transcript:
        _handleTranscript(message);
        break;
      case WSMessageType.participantJoined:
        _handleParticipantJoined(message);
        break;
      case WSMessageType.participantLeft:
        break;
      case WSMessageType.muteStatusChanged:
        break;
      case WSMessageType.callEnded:
        endCall();
        break;
      case WSMessageType.error:
        debugPrint('[CallProvider] WebSocket error: ${message.data}');
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void _handleTranscript(WSMessage message) {
    if (_participants.isEmpty) return;
    final text = message.data?['text'] as String? ?? '';
    final speakerId = message.data?['speaker_id'] as String?;
    if (speakerId != null) {
      _liveTranscription = text;
      _setActiveSpeaker(speakerId);
      _captionManager.addCaptionBubble(speakerId, text);
    }
  }

  void _setActiveSpeaker(String? participantId) {
    _activeSpeakerId = participantId;
    _participants = _participants
        .map((p) => p.copyWith(isSpeaking: p.id == participantId))
        .toList(growable: false);
  }

  void _handleParticipantJoined(WSMessage message) {
    if (message.data == null) return;

    final userId = message.data!['user_id'] as String?;
    if (userId == null) return;

    try {
      final index = _participants.indexWhere((p) => p.userId == userId);
      if (index != -1) {
        var p = _participants[index];
        final updatedParticipant = CallParticipant(
          id: p.id,
          callId: p.callId,
          userId: p.userId,
          targetLanguage: p.targetLanguage,
          speakingLanguage: p.speakingLanguage,
          joinedAt: DateTime.now(),
          createdAt: p.createdAt,
          isConnected: true,
          connectionQuality: p.connectionQuality,
          isMuted: p.isMuted,
          displayName: p.displayName,
        );

        final newList = List<CallParticipant>.from(_participants);
        newList[index] = updatedParticipant;
        _participants = newList;
        notifyListeners();
        debugPrint('[CallProvider] Participant $userId marked as connected');
      }
    } catch (e) {
      debugPrint('[CallProvider] Error handling participant join: $e');
    }
  }

  // === Dispose ===

  @override
  void dispose() {
    _disposed = true;
    _wsSub?.cancel();
    _wsService.disconnect();
    _captionManager.dispose();
    super.dispose();
  }
}
