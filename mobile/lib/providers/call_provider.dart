/// Call Provider - Active call session state management.
///
/// Manages the complete lifecycle of an active call:
/// - WebSocket connection to call session
/// - Audio recording and playback via AudioController
/// - Real-time transcription and translation display
/// - Participant state tracking
/// - Interim captions (WhatsApp-style typing indicators)
///
/// This provider handles the call-specific WebSocket (separate from lobby).
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/websocket/websocket_service.dart';
import '../data/services/call_api_service.dart';
import '../models/call.dart';
import '../models/interim_caption.dart';
import '../models/participant.dart';
import '../models/transcription_entry.dart';
import 'audio_controller.dart';
import 'interim_caption_manager.dart';
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

  /// Client-side deduplication: Tracks recently processed translations
  /// to prevent duplicate display when both streaming and batch pipelines publish
  final Set<String> _recentTranslationKeys = {};

  // Services
  final WebSocketService _wsService;
  final CallApiService _apiService;
  StreamSubscription<WSMessage>? _wsSub;

  // Helpers (SRP: Each handles specific responsibility)
  // Issue B Fix: AudioController is now nullable, recreated fresh for each call
  AudioController? _audioController;
  late final TranscriptionManager _transcriptionManager;
  late final InterimCaptionManager _interimCaptionManager;

  CallProvider({
    required WebSocketService wsService,
    required CallApiService apiService,
  })  : _wsService = wsService,
        _apiService = apiService {
    // AudioController NOT created here - created fresh per call in _joinCallSession
    _transcriptionManager =
        TranscriptionManager(notifyListeners, () => _disposed);
    _interimCaptionManager = InterimCaptionManager(
      notifyListeners: notifyListeners,
      isDisposed: () => _disposed,
      getParticipantName: _getParticipantName,
      setActiveSpeaker: (id) => _setActiveSpeaker(id),
      onInterimTimeout: _handleInterimTimeout,
    );
  }

  /// Handle interim caption timeout - treat timed-out interim as final for self
  /// This is a fallback for languages like Hebrew where Google STT doesn't always send is_final
  void _handleInterimTimeout(InterimCaption caption, String? lastFinalizedText) {
    // Only add to history if this is our own caption
    if (caption.speakerId != _currentUserId) return;
    if (caption.text.isEmpty) return;

    // Compute the NEW text by removing the already-finalized prefix
    // This handles Hebrew STT which returns accumulated text (e.g., "hi whats up how are you")
    // instead of incremental text
    String newText = caption.text;
    
    if (lastFinalizedText != null && lastFinalizedText.isNotEmpty) {
      if (caption.text.startsWith(lastFinalizedText)) {
        // Remove the prefix that was already added to history
        newText = caption.text.substring(lastFinalizedText.length).trim();
        debugPrint('[CallProvider] ⏱️ Computed delta: "${caption.text}" - "$lastFinalizedText" = "$newText"');
      } else if (caption.text.contains(lastFinalizedText)) {
        // Last finalized is somewhere in the middle - extract everything after it
        final idx = caption.text.indexOf(lastFinalizedText);
        newText = caption.text.substring(idx + lastFinalizedText.length).trim();
        debugPrint('[CallProvider] ⏱️ Computed delta (middle): "$newText"');
      }
      // If neither contains the other, it's a completely new sentence - use full text
    }

    // Skip if nothing new to add
    if (newText.isEmpty) {
      debugPrint('[CallProvider] ⏱️ No new text to add (delta empty)');
      return;
    }

    debugPrint('[CallProvider] ⏱️ Interim timeout - adding NEW text to history: "$newText"');

    final participantName = _getParticipantName(caption.speakerId) ?? 'You';

    _transcriptionManager.addEntry(
      TranscriptionEntry(
        participantId: caption.speakerId,
        participantName: participantName,
        originalText: newText,
        translatedText: newText, // Same as original for self
        timestamp: DateTime.now(),
        sourceLanguage: caption.sourceLanguage,
        targetLanguage: caption.sourceLanguage, // Same language for self
      ),
    );

    // Notify listeners to update UI with the new history entry
    if (!_disposed) notifyListeners();

    debugPrint('[CallProvider] ✅ Added timed-out interim to history: "$newText"');
  }

  // === Getters ===

  CallStatus get status => _status;
  String? get activeSessionId => _activeSessionId;
  List<CallParticipant> get participants => List.unmodifiable(_participants);
  String get liveTranscription => _liveTranscription ?? '';
  List<TranscriptionEntry> get transcriptionHistory =>
      _transcriptionManager.entries;
  TranscriptionEntry? get latestTranscription =>
      _transcriptionManager.latestEntry;
  String? get activeSpeakerId => _activeSpeakerId;

  /// Current user ID for identifying self messages in chat view
  String? get currentUserId => _currentUserId;

  /// Alias for activeSpeakerId (for chat view compatibility)
  String? get liveSpeakerId => _activeSpeakerId;

  /// Get transcription history in chronological order (oldest first)
  /// Use this for chat-style display where newest messages are at the bottom
  List<TranscriptionEntry> get transcriptionHistoryChronological =>
      _transcriptionManager.chronologicalEntries;

  bool get isMuted => _audioController?.isMuted ?? false;
  bool get isSpeakerOn => _audioController?.isSpeakerOn ?? false;

  /// Get all active interim captions (for UI display)
  List<InterimCaption> get interimCaptions =>
      _interimCaptionManager.captions.values.toList();

  /// Whether interim captions are enabled
  bool get showInterimCaptions => _interimCaptionManager.showCaptions;

  /// Toggle interim captions visibility
  set showInterimCaptions(bool value) {
    _interimCaptionManager.showCaptions = value;
    notifyListeners();
  }

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

  /// Prepare the provider state for an incoming call acceptance.
  /// This should be called BEFORE the API accept call to prevent race conditions
  /// where the IncomingCallScreen pops due to null incomingCall but status not yet ongoing.
  void prepareForIncomingCall() {
    _status = CallStatus.ongoing;
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
    _activeSessionId = sessionId;

    debugPrint(
        '[CallProvider] Connecting to WebSocket: session=$sessionId, call=$callId');

    final success = await _joinCallSession(sessionId, callId: callId);

    // FIX: Only set ongoing if connection succeeded
    if (success) {
      _status = CallStatus.ongoing;
    } else {
      _status = CallStatus.ended;
      _activeSessionId = null;
      throw Exception('Failed to connect to call session');
    }
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
      {required String currentUserId,
      required String token,
      String? callId}) async {
    _activeSessionId = sessionId;
    _participants = participants;
    _status = CallStatus.initiating; // FIX: Use initiating until actually connected
    _currentUserId = currentUserId;
    _authToken = token;

    // Notify immediately to update UI state BEFORE async operations
    notifyListeners();

    final success = await _joinCallSession(sessionId, callId: callId);

    // FIX: Only set ongoing if connection succeeded
    if (success) {
      _status = CallStatus.ongoing;
    } else {
      _status = CallStatus.ended;
      _activeSessionId = null;
    }
    notifyListeners();
  }

  /// Returns true if connection was successful, false otherwise
  Future<bool> _joinCallSession(String sessionId, {String? callId}) async {
    debugPrint(
        '[CallProvider] Joining call session: $sessionId, call_id: $callId');
    await _wsSub?.cancel();
    if (_currentUserId == null || _authToken == null) {
      debugPrint('[CallProvider] Missing credentials for WebSocket connection');
      return false;
    }

    // Load interim caption preference from SharedPreferences
    await _loadInterimCaptionPreference();

    final connected = await _wsService.connect(
      sessionId,
      userId: _currentUserId!,
      token: _authToken!,
      callId: callId,
    );
    if (!connected) {
      debugPrint(
          '[CallProvider] FAILED to connect to call session: $sessionId');
      return false;
    }

    debugPrint('[CallProvider] Successfully connected to call session');
    _wsSub = _wsService.messages.listen(_handleWebSocketMessage);

    // Create FRESH AudioController for each call
    _audioController?.dispose(); // Clean up any previous instance
    _audioController = AudioController(_wsService, notifyListeners);
    try {
      await _audioController!.initAudio();
    } catch (e) {
      debugPrint('[CallProvider] Failed to initialize audio: $e');
      // Audio init failed but WebSocket connected - continue with call
      // User will see muted state
    }

    return true;
  }

  /// Load interim caption preference from SharedPreferences
  Future<void> _loadInterimCaptionPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _interimCaptionManager.showCaptions =
          prefs.getBool('show_interim_captions') ?? true;
      debugPrint(
          '[CallProvider] Interim captions enabled: ${_interimCaptionManager.showCaptions}');
    } catch (e) {
      debugPrint('[CallProvider] Failed to load interim caption pref: $e');
      _interimCaptionManager.showCaptions = true; // Default to enabled
    }
  }

  /// End the call (called by user or when remote call_ended received)
  void endCall() {
    debugPrint('[CallProvider] endCall called');
    _audioController?.dispose();
    _audioController = null; // Issue B: Release reference for GC
    _status = CallStatus.ended;
    _participants = [];
    _activeSessionId = null;
    _wsSub?.cancel();
    _wsService.disconnect();
    _transcriptionManager.clear();
    _interimCaptionManager.clearAll();
    _recentTranslationKeys.clear(); // Clear dedup set to prevent memory leaks
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

  Future<void> toggleMute() async => await _audioController?.toggleMute();

  Future<void> toggleSpeaker() async => await _audioController?.toggleSpeaker();

  // === WebSocket Message Handling ===

  void _handleWebSocketMessage(WSMessage message) {
    if (_disposed) return; // FIX: Don't process messages if disposed
    debugPrint('[CallProvider] WS message: ${message.type}');

    // ⭐ FIX: Each handler notifies only when it changes state
    // Removed blanket notifyListeners() to prevent:
    // 1. Double notifications for handlers that already notify
    // 2. Unnecessary rebuilds for no-op handlers
    switch (message.type) {
      case WSMessageType.transcript:
        _handleTranscript(message);
        break;
      case WSMessageType.transcriptionUpdate:
        _handleTranscriptionUpdate(message);
        break;
      case WSMessageType.interimTranscript:
        _handleInterimTranscript(message);
        break;
      case WSMessageType.interimClear:
        _handleInterimClear(message);
        break;
      case WSMessageType.translation:
        _handleTranslation(message);
        break;
      case WSMessageType.participantJoined:
        _handleParticipantJoined(message); // Already calls notifyListeners
        break;
      case WSMessageType.participantLeft:
        // No-op: participant list updated via _handleParticipantJoined
        break;
      case WSMessageType.muteStatusChanged:
        // No-op: mute state managed locally
        break;
      case WSMessageType.callEnded:
        _handleCallEnded(message); // Already calls notifyListeners via endCall()
        break;
      case WSMessageType.error:
        debugPrint('[CallProvider] WebSocket error: ${message.data}');
        // No state change, no notification needed
        break;
      default:
        break;
    }
  }

  /// Handle live transcript (original text as it's being spoken)
  void _handleTranscript(WSMessage message) {
    final text = message.data?['text'] as String? ?? '';
    final speakerId = message.data?['speaker_id'] as String?;

    debugPrint('[CallProvider] Transcript: "$text" from $speakerId');

    if (speakerId != null && text.isNotEmpty) {
      _liveTranscription = text;
      _setActiveSpeaker(speakerId);
    }
  }

  /// Handle translation message (includes both original and translated text)
  void _handleTranslation(WSMessage message) {
    final data = message.data;
    if (data == null) {
      debugPrint('[CallProvider] ⚠️ Translation message has NULL data!');
      return;
    }

    // --- Step 1: Parsing ---
    // API is now standardized: transcript, translation
    final originalText = data['transcript'] as String? ?? '';
    final translatedText = data['translation'] as String? ?? '';
    final speakerId = data['speaker_id'] as String? ?? '';
    final sourceLanguage = data['source_lang'] as String? ?? 'auto';
    final targetLanguage = data['target_lang'] as String? ?? 'auto';

    // Comprehensive debug logging for ALL translation messages
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[CallProvider] 📨 TRANSLATION MESSAGE RECEIVED');
    debugPrint('[CallProvider] speaker_id: "$speakerId"');
    debugPrint('[CallProvider] _currentUserId: "$_currentUserId"');
    debugPrint('[CallProvider] IDs match: ${speakerId == _currentUserId}');
    debugPrint('[CallProvider] originalText: "$originalText"');
    debugPrint('[CallProvider] translatedText: "$translatedText"');
    debugPrint('[CallProvider] originalText.isNotEmpty: ${originalText.isNotEmpty}');
    debugPrint('[CallProvider] translatedText.isNotEmpty: ${translatedText.isNotEmpty}');
    debugPrint('[CallProvider] sourceLanguage: $sourceLanguage');
    debugPrint('[CallProvider] targetLanguage: $targetLanguage');
    debugPrint('═══════════════════════════════════════════════════════════');

    // --- Step 1.5: Client-side deduplication ---
    // Prevents duplicate translations when both streaming and batch pipelines publish
    final dedupKey = '$speakerId:${originalText.toLowerCase().trim()}';
    if (_recentTranslationKeys.contains(dedupKey)) {
      debugPrint('[CallProvider] ⏭️ Skipping duplicate translation: "$dedupKey"');
      return;
    }
    _recentTranslationKeys.add(dedupKey);

    // Auto-remove from dedup set after 5 seconds (TTL-based cleanup)
    Future.delayed(const Duration(seconds: 5), () {
      _recentTranslationKeys.remove(dedupKey);
    });

    // --- Step 2: Handling self vs others ---
    final isSelf = speakerId.isNotEmpty && speakerId == _currentUserId;

    if (isSelf) {
      debugPrint('[CallProvider] 🙋 This is MY OWN translation - adding to history without audio');

      // Add to history (use originalText if translatedText is empty for same-language)
      final textToShow = translatedText.isNotEmpty ? translatedText : originalText;
      if (originalText.isNotEmpty && textToShow.isNotEmpty) {
        _addTranslationToHistory(speakerId, originalText, textToShow,
            sourceLanguage, targetLanguage);
        debugPrint('[CallProvider] ✅ Self-translation added to history');
      } else {
        debugPrint('[CallProvider] ❌ Self-translation NOT added - empty text');
      }
      return;
    }

    // --- Step 3: Handle messages from others ---
    debugPrint('[CallProvider] 👤 This is from ANOTHER participant');

    if (translatedText.isNotEmpty && originalText.isNotEmpty) {
      _addTranslationToHistory(speakerId, originalText, translatedText,
          sourceLanguage, targetLanguage);

      // Clear live text since we got final result
      _liveTranscription = null;

      // Clear interim caption for this speaker (final translation supersedes interim)
      _interimCaptionManager.clearCaption(speakerId);

      debugPrint('[CallProvider] ✅ Translation added to history');
    } else {
      debugPrint('[CallProvider] ❌ Translation NOT added - empty text');
    }
  }

  /// Helper method to add translation to history
  void _addTranslationToHistory(
    String speakerId,
    String originalText,
    String translatedText,
    String sourceLanguage,
    String targetLanguage,
  ) {
    debugPrint('[CallProvider] _addTranslationToHistory called');
    debugPrint('[CallProvider]   speakerId: $speakerId');
    debugPrint('[CallProvider]   participants count: ${_participants.length}');

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

    debugPrint('[CallProvider]   participantName: ${participant.displayName}');
    debugPrint('[CallProvider]   Creating TranscriptionEntry...');

    final entry = TranscriptionEntry(
      participantId: speakerId,
      participantName: participant.displayName,
      originalText: originalText,
      translatedText: translatedText,
      timestamp: DateTime.now(),
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );

    final beforeCount = _transcriptionManager.chronologicalEntries.length;
    _transcriptionManager.addEntry(entry);
    final afterCount = _transcriptionManager.chronologicalEntries.length;

    debugPrint('[CallProvider]   Entries before: $beforeCount, after: $afterCount');
    if (afterCount > beforeCount) {
      debugPrint('[CallProvider]   ✅ Entry successfully added to history');
    } else {
      debugPrint('[CallProvider]   ⚠️ Entry NOT added (likely duplicate)');
    }
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
      if (!_disposed) notifyListeners(); // ⭐ FIX: Notify UI of transcription update
    }
  }

  /// Handle real-time interim transcripts (WhatsApp-style typing indicator)
  void _handleInterimTranscript(WSMessage message) {
    _interimCaptionManager.handleInterimTranscript(message.data);

    // Option B Fix: Speaker doesn't receive their own translation from backend,
    // so when we get our own final interim transcript, add it to history directly.
    // This ensures the speaker sees their own messages in the chat view.
    final data = message.data;
    if (data == null) return;

    final speakerId = data['speaker_id'] as String? ?? '';
    final isSelf = speakerId.isNotEmpty && speakerId == _currentUserId;
    final isFinal = data['is_final'] as bool? ?? false;
    final text = data['text'] as String? ?? '';

    // DEBUG: Log all interim transcripts to diagnose the issue
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('[CallProvider] 📝 INTERIM TRANSCRIPT RECEIVED');
    debugPrint('[CallProvider] speaker_id: $speakerId');
    debugPrint('[CallProvider] currentUserId: $_currentUserId');
    debugPrint('[CallProvider] isSelf: $isSelf');
    debugPrint('[CallProvider] is_final: $isFinal');
    debugPrint('[CallProvider] text: "${text.length > 50 ? '${text.substring(0, 50)}...' : text}"');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (isSelf && isFinal && text.isNotEmpty) {
      final sourceLanguage = data['source_lang'] as String? ?? 'auto';
      final participantName = _getParticipantName(speakerId) ?? 'You';

      // Add speaker's own message to history (original text, no translation needed for self)
      _transcriptionManager.addEntry(
        TranscriptionEntry(
          participantId: speakerId,
          participantName: participantName,
          originalText: text,
          translatedText: text, // Same as original for self
          timestamp: DateTime.now(),
          sourceLanguage: sourceLanguage,
          targetLanguage: sourceLanguage, // Same language for self
        ),
      );

      // Clear interim caption now that we have final result
      _interimCaptionManager.clearCaption(speakerId);

      // Notify listeners to update UI with the new history entry
      if (!_disposed) notifyListeners();

      debugPrint('[CallProvider] Added self-transcription to history: "$text"');
    }
  }

  /// Handle interim clear signal from backend
  /// This is sent when streaming STT produces a final result, before translation
  void _handleInterimClear(WSMessage message) {
    final speakerId = message.data?['speaker_id'] as String?;

    if (speakerId == null) {
      debugPrint('[CallProvider] ⚠️ interim_clear missing speaker_id');
      return;
    }

    // Skip clearing our own interim (we don't display our own interim anyway)
    if (speakerId == _currentUserId) {
      return;
    }

    debugPrint('[CallProvider] 🧹 Clearing interim caption for speaker: $speakerId');
    _interimCaptionManager.clearCaption(speakerId);
  }

  /// Get participant display name from user ID
  String? _getParticipantName(String speakerId) {
    try {
      final participant = _participants.firstWhere(
        (p) => p.userId == speakerId || p.id == speakerId,
      );
      return participant.displayName;
    } catch (_) {
      return null;
    }
  }

  void _setActiveSpeaker(String? participantId) {
    if (_disposed) return; // FIX: Don't modify state if disposed
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
    _audioController?.dispose(); // FIX: Dispose audio controller to prevent memory leak
    _audioController = null;
    _interimCaptionManager.dispose();
    super.dispose();
  }
}
