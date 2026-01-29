/// App Theme - Design system and theme configuration.
///
/// Implements a "Fluid Intelligence" design system with:
/// - Glassmorphism effects (translucent cards, blur)
/// - Color palettes for light and dark modes
/// - Gradient definitions for backgrounds and buttons
/// - Typography scale (Inter font family)
/// - Theme-aware helper methods for consistent styling
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fluid Intelligence Design System.
/// Inspired by Glassmorphism, Modern AI interfaces, and subtle animations
class AppTheme {
  // ========== Color Palette ==========

  // Primary Colors - Deep Indigo to Electric Blue (Technology/Trust)
  static const Color primaryDeepIndigo = Color(0xFF1A237E);
  static const Color primaryIndigo = Color(0xFF283593);
  static const Color primaryElectricBlue = Color(0xFF2962FF);
  static const Color primaryBrightBlue = Color(0xFF448AFF);

  // Secondary Colors - Soft Purple (AI/Magic)
  static const Color secondaryPurple = Color(0xFFBB86FC);
  static const Color secondaryLightPurple = Color(0xFFCF94FF);
  static const Color secondaryDeepPurple = Color(0xFF9C27B0);

  // Functional Colors
  static const Color successGreen = Color(0xFF10B981); // Emerald
  static const Color errorRed = Color(0xFFEF4444); // Coral Red
  static const Color warningOrange = Color(0xFFF59E0B); // Amber
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color accentCyan = Color(0xFF00D9FF); // Vibrant Cyan

  // Neutral Colors - Dark Mode
  static const Color darkBackground = Color(0xFF0E0E16);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF16213E);
  static const Color lightText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB0B0B0);

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF0F2F5);
  static const Color darkText = Color(0xFF1A1A2E);
  static const Color lightSecondaryText = Color(0xFF6B7280);
  static const Color lightDivider = Color(0xFFE5E7EB);

  // Glassmorphism Colors
  static const Color glassLight = Color(0x33FFFFFF); // 20% white
  static const Color glassMedium = Color(0x4DFFFFFF); // 30% white
  static const Color glassHeavy = Color(0x66FFFFFF); // 40% white

  // ========== Gradients ==========

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeepIndigo, primaryIndigo, primaryElectricBlue],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF12122A), Color(0xFF1A1A3A), Color(0xFF2B2B5C)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x33FFFFFF), Color(0x1AFFFFFF)],
  );

  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryPurple, secondaryDeepPurple],
  );

  // Light Mode Gradient
  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8F4FD), Color(0xFFF5F7FA)],
  );

  // Dark Mode Screen Gradient (for animated backgrounds)
  static const List<Color> darkScreenGradientColors = [
    Color(0xFF0F1630),
    Color(0xFF1B2750),
    Color(0xFF2A3A6B),
  ];

  // Light Mode Screen Gradient (clean, airy)
  static const List<Color> lightScreenGradientColors = [
    Color(0xFFE8F4FD),
    Color(0xFFF0F4F8),
    Color(0xFFF5F7FA),
  ];

  // ========== Theme-Aware Helpers ==========

  /// Check if current theme is dark mode
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Get background color based on theme
  static Color getBackgroundColor(BuildContext context) {
    return isDarkMode(context) ? darkBackground : lightBackground;
  }

  /// Get surface color based on theme
  static Color getSurfaceColor(BuildContext context) {
    return isDarkMode(context) ? darkSurface : lightSurface;
  }

  /// Get card color based on theme
  static Color getCardColor(BuildContext context) {
    return isDarkMode(context) ? darkCard : lightCard;
  }

  /// Get primary text color based on theme
  static Color getTextColor(BuildContext context) {
    return isDarkMode(context) ? lightText : darkText;
  }

  /// Get secondary text color based on theme
  static Color getSecondaryTextColor(BuildContext context) {
    return isDarkMode(context) ? secondaryText : lightSecondaryText;
  }

  /// Get screen gradient colors based on theme
  static List<Color> getScreenGradientColors(BuildContext context) {
    return isDarkMode(context) ? darkScreenGradientColors : lightScreenGradientColors;
  }

  /// Get glass/overlay color for glassmorphism effects
  /// In dark mode: white overlay on dark background
  /// In light mode: dark overlay on light background
  static Color getGlassColor(BuildContext context, {double opacity = 0.1}) {
    return isDarkMode(context)
        ? Colors.white.withValues(alpha: opacity)
        : Colors.black.withValues(alpha: opacity * 0.5);
  }

  /// Get glass border color based on theme
  static Color getGlassBorderColor(BuildContext context, {double opacity = 0.1}) {
    return isDarkMode(context)
        ? Colors.white.withValues(alpha: opacity)
        : Colors.black.withValues(alpha: opacity * 0.3);
  }

  /// Get floating orb color for decorative backgrounds
  static Color getOrbColor(BuildContext context, Color baseColor, {double opacity = 0.15}) {
    return isDarkMode(context)
        ? baseColor.withValues(alpha: opacity)
        : baseColor.withValues(alpha: opacity * 0.5);
  }

  /// Get theme-aware button gradient
  /// Dark mode: Deep indigo gradient (dark, bold)
  /// Light mode: Bright blue gradient (lighter, vibrant)
  static LinearGradient getButtonGradient(BuildContext context) {
    return isDarkMode(context)
        ? primaryGradient
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryElectricBlue, primaryBrightBlue, Color(0xFF64B5F6)],
          );
  }

  /// Light mode button gradient constant
  static const LinearGradient lightButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryElectricBlue, primaryBrightBlue, Color(0xFF64B5F6)],
  );

  // ========== Border Radius ==========

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusXLarge = 32.0;
  static const double radiusPill = 100.0;

  static BorderRadius borderRadiusSmall = BorderRadius.circular(radiusSmall);
  static BorderRadius borderRadiusMedium = BorderRadius.circular(radiusMedium);
  static BorderRadius borderRadiusLarge = BorderRadius.circular(radiusLarge);
  static BorderRadius borderRadiusXLarge = BorderRadius.circular(radiusXLarge);
  static BorderRadius borderRadiusPill = BorderRadius.circular(radiusPill);

  // ========== Shadows ==========

  static List<BoxShadow> glowShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.6),
          blurRadius: 24,
          spreadRadius: 6,
        ),
      ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // Light mode card shadow - softer, more subtle
  static List<BoxShadow> lightCardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: primaryElectricBlue.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  // ========== Typography ==========

  static const String fontFamily = 'Inter';

  static const TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.5,
    color: lightText,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: lightText,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: lightText,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: lightText,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: lightText,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    color: lightText,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: lightText,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    color: lightText,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    color: secondaryText,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    color: secondaryText,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.25,
    color: lightText,
  );

  // ========== Glassmorphism Decoration ==========

  static BoxDecoration glassDecoration({
    Color? color,
    double borderRadius = radiusMedium,
    Color? borderColor,
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      color: color ?? glassLight,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.1),
        width: borderWidth,
      ),
      boxShadow: cardShadow,
    );
  }

  /// Theme-aware glass decoration
  /// Use this instead of glassDecoration for proper light/dark mode support
  static BoxDecoration themedGlassDecoration(
    BuildContext context, {
    double borderRadius = radiusMedium,
    double borderWidth = 1.0,
    double opacity = 0.08,
  }) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: opacity)
          : Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : lightDivider,
        width: borderWidth,
      ),
      boxShadow: isDark
          ? cardShadow
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  /// Theme-aware card decoration for solid cards
  static BoxDecoration themedCardDecoration(
    BuildContext context, {
    double borderRadius = radiusMedium,
  }) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      color: isDark ? darkCard : lightSurface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : lightDivider,
        width: 1,
      ),
      boxShadow: isDark
          ? cardShadow
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  // ========== Theme Data ==========

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: primaryElectricBlue,
      secondary: secondaryPurple,
      surface: darkSurface,
      error: errorRed,
      onPrimary: lightText,
      onSecondary: lightText,
      onSurface: lightText,
    ),

    // Scaffold
    scaffoldBackgroundColor: darkBackground,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: headlineMedium,
      iconTheme: IconThemeData(color: lightText),
    ),

    // Card
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadiusMedium,
      ),
    ),

    // Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryElectricBlue,
        foregroundColor: lightText,
        elevation: 6,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusPill,
        ),
        textStyle: labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryElectricBlue,
        textStyle: labelLarge,
      ),
    ),

    // Input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCard,
      border: OutlineInputBorder(
        borderRadius: borderRadiusMedium,
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadiusMedium,
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadiusMedium,
        borderSide: const BorderSide(color: primaryElectricBlue, width: 2),
      ),
      labelStyle: bodyMedium,
      hintStyle:
          bodyMedium.copyWith(color: secondaryText.withValues(alpha: 0.5)),
    ),

    // Bottom Navigation
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: primaryElectricBlue,
      unselectedItemColor: secondaryText,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: labelLarge.copyWith(fontSize: 12),
      unselectedLabelStyle: labelLarge.copyWith(fontSize: 12),
    ),

    // Icon
    iconTheme: const IconThemeData(
      color: lightText,
      size: 24,
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: displayLarge,
      displayMedium: displayMedium,
      headlineLarge: headlineLarge,
      headlineMedium: headlineMedium,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      titleSmall: titleSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
    ),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Color Scheme
    colorScheme: const ColorScheme.light(
      primary: primaryElectricBlue,
      secondary: secondaryPurple,
      surface: lightSurface,
      error: errorRed,
      onPrimary: lightText,
      onSecondary: lightText,
      onSurface: darkText,
    ),

    // Scaffold
    scaffoldBackgroundColor: lightBackground,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: darkText,
      ),
      iconTheme: IconThemeData(color: darkText),
    ),

    // Card
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadiusMedium,
      ),
    ),

    // Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryElectricBlue,
        foregroundColor: lightText,
        elevation: 2,
        shadowColor: primaryElectricBlue.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusPill,
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.25,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryElectricBlue,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.25,
        ),
      ),
    ),

    // Input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightCard,
      border: OutlineInputBorder(
        borderRadius: borderRadiusMedium,
        borderSide: const BorderSide(color: lightDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadiusMedium,
        borderSide: const BorderSide(color: lightDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadiusMedium,
        borderSide: const BorderSide(color: primaryElectricBlue, width: 2),
      ),
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: lightSecondaryText,
      ),
      hintStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: lightSecondaryText.withValues(alpha: 0.5),
      ),
    ),

    // Bottom Navigation
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lightSurface,
      selectedItemColor: primaryElectricBlue,
      unselectedItemColor: lightSecondaryText,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),

    // Icon
    iconTheme: const IconThemeData(
      color: darkText,
      size: 24,
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: lightDivider,
      thickness: 1,
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        color: darkText,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: darkText,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: darkText,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: darkText,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: darkText,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: darkText,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: darkText,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: darkText,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: lightSecondaryText,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: lightSecondaryText,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.25,
        color: darkText,
      ),
    ),
  );
}
