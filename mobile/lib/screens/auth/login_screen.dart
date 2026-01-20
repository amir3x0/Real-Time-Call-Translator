import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lobby_provider.dart';
import '../../providers/settings_provider.dart';
import '../../config/app_theme.dart';
import '../../widgets/flash_bar.dart';
import '../../widgets/server_config_widget.dart';
import '../../widgets/shared/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  String? _error;
  bool _isLoading = false;
  late AnimationController _backgroundController;

  bool _isValidPhone(String v) => v.replaceAll(RegExp(r"\D"), "").length >= 6;
  bool _isValidPass(String v) => v.length >= 4;

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
    _phoneController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

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

          // Floating orbs for depth - Theme Aware
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
                    AppTheme.getOrbColor(context, AppTheme.primaryElectricBlue, opacity: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate(
                    onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                    duration: 4.seconds,
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.2, 1.2)),
          ),

          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.getOrbColor(context, AppTheme.secondaryPurple, opacity: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate(
                    onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                    duration: 5.seconds,
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.1, 1.1)),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo with title - Theme Aware
                    const Center(child: AppLoginLogo())
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .scale(delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: 12),

                    Text(
                      "Break language barriers with AI",
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.getSecondaryTextColor(context),
                      ),
                    ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

                    const SizedBox(height: 24),

                    // Server Configuration (compact mode)
                    Center(
                      child: const ServerConfigWidget(compact: true)
                          .animate()
                          .fadeIn(delay: 700.ms, duration: 400.ms),
                    ),

                    const SizedBox(height: 24),

                    // Glassmorphism Phone Input
                    _buildGlassInput(
                      controller: _phoneController,
                      label: "Phone",
                      icon: Icons.phone_android_outlined,
                      keyboardType: TextInputType.phone,
                    )
                        .animate()
                        .fadeIn(delay: 800.ms, duration: 400.ms)
                        .slideX(begin: -0.2, end: 0, duration: 400.ms),

                    const SizedBox(height: 16),

                    // Glassmorphism Password Input
                    _buildGlassInput(
                      controller: _passController,
                      label: "Password",
                      icon: Icons.lock_outline,
                      obscureText: true,
                    )
                        .animate()
                        .fadeIn(delay: 1000.ms, duration: 400.ms)
                        .slideX(begin: -0.2, end: 0, duration: 400.ms),

                    const SizedBox(height: 24),

                    // Error Message
                    if (_error != null)
                      FlashBar(message: _error!)
                          .animate()
                          .shake(duration: 400.ms),

                    const SizedBox(height: 16),

                    // Pill-Shaped Login Button
                    _buildPillButton(
                      label: _isLoading ? "Signing in..." : "Sign In",
                      onPressed:
                          _isLoading ? null : () => _handleLogin(authProvider),
                      isLoading: _isLoading,
                    )
                        .animate()
                        .fadeIn(delay: 1200.ms, duration: 400.ms)
                        .slideY(begin: 0.2, end: 0, duration: 400.ms),

                    const SizedBox(height: 16),

                    // Divider - Theme Aware
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: AppTheme.isDarkMode(context)
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : AppTheme.lightDivider)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "OR",
                            style: AppTheme.bodyMedium
                                .copyWith(color: AppTheme.getSecondaryTextColor(context)),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: AppTheme.isDarkMode(context)
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : AppTheme.lightDivider)),
                      ],
                    ).animate().fadeIn(delay: 1400.ms),

                    const SizedBox(height: 16),

                    // Instead of a Google Sign-In button, we present a 'Create Account' button
                    _buildCreateAccountButton()
                        .animate()
                        .fadeIn(delay: 1600.ms, duration: 400.ms)
                        .slideY(begin: 0.2, end: 0, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    final isDark = AppTheme.isDarkMode(context);

    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: AppTheme.borderRadiusMedium,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.lightDivider,
            ),
            boxShadow: isDark ? null : AppTheme.lightCardShadow,
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.getTextColor(context),
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: AppTheme.bodyMedium.copyWith(
                color: AppTheme.getSecondaryTextColor(context),
              ),
              prefixIcon: Icon(icon, color: AppTheme.primaryElectricBlue),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.getButtonGradient(context),
        borderRadius: AppTheme.borderRadiusPill,
        boxShadow: AppTheme.buttonShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppTheme.borderRadiusPill,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: AppTheme.labelLarge.copyWith(fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateAccountButton() {
    final isDark = AppTheme.isDarkMode(context);

    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppTheme.primaryElectricBlue.withValues(alpha: 0.1),
            borderRadius: AppTheme.borderRadiusMedium,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.primaryElectricBlue.withValues(alpha: 0.3),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('login-create-account'),
              onTap: () => Navigator.pushNamed(context, '/register'),
              borderRadius: AppTheme.borderRadiusMedium,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add,
                    size: 28,
                    color: isDark ? Colors.white : AppTheme.primaryElectricBlue,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create account',
                    style: AppTheme.labelLarge.copyWith(
                      color: isDark ? Colors.white : AppTheme.primaryElectricBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin(AuthProvider authProvider) async {
    final phoneOk = _isValidPhone(_phoneController.text);
    final passOk = _isValidPass(_passController.text);

    if (!phoneOk || !passOk) {
      setState(() => _error = 'Invalid credentials');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final success = await authProvider.login(
      _phoneController.text,
      _passController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      // Connect to lobby after successful login to mark user as online
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
      setState(() => _error = 'Login failed. Please try again.');
    }
  }
}
