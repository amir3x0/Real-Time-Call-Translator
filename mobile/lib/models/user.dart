/// Voice clone quality for the user
enum UserVoiceCloneQuality {
  excellent('excellent'),
  good('good'),
  fair('fair'),
  fallback('fallback');

  final String value;
  const UserVoiceCloneQuality(this.value);

  static UserVoiceCloneQuality fromString(String? value) {
    if (value == null) return UserVoiceCloneQuality.fallback;
    return UserVoiceCloneQuality.values.firstWhere(
      (q) => q.value == value.toLowerCase(),
      orElse: () => UserVoiceCloneQuality.fallback,
    );
  }
}

/// User model matching backend schema
class User {
  final String id;
  final String? email;
  final String phone;
  final String? phoneNumber;
  final String fullName;
  
  /// Primary language (determines call language when user initiates) - IMMUTABLE
  final String primaryLanguage;
  
  /// User's actively selected language (can change)
  final String? languageCode;
  
  final List<String> supportedLanguages;
  
  // Voice cloning attributes
  final bool hasVoiceSample;
  final String? voiceSamplePath;
  final bool voiceModelTrained;
  final int? voiceQualityScore;
  final String? voiceModelId;
  final UserVoiceCloneQuality voiceCloneQuality;
  
  // Status
  final bool isActive;
  final bool isOnline;
  final String status;  // 'online' or 'offline'
  final DateTime? lastSeen;
  
  // Profile
  final String? avatarUrl;
  final String? bio;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    this.email,
    required this.phone,
    this.phoneNumber,
    required this.fullName,
    required this.primaryLanguage,
    this.languageCode,
    required this.supportedLanguages,
    this.hasVoiceSample = false,
    this.voiceSamplePath,
    this.voiceModelTrained = false,
    this.voiceQualityScore,
    this.voiceModelId,
    this.voiceCloneQuality = UserVoiceCloneQuality.fallback,
    this.isActive = true,
    this.isOnline = false,
    this.status = 'offline',
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
      email: json['email'] as String?,
      phone: (json['phone'] ?? json['phone_number'] ?? '') as String,
      phoneNumber: json['phone_number'] as String?,
      fullName: json['full_name'] as String,
      primaryLanguage: json['primary_language'] as String,
      languageCode: json['language_code'] as String?,
      supportedLanguages: json['supported_languages'] != null
          ? List<String>.from(json['supported_languages'])
          : ['he'],
      hasVoiceSample: json['has_voice_sample'] as bool? ?? false,
      voiceSamplePath: json['voice_sample_path'],
      voiceModelTrained: json['voice_model_trained'] ?? false,
      voiceQualityScore: json['voice_quality_score'],
      voiceModelId: json['voice_model_id'],
      voiceCloneQuality: UserVoiceCloneQuality.fromString(json['voice_clone_quality']),
      isActive: json['is_active'] ?? true,
      isOnline: json['is_online'] ?? false,
      status: json['status'] as String? ?? 'offline',
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
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
      'email': email,
      'phone': phone,
      'phone_number': phoneNumber ?? phone,
      'full_name': fullName,
      'primary_language': primaryLanguage,
      'language_code': languageCode,
      'supported_languages': supportedLanguages,
      'has_voice_sample': hasVoiceSample,
      'voice_sample_path': voiceSamplePath,
      'voice_model_trained': voiceModelTrained,
      'voice_quality_score': voiceQualityScore,
      'voice_model_id': voiceModelId,
      'voice_clone_quality': voiceCloneQuality.value,
      'is_active': isActive,
      'is_online': isOnline,
      'status': status,
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
    String? phoneNumber,
    String? fullName,
    String? primaryLanguage,
    String? languageCode,
    List<String>? supportedLanguages,
    bool? hasVoiceSample,
    String? voiceSamplePath,
    bool? voiceModelTrained,
    int? voiceQualityScore,
    String? voiceModelId,
    UserVoiceCloneQuality? voiceCloneQuality,
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
      email: email ?? this.email,
      phone: phone ?? this.phone,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullName: fullName ?? this.fullName,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      languageCode: languageCode ?? this.languageCode,
      supportedLanguages: supportedLanguages ?? this.supportedLanguages,
      hasVoiceSample: hasVoiceSample ?? this.hasVoiceSample,
      voiceSamplePath: voiceSamplePath ?? this.voiceSamplePath,
      voiceModelTrained: voiceModelTrained ?? this.voiceModelTrained,
      voiceQualityScore: voiceQualityScore ?? this.voiceQualityScore,
      voiceModelId: voiceModelId ?? this.voiceModelId,
      voiceCloneQuality: voiceCloneQuality ?? this.voiceCloneQuality,
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
  
  /// Get display phone number
  String get displayPhone => phoneNumber ?? phone;
  
  /// Check if user can use voice cloning
  bool get canUseVoiceClone => 
      voiceModelTrained && 
      voiceQualityScore != null && 
      voiceQualityScore! > 60;
  
  /// Check if voice quality is good enough for cloning
  bool get hasGoodVoiceQuality => 
      voiceQualityScore != null && voiceQualityScore! > 80;
  
  /// Get language display name
  String get languageDisplay {
    switch (primaryLanguage) {
      case 'he':
        return 'Hebrew';
      case 'en':
        return 'English';
      case 'ru':
        return 'Russian';
      default:
        return primaryLanguage;
    }
  }
  
  /// Get voice clone quality display
  String get voiceCloneQualityDisplay {
    switch (voiceCloneQuality) {
      case UserVoiceCloneQuality.excellent:
        return 'Excellent';
      case UserVoiceCloneQuality.good:
        return 'Good';
      case UserVoiceCloneQuality.fair:
        return 'Fair';
      case UserVoiceCloneQuality.fallback:
        return 'Standard TTS';
    }
  }
}
