import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';

import '../data/websocket/websocket_service.dart';

/// Handles audio initialization, recording, and playback for calls.
///
/// Manages:
/// - Audio session configuration
/// - Microphone recording and streaming
/// - Audio playback from WebSocket
class AudioController {
  final WebSocketService _wsService;
  final VoidCallback _notifyListeners;

  // Audio components
  AudioRecorder? _audioRecorder;
  FlutterSoundPlayer? _audioPlayer;
  AudioSession? _audioSession;
  StreamSubscription<Uint8List>? _micStreamSub;
  StreamSubscription<Uint8List>? _incomingAudioSub;

  // State
  bool _isPlayerInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _audioInitializing = false;

  AudioController(this._wsService, this._notifyListeners);

  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  /// Initialize audio for a call session
  Future<void> initAudio() async {
    if (_audioInitializing) {
      debugPrint('[AudioController] Audio initialization already in progress');
      return;
    }
    _audioInitializing = true;

    try {
      debugPrint('[AudioController] Initializing audio...');

      // 1. Configure Audio Session
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
      ));

      _isSpeakerOn = true;

      // 2. Cleanup previous player
      await _cleanupAudioPlayer();

      // 3. Create and initialize flutter_sound player
      _audioPlayer = FlutterSoundPlayer();
      await _audioPlayer!.openPlayer();
      _isPlayerInitialized = true;

      // 4. Start player in stream mode
      await _audioPlayer!.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
        bufferSize: 8192,
        interleaved: true,
      );
      debugPrint('[AudioController] Player started in stream mode');

      // 5. Listen to incoming audio
      await _setupIncomingAudioListener();

      // 6. Initialize Microphone
      await _setupMicrophone();

      debugPrint('[AudioController] Audio initialized successfully');
    } catch (e) {
      debugPrint('[AudioController] Error initializing audio: $e');
    } finally {
      _audioInitializing = false;
    }
  }

  Future<void> _setupIncomingAudioListener() async {
    _incomingAudioSub?.cancel();
    int chunksReceived = 0;
    _incomingAudioSub = _wsService.audioStream.listen(
      (data) {
        if (_audioPlayer != null && _isPlayerInitialized && data.isNotEmpty) {
          _audioPlayer!.uint8ListSink!.add(data);
          chunksReceived++;
          if (chunksReceived % 50 == 0) {
            debugPrint(
                '[AudioController] Playing chunk #$chunksReceived (${data.length} bytes)');
          }
        }
      },
      onError: (e) => debugPrint('[AudioController] Incoming audio error: $e'),
      cancelOnError: false,
    );
  }

  Future<void> _setupMicrophone() async {
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
                    '[AudioController] Sent 50 chunks (${data.length} bytes each)');
              }
            }
          },
          onError: (e) => debugPrint('[AudioController] Mic stream error: $e'),
          cancelOnError: false,
        );

        debugPrint('[AudioController] Microphone started');
      }
    } else {
      debugPrint('[AudioController] No microphone permission');
    }
  }

  Future<void> _cleanupAudioPlayer() async {
    await _incomingAudioSub?.cancel();
    _incomingAudioSub = null;

    if (_audioPlayer != null && _isPlayerInitialized) {
      try {
        if (_audioPlayer!.isPlaying) {
          await _audioPlayer!.stopPlayer();
        }
        await _audioPlayer!.closePlayer();
      } catch (e) {
        debugPrint('[AudioController] Error disposing player: $e');
      }
      _audioPlayer = null;
      _isPlayerInitialized = false;
    }
  }

  /// Toggle mute state
  void toggleMute() {
    _isMuted = !_isMuted;
    _wsService.setMuted(_isMuted);
    _notifyListeners();
  }

  /// Toggle speaker/earpiece
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    if (_audioSession != null) {
      await _audioSession!.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: _isSpeakerOn
            ? AVAudioSessionCategoryOptions.defaultToSpeaker
            : AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
      ));
    }
    _notifyListeners();
  }

  /// Dispose all audio resources
  Future<void> dispose() async {
    debugPrint('[AudioController] Disposing...');

    await _micStreamSub?.cancel();
    _micStreamSub = null;

    await _cleanupAudioPlayer();

    try {
      if (_audioRecorder != null) {
        await _audioRecorder!.stop();
        _audioRecorder!.dispose();
      }
    } catch (e) {
      debugPrint('[AudioController] Error stopping recorder: $e');
    }
    _audioRecorder = null;
    _audioSession = null;

    debugPrint('[AudioController] Disposed');
  }
}
