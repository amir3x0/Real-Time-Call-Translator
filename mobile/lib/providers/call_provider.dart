import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';

import '../data/websocket/websocket_service.dart';
import '../data/api/api_service.dart';
import '../models/call.dart';
import '../models/live_caption.dart';
import '../models/participant.dart';

class CallProvider with ChangeNotifier {
  CallStatus _status = CallStatus.pending;
  List<CallParticipant> _participants = [];
  String? _activeSessionId;
  String _liveTranscription = "";
  final WebSocketService _wsService = WebSocketService();
  final ApiService _apiService = ApiService();
  StreamSubscription<WSMessage>? _wsSub;
  final List<LiveCaptionData> _captionBubbles = [];
  final Map<String, Timer> _bubbleTimers = {};
  String? _activeSpeakerId;

  bool _disposed = false;

  // Audio - using flutter_sound for direct PCM playback
  AudioRecorder? _audioRecorder;
  FlutterSoundPlayer? _audioPlayer;
  AudioSession? _audioSession;
  StreamSubscription<Uint8List>? _micStreamSub;
  StreamSubscription<Uint8List>? _incomingAudioSub;
  bool _isPlayerInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _audioInitializing = false; // Prevent concurrent initialization

  // Incoming call state
  Call? _incomingCall;
  CallStatus? _incomingCallStatus;
  Timer? _callTimeoutTimer;
  String? _incomingCallerName;

  CallStatus get status => _status;
  List<CallParticipant> get participants => List.unmodifiable(_participants);
  String get liveTranscription => _liveTranscription;
  List<LiveCaptionData> get captionBubbles =>
      List.unmodifiable(_captionBubbles);
  String? get activeSpeakerId => _activeSpeakerId;
  Call? get incomingCall => _incomingCall;
  CallStatus? get incomingCallStatus => _incomingCallStatus;
  String? get incomingCallerName => _incomingCallerName;

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

  /// Starts a real call by calling backend API and connecting to the websocket
  Future<void> startCall(List<String> participantUserIds) async {
    // Call API to start call
    final resp = await _apiService.startCall(participantUserIds);
    final sessionId = resp['session_id'] as String;
    // final wsUrl = resp['websocket_url'] as String; // Ignored for now
    final parts = resp['participants'] as List<dynamic>;

    // Map participants
    _participants = parts
        .map((p) => CallParticipant.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    _status = CallStatus.active;
    _activeSessionId = sessionId;

    // Connect to WS and listen
    await _wsSub?.cancel(); // Cancel lobby subscription first
    await _wsService.connect(sessionId);
    _wsSub = _wsService.messages.listen(_handleWebSocketMessage);

    // Initialize Audio
    await _initAudio();

    notifyListeners();
  }

  Future<void> _initAudio() async {
    // Prevent concurrent initialization
    if (_audioInitializing) {
      debugPrint(
          '[CallProvider] Audio initialization already in progress, skipping');
      return;
    }
    _audioInitializing = true;

    try {
      debugPrint('[CallProvider] Initializing audio...');

      // 1. Configure Audio Session (Required for Speaker/Mic)
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
      ));

      _isSpeakerOn = true;

      // 2. Dispose previous player cleanly before creating new ones
      await _cleanupAudioPlayer();

      // 3. Create and initialize flutter_sound player
      _audioPlayer = FlutterSoundPlayer();
      await _audioPlayer!.openPlayer();
      _isPlayerInitialized = true;

      // 4. Start player in stream mode (direct PCM playback)
      await _audioPlayer!.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
        bufferSize: 8192,
        interleaved: true,
      );
      debugPrint('[CallProvider] Player started in stream mode');

      // 5. Listen to incoming audio from WebSocket and write directly to player
      _incomingAudioSub?.cancel();
      int chunksReceived = 0;
      _incomingAudioSub = _wsService.audioStream.listen(
        (data) {
          // Feed audio data directly to the player
          if (_audioPlayer != null && _isPlayerInitialized && data.isNotEmpty) {
            _audioPlayer!.uint8ListSink!.add(data);
            chunksReceived++;
            if (chunksReceived % 50 == 0) {
              debugPrint(
                  '[CallProvider] Playing chunk #$chunksReceived (${data.length} bytes)');
            }
          }
        },
        onError: (e) {
          debugPrint('[CallProvider] Incoming audio stream error: $e');
        },
        cancelOnError: false, // Keep listening even after errors
      );

      // 6. Initialize Microphone
      _audioRecorder ??= AudioRecorder();
      if (await _audioRecorder!.hasPermission()) {
        final isRecording = await _audioRecorder!.isRecording();
        if (!isRecording) {
          final stream = await _audioRecorder!.startStream(
            const RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 16000,
              numChannels: 1,
            ),
          );

          int chunksSent = 0;
          _micStreamSub?.cancel();
          _micStreamSub = stream.listen(
            (data) {
              if (!_isMuted) {
                _wsService.sendAudio(data);
                chunksSent++;
                if (chunksSent % 50 == 0) {
                  debugPrint(
                      '[CallProvider] Sent 50 chunks of audio (${data.length} bytes each)');
                }
              }
            },
            onError: (e) => debugPrint("Mic stream error: $e"),
            cancelOnError: false,
          );

          debugPrint("[CallProvider] Microphone started");
        } else {
          debugPrint("[CallProvider] Microphone already recording");
        }
      } else {
        debugPrint("❌ No microphone permission");
      }

      debugPrint('[CallProvider] Audio initialized successfully');
    } catch (e) {
      debugPrint("❌ Error initializing audio: $e");
      // Do not rethrow to avoid crashing the app flow
    } finally {
      _audioInitializing = false;
    }
  }

  /// Clean up audio player resources
  Future<void> _cleanupAudioPlayer() async {
    // Cancel incoming audio subscription
    await _incomingAudioSub?.cancel();
    _incomingAudioSub = null;

    // Stop and close player
    if (_audioPlayer != null && _isPlayerInitialized) {
      try {
        if (_audioPlayer!.isPlaying) {
          await _audioPlayer!.stopPlayer();
        }
        await _audioPlayer!.closePlayer();
      } catch (e) {
        debugPrint('[CallProvider] Error disposing player: $e');
      }
      _audioPlayer = null;
      _isPlayerInitialized = false;
    }
  }

  Future<void> _disposeAudio() async {
    debugPrint('[CallProvider] Disposing audio...');

    // Cancel microphone subscription first
    await _micStreamSub?.cancel();
    _micStreamSub = null;

    // Use the shared cleanup function for player-related resources
    await _cleanupAudioPlayer();

    // Stop and dispose recorder
    try {
      if (_audioRecorder != null) {
        await _audioRecorder!.stop();
        _audioRecorder!.dispose();
      }
    } catch (e) {
      debugPrint('[CallProvider] Error stopping recorder: $e');
    }
    _audioRecorder = null;
    _audioSession = null;

    debugPrint('[CallProvider] Audio disposed');
  }

  void endCall() {
    debugPrint('[CallProvider] endCall called from:\n${StackTrace.current}');
    _disposeAudio();
    _status = CallStatus.ended;
    // Ensure we assign a new growable empty list instead of trying to clear
    // a fixed-length list (which may have been set by .toList(growable:false)).
    _participants = [];
    _activeSessionId = null;
    _wsSub?.cancel();
    _wsService.disconnect();
    _clearBubbles();
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _wsService.setMuted(_isMuted);

    // Update self in participants list for UI
    if (_participants.isNotEmpty && _activeSessionId != null) {
      // Just notify
    }

    // Actually we don't have our own ID easily accessible unless we store it or find it.
    // But sending WS message will eventually bounce back a "muteStatusChanged" if backend handles it.
    // For local UI responsiveness:
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    if (_audioSession != null) {
      await _audioSession!.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: _isSpeakerOn
            ? AVAudioSessionCategoryOptions.defaultToSpeaker
            : AVAudioSessionCategoryOptions.none, // Earpiece
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
      ));
    }
    notifyListeners();
  }

  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  /// Connects to the Lobby websocket to receive real-time updates and incoming calls
  Future<void> connectToLobby({String? token}) async {
    debugPrint('[CallProvider] Connecting to Lobby...');
    _status = CallStatus.idle;
    _activeSessionId = 'lobby';

    // Connect to lobby session
    final success = await _wsService.connect('lobby', token: token);

    if (success) {
      _wsSub?.cancel();
      _wsSub = _wsService.messages.listen(_handleWebSocketMessage);
      debugPrint('[CallProvider] Connected to Lobby successfully');
    } else {
      debugPrint('[CallProvider] Failed to connect to Lobby');
    }
    notifyListeners();
  }

  /// Disconnects from Lobby WebSocket (called on logout)
  void disconnectFromLobby() {
    if (_activeSessionId == 'lobby') {
      debugPrint('[CallProvider] Disconnecting from Lobby...');
      _wsSub?.cancel();
      _wsService.disconnect();
      _activeSessionId = null;
      _status = CallStatus.idle;
      notifyListeners();
      debugPrint('[CallProvider] Disconnected from Lobby');
    }
  }

  // Broadcast stream for other providers
  final _eventController = StreamController<WSMessage>.broadcast();
  Stream<WSMessage> get events => _eventController.stream;

  void _handleWebSocketMessage(WSMessage message) {
    // Re-broadcast to external listeners
    if (!_eventController.isClosed) {
      _eventController.add(message);
    }

    // Handle different message types
    switch (message.type) {
      case WSMessageType.transcript:
        if (_participants.isNotEmpty) {
          final text = message.data?['text'] as String? ?? '';
          final speakerId = message.data?['speaker_id'] as String?;
          if (speakerId != null) {
            _liveTranscription = text;
            _setActiveSpeaker(speakerId);
            _addCaptionBubble(speakerId, text);
          }
        }
        break;
      case WSMessageType.participantJoined:
        _handleParticipantJoined(message);
        break;
      case WSMessageType.participantLeft:
        // Handle participant left
        break;
      case WSMessageType.muteStatusChanged:
        // Handle mute status change
        break;
      case WSMessageType.callEnded:
        endCall();
        break;
      case WSMessageType.incomingCall:
        handleIncomingCall(message);
        break;
      case WSMessageType.userStatusChanged:
        _handleUserStatusChanged(message);
        break;
      case WSMessageType.contactRequest:
        _handleContactRequest(message);
        break;
      case WSMessageType.error:
        debugPrint('[CallProvider] WebSocket error: ${message.data}');
        break;
      default:
        // Handle other message types as needed
        break;
    }
    notifyListeners();
  }

  void _setActiveSpeaker(String? participantId) {
    _activeSpeakerId = participantId;
    _participants = _participants
        .map((participant) => participant.copyWith(
              isSpeaking: participant.id == participantId,
            ))
        .toList(growable: false);
  }

  void _addCaptionBubble(String participantId, String text) {
    final bubble = LiveCaptionData(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      participantId: participantId,
      text: text,
    );
    _captionBubbles.add(bubble);
    _bubbleTimers[bubble.id]?.cancel();
    _bubbleTimers[bubble.id] = Timer(const Duration(seconds: 4), () {
      _captionBubbles.removeWhere((item) => item.id == bubble.id);
      _bubbleTimers.remove(bubble.id);
      if (!_disposed) notifyListeners();
    });
  }

  void _clearBubbles() {
    for (final timer in _bubbleTimers.values) {
      timer.cancel();
    }
    _bubbleTimers.clear();
    _captionBubbles.clear();
  }

  void handleIncomingCall(WSMessage message) {
    final callData = message.data;
    if (callData == null) return;

    try {
      _incomingCall = Call(
        id: callData['call_id'] as String? ?? '',
        sessionId: '', // Will be set when accepted
        status: CallStatus.ringing,
        callLanguage: callData['call_language'] as String? ?? 'he',
        callerUserId: callData['caller_id'] as String?,
        createdBy: callData['caller_id'] as String? ?? '',
        createdAt: DateTime.now(),
      );
      _incomingCallerName = callData['caller_name'] as String?;
      _incomingCallStatus = CallStatus.ringing;
      _startCallTimeout();
      notifyListeners();
    } catch (e) {
      debugPrint('[CallProvider] Error parsing incoming call: $e');
    }
  }

  void _startCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_incomingCall != null) {
        // Auto-reject after timeout
        rejectIncomingCall();
      }
    });
  }

  Future<void> acceptIncomingCall() async {
    if (_incomingCall == null) return;

    try {
      // Call API to accept - returns CallDetailResponse with session_id
      final callData = await _apiService.acceptCall(_incomingCall!.id);

      final sessionId = callData['session_id'] as String?;
      if (sessionId != null) {
        // Start call normally
        _status = CallStatus.active;
        _activeSessionId = sessionId;

        // Get participants from response
        final parts = callData['participants'] as List<dynamic>?;
        if (parts != null) {
          _participants = parts
              .map(
                  (p) => CallParticipant.fromJson(Map<String, dynamic>.from(p)))
              .toList();
        }

        // Connect to WS and listen
        await _wsSub?.cancel(); // Cancel lobby subscription first
        await _wsService.connect(sessionId);
        _wsSub = _wsService.messages.listen(_handleWebSocketMessage);

        // Initialize Audio (recorder + player) - same as startCall()
        await _initAudio();
      } else {
        throw Exception('No session_id in accept call response');
      }

      _incomingCall = null;
      _incomingCallStatus = null;
      _incomingCallerName = null;
      _callTimeoutTimer?.cancel();
      notifyListeners();
    } catch (e) {
      debugPrint('[CallProvider] Error accepting call: $e');
      // Clear incoming call state on error
      _incomingCall = null;
      _incomingCallStatus = null;
      _incomingCallerName = null;
      _callTimeoutTimer?.cancel();
      notifyListeners();
    }
  }

  Future<void> rejectIncomingCall() async {
    if (_incomingCall == null) return;

    try {
      await _apiService.rejectCall(_incomingCall!.id);
    } catch (e) {
      debugPrint('[CallProvider] Error rejecting call: $e');
    }

    _incomingCall = null;
    _incomingCallStatus = null;
    _incomingCallerName = null;
    _callTimeoutTimer?.cancel();
    notifyListeners();
  }

  /// Get last user status change from WebSocket (cleared after read)
  Map<String, dynamic>? get lastStatusChange {
    final change = _lastStatusChange;
    _lastStatusChange = null; // Clear after read
    return change;
  }

  Map<String, dynamic>? _lastStatusChange;

  void _handleUserStatusChanged(WSMessage message) {
    final data = message.data;
    if (data == null) return;

    final userId = data['user_id'] as String?;
    final isOnline = data['is_online'] as bool?;

    if (userId != null && isOnline != null) {
      _lastStatusChange = {'user_id': userId, 'is_online': isOnline};
      notifyListeners();
    }
  }

  /// Get last contact request (cleared after read)
  Map<String, dynamic>? get lastContactRequest {
    final req = _lastContactRequest;
    _lastContactRequest = null;
    return req;
  }

  Map<String, dynamic>? _lastContactRequest;

  void _handleContactRequest(WSMessage message) {
    if (message.data != null) {
      _lastContactRequest = message.data;
      notifyListeners();
    }
  }

  void _handleParticipantJoined(WSMessage message) {
    if (message.data == null) return;

    final userId = message.data!['user_id'] as String?;
    if (userId == null) return;

    // Find participant and mark as connected
    try {
      final index = _participants.indexWhere((p) => p.userId == userId);
      if (index != -1) {
        var p = _participants[index];
        // p = p.copyWith(isConnected: true, joinedAt: DateTime.now()); // Need to ensure copyWith exists or create new
        // Since CallParticipant is likely immutable, we create a new list
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
            displayName: p.displayName);

        // Create new list to trigger change
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

  @override
  @override
  void dispose() {
    _disposed = true;
    _eventController.close();
    _wsSub?.cancel();
    _wsService.disconnect();
    _clearBubbles();
    _callTimeoutTimer?.cancel();
    super.dispose();
  }
}
