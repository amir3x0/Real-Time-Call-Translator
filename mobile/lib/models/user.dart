/// User model matching backend schema
class User {
  final String id;
  final String phone;
  final String fullName;
  final String primaryLanguage;
  final String? languageCode;  // User's selected language: 'he', 'en', or 'ru'
  final List<String> supportedLanguages;
  final bool hasVoiceSample;
  final String? voiceSamplePath;
  final bool voiceModelTrained;
  final int? voiceQualityScore;
  final bool isActive;
  final bool isOnline;
  final String status;  // 'online' or 'offline'
  final DateTime? lastSeen;
  final String? avatarUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.primaryLanguage,
    this.languageCode,  // NEW
    required this.supportedLanguages,
    this.hasVoiceSample = false,
    this.voiceSamplePath,
    this.voiceModelTrained = false,
    this.voiceQualityScore,
    this.isActive = true,
    this.isOnline = false,
    this.status = 'offline',  // NEW - default to offline
    this.lastSeen,
    this.avatarUrl,
    this.bio,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phone: json['phone'] as String,
      fullName: json['full_name'] as String,
      primaryLanguage: json['primary_language'] as String,
      languageCode: json['language_code'] as String?,  // NEW
      supportedLanguages: json['supported_languages'] != null
          ? List<String>.from(json['supported_languages'])
          : ['he'],
      hasVoiceSample: json['has_voice_sample'] as bool? ?? false,
      voiceSamplePath: json['voice_sample_path'],
      voiceModelTrained: json['voice_model_trained'] ?? false,
      voiceQualityScore: json['voice_quality_score'],
      isActive: json['is_active'] ?? true,
      isOnline: json['is_online'] ?? false,
      status: json['status'] as String? ?? 'offline',  // NEW
      lastSeen: json['last_seen'] != null  // NEW
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      createdAt: DateTime.parse(json['created_at']),
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
      'language_code': languageCode,  // NEW
      'supported_languages': supportedLanguages,
      'has_voice_sample': hasVoiceSample,
      'voice_sample_path': voiceSamplePath,
      'voice_model_trained': voiceModelTrained,
      'voice_quality_score': voiceQualityScore,
      'is_active': isActive,
      'is_online': isOnline,
      'status': status,  // NEW
      'last_seen': lastSeen?.toIso8601String(),  // NEW
      'avatar_url': avatarUrl,
      'bio': bio,
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
    String? languageCode,
    List<String>? supportedLanguages,
    bool? hasVoiceSample,
    String? voiceSamplePath,
    bool? voiceModelTrained,
    int? voiceQualityScore,
    bool? isActive,
    bool? isOnline,
    String? status,
    DateTime? lastSeen,
    String? avatarUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      languageCode: languageCode ?? this.languageCode,
      supportedLanguages: supportedLanguages ?? this.supportedLanguages,
      hasVoiceSample: hasVoiceSample ?? this.hasVoiceSample,
      voiceSamplePath: voiceSamplePath ?? this.voiceSamplePath,
      voiceModelTrained: voiceModelTrained ?? this.voiceModelTrained,
      voiceQualityScore: voiceQualityScore ?? this.voiceQualityScore,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
