import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:mobile/config/app_theme.dart';
import 'package:mobile/models/participant.dart';

class ParticipantCard extends StatelessWidget {
  const ParticipantCard({
    super.key,
    required this.participant,
    this.mockName = "User",
    this.isFullScreen = false,
    this.isSpeaking = false,
    this.isCompact = false,
  });

  final CallParticipant participant;
  final String mockName;
  final bool isFullScreen;
  final bool isSpeaking;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactCard();
    }
    return _buildFullCard();
  }

  Widget _buildCompactCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Speaking Glow
            if (isSpeaking)
              AvatarGlow(
                glowColor: AppTheme.secondaryPurple,
                glowRadiusFactor: 0.4,
                duration: const Duration(milliseconds: 1500),
                repeat: true,
                animate: true,
                child: const SizedBox(width: 56, height: 56),
              ),

            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSpeaking
                      ? AppTheme.secondaryPurple
                      : Colors.white.withValues(alpha: 0.1),
                  width: isSpeaking ? 2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: AppTheme.primaryIndigo,
                child: Text(
                  mockName.isNotEmpty ? mockName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Mute Icon (Mini badge)
            if (participant.isMuted)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppTheme.darkBackground, width: 2),
                  ),
                  child:
                      const Icon(Icons.mic_off, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Compact Name & Flag
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mockName,
              style: AppTheme.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 4),
            Text(
              _getFlag(participant.speakingLanguage),
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFullCard() {
    final avatarRadius = isFullScreen ? 80.0 : 50.0;
    final fontSize = isFullScreen ? 50.0 : 30.0;

    return ClipRRect(
      borderRadius: AppTheme.borderRadiusLarge,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.darkCard.withValues(alpha: 0.8),
              AppTheme.darkSurface.withValues(alpha: 0.6),
            ],
          ),
          borderRadius: AppTheme.borderRadiusLarge,
          border: Border.all(
            color: _getBorderColor(),
            width: isSpeaking ? 3 : 2,
          ),
        ),
        child: Stack(
          children: [
            // Glassmorphism backdrop
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Avatar with glow effect
            Center(
              child: AvatarGlow(
                glowColor:
                    isSpeaking ? AppTheme.secondaryPurple : Colors.transparent,
                glowRadiusFactor: isSpeaking ? 0.6 : 0.0,
                duration: const Duration(milliseconds: 2000),
                animate: isSpeaking,
                child: CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: AppTheme.primaryIndigo,
                  child: Text(
                    mockName.isNotEmpty ? mockName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: fontSize,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // Name & Flag (Bottom Left)
            Positioned(
              bottom: 12,
              left: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mockName,
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(_getFlag(participant.speakingLanguage)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Mute Icon (Top Right)
            if (participant.isMuted)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.glowShadow(AppTheme.errorRed),
                  ),
                  child: const Icon(
                    Icons.mic_off,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

            // Connection Quality Indicator (Top Left)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getConnectionColor().withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getConnectionIcon(),
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

            // Speaking Indicator (pulsating border effect)
            if (isSpeaking)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppTheme.borderRadiusLarge,
                    border: Border.all(
                      color: AppTheme.secondaryPurple.withValues(alpha: 0.5),
                      width: 4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBorderColor() {
    if (isSpeaking) return AppTheme.secondaryPurple;

    try {
      return Color(
        int.parse(participant.connectionColor.replaceFirst('#', '0xff')),
      );
    } catch (e) {
      return AppTheme.primaryElectricBlue;
    }
  }

  Color _getConnectionColor() {
    switch (participant.connectionQuality) {
      case 'excellent':
        return AppTheme.successGreen;
      case 'good':
        return Colors.lightGreen;
      case 'fair':
        return AppTheme.warningOrange;
      case 'poor':
        return AppTheme.errorRed;
      default:
        return AppTheme.secondaryText;
    }
  }

  IconData _getConnectionIcon() {
    switch (participant.connectionQuality) {
      case 'excellent':
        return Icons.signal_cellular_alt;
      case 'good':
        return Icons.signal_cellular_alt_2_bar;
      case 'fair':
        return Icons.signal_cellular_alt_1_bar;
      case 'poor':
        return Icons.signal_cellular_connected_no_internet_0_bar;
      default:
        return Icons.signal_cellular_off;
    }
  }

  String _getFlag(String languageCode) {
    switch (languageCode) {
      case 'he':
        return '🇮🇱';
      case 'ru':
        return '🇷🇺';
      case 'en':
        return '🇺🇸';
      default:
        return '🌐';
    }
  }
}
