import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/call_provider.dart';
import '../../widgets/call/circle_control.dart';
import '../../widgets/call/network_indicator.dart';
import '../../widgets/call/participant_grid.dart';

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  late List<double> _amplitudes;
  final double _subtitleOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _amplitudes = List<double>.generate(24, (i) => _randAmp());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  double _randAmp() => 0.2 + Random().nextDouble() * 0.8;

  String _buildLiveSubtitle(CallProvider provider) {
    if (provider.participants.isEmpty) {
      return provider.liveTranscription;
    }
    final speakerId = provider.activeSpeakerId;
    if (speakerId == null) {
      return provider.liveTranscription;
    }
    final participant = provider.participants.firstWhere(
      (p) => p.id == speakerId,
      orElse: () => provider.participants.first,
    );
    return '${participant.displayName}: ${provider.liveTranscription}';
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E16),
      body: Stack(
        children: [
          // Futuristic gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF12122A),
                    Color(0xFF1A1A3A),
                    Color(0xFF2B2B5C)
                  ],
                ),
              ),
            ),
          ),

          // Participants Grid with speaking glow + waveform overlay
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 56),
                Expanded(
                  child: ParticipantGrid(
                    participants: callProvider.participants,
                    waveAnimation: _waveController,
                    waveAmplitudes: _amplitudes,
                    captionBubbles: callProvider.captionBubbles,
                  ),
                ),
              ],
            ),
          ),

          // Glassmorphism live transcription at bottom
          Positioned(
            left: 12,
            right: 12,
            bottom: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _subtitleOpacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      _buildLiveSubtitle(callProvider),
                      key: const Key('live-subtitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top bar with timer + network indicator
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '00:45',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    NetworkIndicator(participants: callProvider.participants),
                  ],
                ),
              ),
            ),
          ),

          // Controls bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF121226),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CircleControl(
                      icon: Icons.mic,
                      color: Colors.white,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        callProvider.toggleMute();
                      },
                    ),
                    CircleControl(
                      icon: Icons.volume_up,
                      color: Colors.white,
                      onTap: () => HapticFeedback.lightImpact(),
                    ),
                    CircleControl(
                      icon: Icons.call_end,
                      color: Colors.redAccent,
                      requireLongPress: true,
                      onLongPress: () {
                        HapticFeedback.heavyImpact();
                        callProvider.endCall();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
