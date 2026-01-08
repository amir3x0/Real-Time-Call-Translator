import 'dart:async';
import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/call_provider.dart';
import '../../providers/lobby_provider.dart';
import '../../models/call.dart';
import '../../models/participant.dart';
import '../../utils/language_utils.dart';

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

  @override
  Widget build(BuildContext context) {
    final lobbyProvider = Provider.of<LobbyProvider>(context);
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final incomingCall = lobbyProvider.incomingCall;

    // Only pop if incoming call is null AND we are not in active state (accepted)
    if (incomingCall == null && callProvider.status != CallStatus.ongoing) {
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

    if (incomingCall == null && callProvider.status == CallStatus.ongoing) {
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                LanguageUtils.getFlag(
                                    incomingCall.callLanguage),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                LanguageUtils.getEnglishName(
                                    incomingCall.callLanguage),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
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

                          if (!context.mounted) return;

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

                            final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false);
                            final currentUser = authProvider.currentUser;
                            // Check if authed
                            if (currentUser == null) {
                              // Should not happen if here
                              if (context.mounted) Navigator.pop(context);
                              return;
                            }
                            // 2. Join Session in CallProvider
                            // We need token, checking directly or assuming persisted if logged in
                            // Since we are logged in, we can get token. But AuthProvider checkAuthStatus returns it.
                            // Or we assume we have it. The cleanest is if AuthProvider exposed it, but it doesn't directly publicly property it?
                            // It returns it in checkAuthStatus.
                            // However, we can use the one from SharedPreferences slightly dirtily OR add a getter to AuthProvider.
                            // Ideally AuthProvider should expose the current valid token.
                            // BUT... AuthProvider has `currentUser`.
                            // Let's rely on SharedPreferences being available OR checkAuthStatus.
                            final token = await authProvider.checkAuthStatus();
                            if (token == null) return;

                            await callProvider.joinCall(
                              sessionId,
                              participants,
                              currentUserId: currentUser.id,
                              token: token,
                            );

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
