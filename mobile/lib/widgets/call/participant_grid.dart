import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/live_caption.dart';
import '../../models/participant.dart';
import '../waveform_painter.dart';
import 'live_caption_bubble.dart';
import 'participant_card.dart';

/// Responsive participant grid that scales from 1 to 4 people and
/// overlays floating captions for the active speaker.
class ParticipantGrid extends StatelessWidget {
  const ParticipantGrid({
    super.key,
    required this.participants,
    this.waveAnimation,
    this.waveAmplitudes,
    this.captionBubbles = const [],
  });

  final List<CallParticipant> participants;
  final Animation<double>? waveAnimation;
  final List<double>? waveAmplitudes;
  final List<LiveCaptionData> captionBubbles;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return _buildEmptyState();
    }

    final crossAxisCount = _crossAxisCount(participants.length);
    final aspectRatio = participants.length <= 1 ? 0.82 : 0.9;

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: aspectRatio,
              ),
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final participant = participants[index];
                return _ParticipantTile(
                  participant: participant,
                  waveAnimation: waveAnimation,
                  waveAmplitudes: waveAmplitudes,
                );
              },
            ),
          ),
          ...captionBubbles.map((bubble) {
            final idx = participants.indexWhere((p) => p.id == bubble.participantId);
            if (idx == -1) return const SizedBox.shrink();
            return IgnorePointer(
              child: LiveCaptionBubble(
                key: ValueKey('bubble-${bubble.id}'),
                data: bubble,
                alignment: _bubbleAlignment(idx, participants.length),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: AppTheme.secondaryText.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Waiting for participants…',
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.secondaryText),
          ),
        ],
      ),
    );
  }

  int _crossAxisCount(int length) {
    if (length <= 1) return 1;
    if (length == 2) return 1;
    return 2;
  }

  static Alignment _bubbleAlignment(int index, int total) {
    if (total == 1) return Alignment.bottomCenter;
    if (total == 2) {
      return index == 0 ? Alignment.topCenter : Alignment.bottomCenter;
    }
    if (total == 3) {
      return [Alignment.topLeft, Alignment.topRight, Alignment.bottomCenter][index];
    }
    const positions = [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ];
    return positions[index.clamp(0, positions.length - 1)];
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    this.waveAnimation,
    this.waveAmplitudes,
  });

  final CallParticipant participant;
  final Animation<double>? waveAnimation;
  final List<double>? waveAmplitudes;

  @override
  Widget build(BuildContext context) {
    final isSpeaking = participant.isSpeaking && !participant.isMuted;
    final sourceAmplitudes = waveAmplitudes ?? List<double>.filled(24, 0.5);
    final amplitudes = sourceAmplitudes
      .map((value) => value * (isSpeaking ? 1.0 : 0.25))
      .toList(growable: false);

    final animation = waveAnimation ?? const AlwaysStoppedAnimation<double>(0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      decoration: BoxDecoration(
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.45),
                  blurRadius: 28,
                  spreadRadius: 8,
                ),
              ]
            : [],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ParticipantCard(
            participant: participant,
            mockName: participant.displayName,
            isSpeaking: isSpeaking,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: animation,
                builder: (_, __) => CustomPaint(
                  painter: WaveformPainter(
                    amplitudes: amplitudes,
                    progress: animation.value,
                    color: isSpeaking
                        ? Colors.purpleAccent.withValues(alpha: 0.35)
                        : Colors.blueGrey.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
