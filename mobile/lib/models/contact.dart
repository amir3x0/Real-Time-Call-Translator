import 'user.dart';

/// Contact model matching backend schema
///
/// Purpose: Control who each user can call (authorization layer)
/// Business Logic:
/// - Before initiating a call: Verify Contact exists
/// - If contact doesn't exist: Reject the call initiation
class Contact {
  final String id;
  final String userId;
  final String contactUserId;
  final String? contactName;
  final bool isBlocked;
  final bool isFavorite;
  final String status; // 'pending', 'accepted'
  final DateTime addedAt;
  final DateTime? createdAt;
  
  // Joined user information (populated when fetching contacts)
  final String? fullName;
  final String? phone;
  final String? primaryLanguage;
  final bool? isOnline;

  Contact({
    required this.id,
    required this.userId,
    required this.contactUserId,
    this.contactName,
    this.isBlocked = false,
    this.isFavorite = false,
    this.status = 'accepted',
    required this.addedAt,
    this.createdAt,
    this.fullName,
    this.phone,
    this.primaryLanguage,
    this.isOnline,
  });
  
  /// Get contact user as a User object for compatibility
  User get contactUser => User(
    id: contactUserId,
    phone: phone ?? '',
    fullName: fullName ?? displayName,
    primaryLanguage: primaryLanguage ?? 'he',
    isOnline: isOnline ?? false,
    createdAt: addedAt,
  );

  /// Create Contact from JSON (API response)
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] ?? json['contact_id'],
      userId: json['user_id'] ?? '',
      contactUserId: json['contact_user_id'] ?? json['user_id'],
      contactName: json['contact_name'],
      isBlocked: json['is_blocked'] ?? false,
      isFavorite: json['is_favorite'] ?? false,
      status: json['status'] ?? 'accepted',
      addedAt: json['added_at'] != null 
          ? DateTime.parse(json['added_at'])
          : DateTime.now(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : null,
      // Joined user info
      fullName: json['full_name'],
      phone: json['phone'],
      primaryLanguage: json['primary_language'],
      isOnline: json['is_online'],
    );
  }

  /// Convert Contact to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'contact_user_id': contactUserId,
      'contact_name': contactName,
      'is_blocked': isBlocked,
      'is_favorite': isFavorite,
      'added_at': addedAt.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'full_name': fullName,
      'phone': phone,
      'primary_language': primaryLanguage,
      'is_online': isOnline,
    };
  }

  /// Create a copy with updated fields
  Contact copyWith({
    String? id,
    String? userId,
    String? contactUserId,
    String? contactName,
    bool? isBlocked,
    bool? isFavorite,
    DateTime? addedAt,
    DateTime? createdAt,
    String? fullName,
    String? phone,
    String? primaryLanguage,
    bool? isOnline,
  }) {
    return Contact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contactUserId: contactUserId ?? this.contactUserId,
      contactName: contactName ?? this.contactName,
      isBlocked: isBlocked ?? this.isBlocked,
      isFavorite: isFavorite ?? this.isFavorite,
      addedAt: addedAt ?? this.addedAt,
      createdAt: createdAt ?? this.createdAt,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  /// Get display name (custom name or full name)
  String get displayName => contactName ?? fullName ?? 'Unknown';
  
  /// Get language code (alias for primaryLanguage for compatibility)
  String get language => primaryLanguage ?? 'he';
  
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
        return primaryLanguage ?? 'Unknown';
    }
  }
  
  /// Get language name (alias for languageDisplay)
  String get languageName => languageDisplay;
  
  /// Get language flag emoji
  String get languageFlag {
    switch (primaryLanguage) {
      case 'he':
        return '🇮🇱';
      case 'en':
        return '🇺🇸';
      case 'ru':
        return '🇷🇺';
      default:
        return '🌐';
    }
  }
  
  /// Get avatar letter (first letter of display name)
  String get avatarLetter {
    final name = displayName;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
  
  /// Get status display
  String get statusDisplay => isOnline == true ? 'Online' : 'Offline';
  
  /// Check if contact is available for calling
  bool get isAvailable => !isBlocked && isOnline == true;
}
