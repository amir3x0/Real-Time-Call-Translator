import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/services/voice_service.dart';
import '../config/app_config.dart';

/// Service for recording and managing voice samples
class VoiceRecordingService {
  static final VoiceRecordingService _instance =
      VoiceRecordingService._internal();
  factory VoiceRecordingService() => _instance;
  VoiceRecordingService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final VoiceService _voiceService = VoiceService();

  String? _currentRecordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  /// Start recording audio
  Future<bool> startRecording() async {
    try {
      // Check permission
      if (!await _recorder.hasPermission()) {
        debugPrint('[VoiceRecording] No permission to record');
        return false;
      }

      // Get temp directory for recording
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${dir.path}/voice_sample_$timestamp.wav';

      // Configure recording
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      );

      await _recorder.start(config, path: _currentRecordingPath!);
      _isRecording = true;
      debugPrint('[VoiceRecording] Recording started: $_currentRecordingPath');
      return true;
    } catch (e) {
      debugPrint('[VoiceRecording] Error starting recording: $e');
      return false;
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _recorder.stop();
      _isRecording = false;
      debugPrint('[VoiceRecording] Recording stopped: $path');
      return path;
    } catch (e) {
      debugPrint('[VoiceRecording] Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording and delete the file
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;
      }

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('[VoiceRecording] Recording cancelled and deleted');
        }
      }
      _currentRecordingPath = null;
    } catch (e) {
      debugPrint('[VoiceRecording] Error cancelling recording: $e');
    }
  }

  /// Upload the recorded voice sample to the backend
  Future<bool> uploadRecording({
    required String filePath,
    required String language,
    String? textContent,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[VoiceRecording] File not found: $filePath');
        return false;
      }

      debugPrint('[VoiceRecording] Uploading: $filePath');

      await _voiceService.uploadVoiceSample(
        filePath,
        language,
        textContent ?? 'Voice sample for voice cloning',
      );

      debugPrint('[VoiceRecording] Upload successful');
      return true;
    } catch (e) {
      debugPrint('[VoiceRecording] Upload failed: $e');
      return false;
    }
  }

  /// Get the current user's language for the recording
  Future<String> getUserLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.primaryLanguageKey) ?? 'he';
  }

  /// Delete a voice recording file
  Future<void> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[VoiceRecording] Deleted: $filePath');
      }
    } catch (e) {
      debugPrint('[VoiceRecording] Error deleting: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _recorder.dispose();
  }
}
