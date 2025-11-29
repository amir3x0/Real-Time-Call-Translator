class LiveCaptionData {
  final String id;
  final String participantId;
  final String text;
  final bool fromAi;
  final DateTime createdAt;

  LiveCaptionData({
    required this.id,
    required this.participantId,
    required this.text,
    this.fromAi = true,
    DateTime? createdAtOverride,
  }) : createdAt = createdAtOverride ?? DateTime.now();
}
