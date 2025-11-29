import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../data/api/api_service.dart';
import '../../widgets/voice_recorder_widget.dart';
import '../../config/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLang = 'en';
  String? _voiceSamplePath;

  final ApiService _api = ApiService();

  static const List<Map<String, String>> _languages = [
    {'code': 'he', 'flag': '🇮🇱', 'name': 'עברית'},
    {'code': 'en', 'flag': '🇺🇸', 'name': 'English'},
    {'code': 'ru', 'flag': '🇷🇺', 'name': 'Русский'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
      setState(() => _selectedLang = settingsProv.appLanguage);
    });
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
          // Section: Language
          _buildSectionHeader('Language', Icons.translate)
            .animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 12),
          
          _buildLanguageSelector()
            .animate().fadeIn(delay: 300.ms, duration: 400.ms),
          
          const SizedBox(height: 24),
          
          // Section: Voice
          _buildSectionHeader('Voice Profile', Icons.mic_outlined)
            .animate().fadeIn(delay: 350.ms, duration: 400.ms),
          const SizedBox(height: 12),
          
          _buildVoiceSection()
            .animate().fadeIn(delay: 400.ms, duration: 400.ms),
          
          const SizedBox(height: 24),
          
          // Section: Account
          _buildSectionHeader('Account', Icons.person_outlined)
            .animate().fadeIn(delay: 450.ms, duration: 400.ms),
          const SizedBox(height: 12),
          
          _buildLogoutButton(authProv)
            .animate().fadeIn(delay: 500.ms, duration: 400.ms),
          
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
            color: AppTheme.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector() {
    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.glassDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderColor: Colors.white.withValues(alpha: 0.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App Language',
                style: AppTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _languages.map((lang) {
                  final isSelected = _selectedLang == lang['code'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedLang = lang['code']!);
                        final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
                        settingsProv.setLanguage(_selectedLang);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryElectricBlue.withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: AppTheme.borderRadiusSmall,
                          border: isSelected
                              ? Border.all(color: AppTheme.primaryElectricBlue, width: 1.5)
                              : Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                                color: isSelected ? Colors.white : AppTheme.secondaryText,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
          decoration: AppTheme.glassDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderColor: Colors.white.withValues(alpha: 0.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppTheme.purpleGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.record_voice_over, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Voice Sample', style: AppTheme.titleMedium),
                        Text(
                          _voiceSamplePath == null
                              ? 'No sample uploaded'
                              : 'Sample ready',
                          style: AppTheme.bodyMedium.copyWith(
                            color: _voiceSamplePath == null
                                ? AppTheme.secondaryText
                                : AppTheme.successGreen,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              VoiceRecorderWidget(
                onUpload: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final result = await _api.uploadVoiceSample(
                    '/mock/path/sample.wav',
                    'he',  // language
                    'Sample text content for voice training',  // textContent
                  );
                  if (!mounted) return;
                  setState(() {
                    _voiceSamplePath = result['file_path'];
                  });
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Voice sample uploaded'),
                      backgroundColor: AppTheme.darkCard,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                onDelete: () async {
                  await _api.deleteVoiceSample('user_1');
                  setState(() => _voiceSamplePath = null);
                },
                onPlay: () async {
                  await Future.delayed(const Duration(milliseconds: 300));
                },
              ),
            ],
          ),
        ),
      ),
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
              decoration: AppTheme.glassDecoration(
                color: AppTheme.darkCard.withValues(alpha: 0.9),
                borderColor: Colors.white.withValues(alpha: 0.1),
              ),
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
                  Text('Sign Out', style: AppTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to sign out?',
                    style: AppTheme.bodyMedium,
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
                            style: AppTheme.labelLarge.copyWith(color: AppTheme.secondaryText),
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
                              Navigator.pushReplacementNamed(context, '/');
                            },
                            child: Text(
                              'Sign Out',
                              style: AppTheme.labelLarge.copyWith(color: Colors.white),
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
