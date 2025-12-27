/// TranscriptionEntry model for storing transcription history.
/// 
/// Each entry represents a single translated message from a participant.
class TranscriptionEntry {
  final String participantId;
  final String participantName;
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime timestamp;
  final double? confidence;

  const TranscriptionEntry({
    required this.participantId,
    required this.participantName,
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
    this.confidence,
  });

  /// Create from JSON
  factory TranscriptionEntry.fromJson(Map<String, dynamic> json) {
    return TranscriptionEntry(
      participantId: json['participant_id'] as String,
      participantName: json['participant_name'] as String? ?? 'Unknown',
      originalText: json['original_text'] as String,
      translatedText: json['translated_text'] as String,
      sourceLanguage: json['source_language'] as String,
      targetLanguage: json['target_language'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'participant_id': participantId,
      'participant_name': participantName,
      'original_text': originalText,
      'translated_text': translatedText,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
    };
  }

  /// Display format: "Name: translated text"
  String get displayText => '$participantName: $translatedText';

  /// Display format with original: "translated (original)"
  String get fullText => '$translatedText ($originalText)';

  /// Check if this is a high-confidence translation
  bool get isHighConfidence => (confidence ?? 100) >= 80;

  @override
  String toString() => 'TranscriptionEntry(from: $participantName, text: $translatedText)';
}
