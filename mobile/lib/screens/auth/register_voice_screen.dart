import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lobby_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/voice_recorder_widget.dart';
import '../../config/app_theme.dart';

class RegisterVoiceScreen extends StatefulWidget {
  const RegisterVoiceScreen({super.key});

  @override
  State<RegisterVoiceScreen> createState() => _RegisterVoiceScreenState();
}

class _RegisterVoiceScreenState extends State<RegisterVoiceScreen>
    with SingleTickerProviderStateMixin {
  bool _uploaded = false;
  bool _isRegistering = false;
  late AnimationController _backgroundController;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  /// Complete the registration and navigate to home
  Future<void> _completeRegistration() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!authProvider.hasPendingRegistration) {
      debugPrint('[RegisterVoice] No pending registration found');
      navigator.pushReplacementNamed('/home');
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    final success = await authProvider.completePendingRegistration();

    if (!mounted) return;
    setState(() => _isRegistering = false);

    if (success) {
      if (mounted) {
        final token = await authProvider.checkAuthStatus();
        if (!mounted) return;
        if (token != null && authProvider.currentUser != null) {
          Provider.of<LobbyProvider>(context, listen: false)
              .connect(token, authProvider.currentUser!.id);
          // Apply server theme preference (server wins)
          Provider.of<SettingsProvider>(context, listen: false)
              .applyServerTheme(authProvider.currentUser!.themePreference);
        }
      }
      navigator.pushReplacementNamed('/home');
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Registration failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Gradient Background - Theme Aware
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              final gradientColors = AppTheme.getScreenGradientColors(context);
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                    stops: [
                      0.0,
                      _backgroundController.value,
                      1.0,
                    ],
                  ),
                ),
              );
            },
          ),

          // Floating orb - Theme Aware
          Positioned(
            top: 100,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.getOrbColor(context, AppTheme.secondaryPurple, opacity: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                duration: 4.seconds,
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.2, 1.2)),
          ),

          // Main Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight - 48, // Account for padding
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header with Skip button - Theme Aware
                          _buildHeader().animate().fadeIn(duration: 300.ms),

                          const SizedBox(height: 16),

                          // Title - Theme Aware
                          Text(
                            "Voice Calibration",
                            style: AppTheme.headlineLarge.copyWith(
                              fontSize: 26,
                              color: AppTheme.getTextColor(context),
                            ),
                            textAlign: TextAlign.center,
                          )
                              .animate()
                              .fadeIn(delay: 200.ms, duration: 500.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 12),

                          // Privacy-focused explanation card
                          _buildExplanationCard()
                              .animate()
                              .fadeIn(delay: 400.ms, duration: 500.ms),

                          const SizedBox(height: 24),

                          // Voice Recorder Widget
                          Expanded(
                            child: Center(
                              child: VoiceRecorderWidget(
                                maxDuration: const Duration(seconds: 30),
                                prompt:
                                    'Read a short joke or story (up to 30s)',
                                // Complete registration BEFORE upload starts
                                onBeforeUpload: () async {
                                  final authProvider =
                                      Provider.of<AuthProvider>(context,
                                          listen: false);
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  if (!authProvider.isAuthenticated &&
                                      authProvider.hasPendingRegistration) {
                                    debugPrint(
                                        '[RegisterVoice] Completing registration before upload...');
                                    final success = await authProvider
                                        .completePendingRegistration();
                                    if (!success) {
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Registration failed. Please try again.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return false; // Cancel upload
                                    }
                                    debugPrint(
                                        '[RegisterVoice] Registration completed! Proceeding with upload...');
                                  }
                                  return true; // Proceed with upload
                                },
                                // Called AFTER successful upload
                                onUpload: () async {
                                  setState(() => _uploaded = true);
                                  if (!mounted) return;
                                  // Navigate to home after successful upload
                                  Navigator.of(context)
                                      .pushReplacementNamed('/home');
                                },
                              ),
                            ),
                          ).animate().fadeIn(delay: 600.ms, duration: 500.ms),

                          // Done button (only shows after upload)
                          if (_uploaded)
                            _buildDoneButton()
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = AppTheme.isDarkMode(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark ? Colors.white70 : AppTheme.darkText,
          ),
          onPressed: () {
            // Clear pending registration when going back
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            authProvider.clearPendingRegistration();
            Navigator.pop(context);
          },
        ),
        // Skip button - Theme Aware
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.primaryElectricBlue.withValues(alpha: 0.1),
            borderRadius: AppTheme.borderRadiusPill,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.primaryElectricBlue.withValues(alpha: 0.3),
            ),
          ),
          child: TextButton.icon(
            key: const Key('register-skip'),
            onPressed: _isRegistering ? null : _completeRegistration,
            icon: _isRegistering
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDark ? Colors.white70 : AppTheme.primaryElectricBlue,
                    ),
                  )
                : Icon(
                    Icons.skip_next_rounded,
                    color: isDark ? Colors.white70 : AppTheme.primaryElectricBlue,
                    size: 20,
                  ),
            label: Text(
              _isRegistering ? 'Registering...' : 'Skip for now',
              style: AppTheme.bodyMedium.copyWith(
                color: isDark ? Colors.white70 : AppTheme.primaryElectricBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExplanationCard() {
    final isDark = AppTheme.isDarkMode(context);

    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: AppTheme.borderRadiusMedium,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : AppTheme.lightDivider,
            ),
            boxShadow: isDark ? null : AppTheme.lightCardShadow,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryElectricBlue.withValues(alpha: 0.2),
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                    child: const Icon(
                      Icons.privacy_tip_outlined,
                      color: AppTheme.primaryElectricBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Why we need your voice',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.getTextColor(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildBulletPoint(
                Icons.record_voice_over,
                'Creates your unique voice signature',
              ),
              const SizedBox(height: 6),
              _buildBulletPoint(
                Icons.translate,
                'Optimizes translation accuracy',
              ),
              const SizedBox(height: 6),
              _buildBulletPoint(
                Icons.lock_outline,
                'Encrypted and stored securely on-device',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.secondaryPurple,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.getSecondaryTextColor(context),
              height: 1.3,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoneButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: AppTheme.borderRadiusPill,
        boxShadow: AppTheme.buttonShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('register-voice-next'),
          borderRadius: AppTheme.borderRadiusPill,
          onTap: _isRegistering
              ? null
              : () async {
                  // If already uploaded and registered, just navigate
                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);

                  // Connect to lobby
                  if (mounted && authProvider.currentUser != null) {
                    final token = await authProvider.checkAuthStatus();
                    if (!mounted) return;

                    if (token != null && authProvider.currentUser != null) {
                      // Use context.read or Provider.of with listen: false
                      if (context.mounted) {
                        Provider.of<LobbyProvider>(context, listen: false)
                            .connect(token, authProvider.currentUser!.id);
                      }
                    }
                  }

                  if (!mounted) return;
                  if (authProvider.isAuthenticated) {
                    Navigator.pushReplacementNamed(context, '/home');
                  } else {
                    _completeRegistration();
                  }
                },
          child: Center(
            child: _isRegistering
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        'Continue to App',
                        style: AppTheme.labelLarge.copyWith(fontSize: 16),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
