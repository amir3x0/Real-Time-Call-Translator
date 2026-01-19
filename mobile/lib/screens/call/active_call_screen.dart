import 'dart:async';

import 'dart:ui'; // Required for ImageFilter

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/call_provider.dart';
import '../../widgets/call/network_indicator.dart';
import '../../widgets/call/participant_grid.dart';
import '../../widgets/call/chat_transcription_view.dart';
import '../../config/app_theme.dart';

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen>
    with SingleTickerProviderStateMixin {
  bool _isExiting = false;

  // Call timer
  Timer? _callTimer;
  int _callDurationSeconds = 0;

  // Store provider reference for safe disposal
  CallProvider? _callProviderRef;

  @override
  void initState() {
    super.initState();
    // Start call duration timer
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
        });
      }
    });

    // Listen for remote call ended
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      callProvider.onCallEnded = _onCallEndedRemotely;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save reference while context is still valid (for safe disposal)
    _callProviderRef ??= Provider.of<CallProvider>(context, listen: false);
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    // Cancel call timer
    _callTimer?.cancel();
    // Clear callback using saved reference (context is invalid in dispose)
    _callProviderRef?.onCallEnded = null;
    super.dispose();
  }

  /// Called when the call ends remotely (e.g., other participant left)
  void _onCallEndedRemotely(String reason) {
    if (_isExiting || !mounted) return;
    _isExiting = true;

    debugPrint('[ActiveCallScreen] Call ended remotely: $reason');

    // Navigate back to home without showing a message
    Navigator.of(context).pop();
  }

  /// Format seconds into MM:SS or HH:MM:SS
  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Dynamic Background
          _buildDynamicBackground(callProvider),

          // 2. Main Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Bar (Timer + Network)
                _buildTopBar(callProvider),

                // Spacer
                const Spacer(flex: 1),

                // Transcription Area - Chat-style UI with integrated interim captions
                Expanded(
                  flex: 10,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ChatTranscriptionView(
                      key: const Key('chat-transcription-view'),
                      entries: callProvider.transcriptionHistoryChronological,
                      currentUserId: callProvider.currentUserId ?? '',
                      interimCaptions: callProvider.interimCaptions,
                      maxMessages: 20,
                    ),
                  ),
                ),

                // Spacer
                const Spacer(flex: 2),

                // Participant Strip (Floating Bubbles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ParticipantGrid(
                    participants: callProvider.participants,
                  ),
                ),

                // Controls Capsule
                _buildControlCapsule(callProvider, bottomPadding),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicBackground(CallProvider provider) {
    final gradientColors = AppTheme.getScreenGradientColors(context);

    return AnimatedContainer(
      duration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
    );
  }

  // Reused buildTopBar...
  Widget _buildTopBar(CallProvider callProvider) {
    final isDark = AppTheme.isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Timer Capsule
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppTheme.lightDivider,
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                          )
                        ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.successGreen,
                        boxShadow: [
                          BoxShadow(color: AppTheme.successGreen, blurRadius: 4)
                        ],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatDuration(_callDurationSeconds),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppTheme.getTextColor(context),
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Network Indicator
          NetworkIndicator(participants: callProvider.participants),
        ],
      ),
    );
  }

  Widget _buildControlCapsule(CallProvider callProvider, double bottomPadding) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding + 24, left: 32, right: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: callProvider.isMuted ? Icons.mic_off : Icons.mic,
                  isActive: !callProvider.isMuted,
                  activeColor: Colors.white,
                  inactiveColor: AppTheme.errorRed,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    callProvider.toggleMute();
                  },
                ),
                _buildControlButton(
                    icon: Icons.call_end,
                    isActive: true,
                    activeColor: Colors.white,
                    bgColor: AppTheme.errorRed,
                    size: 56, // Larger end call button
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      callProvider.endCall();
                      Navigator.pop(context);
                    }),
                _buildControlButton(
                  icon: callProvider.isSpeakerOn
                      ? Icons.volume_up
                      : Icons.phone_in_talk,
                  isActive: callProvider.isSpeakerOn,
                  activeColor: AppTheme.primaryElectricBlue,
                  inactiveColor: Colors.white.withValues(alpha: 0.7),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    callProvider.toggleSpeaker();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    Color activeColor = Colors.white,
    Color inactiveColor = Colors.grey,
    Color? bgColor,
    double size = 48,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor ??
              (isActive
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: bgColor != null
              ? Colors.white
              : (isActive ? activeColor : inactiveColor),
          size: size * 0.5,
        ),
      ),
    );
  }
}
