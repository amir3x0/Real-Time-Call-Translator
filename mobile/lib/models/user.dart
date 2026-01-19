import '../utils/language_utils.dart';
import 'participant.dart';

/// User model matching backend schema (simplified)
class User {
  final String id;
  final String phone;
  final String fullName;

  /// Primary language (determines call language when user initiates) - IMMUTABLE
  final String primaryLanguage;

  /// Theme preference ('light' or 'dark')
  final String themePreference;

  // Voice cloning attributes
  final bool hasVoiceSample;
  final bool voiceModelTrained;
  final int? voiceQualityScore;

  // Status
  final bool isOnline;
  final DateTime? lastSeen;

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.primaryLanguage,
    this.themePreference = 'light',
    this.hasVoiceSample = false,
    this.voiceModelTrained = false,
    this.voiceQualityScore,
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phone: (json['phone'] ?? '') as String,
      fullName: json['full_name'] as String,
      primaryLanguage: json['primary_language'] as String? ?? 'he',
      themePreference: json['theme_preference'] as String? ?? 'light',
      hasVoiceSample: json['has_voice_sample'] as bool? ?? false,
      voiceModelTrained: json['voice_model_trained'] as bool? ?? false,
      voiceQualityScore: json['voice_quality_score'] as int?,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  /// Convert User to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'full_name': fullName,
      'primary_language': primaryLanguage,
      'theme_preference': themePreference,
      'has_voice_sample': hasVoiceSample,
      'voice_model_trained': voiceModelTrained,
      'voice_quality_score': voiceQualityScore,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  User copyWith({
    String? id,
    String? phone,
    String? fullName,
    String? primaryLanguage,
    String? themePreference,
    bool? hasVoiceSample,
    bool? voiceModelTrained,
    int? voiceQualityScore,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      themePreference: themePreference ?? this.themePreference,
      hasVoiceSample: hasVoiceSample ?? this.hasVoiceSample,
      voiceModelTrained: voiceModelTrained ?? this.voiceModelTrained,
      voiceQualityScore: voiceQualityScore ?? this.voiceQualityScore,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get display phone number
  String get displayPhone => phone;

  /// Get voice clone quality
  VoiceCloneQuality get voiceCloneQuality {
    if (!voiceModelTrained || voiceQualityScore == null) {
      return VoiceCloneQuality.fallback;
    }
    if (voiceQualityScore! > 80) return VoiceCloneQuality.excellent;
    if (voiceQualityScore! > 60) return VoiceCloneQuality.good;
    if (voiceQualityScore! > 40) return VoiceCloneQuality.fair;
    return VoiceCloneQuality.fallback;
  }

  /// Check if user can use voice cloning
  bool get canUseVoiceClone =>
      voiceModelTrained && voiceQualityScore != null && voiceQualityScore! > 60;

  /// Check if voice quality is good enough for cloning
  bool get hasGoodVoiceQuality =>
      voiceQualityScore != null && voiceQualityScore! > 80;

  /// Get language display name
  String get languageDisplay => LanguageUtils.getEnglishName(primaryLanguage);

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

  /// Get avatar letter for display
  String get avatarLetter =>
      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

  /// Get language flag emoji
  String get languageFlag => LanguageUtils.getFlag(primaryLanguage);
}
