/// Model for real-time interim captions (WhatsApp-style typing indicator).
///
/// Unlike [LiveCaptionData], this model is designed for the typing indicator
/// that updates in real-time as speech is being transcribed, before translation.
class InterimCaption {
  /// The speaker's user ID
  final String speakerId;

  /// The interim transcription text
  final String text;

  /// Whether this caption is from the current user (self-preview)
  final bool isSelf;

  /// Source language code (e.g., "en-US", "he-IL")
  final String sourceLanguage;

  /// Confidence score from STT (0.0 - 1.0)
  final double confidence;

  /// Whether this is a final result (sentence complete)
  final bool isFinal;

  /// When this interim was received
  final DateTime timestamp;

  /// Display name for the speaker (resolved from participant data)
  String? speakerName;

  InterimCaption({
    required this.speakerId,
    required this.text,
    required this.isSelf,
    this.sourceLanguage = 'en-US',
    this.confidence = 0.7,
    this.isFinal = false,
    DateTime? timestamp,
    this.speakerName,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from WebSocket message data
  factory InterimCaption.fromJson(Map<String, dynamic> json) {
    return InterimCaption(
      speakerId: json['speaker_id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      isSelf: json['is_self'] as bool? ?? false,
      sourceLanguage: json['source_lang'] as String? ?? 'en-US',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.7,
      isFinal: json['is_final'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              ((json['timestamp'] as num) * 1000).toInt())
          : DateTime.now(),
    );
  }

  /// Get display tag for the speaker
  String get displayTag => isSelf ? 'You' : (speakerName ?? speakerId.substring(0, 8));

  /// Create a copy with updated text (for smooth transitions)
  InterimCaption copyWith({
    String? text,
    bool? isFinal,
    double? confidence,
    String? speakerName,
  }) {
    return InterimCaption(
      speakerId: speakerId,
      text: text ?? this.text,
      isSelf: isSelf,
      sourceLanguage: sourceLanguage,
      confidence: confidence ?? this.confidence,
      isFinal: isFinal ?? this.isFinal,
      timestamp: DateTime.now(),
      speakerName: speakerName ?? this.speakerName,
    );
  }

  @override
  String toString() => 'InterimCaption([$displayTag] "$text", final=$isFinal)';
}
