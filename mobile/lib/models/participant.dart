/// Call Participant model matching backend schema
class CallParticipant {
  final String id;
  final String callId;
  final String userId;
  final String targetLanguage;
  final String speakingLanguage;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool useVoiceCloning;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final int? durationSeconds;
  final bool isConnected;
  final String? connectionQuality;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CallParticipant({
    required this.id,
    required this.callId,
    required this.userId,
    required this.targetLanguage,
    required this.speakingLanguage,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.useVoiceCloning = false,
    required this.joinedAt,
    this.leftAt,
    this.durationSeconds,
    this.isConnected = true,
    this.connectionQuality,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create CallParticipant from JSON
  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    return CallParticipant(
      id: json['id'],
      callId: json['call_id'],
      userId: json['user_id'],
      targetLanguage: json['target_language'],
      speakingLanguage: json['speaking_language'],
      isMuted: json['is_muted'] ?? false,
      isSpeakerOn: json['is_speaker_on'] ?? true,
      useVoiceCloning: json['use_voice_cloning'] ?? false,
      joinedAt: DateTime.parse(json['joined_at']),
      leftAt:
          json['left_at'] != null ? DateTime.parse(json['left_at']) : null,
      durationSeconds: json['duration_seconds'],
      isConnected: json['is_connected'] ?? true,
      connectionQuality: json['connection_quality'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  /// Convert CallParticipant to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'call_id': callId,
      'user_id': userId,
      'target_language': targetLanguage,
      'speaking_language': speakingLanguage,
      'is_muted': isMuted,
      'is_speaker_on': isSpeakerOn,
      'use_voice_cloning': useVoiceCloning,
      'joined_at': joinedAt.toIso8601String(),
      'left_at': leftAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'is_connected': isConnected,
      'connection_quality': connectionQuality,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  CallParticipant copyWith({
    String? id,
    String? callId,
    String? userId,
    String? targetLanguage,
    String? speakingLanguage,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? useVoiceCloning,
    DateTime? joinedAt,
    DateTime? leftAt,
    int? durationSeconds,
    bool? isConnected,
    String? connectionQuality,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CallParticipant(
      id: id ?? this.id,
      callId: callId ?? this.callId,
      userId: userId ?? this.userId,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      speakingLanguage: speakingLanguage ?? this.speakingLanguage,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      useVoiceCloning: useVoiceCloning ?? this.useVoiceCloning,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isConnected: isConnected ?? this.isConnected,
      connectionQuality: connectionQuality ?? this.connectionQuality,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if participant is still in the call
  bool get isInCall => leftAt == null && isConnected;

  /// Get connection quality color
  String get connectionColor {
    switch (connectionQuality?.toLowerCase()) {
      case 'excellent':
        return '#4CAF50'; // Green
      case 'good':
        return '#8BC34A'; // Light green
      case 'fair':
        return '#FFC107'; // Yellow
      case 'poor':
        return '#FF5722'; // Red
      default:
        return '#9E9E9E'; // Gray
    }
  }
}
