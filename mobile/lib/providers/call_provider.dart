import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/websocket/websocket_service.dart';
import '../data/services/call_api_service.dart';
import '../models/call.dart';
import '../models/live_caption.dart';
import '../models/participant.dart';
import '../models/transcription_entry.dart';
import 'audio_controller.dart';
import 'caption_manager.dart';
import 'transcription_manager.dart';

/// Callback for when call ends remotely (e.g., other participant left)
typedef OnCallEndedCallback = void Function(String reason);

/// Managed Active Call Sessions.
///
/// Responsibilities:
/// - Connects to specific Call Session WebSocket
/// - Handles Audio/Microphone
/// - Handles Transcripts
/// - Handles Participant Updates
class CallProvider with ChangeNotifier {
  CallStatus _status = CallStatus.idle;
  List<CallParticipant> _participants = [];
  String? _activeSessionId;
  String? _liveTranscription;
  String? _activeSpeakerId;

  /// Current user ID - set when joining a call
  String? _currentUserId;
  String? _authToken;

  bool _disposed = false;

  /// Callback invoked when call ends remotely
  OnCallEndedCallback? onCallEnded;

  // Services
  final WebSocketService _wsService;
  final CallApiService _apiService;
  StreamSubscription<WSMessage>? _wsSub;

  // Helpers (SRP: Each handles specific responsibility)
  late final AudioController _audioController;
  late final CaptionManager _captionManager;
  late final TranscriptionManager _transcriptionManager;

  CallProvider({
    required WebSocketService wsService,
    required CallApiService apiService,
  })  : _wsService = wsService,
        _apiService = apiService {
    _audioController = AudioController(_wsService, notifyListeners);
    _captionManager = CaptionManager(notifyListeners, () => _disposed);
    _transcriptionManager =
        TranscriptionManager(notifyListeners, () => _disposed);
  }

  // === Getters ===

  CallStatus get status => _status;
  String? get activeSessionId => _activeSessionId;
  List<CallParticipant> get participants => List.unmodifiable(_participants);
  String get liveTranscription => _liveTranscription ?? '';
  List<LiveCaptionData> get captionBubbles => _captionManager.captionBubbles;
  List<TranscriptionEntry> get transcriptionHistory =>
      _transcriptionManager.entries;
  TranscriptionEntry? get latestTranscription =>
      _transcriptionManager.latestEntry;
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
  /// [currentUserId] is needed for audio routing (to avoid hearing your own translation)
  Future<void> startCall(List<String> participantUserIds,
      {required String currentUserId, required String token}) async {
    _currentUserId = currentUserId;
    _authToken = token;
    _status = CallStatus.initiating;
    notifyListeners();

    try {
      await _initiateCallWithRetry(participantUserIds);
    } catch (e) {
      debugPrint('[CallProvider] Error starting call: $e');
      _status = CallStatus.ended;
      notifyListeners();
      rethrow;
    }
  }

  /// Attempts to initiate call, with auto-recovery from stuck state
  Future<void> _initiateCallWithRetry(List<String> participantUserIds) async {
    try {
      await _executeCallInitiation(participantUserIds);
    } catch (e) {
      if (_isStuckInCallError(e)) {
        await _recoverFromStuckState(participantUserIds);
      } else {
        rethrow;
      }
    }
  }

  /// Core call initiation logic - single responsibility: start a call
  Future<void> _executeCallInitiation(List<String> participantUserIds) async {
    debugPrint(
        '[CallProvider] Starting call with participants: $participantUserIds');
    final resp = await _apiService.startCall(participantUserIds);
    await _processCallResponse(resp);
  }

  /// Process API response and setup call state
  Future<void> _processCallResponse(Map<String, dynamic> resp) async {
    debugPrint('[CallProvider] Received response: $resp');

    final sessionId = resp['session_id'] as String;
    final callId = resp['call_id'] as String?;
    final parts = resp['participants'] as List<dynamic>;

    _participants = parts
        .map((p) => CallParticipant.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    _status = CallStatus.ongoing;
    _activeSessionId = sessionId;

    debugPrint(
        '[CallProvider] Connecting to WebSocket: session=$sessionId, call=$callId');
    await _joinCallSession(sessionId, callId: callId);
    notifyListeners();
  }

  /// Check if error is "already in active call" error
  bool _isStuckInCallError(Object error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('already in') && errorStr.contains('active call');
  }

  /// Recover from stuck call state and retry
  Future<void> _recoverFromStuckState(List<String> participantUserIds) async {
    debugPrint('[CallProvider] Detected stuck call state - auto-resetting...');
    await _apiService.resetCallState();
    debugPrint('[CallProvider] Reset successful, retrying call...');
    await _executeCallInitiation(participantUserIds);
  }

  /// Join an existing call session (e.g. accepting an incoming call)
  Future<void> joinCall(String sessionId, List<CallParticipant> participants,
      {required String currentUserId, required String token}) async {
    _activeSessionId = sessionId;
    _participants = participants;
    _status = CallStatus.ongoing;
    _currentUserId = currentUserId;
    _authToken = token;

    await _joinCallSession(sessionId);
    notifyListeners();
  }

  Future<void> _joinCallSession(String sessionId, {String? callId}) async {
    debugPrint(
        '[CallProvider] Joining call session: $sessionId, call_id: $callId');
    await _wsSub?.cancel();
    if (_currentUserId == null || _authToken == null) {
      debugPrint('[CallProvider] Missing credentials for WebSocket connection');
      return;
    }
    final connected = await _wsService.connect(
      sessionId,
      userId: _currentUserId!,
      token: _authToken!,
      callId: callId,
    );
    if (!connected) {
      debugPrint(
          '[CallProvider] FAILED to connect to call session: $sessionId');
      // Optionally handle error state here
      return;
    }

    debugPrint('[CallProvider] Successfully connected to call session');
    _wsSub = _wsService.messages.listen(_handleWebSocketMessage);

    // Initialize Audio
    await _audioController.initAudio();
  }

  /// End the call (called by user or when remote call_ended received)
  void endCall() {
    debugPrint('[CallProvider] endCall called');
    _audioController.dispose();
    _status = CallStatus.ended;
    _participants = [];
    _activeSessionId = null;
    _wsSub?.cancel();
    _wsService.disconnect();
    _captionManager.clearBubbles();
    _transcriptionManager.clear();
    notifyListeners();
  }

  /// Handle remote call ended (e.g., other participant left)
  void _handleCallEnded(WSMessage message) {
    final reason = message.data?['reason'] as String? ?? 'unknown';
    debugPrint('[CallProvider] Call ended remotely: $reason');

    // Clean up the call
    endCall();

    // Notify listener (e.g., ActiveCallScreen) to navigate away
    onCallEnded?.call(reason);
  }

  // === Audio Controls ===

  void toggleMute() => _audioController.toggleMute();

  Future<void> toggleSpeaker() => _audioController.toggleSpeaker();

  // === WebSocket Message Handling ===

  void _handleWebSocketMessage(WSMessage message) {
    debugPrint('[CallProvider] WS message: ${message.type}');
    switch (message.type) {
      case WSMessageType.transcript:
        _handleTranscript(message);
        break;
      case WSMessageType.transcriptionUpdate:
        _handleTranscriptionUpdate(message);
        break;
      case WSMessageType.translation:
        _handleTranslation(message);
        break;
      case WSMessageType.participantJoined:
        _handleParticipantJoined(message);
        break;
      case WSMessageType.participantLeft:
        break;
      case WSMessageType.muteStatusChanged:
        break;
      case WSMessageType.callEnded:
        _handleCallEnded(message);
        break;
      case WSMessageType.error:
        debugPrint('[CallProvider] WebSocket error: ${message.data}');
        break;
      default:
        break;
    }
    notifyListeners();
  }

  /// Handle live transcript (original text as it's being spoken)
  void _handleTranscript(WSMessage message) {
    final text = message.data?['text'] as String? ?? '';
    final speakerId = message.data?['speaker_id'] as String?;

    debugPrint('[CallProvider] Transcript: "$text" from $speakerId');

    if (speakerId != null && text.isNotEmpty) {
      _liveTranscription = text;
      _setActiveSpeaker(speakerId);
      _captionManager.addCaptionBubble(speakerId, text);
    }
  }

  /// Handle translation message (includes both original and translated text)
  void _handleTranslation(WSMessage message) {
    final data = message.data;
    if (data == null) return;

    // --- Step 1: Parsing ---
    // API is now standardized: transcript, translation
    final originalText = data['transcript'] as String? ?? '';
    final translatedText = data['translation'] as String? ?? '';
    final speakerId = data['speaker_id'] as String? ?? '';
    final sourceLanguage = data['source_lang'] as String? ?? 'auto';
    final targetLanguage = data['target_lang'] as String? ?? 'auto';

    // --- Step 2: Filtering ---
    if (speakerId.isNotEmpty && speakerId == _currentUserId) {
      debugPrint(
          '[CallProvider] This is my own speech ($speakerId), skipping audio playback');
      // עדיין מוסיפים להיסטוריה אבל לא מנגנים
      if (translatedText.isNotEmpty && originalText.isNotEmpty) {
        _addTranslationToHistory(speakerId, originalText, translatedText,
            sourceLanguage, targetLanguage);
      }
      return;
    }

    // --- שלב 3: עדכון הממשק (UI Logic) ---
    // הוספה להיסטוריה כדי שהמשתמש יראה את הבועה הסופית
    if (translatedText.isNotEmpty && originalText.isNotEmpty) {
      _addTranslationToHistory(speakerId, originalText, translatedText,
          sourceLanguage, targetLanguage);

      // איפוס הטקסט החי כי קיבלנו תוצאה סופית
      _liveTranscription = null;
    }

    debugPrint(
        '[CallProvider] Translation processed: "$originalText" -> "$translatedText"');
  }

  /// Helper method to add translation to history
  void _addTranslationToHistory(
    String speakerId,
    String originalText,
    String translatedText,
    String sourceLanguage,
    String targetLanguage,
  ) {
    // Find participant name from speakerId
    final participant = _participants.firstWhere(
      (p) => p.userId == speakerId || p.id == speakerId,
      orElse: () => CallParticipant(
        id: speakerId,
        callId: '',
        userId: speakerId,
        targetLanguage: targetLanguage,
        speakingLanguage: sourceLanguage,
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        displayName: 'Unknown',
      ),
    );

    _transcriptionManager.addEntry(
      TranscriptionEntry(
        participantId: speakerId,
        participantName: participant.displayName,
        originalText: originalText,
        translatedText: translatedText,
        timestamp: DateTime.now(),
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      ),
    );
  }

  void _handleTranscriptionUpdate(WSMessage message) {
    // Server sends 'transcript' for the original text and optionally 'translation' for interim translation
    final transcript = message.data?['transcript'] as String?;
    final translation = message.data?['translation'] as String?;
    final speakerId = message.data?['speaker_id'] as String?;

    // Skip if this is my own speech
    if (speakerId != null && speakerId == _currentUserId) {
      return;
    }

    // Use translation if available (for real-time translated display), otherwise use transcript
    final displayText =
        translation?.isNotEmpty == true ? translation : transcript;

    if (displayText != null && displayText.isNotEmpty) {
      _liveTranscription = displayText;
      debugPrint('[CallProvider] Live transcription update: "$displayText"');
    }
  }

  void _setActiveSpeaker(String? participantId) {
    _activeSpeakerId = participantId;
    _participants = _participants
        .map((p) => p.copyWith(
            isSpeaking: p.id == participantId || p.userId == participantId))
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
