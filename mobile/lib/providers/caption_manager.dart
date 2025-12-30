import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/live_caption.dart';

/// Manages live caption bubbles during calls.
///
/// Handles:
/// - Adding captions with auto-dismiss timers
/// - Clearing bubbles on call end
class CaptionManager {
  final VoidCallback _notifyListeners;
  final bool Function() _isDisposed;

  final List<LiveCaptionData> _captionBubbles = [];
  final Map<String, Timer> _bubbleTimers = {};

  CaptionManager(this._notifyListeners, this._isDisposed);

  List<LiveCaptionData> get captionBubbles =>
      List.unmodifiable(_captionBubbles);

  /// Add a caption bubble that auto-dismisses after 4 seconds
  void addCaptionBubble(String participantId, String text) {
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
      if (!_isDisposed()) _notifyListeners();
    });
  }

  /// Clear all caption bubbles
  void clearBubbles() {
    for (final timer in _bubbleTimers.values) {
      timer.cancel();
    }
    _bubbleTimers.clear();
    _captionBubbles.clear();
  }

  /// Dispose resources
  void dispose() {
    clearBubbles();
  }
}
