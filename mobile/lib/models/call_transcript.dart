/// Call Transcript model matching backend schema
/// 
/// Purpose: Store complete word-by-word record of all calls for history and debugging
/// 
/// Workflow:
/// 1. Every time a participant speaks, create ONE record per listener group
/// 2. Store original_text (what was actually said)
/// 3. Store translated_text (if translation occurred)
/// 4. Use timestamp_ms to reconstruct timeline
class CallTranscript {
  final String id;
  final String callId;
  final String? speakerUserId;
  final String originalLanguage;
  final String originalText;
  final String? translatedText;
  final String? targetLanguage;
  final int? timestampMs;
  final String? audioFilePath;
  final String? originalAudioPath;
  final String? translatedAudioPath;
  final int? sttConfidence;
  final int? translationQuality;
  final String? ttsMethod;
  final int? processingTimeMs;
  final DateTime createdAt;

  // Joined speaker information
  final String? speakerName;
  final String? speakerAvatarUrl;

  CallTranscript({
    required this.id,
    required this.callId,
    this.speakerUserId,
    required this.originalLanguage,
    required this.originalText,
    this.translatedText,
    this.targetLanguage,
    this.timestampMs,
    this.audioFilePath,
    this.originalAudioPath,
    this.translatedAudioPath,
    this.sttConfidence,
    this.translationQuality,
    this.ttsMethod,
    this.processingTimeMs,
    required this.createdAt,
    this.speakerName,
    this.speakerAvatarUrl,
  });

  /// Create CallTranscript from JSON
  factory CallTranscript.fromJson(Map<String, dynamic> json) {
    return CallTranscript(
      id: json['id'],
      callId: json['call_id'],
      speakerUserId: json['speaker_user_id'] ?? json['speaker_id'],
      originalLanguage: json['original_language'] ?? json['language'] ?? 'he',
      originalText: json['original_text'] ?? json['text'] ?? '',
      translatedText: json['translated_text'] ?? json['translated'],
      targetLanguage: json['target_language'],
      timestampMs: json['timestamp_ms'],
      audioFilePath: json['audio_file_path'],
      originalAudioPath: json['original_audio_path'],
      translatedAudioPath: json['translated_audio_path'],
      sttConfidence: json['stt_confidence'],
      translationQuality: json['translation_quality'],
      ttsMethod: json['tts_method'],
      processingTimeMs: json['processing_time_ms'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      speakerName: json['speaker_name'],
      speakerAvatarUrl: json['speaker_avatar_url'],
    );
  }

  /// Create CallTranscript from timeline format (simplified)
  factory CallTranscript.fromTimelineJson(Map<String, dynamic> json) {
    return CallTranscript(
      id: json['id'] ?? '',
      callId: json['call_id'] ?? '',
      speakerUserId: json['speaker_id'],
      originalLanguage: json['language'] ?? 'he',
      originalText: json['text'] ?? '',
      translatedText: json['translated'],
      timestampMs: json['timestamp_ms'],
      createdAt: DateTime.now(),
    );
  }

  /// Convert CallTranscript to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'call_id': callId,
      'speaker_user_id': speakerUserId,
      'original_language': originalLanguage,
      'original_text': originalText,
      'translated_text': translatedText,
      'target_language': targetLanguage,
      'timestamp_ms': timestampMs,
      'audio_file_path': audioFilePath,
      'original_audio_path': originalAudioPath,
      'translated_audio_path': translatedAudioPath,
      'stt_confidence': sttConfidence,
      'translation_quality': translationQuality,
      'tts_method': ttsMethod,
      'processing_time_ms': processingTimeMs,
      'created_at': createdAt.toIso8601String(),
      'speaker_name': speakerName,
      'speaker_avatar_url': speakerAvatarUrl,
    };
  }

  /// Convert to timeline format
  Map<String, dynamic> toTimelineJson() {
    return {
      'timestamp_ms': timestampMs,
      'speaker_id': speakerUserId,
      'text': originalText,
      'translated': translatedText,
      'language': originalLanguage,
    };
  }

  /// Create a copy with updated fields
  CallTranscript copyWith({
    String? id,
    String? callId,
    String? speakerUserId,
    String? originalLanguage,
    String? originalText,
    String? translatedText,
    String? targetLanguage,
    int? timestampMs,
    String? audioFilePath,
    String? originalAudioPath,
    String? translatedAudioPath,
    int? sttConfidence,
    int? translationQuality,
    String? ttsMethod,
    int? processingTimeMs,
    DateTime? createdAt,
    String? speakerName,
    String? speakerAvatarUrl,
  }) {
    return CallTranscript(
      id: id ?? this.id,
      callId: callId ?? this.callId,
      speakerUserId: speakerUserId ?? this.speakerUserId,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      timestampMs: timestampMs ?? this.timestampMs,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      originalAudioPath: originalAudioPath ?? this.originalAudioPath,
      translatedAudioPath: translatedAudioPath ?? this.translatedAudioPath,
      sttConfidence: sttConfidence ?? this.sttConfidence,
      translationQuality: translationQuality ?? this.translationQuality,
      ttsMethod: ttsMethod ?? this.ttsMethod,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      createdAt: createdAt ?? this.createdAt,
      speakerName: speakerName ?? this.speakerName,
      speakerAvatarUrl: speakerAvatarUrl ?? this.speakerAvatarUrl,
    );
  }

  /// Check if translation was performed
  bool get hasTranslation => translatedText != null && translatedText!.isNotEmpty;

  /// Get display text (translated if available, otherwise original)
  String get displayText => translatedText ?? originalText;

  /// Get language display name
  String get languageDisplay {
    switch (originalLanguage) {
      case 'he':
        return 'Hebrew';
      case 'en':
        return 'English';
      case 'ru':
        return 'Russian';
      default:
        return originalLanguage;
    }
  }

  /// Get timestamp as formatted string
  String get timestampDisplay {
    if (timestampMs == null) return '--:--';
    final totalSeconds = timestampMs! ~/ 1000;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Get TTS method display
  String get ttsMethodDisplay {
    switch (ttsMethod?.toLowerCase()) {
      case 'xtts':
      case 'xtts_voice_clone':
        return 'Voice Clone';
      case 'google_tts':
      case 'google_tts_fallback':
        return 'Standard TTS';
      case 'passthrough':
        return 'Direct Audio';
      default:
        return ttsMethod ?? 'Unknown';
    }
  }

  /// Get confidence display
  String get confidenceDisplay {
    if (sttConfidence == null) return 'N/A';
    return '$sttConfidence%';
  }
}

