import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/call_provider.dart';
import '../../providers/lobby_provider.dart';
import '../../models/call.dart';
import '../../models/participant.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _countdownTimer;
  int _remainingSeconds = 45;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        // Timeout handling - reject via lobby provider
        final lobbyProvider =
            Provider.of<LobbyProvider>(context, listen: false);
        lobbyProvider.rejectIncomingCall();
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  String _getLanguageName(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return 'English';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      case 'ru':
        return 'Russian';
      case 'zh':
        return 'Chinese';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      default:
        return code.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobbyProvider = Provider.of<LobbyProvider>(context);
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final incomingCall = lobbyProvider.incomingCall;

    // Only pop if incoming call is null AND we are not in active state (accepted)
    if (incomingCall == null && callProvider.status != CallStatus.active) {
      // No incoming call and not active, navigate back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Ensure we don't pop if we're already navigating away or unmounted
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (incomingCall == null && callProvider.status == CallStatus.active) {
      // Call accepted, waiting for navigation or already navigating
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Safety check if we somehow got here with null incomingCall but not active
    if (incomingCall == null) return const SizedBox();

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E16),
      body: Stack(
        children: [
          // Gradient background
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
          // Content
          SafeArea(
            child: Column(
              children: [
                // Timer
                Padding(
                  padding: const EdgeInsets.only(top: 40, bottom: 20),
                  child: Text(
                    '$_remainingSeconds',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Avatar/Icon
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar circle
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF4A90E2),
                                Color(0xFF357ABD),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Caller name
                        Text(
                          lobbyProvider.incomingCallerName ?? 'Incoming Call',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Call language
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getLanguageName(incomingCall.callLanguage),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline button
                      _ActionButton(
                        icon: Icons.call_end,
                        color: Colors.red,
                        onPressed: () {
                          _countdownTimer?.cancel();
                          lobbyProvider.rejectIncomingCall();
                          Navigator.of(context).pop();
                        },
                      ),
                      // Accept button
                      _ActionButton(
                        icon: Icons.call,
                        color: Colors.green,
                        onPressed: () async {
                          _countdownTimer?.cancel();
                          // 1. Accept in Lobby -> Get Session Data
                          final callData =
                              await lobbyProvider.acceptIncomingCall();

                          if (callData != null &&
                              callData['session_id'] != null) {
                            final sessionId = callData['session_id'];
                            final participantsData =
                                callData['participants'] as List<dynamic>? ??
                                    [];

                            final participants = participantsData
                                .map((p) => CallParticipant.fromJson(
                                    Map<String, dynamic>.from(p)))
                                .toList();

                            // 2. Join Session in CallProvider
                            await callProvider.joinCall(
                                sessionId, participants);

                            if (context.mounted) {
                              Navigator.of(context)
                                  .pushReplacementNamed('/call/active');
                            }
                          } else {
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(
            icon,
            size: 40,
            color: Colors.white,
          ),
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(
        duration: 1000.ms,
        begin: const Offset(1, 1),
        end: const Offset(1.1, 1.1));
  }
}
