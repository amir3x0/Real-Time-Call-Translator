import 'package:flutter/material.dart';

import '../../models/participant.dart';
import 'participant_card.dart';

/// Responsive participant grid that scales from 1 to 4 people and
/// overlays floating captions for the active speaker.
class ParticipantGrid extends StatelessWidget {
  const ParticipantGrid({
    super.key,
    required this.participants,
  });

  final List<CallParticipant> participants;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return _buildEmptyState();
    }

    return SizedBox(
      height: 120, // Fixed height for the strip
      child: Center(
        child: ListView.separated(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: participants.length,
          separatorBuilder: (_, __) => const SizedBox(width: 24),
          itemBuilder: (context, index) {
            final participant = participants[index];
            return Center(
              child: _ParticipantTile(
                participant: participant,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox
        .shrink(); // No empty state needed in this layout, it just hides
  }

  // Helper methods like _crossAxisCount are no longer needed
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
  });

  final CallParticipant participant;

  @override
  Widget build(BuildContext context) {
    final isSpeaking = participant.isSpeaking && !participant.isMuted;

    return AnimatedScale(
      scale: isSpeaking ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: ParticipantCard(
        participant: participant,
        mockName: participant.displayName,
        isSpeaking: isSpeaking,
        isCompact: true, // Use the new compact mode
      ),
    );
  }
}
