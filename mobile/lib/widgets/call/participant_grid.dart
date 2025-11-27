import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/participant.dart';
import '../../config/app_theme.dart';
import 'participant_card.dart';

/// Dynamic participant grid that adapts to the number of participants
/// - 1 participant: Full screen
/// - 2 participants: Split screen (vertical)
/// - 3-4 participants: 2x2 Grid
class ParticipantGrid extends StatelessWidget {
  final List<CallParticipant> participants;
  final int? activeSpeakerIndex;

  const ParticipantGrid({
    super.key,
    required this.participants,
    this.activeSpeakerIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return _buildEmptyState();
    }

    if (participants.length == 1) {
      return _buildFullScreen(participants[0], 0);
    }

    if (participants.length == 2) {
      return _buildSplitScreen();
    }

    return _buildGridView();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: AppTheme.secondaryText.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Waiting for participants...',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreen(CallParticipant participant, int index) {
    final isSpeaking = activeSpeakerIndex == index && !participant.isMuted;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        boxShadow: isSpeaking
            ? AppTheme.glowShadow(AppTheme.secondaryPurple)
            : [],
      ),
      child: ParticipantCard(
        participant: participant,
        mockName: _getMockName(index),
        isFullScreen: true,
        isSpeaking: isSpeaking,
      ),
    ).animate()
      .fadeIn(duration: 400.ms)
      .scale(delay: 100.ms, duration: 300.ms);
  }

  Widget _buildSplitScreen() {
    return Column(
      children: List.generate(2, (index) {
        if (index >= participants.length) return const SizedBox.shrink();
        
        final participant = participants[index];
        final isSpeaking = activeSpeakerIndex == index && !participant.isMuted;
        
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 12 : 6,
              bottom: index == 1 ? 12 : 6,
              left: 12,
              right: 12,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: AppTheme.borderRadiusLarge,
                boxShadow: isSpeaking
                    ? AppTheme.glowShadow(AppTheme.secondaryPurple)
                    : [],
              ),
              child: ParticipantCard(
                participant: participant,
                mockName: _getMockName(index),
                isSpeaking: isSpeaking,
              ),
            ).animate()
              .fadeIn(delay: (index * 100).ms, duration: 400.ms)
              .slideY(
                begin: index == 0 ? -0.2 : 0.2,
                end: 0,
                duration: 400.ms,
              ),
          ),
        );
      }),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final isSpeaking = activeSpeakerIndex == index && !participant.isMuted;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: AppTheme.borderRadiusLarge,
            boxShadow: isSpeaking
                ? AppTheme.glowShadow(AppTheme.secondaryPurple)
                : [],
          ),
          child: ParticipantCard(
            participant: participant,
            mockName: _getMockName(index),
            isSpeaking: isSpeaking,
          ),
        ).animate()
          .fadeIn(delay: (index * 100).ms, duration: 400.ms)
          .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1, 1),
            duration: 400.ms,
          );
      },
    );
  }

  String _getMockName(int index) {
    const names = ['Daniel', 'Sarah', 'Alex', 'Emma'];
    return index < names.length ? names[index] : 'User ${index + 1}';
  }
}
