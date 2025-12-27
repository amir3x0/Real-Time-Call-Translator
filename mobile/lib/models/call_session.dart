import 'participant.dart';

/// Call status enum matching backend
enum CallStatus {
  pending('PENDING'),
  ringing('RINGING'),
  active('ACTIVE'),
  ended('ENDED'),
  cancelled('CANCELLED');

  final String value;
  const CallStatus(this.value);

  static CallStatus fromString(String value) {
    return CallStatus.values.firstWhere(
      (status) => status.value == value.toUpperCase(),
      orElse: () => CallStatus.pending,
    );
  }
}

/// CallSession model representing an active or historical call.
/// 
/// This is the main model for managing call state, participants,
/// and call lifecycle. It wraps Call + participants in a unified view.
class CallSession {
  final String id;
  final String sessionId;
  final CallStatus status;
  final String initiatorId;
  final List<CallParticipant> participants;
  final int maxParticipants;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  /// Check if call is currently active
  bool get isActive => status == CallStatus.active;

  /// Check if call is pending/ringing
  bool get isPending => status == CallStatus.pending || status == CallStatus.ringing;

  /// Check if call has ended
  bool get hasEnded => status == CallStatus.ended || status == CallStatus.cancelled;

  /// Get number of participants
  int get participantCount => participants.length;

  /// Get connected participants only
  List<CallParticipant> get connectedParticipants =>
      participants.where((p) => p.isConnected).toList();

  /// Get the participant who is currently speaking (if any)
  CallParticipant? get activeSpeaker =>
      participants.cast<CallParticipant?>().firstWhere(
        (p) => p!.isSpeaking,
        orElse: () => null,
      );

  /// Format duration as MM:SS
  String get formattedDuration {
    if (durationSeconds == null) return '--:--';
    final minutes = (durationSeconds! ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds! % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Calculate live duration from startedAt
  Duration get liveDuration {
    if (startedAt == null) return Duration.zero;
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  /// Format live duration as MM:SS
  String get formattedLiveDuration {
    final duration = liveDuration;
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Get all unique languages in the call
  Set<String> get languages {
    final langs = <String>{};
    for (final p in participants) {
      langs.add(p.speakingLanguage);
    }
    return langs;
  }

  /// Check if translation is needed (more than one language)
  bool get needsTranslation => languages.length > 1;

  const CallSession({
    required this.id,
    required this.sessionId,
    required this.status,
    required this.initiatorId,
    required this.participants,
    this.maxParticipants = 4,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
  });

  /// Create CallSession from JSON
  factory CallSession.fromJson(Map<String, dynamic> json) {
    final participantsList = json['participants'] as List<dynamic>?;
    
    return CallSession(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      status: CallStatus.fromString(json['status'] as String? ?? 'PENDING'),
      initiatorId: json['initiator_id'] as String? ?? json['created_by'] as String,
      participants: participantsList != null
          ? participantsList
              .map((p) => CallParticipant.fromJson(p as Map<String, dynamic>))
              .toList()
          : [],
      maxParticipants: json['max_participants'] as int? ?? 4,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int?,
    );
  }

  /// Convert CallSession to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'status': status.value,
      'initiator_id': initiatorId,
      'participants': participants.map((p) => p.toJson()).toList(),
      'max_participants': maxParticipants,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
    };
  }

  /// Create a copy with updated fields
  CallSession copyWith({
    String? id,
    String? sessionId,
    CallStatus? status,
    String? initiatorId,
    List<CallParticipant>? participants,
    int? maxParticipants,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) {
    return CallSession(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      initiatorId: initiatorId ?? this.initiatorId,
      participants: participants ?? this.participants,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  @override
  String toString() => 
      'CallSession(id: $id, status: $status, participants: $participantCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
