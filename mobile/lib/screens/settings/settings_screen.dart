import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lobby_provider.dart';
import '../../config/app_config.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/voice_service.dart';
import '../../widgets/voice_recorder_widget.dart';
import '../../widgets/server_config_widget.dart';
import '../../utils/language_utils.dart';
import '../../config/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLang = 'en';
  bool _hasVoiceSample = false;
  bool _isLoadingVoiceStatus = true;
  bool _showInterimCaptions = true;

  final AuthService _authService = AuthService();
  final VoiceService _voiceService = VoiceService();

  static const String _interimCaptionsKey = 'show_interim_captions';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserSettings();
    });
  }

  Future<void> _loadUserSettings() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProv.currentUser;

    // Set language from user's primary_language
    if (currentUser != null) {
      setState(() {
        _selectedLang = currentUser.primaryLanguage;
      });
    }

    // Load interim caption preference
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showInterimCaptions = prefs.getBool(_interimCaptionsKey) ?? true;
    });

    // Check voice sample status
    try {
      final voiceRecordings = await _voiceService.getVoiceRecordings();
      setState(() {
        _hasVoiceSample = voiceRecordings.isNotEmpty;
        _isLoadingVoiceStatus = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingVoiceStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to settings changes for reactivity
    Provider.of<SettingsProvider>(context);
    final authProv = Provider.of<AuthProvider>(context, listen: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Appearance (Theme)
          _buildSectionHeader('Appearance', Icons.palette_outlined)
              .animate()
              .fadeIn(delay: 50.ms, duration: 400.ms),
          const SizedBox(height: 12),

          _buildThemeSelector()
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms),

          const SizedBox(height: 24),

          // Section: Language
          _buildSectionHeader('Language', Icons.translate)
              .animate()
              .fadeIn(delay: 150.ms, duration: 400.ms),
          const SizedBox(height: 12),

          _buildLanguageSelector()
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 24),

          // Section: Voice
          _buildSectionHeader('Voice Profile', Icons.mic_outlined)
              .animate()
              .fadeIn(delay: 350.ms, duration: 400.ms),
          const SizedBox(height: 12),

          _buildVoiceSection()
              .animate()
              .fadeIn(delay: 400.ms, duration: 400.ms),

          const SizedBox(height: 24),

          // Section: Call Settings
          _buildSectionHeader('Call Settings', Icons.call_outlined)
              .animate()
              .fadeIn(delay: 410.ms, duration: 400.ms),
          const SizedBox(height: 12),

          _buildCallSettingsSection()
              .animate()
              .fadeIn(delay: 420.ms, duration: 400.ms),

          const SizedBox(height: 24),

          // Section: Server
          _buildSectionHeader('Server', Icons.dns_outlined)
              .animate()
              .fadeIn(delay: 425.ms, duration: 400.ms),
          const SizedBox(height: 12),

          _buildServerSection(authProv)
              .animate()
              .fadeIn(delay: 450.ms, duration: 400.ms),

          const SizedBox(height: 24),

          // Section: Account
          _buildSectionHeader('Account', Icons.person_outlined)
              .animate()
              .fadeIn(delay: 475.ms, duration: 400.ms),
          const SizedBox(height: 12),

          _buildLogoutButton(authProv)
              .animate()
              .fadeIn(delay: 500.ms, duration: 400.ms),

          // Extra padding for floating nav bar
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryElectricBlue.withValues(alpha: 0.15),
            borderRadius: AppTheme.borderRadiusSmall,
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppTheme.primaryElectricBlue,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.getSecondaryTextColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelector() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = settingsProvider.isDarkMode;

    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.themedGlassDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: AppTheme.titleMedium.copyWith(
                  color: AppTheme.getTextColor(context),
                ),
              ),
              const SizedBox(height: 12),
              // Segmented Button
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.getGlassColor(context, opacity: 0.1),
                  borderRadius: AppTheme.borderRadiusPill,
                ),
                child: Row(
                  children: [
                    // Light button
                    Expanded(
                      child: _buildThemeOption(
                        icon: Icons.light_mode,
                        label: 'Light',
                        isSelected: !isDark,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          settingsProvider.setTheme(ThemeMode.light);
                        },
                      ),
                    ),
                    // Dark button
                    Expanded(
                      child: _buildThemeOption(
                        icon: Icons.dark_mode,
                        label: 'Dark',
                        isSelected: isDark,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          settingsProvider.setTheme(ThemeMode.dark);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final secondaryColor = AppTheme.getSecondaryTextColor(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryElectricBlue.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: AppTheme.borderRadiusPill,
          border: isSelected
              ? Border.all(color: AppTheme.primaryElectricBlue, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primaryElectricBlue : secondaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: isSelected
                    ? AppTheme.primaryElectricBlue
                    : secondaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLanguageConfirmation(
      String newLangCode, String langName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: AppTheme.borderRadiusMedium,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.themedGlassDecoration(ctx, opacity: 0.9),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color:
                          AppTheme.primaryElectricBlue.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.language,
                      color: AppTheme.primaryElectricBlue,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Change Language',
                    style: AppTheme.titleLarge.copyWith(
                      color: AppTheme.getTextColor(ctx),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to change your primary language to $langName?\n\nThis will update your profile and other users will see this change.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.getSecondaryTextColor(ctx),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            'Cancel',
                            style: AppTheme.labelLarge
                                .copyWith(color: AppTheme.getSecondaryTextColor(ctx)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryElectricBlue,
                            borderRadius: AppTheme.borderRadiusSmall,
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              'Confirm',
                              style: AppTheme.labelLarge
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      // Update locally
      setState(() => _selectedLang = newLangCode);
      final settingsProv =
          Provider.of<SettingsProvider>(context, listen: false);
      settingsProv.setLanguage(_selectedLang);

      // Update in database
      try {
        await _authService.updateUserLanguage(newLangCode);

        // Refresh current user to reflect the change
        if (!mounted) return;
        final authProv = Provider.of<AuthProvider>(context, listen: false);
        await authProv.refreshCurrentUser();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Language changed to $langName'),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error updating language: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update language'),
              backgroundColor: AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _buildLanguageSelector() {
    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.themedGlassDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Primary Language',
                style: AppTheme.titleMedium.copyWith(
                  color: AppTheme.getTextColor(context),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: LanguageUtils.getAllLanguages().map((lang) {
                  final isSelected = _selectedLang == lang['code'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_selectedLang != lang['code']) {
                          HapticFeedback.selectionClick();
                          _showLanguageConfirmation(
                              lang['code']!, lang['name']!);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryElectricBlue
                                  .withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: AppTheme.borderRadiusSmall,
                          border: isSelected
                              ? Border.all(
                                  color: AppTheme.primaryElectricBlue,
                                  width: 1.5)
                              : Border.all(
                                  color: AppTheme.getGlassColor(context, opacity: 0.1)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              lang['flag']!,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lang['name']!,
                              style: AppTheme.bodyMedium.copyWith(
                                color: isSelected
                                    ? AppTheme.primaryElectricBlue
                                    : AppTheme.getSecondaryTextColor(context),
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 11,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceSection() {
    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.themedGlassDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: _hasVoiceSample
                          ? LinearGradient(colors: [
                              AppTheme.successGreen,
                              AppTheme.successGreen.withValues(alpha: 0.7)
                            ])
                          : AppTheme.purpleGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.record_voice_over,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Voice Sample', style: AppTheme.titleMedium.copyWith(
                          color: AppTheme.getTextColor(context),
                        )),
                        _isLoadingVoiceStatus
                            ? Text(
                                'Loading...',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.getSecondaryTextColor(context),
                                  fontSize: 12,
                                ),
                              )
                            : Text(
                                _hasVoiceSample
                                    ? 'Voice sample saved ✓'
                                    : 'No sample uploaded',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: _hasVoiceSample
                                      ? AppTheme.successGreen
                                      : AppTheme.getSecondaryTextColor(context),
                                  fontSize: 12,
                                ),
                              ),
                      ],
                    ),
                  ),
                  // Re-record button when sample exists
                  if (_hasVoiceSample && !_isLoadingVoiceStatus)
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _hasVoiceSample = false);
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Re-record'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryElectricBlue,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Show recorder only if no sample or user wants to re-record
              if (!_hasVoiceSample)
                VoiceRecorderWidget(
                  onUpload: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() {
                      _hasVoiceSample = true;
                    });
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Voice sample uploaded successfully!'),
                        backgroundColor: AppTheme.successGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  onDelete: () async {
                    setState(() => _hasVoiceSample = false);
                  },
                  onPlay: () async {
                    await Future.delayed(const Duration(milliseconds: 300));
                  },
                )
              else
                // Show info when sample exists
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.1),
                    borderRadius: AppTheme.borderRadiusSmall,
                    border: Border.all(
                      color: AppTheme.successGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppTheme.successGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your voice sample is ready for voice cloning during calls.',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.successGreen,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallSettingsSection() {
    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.themedGlassDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Interim Captions Toggle
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _showInterimCaptions
                          ? AppTheme.accentCyan.withValues(alpha: 0.2)
                          : AppTheme.getGlassColor(context, opacity: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.closed_caption,
                      color: _showInterimCaptions
                          ? AppTheme.accentCyan
                          : AppTheme.getSecondaryTextColor(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live Captions',
                            style: AppTheme.titleMedium.copyWith(
                              color: AppTheme.getTextColor(context),
                            )),
                        Text(
                          'Show real-time transcription as you speak',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.getSecondaryTextColor(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _showInterimCaptions,
                    activeTrackColor: AppTheme.accentCyan,
                    onChanged: (value) async {
                      HapticFeedback.selectionClick();
                      setState(() => _showInterimCaptions = value);

                      // Persist to SharedPreferences
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(_interimCaptionsKey, value);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Live captions enabled'
                                  : 'Live captions disabled',
                            ),
                            backgroundColor: value
                                ? AppTheme.accentCyan
                                : AppTheme.getSecondaryTextColor(context),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Info text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: 0.08),
                  borderRadius: AppTheme.borderRadiusSmall,
                  border: Border.all(
                    color: AppTheme.accentCyan.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.accentCyan.withValues(alpha: 0.8),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Live captions show what is being said in real-time, like a typing indicator.',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.getSecondaryTextColor(context),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerSection(AuthProvider authProv) {
    return FutureBuilder<String?>(
      future: SharedPreferences.getInstance()
          .then((prefs) => prefs.getString(AppConfig.userTokenKey)),
      builder: (context, snapshot) {
        final token = snapshot.data;

        return ServerConfigWidget(
          compact: false,
          validateAuthToken: true,
          authToken: token,
          onConfigSaved: () {
            // Reconnect lobby WebSocket to new server
            final lobbyProvider =
                Provider.of<LobbyProvider>(context, listen: false);
            final userId = authProv.currentUser?.id;

            if (token != null && userId != null) {
              // Disconnect from old server and reconnect to new
              lobbyProvider.disconnect();
              lobbyProvider.connect(token, userId);
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Server configuration updated'),
                backgroundColor: AppTheme.successGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          onAuthTokenInvalid: () {
            // Token is invalid on new server - log out the user
            authProv.logout();
            Navigator.pushReplacementNamed(context, '/login');
          },
        );
      },
    );
  }

  Widget _buildLogoutButton(AuthProvider authProv) {
    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: AppTheme.glassDecoration(
            color: AppTheme.errorRed.withValues(alpha: 0.1),
            borderColor: AppTheme.errorRed.withValues(alpha: 0.3),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AppTheme.borderRadiusMedium,
              onTap: () {
                HapticFeedback.mediumImpact();
                _showLogoutConfirmation(authProv);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout, color: AppTheme.errorRed),
                    const SizedBox(width: 12),
                    Text(
                      'Sign Out',
                      style: AppTheme.labelLarge.copyWith(
                        color: AppTheme.errorRed,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(AuthProvider authProv) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: AppTheme.borderRadiusMedium,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.themedGlassDecoration(ctx, opacity: 0.9),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: AppTheme.errorRed,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Sign Out', style: AppTheme.titleLarge.copyWith(
                    color: AppTheme.getTextColor(ctx),
                  )),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to sign out?',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.getSecondaryTextColor(ctx),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cancel',
                            style: AppTheme.labelLarge
                                .copyWith(color: AppTheme.getSecondaryTextColor(ctx)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed,
                            borderRadius: AppTheme.borderRadiusSmall,
                          ),
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              authProv.logout();
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: Text(
                              'Sign Out',
                              style: AppTheme.labelLarge
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
