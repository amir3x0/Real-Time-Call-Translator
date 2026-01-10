import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';

import '../data/websocket/websocket_service.dart';
import '../config/constants.dart';

/// Handles audio initialization, recording, and playback for calls.
///
/// Manages:
/// - Audio session configuration
/// - Microphone recording and streaming
/// - Audio playback from WebSocket with jitter buffering
class AudioController {
  final WebSocketService _wsService;
  final VoidCallback _notifyListeners;

  // Audio components
  AudioRecorder? _audioRecorder;
  FlutterSoundPlayer? _audioPlayer;
  AudioSession? _audioSession;
  StreamSubscription<Uint8List>? _micStreamSub;
  StreamSubscription<Uint8List>? _incomingAudioSub;

  // Audio buffering for smooth playback
  final Queue<Uint8List> _audioBuffer = Queue<Uint8List>();
  Timer? _playbackTimer;
  static const int _minBufferSize = AppConstants.audioMinBufferSize;
  static const int _maxBufferSize = AppConstants.audioMaxBufferSize;
  bool _isBuffering = true;

  // State
  bool _isPlayerInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _audioInitializing = false;

  // Audio chunk accumulation for better STT results
  final List<int> _accumulatedChunks = [];
  Timer? _sendTimer;
  static const int _sendIntervalMs = AppConstants.audioSendIntervalMs;
  static const int _minChunkSize = AppConstants.audioMinChunkSize;

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
        sampleRate: AppConstants.audioSampleRate,
        bufferSize: AppConstants.audioBufferSize,
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

    // Debug: Check if audioStream is real or empty
    debugPrint('[AudioController] Setting up audio listener...');
    debugPrint(
        '[AudioController] WebSocket connected: ${_wsService.isConnected}');

    _incomingAudioSub = _wsService.audioStream.listen(
      (data) {
        if (data.isEmpty) return;

        chunksReceived++;

        // Debug logging for audio chunks
        debugPrint(
            '[AudioController] 🔊 Chunk #$chunksReceived: ${data.length} bytes');

        // Log EVERY chunk for debugging TTS audio
        final isWavHeader = data.length > 4 &&
            data[0] == 0x52 &&
            data[1] == 0x49 &&
            data[2] == 0x46 &&
            data[3] == 0x46; // "RIFF"
        if (isWavHeader) {
          debugPrint('[AudioController] ⚠️ WAV header detected in chunk!');
        }

        // Add to buffer
        _audioBuffer.add(data);

        // Drop old chunks if buffer is too large (catch up with real-time)
        while (_audioBuffer.length > _maxBufferSize) {
          _audioBuffer.removeFirst();
          debugPrint('[AudioController] Buffer overflow, dropping old chunk');
        }

        // Start playback once we have enough buffered
        if (_isBuffering && _audioBuffer.length >= _minBufferSize) {
          _isBuffering = false;
          _startBufferedPlayback();
          debugPrint('[AudioController] Starting buffered playback');
        }
      },
      onError: (e) => debugPrint('[AudioController] Incoming audio error: $e'),
      cancelOnError: false,
    );
  }

  void _startBufferedPlayback() {
    _playbackTimer?.cancel();

    // Play chunks at regular intervals to smooth out jitter
    int playedChunks = 0;
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_audioBuffer.isNotEmpty &&
          _audioPlayer != null &&
          _isPlayerInitialized) {
        final chunk = _audioBuffer.removeFirst();
        playedChunks++;
        debugPrint(
            '[AudioController] 🔈 Playing chunk #$playedChunks: ${chunk.length} bytes');
        _audioPlayer!.uint8ListSink?.add(chunk);
      } else if (_audioBuffer.isEmpty && !_isBuffering) {
        // Buffer underrun - stop playing and wait for buffer to refill
        _isBuffering = true;
        debugPrint(
            '[AudioController] Buffer underrun, entering buffering mode');
        // Stop the timer until we have enough buffered data again
        _playbackTimer?.cancel();
        _playbackTimer = null;
      }
    });
  }

  Future<void> _setupMicrophone() async {
    _audioRecorder ??= AudioRecorder();
    if (await _audioRecorder!.hasPermission()) {
      final isRecording = await _audioRecorder!.isRecording();
      if (!isRecording) {
        final stream = await _audioRecorder!.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: AppConstants.audioSampleRate,
            numChannels: 1,
          ),
        );

        _micStreamSub?.cancel();

        // Start periodic sender for accumulated audio
        _sendTimer?.cancel();
        _sendTimer = Timer.periodic(
          const Duration(milliseconds: _sendIntervalMs),
          (_) => _sendAccumulatedAudio(),
        );

        _micStreamSub = stream.listen(
          (data) {
            if (!_isMuted) {
              // Accumulate chunks instead of sending immediately
              _accumulatedChunks.addAll(data);

              // If we have enough data, send immediately
              if (_accumulatedChunks.length >= _minChunkSize * 2) {
                _sendAccumulatedAudio();
              }
            }
          },
          onError: (e) => debugPrint('[AudioController] Mic stream error: $e'),
          cancelOnError: false,
        );

        debugPrint(
            '[AudioController] Microphone started with chunk accumulation');
      }
    } else {
      debugPrint('[AudioController] No microphone permission');
    }
  }

  void _sendAccumulatedAudio() {
    if (_accumulatedChunks.isEmpty || _isMuted) return;

    // Only send if we have minimum chunk size
    if (_accumulatedChunks.length >= _minChunkSize) {
      final audioData = Uint8List.fromList(_accumulatedChunks);
      _wsService.sendAudio(audioData);
      debugPrint(
          '[AudioController] Sent accumulated audio: ${audioData.length} bytes');
      _accumulatedChunks.clear();
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

    _sendTimer?.cancel();
    _sendTimer = null;
    _playbackTimer?.cancel();
    _playbackTimer = null;

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
    _audioBuffer.clear();
    _accumulatedChunks.clear();

    debugPrint('[AudioController] Disposed');
  }
}
