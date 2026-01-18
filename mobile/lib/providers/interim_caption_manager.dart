import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/interim_caption.dart';
import '../config/constants.dart';

/// Callback to resolve speaker name from participant list
typedef GetParticipantNameCallback = String? Function(String speakerId);

/// Callback to set the active speaker
typedef SetActiveSpeakerCallback = void Function(String speakerId);

/// Manages real-time interim captions (WhatsApp-style typing indicators).
///
/// Responsibilities:
/// - Track interim captions per speaker
/// - Auto-clear stale captions after timeout
/// - Handle show/hide preference
class InterimCaptionManager {
  final VoidCallback _notifyListeners;
  final bool Function() _isDisposed;
  final GetParticipantNameCallback _getParticipantName;
  final SetActiveSpeakerCallback _setActiveSpeaker;

  /// Interim captions per speaker (real-time typing indicator)
  final Map<String, InterimCaption> _captions = {};

  /// Timers to auto-clear stale interim captions
  final Map<String, Timer> _timers = {};

  /// User preference: whether to show interim captions
  bool _showCaptions = true;

  InterimCaptionManager({
    required VoidCallback notifyListeners,
    required bool Function() isDisposed,
    required GetParticipantNameCallback getParticipantName,
    required SetActiveSpeakerCallback setActiveSpeaker,
  })  : _notifyListeners = notifyListeners,
        _isDisposed = isDisposed,
        _getParticipantName = getParticipantName,
        _setActiveSpeaker = setActiveSpeaker;

  /// Get all current interim captions
  Map<String, InterimCaption> get captions => Map.unmodifiable(_captions);

  /// Whether interim captions are enabled
  bool get showCaptions => _showCaptions;

  /// Toggle interim captions visibility
  set showCaptions(bool value) {
    _showCaptions = value;
    if (!value) {
      clearAll();
    }
  }

  /// Handle incoming interim transcript message
  void handleInterimTranscript(Map<String, dynamic>? data) {
    if (!_showCaptions) return;
    if (data == null) return;

    // Parse interim caption from message
    final interim = InterimCaption.fromJson(data);
    if (interim.text.isEmpty) return;

    // Resolve speaker name from participants
    final speakerName = _getParticipantName(interim.speakerId);
    final interimWithName = interim.copyWith(speakerName: speakerName);

    // Update the interim caption for this speaker
    _captions[interim.speakerId] = interimWithName;

    // Reset the auto-clear timer for this speaker
    _resetTimer(interim.speakerId);

    // If this is a final result from streaming STT, mark active speaker
    if (interim.isFinal) {
      _setActiveSpeaker(interim.speakerId);
    }

    if (!_isDisposed()) {
      _notifyListeners();
    }

    debugPrint(
        '[InterimCaptionManager] [${interimWithName.displayTag}]: "${interim.text.length > 30 ? '${interim.text.substring(0, 30)}...' : interim.text}"');
  }

  /// Reset the auto-clear timer for an interim caption
  void _resetTimer(String speakerId) {
    _timers[speakerId]?.cancel();
    _timers[speakerId] = Timer(
      const Duration(milliseconds: AppConstants.interimCaptionTimeoutMs),
      () {
        if (!_isDisposed()) {
          clearCaption(speakerId);
        }
      },
    );
  }

  /// Clear interim caption for a specific speaker
  void clearCaption(String speakerId) {
    _captions.remove(speakerId);
    _timers[speakerId]?.cancel();
    _timers.remove(speakerId);
    if (!_isDisposed()) {
      _notifyListeners();
    }
  }

  /// Clear all interim captions
  void clearAll() {
    _captions.clear();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// Dispose all timers
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _captions.clear();
  }
}
