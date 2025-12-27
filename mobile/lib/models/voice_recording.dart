/// Voice Recording model matching backend schema
/// 
/// Purpose: Store raw voice samples used for training voice cloning models
/// 
/// Workflow:
/// 1. User uploads 2-3 voice samples (each ~15-30 seconds)
/// 2. Each sample is stored with is_processed = FALSE
/// 3. Backend processes samples (quality check, noise reduction)
/// 4. Set is_processed = TRUE and quality_score
/// 5. Select best 2 samples and set used_for_training = TRUE
/// 6. Feed to xTTS: Train voice model
class VoiceRecording {
  final String id;
  final String userId;
  final String language;
  final String textContent;
  final String filePath;
  final int? fileSizeBytes;
  final int? durationSeconds;
  final int? sampleRate;
  final String? audioFormat;
  final int? qualityScore;
  final bool isProcessed;
  final DateTime? processedAt;
  final String? processingError;
  final bool usedForTraining;
  final String? trainingBatchId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VoiceRecording({
    required this.id,
    required this.userId,
    required this.language,
    required this.textContent,
    required this.filePath,
    this.fileSizeBytes,
    this.durationSeconds,
    this.sampleRate,
    this.audioFormat,
    this.qualityScore,
    this.isProcessed = false,
    this.processedAt,
    this.processingError,
    this.usedForTraining = false,
    this.trainingBatchId,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create VoiceRecording from JSON
  factory VoiceRecording.fromJson(Map<String, dynamic> json) {
    return VoiceRecording(
      id: json['id'],
      userId: json['user_id'],
      language: json['language'] ?? 'he',
      textContent: json['text_content'] ?? '',
      filePath: json['file_path'] ?? '',
      fileSizeBytes: json['file_size_bytes'],
      durationSeconds: json['duration_seconds'],
      sampleRate: json['sample_rate'],
      audioFormat: json['audio_format'],
      qualityScore: json['quality_score'],
      isProcessed: json['is_processed'] ?? false,
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : null,
      processingError: json['processing_error'],
      usedForTraining: json['used_for_training'] ?? false,
      trainingBatchId: json['training_batch_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  /// Convert VoiceRecording to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'language': language,
      'text_content': textContent,
      'file_path': filePath,
      'file_size_bytes': fileSizeBytes,
      'duration_seconds': durationSeconds,
      'sample_rate': sampleRate,
      'audio_format': audioFormat,
      'quality_score': qualityScore,
      'is_processed': isProcessed,
      'processed_at': processedAt?.toIso8601String(),
      'processing_error': processingError,
      'used_for_training': usedForTraining,
      'training_batch_id': trainingBatchId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  VoiceRecording copyWith({
    String? id,
    String? userId,
    String? language,
    String? textContent,
    String? filePath,
    int? fileSizeBytes,
    int? durationSeconds,
    int? sampleRate,
    String? audioFormat,
    int? qualityScore,
    bool? isProcessed,
    DateTime? processedAt,
    String? processingError,
    bool? usedForTraining,
    String? trainingBatchId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VoiceRecording(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      language: language ?? this.language,
      textContent: textContent ?? this.textContent,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sampleRate: sampleRate ?? this.sampleRate,
      audioFormat: audioFormat ?? this.audioFormat,
      qualityScore: qualityScore ?? this.qualityScore,
      isProcessed: isProcessed ?? this.isProcessed,
      processedAt: processedAt ?? this.processedAt,
      processingError: processingError ?? this.processingError,
      usedForTraining: usedForTraining ?? this.usedForTraining,
      trainingBatchId: trainingBatchId ?? this.trainingBatchId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get status display
  String get statusDisplay {
    if (processingError != null) return 'Error';
    if (!isProcessed) return 'Processing...';
    if (usedForTraining) return 'Used for Training';
    return 'Ready';
  }

  /// Get quality display
  String get qualityDisplay {
    if (qualityScore == null) return 'Not assessed';
    if (qualityScore! > 80) return 'Excellent';
    if (qualityScore! > 60) return 'Good';
    if (qualityScore! > 40) return 'Fair';
    return 'Poor';
  }

  /// Get language display name
  String get languageDisplay {
    switch (language) {
      case 'he':
        return 'Hebrew';
      case 'en':
        return 'English';
      case 'ru':
        return 'Russian';
      default:
        return language;
    }
  }

  /// Get file size display
  String get fileSizeDisplay {
    if (fileSizeBytes == null) return 'Unknown';
    if (fileSizeBytes! < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes! < 1024 * 1024) {
      return '${(fileSizeBytes! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get duration display
  String get durationDisplay {
    if (durationSeconds == null) return '--:--';
    final minutes = (durationSeconds! ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds! % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Check if recording is ready for training
  bool get isReadyForTraining => isProcessed && qualityScore != null && qualityScore! > 40;
}

