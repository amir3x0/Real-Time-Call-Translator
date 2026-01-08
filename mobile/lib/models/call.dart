/// Call status enum matching backend
enum CallStatus {
  initiating('initiating'),
  idle('idle'),
  ringing('ringing'),
  ongoing('ongoing'),
  ended('ended'),
  missed('missed');

  final String value;
  const CallStatus(this.value);

  static CallStatus fromString(String value) {
    final normalized = value.toLowerCase();
    // Map legacy 'active' to 'ongoing'
    if (normalized == 'active') return CallStatus.ongoing;

    return CallStatus.values.firstWhere(
      (status) => status.value == normalized,
      orElse: () => CallStatus.initiating,
    );
  }
}

/// Call model matching backend schema
class Call {
  final String id;
  final String sessionId;
  final CallStatus status;
  final String? callerUserId;
  final String
      callLanguage; // The language of the call (set by caller) - IMMUTABLE
  final bool isActive;
  final int maxParticipants;
  final int currentParticipants;
  final int participantCount;
  final String createdBy;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Call({
    required this.id,
    required this.sessionId,
    required this.status,
    this.callerUserId,
    this.callLanguage = 'he',
    this.isActive = true,
    this.maxParticipants = 4,
    this.currentParticipants = 0,
    this.participantCount = 1,
    required this.createdBy,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create Call from JSON
  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      id: json['id'] ?? json['call_id'],
      sessionId: json['session_id'],
      status: CallStatus.fromString(json['status'] ?? 'initiating'),
      callerUserId: json['caller_user_id'],
      callLanguage: json['call_language'] ?? 'he',
      isActive: json['is_active'] ?? true,
      maxParticipants: json['max_participants'] ?? 4,
      currentParticipants: json['current_participants'] ?? 0,
      participantCount: json['participant_count'] ?? 1,
      createdBy: json['created_by'] ?? json['caller_user_id'] ?? '',
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      endedAt:
          json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      durationSeconds: json['duration_seconds'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  /// Convert Call to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'status': status.value,
      'caller_user_id': callerUserId,
      'call_language': callLanguage,
      'is_active': isActive,
      'max_participants': maxParticipants,
      'current_participants': currentParticipants,
      'participant_count': participantCount,
      'created_by': createdBy,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Call copyWith({
    String? id,
    String? sessionId,
    CallStatus? status,
    String? callerUserId,
    String? callLanguage,
    bool? isActive,
    int? maxParticipants,
    int? currentParticipants,
    int? participantCount,
    String? createdBy,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Call(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      callerUserId: callerUserId ?? this.callerUserId,
      callLanguage: callLanguage ?? this.callLanguage,
      isActive: isActive ?? this.isActive,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      participantCount: participantCount ?? this.participantCount,
      createdBy: createdBy ?? this.createdBy,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if call is currently active (ongoing or initiating)
  bool get isCallActive =>
      isActive &&
      (status == CallStatus.ongoing ||
          status == CallStatus.initiating ||
          status == CallStatus.ringing);

  /// Check if call is ended
  bool get isEnded => status == CallStatus.ended || status == CallStatus.missed;

  /// Get call duration as formatted string
  String get formattedDuration {
    if (durationSeconds == null) return '--:--';
    final minutes = (durationSeconds! ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds! % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Get status display string
  String get statusDisplay {
    switch (status) {
      case CallStatus.initiating:
        return 'Connecting...';
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.ongoing:
        return 'In Call';
      case CallStatus.ended:
        return 'Ended';
      case CallStatus.missed:
        return 'Missed';

      case CallStatus.idle:
        return 'Idle';
    }
  }
}
