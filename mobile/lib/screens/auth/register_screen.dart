import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../utils/language_utils.dart';
import '../../config/app_theme.dart';
import '../../widgets/flash_bar.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  String? _error;
  final bool _isLoading = false;
  String _selectedLang = 'en';
  late AnimationController _backgroundController;

  // Password strength indicators
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _passController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final pass = _passController.text;
    setState(() {
      _hasMinLength = pass.length >= 6;
      _hasUppercase = pass.contains(RegExp(r'[A-Z]'));
      _hasNumber = pass.contains(RegExp(r'[0-9]'));
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // Language data with flags

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);

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
            top: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.getOrbColor(context, AppTheme.secondaryPurple, opacity: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                duration: 5.seconds,
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.15, 1.15)),
          ),

          Positioned(
            bottom: -120,
            right: -120,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.getOrbColor(context, AppTheme.primaryElectricBlue, opacity: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                duration: 6.seconds,
                begin: const Offset(0.85, 0.85),
                end: const Offset(1.1, 1.1)),
          ),

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios,
                          color: AppTheme.isDarkMode(context) ? Colors.white70 : AppTheme.darkText),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    "Create Account",
                    style: AppTheme.headlineLarge.copyWith(
                      fontSize: 32,
                      color: AppTheme.getTextColor(context),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 500.ms)
                      .slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 8),

                  Text(
                    "Join the future of multilingual communication",
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.getSecondaryTextColor(context)),
                  ).animate().fadeIn(delay: 400.ms, duration: 500.ms),

                  const SizedBox(height: 32),

                  // Name Input
                  _buildGlassInput(
                    controller: _nameController,
                    label: "Full Name",
                    icon: Icons.person_outline,
                  )
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 400.ms)
                      .slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 16),

                  // Phone Input
                  _buildGlassInput(
                    controller: _phoneController,
                    label: "Phone",
                    icon: Icons.phone_android_outlined,
                    keyboardType: TextInputType.phone,
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 400.ms)
                      .slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 16),

                  // Password Input
                  _buildGlassInput(
                    controller: _passController,
                    label: "Password",
                    icon: Icons.lock_outline,
                    obscureText: true,
                  )
                      .animate()
                      .fadeIn(delay: 700.ms, duration: 400.ms)
                      .slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 12),

                  // Password strength indicators
                  _buildPasswordStrength()
                      .animate()
                      .fadeIn(delay: 750.ms, duration: 400.ms),

                  const SizedBox(height: 24),

                  // Language Selector Label
                  Text(
                    "Primary Language",
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.getSecondaryTextColor(context)),
                  ).animate().fadeIn(delay: 800.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  // Visual Language Selector with Flags
                  _buildLanguageSelector()
                      .animate()
                      .fadeIn(delay: 850.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 24),

                  // Error Message
                  if (_error != null)
                    FlashBar(message: _error!)
                        .animate()
                        .shake(duration: 400.ms),

                  const SizedBox(height: 16),

                  // Register Button
                  _buildRegisterButton(authProv)
                      .animate()
                      .fadeIn(delay: 900.ms, duration: 400.ms)
                      .slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 24),

                  // Already have account link
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: RichText(
                        text: TextSpan(
                          text: "Already have an account? ",
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.getSecondaryTextColor(context),
                          ),
                          children: [
                            TextSpan(
                              text: "Sign In",
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.primaryElectricBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 1000.ms, duration: 400.ms),
                ],
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
                  ? Colors.white.withValues(alpha: 0.15)
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

  Widget _buildPasswordStrength() {
    return Row(
      children: [
        _buildStrengthIndicator("6+ chars", _hasMinLength),
        const SizedBox(width: 12),
        _buildStrengthIndicator("Uppercase", _hasUppercase),
        const SizedBox(width: 12),
        _buildStrengthIndicator("Number", _hasNumber),
      ],
    );
  }

  Widget _buildStrengthIndicator(String label, bool isValid) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: isValid
              ? AppTheme.successGreen
              : AppTheme.getSecondaryTextColor(context).withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            fontSize: 12,
            color: isValid
                ? AppTheme.successGreen
                : AppTheme.getSecondaryTextColor(context).withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector() {
    final isDark = AppTheme.isDarkMode(context);

    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(8),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: LanguageUtils.getAllLanguages().map((lang) {
              final isSelected = _selectedLang == lang['code'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedLang = lang['code']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryElectricBlue.withValues(alpha: isDark ? 0.3 : 0.15)
                          : Colors.transparent,
                      borderRadius: AppTheme.borderRadiusSmall,
                      border: isSelected
                          ? Border.all(
                              color: AppTheme.primaryElectricBlue, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          lang['flag']!,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lang['name']!,
                          style: AppTheme.bodyMedium.copyWith(
                            color: isSelected
                                ? (isDark ? Colors.white : AppTheme.primaryElectricBlue)
                                : AppTheme.getSecondaryTextColor(context),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterButton(AuthProvider authProv) {
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
          key: const Key('register-create-account'),
          borderRadius: AppTheme.borderRadiusPill,
          onTap: _isLoading
              ? null
              : () {
                  // Basic validation
                  if (_nameController.text.trim().isEmpty) {
                    setState(() => _error = 'Please enter your name');
                    return;
                  }
                  if (_phoneController.text.trim().isEmpty) {
                    setState(() => _error = 'Please enter your phone number');
                    return;
                  }
                  if (!_hasMinLength) {
                    setState(() =>
                        _error = 'Password must be at least 6 characters');
                    return;
                  }

                  setState(() => _error = null);

                  // Store registration data temporarily - don't call API yet!
                  // Registration will complete after voice recording or skip
                  authProv.setPendingRegistration(
                    phone: _phoneController.text.trim(),
                    fullName: _nameController.text.trim(),
                    password: _passController.text,
                    primaryLanguage: _selectedLang,
                  );

                  // Navigate to voice registration screen
                  Navigator.of(context).pushReplacementNamed('/register/voice');
                },
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rocket_launch, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        'Create Account',
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
