import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../providers/call_provider.dart';
import '../../widgets/call/participant_card.dart';
import '../../widgets/waveform_painter.dart';
import '../../widgets/call/circle_control.dart';
import '../../widgets/call/network_indicator.dart';

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  late List<double> _amplitudes;
  final int _speakingIndex = 0;
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
                  colors: [Color(0xFF12122A), Color(0xFF1A1A3A), Color(0xFF2B2B5C)],
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
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: callProvider.participants.length,
                    itemBuilder: (context, index) {
                      final p = callProvider.participants[index];
                      final isSpeaking = index == _speakingIndex && !p.isMuted;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          boxShadow: isSpeaking
                              ? [
                                  BoxShadow(
                                    color: Colors.deepPurpleAccent.withAlpha(153),
                                    blurRadius: 24,
                                    spreadRadius: 6,
                                  ),
                                ]
                              : [],
                        ),
                        child: Stack(
                          children: [
                            ParticipantCard(
                              participant: p,
                              mockName: index == 0 ? 'Daniel' : 'Guest',
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: _waveController,
                                  builder: (_, __) => CustomPaint(
                                    painter: WaveformPainter(
                                      amplitudes: _amplitudes
                                          .map((a) => a * (isSpeaking ? 1.0 : 0.2))
                                          .toList(),
                                      progress: _waveController.value,
                                      color: isSpeaking
                                          ? Colors.purpleAccent.withAlpha(89)
                                          : Colors.blueGrey.withAlpha(31),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      callProvider.liveTranscription,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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