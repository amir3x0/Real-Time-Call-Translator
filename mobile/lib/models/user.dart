/// User model matching backend schema
class User {
  final String id;
  final String email;
  final String? phone;
  final String name;
  final String primaryLanguage;
  final List<String> supportedLanguages;
  final bool hasVoiceSample;
  final String? voiceSamplePath;
  final bool voiceModelTrained;
  final int? voiceQualityScore;
  final bool isActive;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? avatarUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.email,
    this.phone,
    required this.name,
    required this.primaryLanguage,
    required this.supportedLanguages,
    this.hasVoiceSample = false,
    this.voiceSamplePath,
    this.voiceModelTrained = false,
    this.voiceQualityScore,
    this.isActive = true,
    this.isOnline = false,
    this.lastSeen,
    this.avatarUrl,
    this.bio,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      phone: json['phone'],
      name: json['name'],
      primaryLanguage: json['primary_language'] ?? 'he',
      supportedLanguages: json['supported_languages'] != null
          ? List<String>.from(json['supported_languages'])
          : ['he'],
      hasVoiceSample: json['has_voice_sample'] ?? false,
      voiceSamplePath: json['voice_sample_path'],
      voiceModelTrained: json['voice_model_trained'] ?? false,
      voiceQualityScore: json['voice_quality_score'],
      isActive: json['is_active'] ?? true,
      isOnline: json['is_online'] ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'])
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
      'email': email,
      'phone': phone,
      'name': name,
      'primary_language': primaryLanguage,
      'supported_languages': supportedLanguages,
      'has_voice_sample': hasVoiceSample,
      'voice_sample_path': voiceSamplePath,
      'voice_model_trained': voiceModelTrained,
      'voice_quality_score': voiceQualityScore,
      'is_active': isActive,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
      'avatar_url': avatarUrl,
      'bio': bio,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  User copyWith({
    String? id,
    String? email,
    String? phone,
    String? name,
    String? primaryLanguage,
    List<String>? supportedLanguages,
    bool? hasVoiceSample,
    String? voiceSamplePath,
    bool? voiceModelTrained,
    int? voiceQualityScore,
    bool? isActive,
    bool? isOnline,
    DateTime? lastSeen,
    String? avatarUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      supportedLanguages: supportedLanguages ?? this.supportedLanguages,
      hasVoiceSample: hasVoiceSample ?? this.hasVoiceSample,
      voiceSamplePath: voiceSamplePath ?? this.voiceSamplePath,
      voiceModelTrained: voiceModelTrained ?? this.voiceModelTrained,
      voiceQualityScore: voiceQualityScore ?? this.voiceQualityScore,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
