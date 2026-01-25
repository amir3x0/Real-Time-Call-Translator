import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/interim_caption.dart';
import '../config/constants.dart';

/// Callback to resolve speaker name from participant list
typedef GetParticipantNameCallback = String? Function(String speakerId);

/// Callback to set the active speaker
typedef SetActiveSpeakerCallback = void Function(String speakerId);

/// Callback when interim caption times out without receiving is_final=true
/// This allows treating timed-out interim as a final result (for languages like Hebrew
/// where Google STT doesn't always send is_final)
/// Parameters:
///   - caption: The current interim caption that timed out
///   - lastFinalizedText: The text that was previously finalized (to compute delta)
typedef OnInterimTimeoutCallback = void Function(InterimCaption caption, String? lastFinalizedText);

/// Manages real-time interim captions (WhatsApp-style typing indicators).
///
/// Responsibilities:
/// - Track interim captions per speaker
/// - Auto-clear stale captions after timeout
/// - Handle show/hide preference
/// - Notify when interim times out (for fallback finalization)
class InterimCaptionManager {
  final VoidCallback _notifyListeners;
  final bool Function() _isDisposed;
  final GetParticipantNameCallback _getParticipantName;
  final SetActiveSpeakerCallback _setActiveSpeaker;
  OnInterimTimeoutCallback? _onInterimTimeout;

  /// Interim captions per speaker (real-time typing indicator)
  final Map<String, InterimCaption> _captions = {};

  /// Timers to auto-clear stale interim captions
  final Map<String, Timer> _timers = {};

  /// Track last finalized text per speaker to avoid duplication
  /// When Hebrew STT sends accumulated text, we use this to compute the delta
  final Map<String, String> _lastFinalizedText = {};

  /// Track the FULL accumulated text from STT (before delta computation)
  /// This is needed for the timeout callback to compute the correct delta for history
  final Map<String, String> _fullAccumulatedText = {};

  /// User preference: whether to show interim captions
  bool _showCaptions = true;

  InterimCaptionManager({
    required VoidCallback notifyListeners,
    required bool Function() isDisposed,
    required GetParticipantNameCallback getParticipantName,
    required SetActiveSpeakerCallback setActiveSpeaker,
    OnInterimTimeoutCallback? onInterimTimeout,
  })  : _notifyListeners = notifyListeners,
        _isDisposed = isDisposed,
        _getParticipantName = getParticipantName,
        _setActiveSpeaker = setActiveSpeaker,
        _onInterimTimeout = onInterimTimeout;

  /// Set the callback for interim timeout (fallback finalization)
  set onInterimTimeout(OnInterimTimeoutCallback? callback) {
    _onInterimTimeout = callback;
  }

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

    // Compute the delta text for display (only the NEW portion since last finalization)
    // This handles Hebrew STT which returns accumulated text like "hi whats up how are you"
    // We only want to display the current sentence, not the full accumulation
    final lastFinalized = _lastFinalizedText[interim.speakerId];
    String displayText = interim.text;

    if (lastFinalized != null && lastFinalized.isNotEmpty) {
      if (interim.text.startsWith(lastFinalized)) {
        // Remove the prefix that was already finalized
        displayText = interim.text.substring(lastFinalized.length).trim();
      } else if (interim.text.contains(lastFinalized)) {
        // Last finalized is somewhere in the middle - extract everything after it
        final idx = interim.text.indexOf(lastFinalized);
        displayText = interim.text.substring(idx + lastFinalized.length).trim();
      }
      // If neither contains the other, it's a completely new sentence - use full text
    }

    // If delta is empty, skip this update (nothing new to show)
    if (displayText.isEmpty) {
      return;
    }

    // Create interim with delta text for display, but keep original for tracking
    final interimForDisplay = interim.copyWith(text: displayText, speakerName: speakerName);

    // Check if display text is growing vs shrinking
    final existingCaption = _captions[interim.speakerId];
    final isTextGrowing = existingCaption == null ||
        displayText.length >= existingCaption.text.length;

    // Update the interim caption with the DELTA text for display
    _captions[interim.speakerId] = interimForDisplay;

    // Store the FULL original text for timeout callback (to compute delta for history)
    // We use a separate map to track the full accumulated text
    _fullAccumulatedText[interim.speakerId] = interim.text;

    // Only reset timer if:
    // 1. This is a final result (sentence complete)
    // 2. Text is growing (active sentence, not stale) - includes new caption case
    if (interim.isFinal || isTextGrowing) {
      _resetTimer(interim.speakerId, interim.isFinal);
    }
    // If text is shrinking and not final, don't reset timer (let it timeout naturally)

    // If this is a final result from streaming STT, mark active speaker
    // and clear the last finalized text (fresh start for next sentence)
    if (interim.isFinal) {
      _setActiveSpeaker(interim.speakerId);
      _lastFinalizedText.remove(interim.speakerId);
      _fullAccumulatedText.remove(interim.speakerId);
    }

    if (!_isDisposed()) {
      _notifyListeners();
    }

    debugPrint(
        '[InterimCaptionManager] [${interimForDisplay.displayTag}]: display="$displayText" full="${interim.text.length > 30 ? '${interim.text.substring(0, 30)}...' : interim.text}" (final=${interim.isFinal})');
  }

  /// Reset the auto-clear timer for an interim caption
  /// Uses longer timeout for final results to ensure they're visible before clearing
  void _resetTimer(String speakerId, [bool isFinal = false]) {
    _timers[speakerId]?.cancel();

    // Use longer timeout for final results (6 seconds) vs interim (3 seconds)
    // This ensures Hebrew sentences have time to be displayed before clearing
    final timeoutMs = isFinal
        ? AppConstants.interimCaptionTimeoutMs * 2 // 6 seconds for final
        : AppConstants.interimCaptionTimeoutMs; // 3 seconds for interim

    _timers[speakerId] = Timer(
      Duration(milliseconds: timeoutMs),
      () {
        if (!_isDisposed()) {
          // If this is a non-final caption timing out, notify the callback
          // so it can be treated as a final result (fallback for Hebrew STT)
          final caption = _captions[speakerId];
          final fullText = _fullAccumulatedText[speakerId];
          if (caption != null && !caption.isFinal && _onInterimTimeout != null && fullText != null) {
            final lastFinalized = _lastFinalizedText[speakerId];
            debugPrint('[InterimCaptionManager] ⏱️ Interim timeout for ${caption.speakerId}');
            debugPrint('[InterimCaptionManager]   Full accumulated: "$fullText"');
            debugPrint('[InterimCaptionManager]   Last finalized: "$lastFinalized"');
            
            // Create a caption with the FULL accumulated text for the callback
            // (callback needs full text to compute delta for history)
            final captionWithFullText = caption.copyWith(text: fullText);
            
            // Pass both the caption (with full text) and the last finalized text
            _onInterimTimeout!(captionWithFullText, lastFinalized);
            
            // Update last finalized text to the FULL accumulated text
            _lastFinalizedText[speakerId] = fullText;
          }
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
    _fullAccumulatedText.remove(speakerId);
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
    _lastFinalizedText.clear();
    _fullAccumulatedText.clear();
  }

  /// Dispose all timers
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _captions.clear();
    _lastFinalizedText.clear();
    _fullAccumulatedText.clear();
  }
}
