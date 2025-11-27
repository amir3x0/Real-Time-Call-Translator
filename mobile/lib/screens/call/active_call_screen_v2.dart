import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/call_provider.dart';
import '../../config/app_theme.dart';
import '../../widgets/call/participant_grid.dart';
import '../../widgets/call/floating_subtitle.dart';
import '../../widgets/call/circle_control.dart';
import '../../widgets/call/network_indicator.dart';

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerController;
  int _callDuration = 0;
  int _activeSpeakerIndex = 0;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    
    // Simulate call timer
    _startCallTimer();
    
    // Simulate active speaker rotation
    _rotateActiveSpeaker();
  }

  void _startCallTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _callDuration++);
        return true;
      }
      return false;
    });
  }

  void _rotateActiveSpeaker() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        final callProvider = Provider.of<CallProvider>(context, listen: false);
        setState(() {
          _activeSpeakerIndex = (_activeSpeakerIndex + 1) % callProvider.participants.length;
        });
        return true;
      }
      return false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
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
                    Color(0xFF2B2B5C),
                  ],
                ),
              ),
            ),
          ),

          // Floating orbs for depth
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondaryPurple.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(duration: 6.seconds),
          ),

          // Participants Grid
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Expanded(
                  child: ParticipantGrid(
                    participants: callProvider.participants,
                    activeSpeakerIndex: _activeSpeakerIndex,
                  ),
                ),
              ],
            ),
          ),

          // Floating Subtitle Bubbles
          SubtitleContainer(
            subtitles: [
              SubtitleData(
                text: callProvider.liveTranscription,
                speakerName: 'Daniel',
                accentColor: AppTheme.secondaryPurple,
              ),
            ],
          ),

          // Top bar with timer + network indicator
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Call Duration
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.errorRed,
                                boxShadow: AppTheme.glowShadow(AppTheme.errorRed),
                              ),
                            ).animate(onPlay: (controller) => controller.repeat())
                              .fadeOut(duration: 1.seconds)
                              .then()
                              .fadeIn(duration: 1.seconds),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(_callDuration),
                              style: AppTheme.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        
                        // Network Indicator
                        NetworkIndicator(participants: callProvider.participants),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ).animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: -0.5, end: 0, duration: 400.ms),

          // Controls bar (Glassmorphism)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mute Button
                        CircleControl(
                          icon: callProvider.participants.isNotEmpty && callProvider.participants[0].isMuted
                              ? Icons.mic_off
                              : Icons.mic,
                          color: Colors.white,
                          backgroundColor: AppTheme.darkCard,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            callProvider.toggleMute();
                          },
                        ).animate()
                          .fadeIn(delay: 100.ms, duration: 300.ms)
                          .scale(delay: 100.ms, duration: 300.ms),
                        
                        // Speaker Button
                        CircleControl(
                          icon: Icons.volume_up,
                          color: Colors.white,
                          backgroundColor: AppTheme.darkCard,
                          onTap: () => HapticFeedback.lightImpact(),
                        ).animate()
                          .fadeIn(delay: 200.ms, duration: 300.ms)
                          .scale(delay: 200.ms, duration: 300.ms),
                        
                        // End Call Button (Pill-shaped, larger)
                        _buildEndCallButton(callProvider)
                          .animate()
                          .fadeIn(delay: 300.ms, duration: 300.ms)
                          .scale(delay: 300.ms, duration: 300.ms),
                        
                        // Add Participant Button
                        CircleControl(
                          icon: Icons.person_add,
                          color: Colors.white,
                          backgroundColor: AppTheme.darkCard,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            // TODO: Implement add participant
                          },
                        ).animate()
                          .fadeIn(delay: 400.ms, duration: 300.ms)
                          .scale(delay: 400.ms, duration: 300.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ).animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.5, end: 0, duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildEndCallButton(CallProvider callProvider) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _showEndCallConfirmation(callProvider);
      },
      child: Container(
        width: 140,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.errorRed,
              AppTheme.errorRed.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.glowShadow(AppTheme.errorRed),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.call_end, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text(
              'End',
              style: AppTheme.labelLarge.copyWith(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _showEndCallConfirmation(CallProvider callProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.borderRadiusLarge,
        ),
        title: Text(
          'End Call?',
          style: AppTheme.titleLarge,
        ),
        content: Text(
          'Are you sure you want to end this call?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.secondaryText,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              callProvider.endCall();
              Navigator.pop(context);
            },
            child: Text(
              'End Call',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
