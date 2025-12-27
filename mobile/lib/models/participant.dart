/// Voice clone quality enum
enum VoiceCloneQuality {
  excellent('excellent'),
  good('good'),
  fair('fair'),
  fallback('fallback');

  final String value;
  const VoiceCloneQuality(this.value);

  static VoiceCloneQuality fromString(String? value) {
    if (value == null) return VoiceCloneQuality.fallback;
    return VoiceCloneQuality.values.firstWhere(
      (q) => q.value == value.toLowerCase(),
      orElse: () => VoiceCloneQuality.fallback,
    );
  }
}

/// Call Participant model matching backend schema
class CallParticipant {
  final String id;
  final String callId;
  final String userId;
  
  /// Participant's language (from users.primary_language at join time)
  final String participantLanguage;
  
  /// Target language for receiving translations
  final String targetLanguage;
  
  /// Speaking language (what the participant speaks)
  final String speakingLanguage;
  
  /// Whether dubbing/translation is required
  /// TRUE if participant_language != call.call_language
  final bool dubbingRequired;
  
  /// Whether to use voice cloning for this participant
  final bool useVoiceClone;
  
  /// Quality of user's voice clone
  final VoiceCloneQuality voiceCloneQuality;
  
  final bool isMuted;
  final bool isSpeakerOn;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final int? durationSeconds;
  final bool isConnected;
  final String? connectionQuality;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String displayName;
  final String? fullName;
  final String? phone;
  final String? primaryLanguage;

  /// UI-only state coming from the websocket pipeline
  final bool isSpeaking;
  final bool isTranslating;
  final double speakingEnergy;
  final String? latestCaption;

  CallParticipant({
    required this.id,
    required this.callId,
    required this.userId,
    this.participantLanguage = 'he',
    required this.targetLanguage,
    required this.speakingLanguage,
    this.dubbingRequired = false,
    this.useVoiceClone = false,
    this.voiceCloneQuality = VoiceCloneQuality.fallback,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.joinedAt,
    this.leftAt,
    this.durationSeconds,
    this.isConnected = true,
    this.connectionQuality,
    this.createdAt,
    this.updatedAt,
    this.displayName = 'Participant',
    this.fullName,
    this.phone,
    this.primaryLanguage,
    this.isSpeaking = false,
    this.isTranslating = false,
    this.speakingEnergy = 0.0,
    this.latestCaption,
  });

  /// Create CallParticipant from JSON (API response)
  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    return CallParticipant(
      id: json['id'],
      callId: json['call_id'] ?? '',
      userId: json['user_id'],
      participantLanguage: json['participant_language'] ?? json['primary_language'] ?? 'he',
      targetLanguage: json['target_language'] ?? 'he',
      speakingLanguage: json['speaking_language'] ?? 'he',
      dubbingRequired: json['dubbing_required'] ?? false,
      useVoiceClone: json['use_voice_clone'] ?? false,
      voiceCloneQuality: VoiceCloneQuality.fromString(json['voice_clone_quality']),
      isMuted: json['is_muted'] ?? false,
      isSpeakerOn: json['is_speaker_on'] ?? true,
      joinedAt: json['joined_at'] != null 
          ? DateTime.parse(json['joined_at']) 
          : null,
      leftAt:
          json['left_at'] != null ? DateTime.parse(json['left_at']) : null,
      durationSeconds: json['duration_seconds'],
      isConnected: json['is_connected'] ?? true,
      connectionQuality: json['connection_quality'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      displayName: json['display_name'] ?? json['full_name'] ?? json['user_name'] ?? 'Participant',
      fullName: json['full_name'],
      phone: json['phone'],
      primaryLanguage: json['primary_language'],
      isSpeaking: json['is_speaking'] ?? false,
      isTranslating: json['is_translating'] ?? false,
      speakingEnergy: (json['speaking_energy'] ?? 0).toDouble(),
      latestCaption: json['latest_caption'],
    );
  }

  /// Convert CallParticipant to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'call_id': callId,
      'user_id': userId,
      'participant_language': participantLanguage,
      'target_language': targetLanguage,
      'speaking_language': speakingLanguage,
      'dubbing_required': dubbingRequired,
      'use_voice_clone': useVoiceClone,
      'voice_clone_quality': voiceCloneQuality.value,
      'is_muted': isMuted,
      'is_speaker_on': isSpeakerOn,
      'joined_at': joinedAt?.toIso8601String(),
      'left_at': leftAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'is_connected': isConnected,
      'connection_quality': connectionQuality,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'display_name': displayName,
      'full_name': fullName,
      'phone': phone,
      'primary_language': primaryLanguage,
      'is_speaking': isSpeaking,
      'is_translating': isTranslating,
      'speaking_energy': speakingEnergy,
      'latest_caption': latestCaption,
    };
  }

  /// Create a copy with updated fields
  CallParticipant copyWith({
    String? id,
    String? callId,
    String? userId,
    String? participantLanguage,
    String? targetLanguage,
    String? speakingLanguage,
    bool? dubbingRequired,
    bool? useVoiceClone,
    VoiceCloneQuality? voiceCloneQuality,
    bool? isMuted,
    bool? isSpeakerOn,
    DateTime? joinedAt,
    DateTime? leftAt,
    int? durationSeconds,
    bool? isConnected,
    String? connectionQuality,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? displayName,
    String? fullName,
    String? phone,
    String? primaryLanguage,
    bool? isSpeaking,
    bool? isTranslating,
    double? speakingEnergy,
    String? latestCaption,
  }) {
    return CallParticipant(
      id: id ?? this.id,
      callId: callId ?? this.callId,
      userId: userId ?? this.userId,
      participantLanguage: participantLanguage ?? this.participantLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      speakingLanguage: speakingLanguage ?? this.speakingLanguage,
      dubbingRequired: dubbingRequired ?? this.dubbingRequired,
      useVoiceClone: useVoiceClone ?? this.useVoiceClone,
      voiceCloneQuality: voiceCloneQuality ?? this.voiceCloneQuality,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isConnected: isConnected ?? this.isConnected,
      connectionQuality: connectionQuality ?? this.connectionQuality,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      displayName: displayName ?? this.displayName,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isTranslating: isTranslating ?? this.isTranslating,
      speakingEnergy: speakingEnergy ?? this.speakingEnergy,
      latestCaption: latestCaption ?? this.latestCaption,
    );
  }

  /// Check if participant is still in the call
  bool get isInCall => leftAt == null && isConnected;

  /// Check if participant needs translation
  bool get needsTranslation => dubbingRequired;
  
  /// Check if voice cloning is available and enabled
  bool get canUseVoiceClone => 
      useVoiceClone && 
      voiceCloneQuality != VoiceCloneQuality.fallback;

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
  
  /// Get language display name
  String get languageDisplay {
    switch (participantLanguage) {
      case 'he':
        return 'Hebrew';
      case 'en':
        return 'English';
      case 'ru':
        return 'Russian';
      default:
        return participantLanguage;
    }
  }
  
  /// Get voice clone quality display
  String get voiceCloneQualityDisplay {
    switch (voiceCloneQuality) {
      case VoiceCloneQuality.excellent:
        return 'Excellent';
      case VoiceCloneQuality.good:
        return 'Good';
      case VoiceCloneQuality.fair:
        return 'Fair';
      case VoiceCloneQuality.fallback:
        return 'Standard TTS';
    }
  }
}
