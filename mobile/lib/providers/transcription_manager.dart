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

  /// Get all transcription entries in chronological order (oldest first)
  /// Use this for chat-style display where newest messages are at the bottom
  List<TranscriptionEntry> get chronologicalEntries => List.unmodifiable(_entries);

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

  /// Add a new transcription entry with deduplication
  ///
  /// Deduplication prevents duplicate messages when the same transcription
  /// arrives via multiple paths (e.g., interim_transcript + translation).
  void addEntry(TranscriptionEntry entry) {
    debugPrint('[TranscriptionManager] addEntry called for: "${entry.originalText}"');
    debugPrint('[TranscriptionManager]   participantId: ${entry.participantId}');
    debugPrint('[TranscriptionManager]   current entries count: ${_entries.length}');

    // Deduplication: Skip if recent entry from same speaker has EXACT same text
    if (_isDuplicate(entry)) {
      debugPrint('[TranscriptionManager] ⚠️ Skipped duplicate: ${entry.originalText}');
      return;
    }

    _entries.add(entry);
    _trimHistory();
    debugPrint('[TranscriptionManager] ✅ Entry added! New count: ${_entries.length}');
    if (!_isDisposed()) _notifyListeners();
  }

  /// Check if entry is a duplicate of a recent entry from the same speaker
  /// Only checks for EXACT matches within 3 seconds to avoid false positives
  bool _isDuplicate(TranscriptionEntry entry) {
    // Look at last 3 entries for duplicates
    final recentEntries = _entries.reversed.take(3);

    for (final existing in recentEntries) {
      // Same speaker?
      if (existing.participantId != entry.participantId) continue;

      // Within dedup window (3 seconds - reduced from 5)?
      final timeDiff = entry.timestamp.difference(existing.timestamp).inSeconds.abs();
      if (timeDiff > 3) continue;

      // EXACT match only (normalized comparison)
      final existingText = existing.originalText.trim().toLowerCase();
      final newText = entry.originalText.trim().toLowerCase();

      if (existingText == newText) {
        debugPrint('[TranscriptionManager] Duplicate detected: same speaker, same text within 3s');
        return true;
      }
    }

    return false;
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
