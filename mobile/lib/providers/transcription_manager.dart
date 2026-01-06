import 'package:flutter/foundation.dart';

import '../models/transcription_entry.dart';

/// Manages transcription history during calls.
///
/// SRP: Single responsibility - manage transcription/translation history.
///
/// Handles:
/// - Storing transcription entries with original + translated text
/// - Limiting history size for memory efficiency
/// - Providing access to recent entries
class TranscriptionManager {
  final VoidCallback _notifyListeners;
  final bool Function() _isDisposed;

  final List<TranscriptionEntry> _entries = [];
  static const int _maxEntries = 100; // Keep last 100 entries

  TranscriptionManager(this._notifyListeners, this._isDisposed);

  /// Get all transcription entries (newest first)
  List<TranscriptionEntry> get entries => List.unmodifiable(_entries.reversed.toList());

  /// Get the most recent entry
  TranscriptionEntry? get latestEntry => _entries.isNotEmpty ? _entries.last : null;

  /// Get entries for a specific participant
  List<TranscriptionEntry> entriesForParticipant(String participantId) {
    return _entries
        .where((e) => e.participantId == participantId)
        .toList()
        .reversed
        .toList();
  }

  /// Add a new transcription entry
  void addEntry(TranscriptionEntry entry) {
    _entries.add(entry);
    _trimHistory();
    if (!_isDisposed()) _notifyListeners();
    debugPrint('[TranscriptionManager] Added entry: ${entry.originalText} -> ${entry.translatedText}');
  }

  /// Add entry from raw data (e.g., WebSocket message)
  void addFromMessage({
    required String participantId,
    required String participantName,
    required String originalText,
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
    double? confidence,
  }) {
    final entry = TranscriptionEntry(
      participantId: participantId,
      participantName: participantName,
      originalText: originalText,
      translatedText: translatedText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      timestamp: DateTime.now(),
      confidence: confidence,
    );
    addEntry(entry);
  }

  /// Clear all entries
  void clear() {
    _entries.clear();
    if (!_isDisposed()) _notifyListeners();
  }

  /// Trim history to max size
  void _trimHistory() {
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
  }

  /// Dispose resources
  void dispose() {
    clear();
  }
}
