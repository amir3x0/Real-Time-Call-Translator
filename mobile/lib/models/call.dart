/// Call status enum matching backend
enum CallStatus {
  pending('PENDING'),
  active('ACTIVE'),
  ended('ENDED'),
  cancelled('CANCELLED');

  final String value;
  const CallStatus(this.value);

  static CallStatus fromString(String value) {
    return CallStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => CallStatus.pending,
    );
  }
}

/// Call model matching backend schema
class Call {
  final String id;
  final String sessionId;
  final CallStatus status;
  final int maxParticipants;
  final int currentParticipants;
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
    this.maxParticipants = 4,
    this.currentParticipants = 0,
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
      id: json['id'],
      sessionId: json['session_id'],
      status: CallStatus.fromString(json['status']),
      maxParticipants: json['max_participants'] ?? 4,
      currentParticipants: json['current_participants'] ?? 0,
      createdBy: json['created_by'],
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      endedAt:
          json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      durationSeconds: json['duration_seconds'],
      createdAt: DateTime.parse(json['created_at']),
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
      'max_participants': maxParticipants,
      'current_participants': currentParticipants,
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
    int? maxParticipants,
    int? currentParticipants,
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
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      createdBy: createdBy ?? this.createdBy,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if call is active
  bool get isActive => status == CallStatus.active;

  /// Check if call is ended
  bool get isEnded =>
      status == CallStatus.ended || status == CallStatus.cancelled;

  /// Get call duration as formatted string
  String get formattedDuration {
    if (durationSeconds == null) return '--:--';
    final minutes = (durationSeconds! ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds! % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
