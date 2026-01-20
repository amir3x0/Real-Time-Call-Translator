import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// App logo widget with theme support.
///
/// Displays the Voice Translator logo with optional size and decoration.
/// The logo image works well on both light and dark backgrounds.
class AppLogo extends StatelessWidget {
  /// Size of the logo (width and height)
  final double size;

  /// Whether to show a container with background decoration
  final bool showBackground;

  /// Border radius for the background container
  final double? borderRadius;

  /// Whether to add a subtle shadow/glow effect
  final bool showGlow;

  const AppLogo({
    super.key,
    this.size = 44,
    this.showBackground = false,
    this.borderRadius,
    this.showGlow = false,
  });

  /// Small logo variant (32px)
  const AppLogo.small({
    super.key,
    this.showBackground = false,
    this.borderRadius,
    this.showGlow = false,
  }) : size = 32;

  /// Medium logo variant (44px) - default
  const AppLogo.medium({
    super.key,
    this.showBackground = false,
    this.borderRadius,
    this.showGlow = false,
  }) : size = 44;

  /// Large logo variant (64px)
  const AppLogo.large({
    super.key,
    this.showBackground = false,
    this.borderRadius,
    this.showGlow = false,
  }) : size = 64;

  /// Extra large logo variant (120px) - for splash/login screens
  const AppLogo.xlarge({
    super.key,
    this.showBackground = false,
    this.borderRadius,
    this.showGlow = true,
  }) : size = 120;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final effectiveRadius = borderRadius ?? (size * 0.2);

    Widget logo = Image.asset(
      'assets/images/app_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (showBackground) {
      logo = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(effectiveRadius),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.lightDivider,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.primaryElectricBlue.withValues(alpha: 0.12),
                    blurRadius: size * 0.25,
                    spreadRadius: size * 0.02,
                  ),
                  ...AppTheme.lightCardShadow,
                ],
        ),
        padding: EdgeInsets.all(size * 0.1),
        child: logo,
      );
    }

    if (showGlow) {
      logo = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(effectiveRadius),
          boxShadow: isDark
              ? [
                  // Dark mode: more visible glow
                  BoxShadow(
                    color: AppTheme.primaryElectricBlue.withValues(alpha: 0.3),
                    blurRadius: size * 0.3,
                    spreadRadius: size * 0.05,
                  ),
                  BoxShadow(
                    color: AppTheme.accentCyan.withValues(alpha: 0.2),
                    blurRadius: size * 0.5,
                    spreadRadius: size * 0.1,
                  ),
                ]
              : [
                  // Light mode: subtle glow
                  BoxShadow(
                    color: AppTheme.primaryElectricBlue.withValues(alpha: 0.1),
                    blurRadius: size * 0.2,
                    spreadRadius: size * 0.01,
                  ),
                  BoxShadow(
                    color: AppTheme.accentCyan.withValues(alpha: 0.06),
                    blurRadius: size * 0.3,
                    spreadRadius: size * 0.02,
                  ),
                ],
        ),
        child: logo,
      );
    }

    return logo;
  }
}

/// Logo with "REAL-TIME CALL TRANSLATOR" text for login screen.
/// Text colors adapt to light/dark mode.
class AppLoginLogo extends StatelessWidget {
  final double logoSize;
  final bool showGlow;

  const AppLoginLogo({
    super.key,
    this.logoSize = 120,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo icon with glow
        AppLogo(size: logoSize, showGlow: showGlow),
        const SizedBox(height: 24),
        // "REAL-TIME" text - light blue
        const Text(
          'REAL-TIME',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppTheme.primaryElectricBlue,
            letterSpacing: 2,
          ),
        ),
        // "CALL TRANSLATOR" text - dark/light based on theme
        Text(
          'CALL\nTRANSLATOR',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.1,
            color: isDark ? Colors.white : const Color(0xFF2D3436),
          ),
        ),
      ],
    );
  }
}

/// Logo with app name text beside it
class AppLogoWithTitle extends StatelessWidget {
  final double logoSize;
  final bool showSubtitle;
  final String? subtitle;

  const AppLogoWithTitle({
    super.key,
    this.logoSize = 44,
    this.showSubtitle = true,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: logoSize),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Voice Translator',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextColor(context),
                ),
              ),
              if (showSubtitle && subtitle != null)
                Text(
                  subtitle!,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.getSecondaryTextColor(context),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
