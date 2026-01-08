import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/call_provider.dart';
import '../../widgets/call/circle_control.dart';
import '../../widgets/call/network_indicator.dart';
import '../../widgets/call/participant_grid.dart';
import '../../widgets/call/transcription_panel.dart';

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
  bool _isExiting = false;

  // Call timer
  Timer? _callTimer;
  int _callDurationSeconds = 0;

  // Store provider reference for safe disposal
  CallProvider? _callProviderRef;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _amplitudes = List<double>.generate(24, (i) => _randAmp());

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
    _waveController.dispose();
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

  double _randAmp() => 0.2 + Random().nextDouble() * 0.8;

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

          // Live transcription bubble (text being transcribed in real-time)
          if (callProvider.liveTranscription.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 220,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: 1.0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withAlpha(100)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          callProvider.liveTranscription,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Transcription panel with original + translated text
          Positioned(
            left: 12,
            right: 12,
            bottom: 96,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _subtitleOpacity,
              child: TranscriptionPanel(
                key: const Key('transcription-panel'),
                entries: callProvider.transcriptionHistory,
                maxVisible: 3,
                showOriginal: true,
                showTranslated: true,
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
                    Text(
                      _formatDuration(_callDurationSeconds),
                      style: const TextStyle(color: Colors.white, fontSize: 18),
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
                      icon: callProvider.isMuted ? Icons.mic_off : Icons.mic,
                      color: callProvider.isMuted ? Colors.grey : Colors.white,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        callProvider.toggleMute();
                      },
                    ),
                    CircleControl(
                      icon: callProvider.isSpeakerOn
                          ? Icons.volume_up
                          : Icons.phone_in_talk,
                      color: callProvider.isSpeakerOn
                          ? Colors.blueAccent
                          : Colors.white,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        callProvider.toggleSpeaker();
                      },
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
