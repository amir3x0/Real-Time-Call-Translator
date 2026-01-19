import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_theme.dart';

/// Floating subtitle bubble that appears above the active speaker
/// Similar to cinematic subtitles
class FloatingSubtitleBubble extends StatelessWidget {
  final String text;
  final String speakerName;
  final Color? accentColor;

  const FloatingSubtitleBubble({
    super.key,
    required this.text,
    required this.speakerName,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.05),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.85),
                    ],
            ),
            borderRadius: AppTheme.borderRadiusMedium,
            border: Border.all(
              color: (accentColor ?? AppTheme.primaryElectricBlue).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Speaker name indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor ?? AppTheme.primaryElectricBlue,
                      boxShadow: AppTheme.glowShadow(
                        accentColor ?? AppTheme.primaryElectricBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    speakerName,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.getSecondaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Translation text
              Text(
                text,
                textAlign: TextAlign.start,
                style: AppTheme.bodyLarge.copyWith(
                  color: isDark ? Colors.white : AppTheme.darkText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: 200.ms)
      .slideY(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

/// Container for managing multiple subtitle bubbles
class SubtitleContainer extends StatelessWidget {
  final List<SubtitleData> subtitles;

  const SubtitleContainer({
    super.key,
    required this.subtitles,
  });

  @override
  Widget build(BuildContext context) {
    if (subtitles.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 16,
      right: 16,
      bottom: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: subtitles.map((subtitle) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FloatingSubtitleBubble(
              text: subtitle.text,
              speakerName: subtitle.speakerName,
              accentColor: subtitle.accentColor,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SubtitleData {
  final String text;
  final String speakerName;
  final Color? accentColor;

  SubtitleData({
    required this.text,
    required this.speakerName,
    this.accentColor,
  });
}
