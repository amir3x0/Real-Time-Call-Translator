import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fluid Intelligence Design System
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
  static const Color successGreen = Color(0xFF10B981);      // Emerald
  static const Color errorRed = Color(0xFFEF4444);          // Coral Red
  static const Color warningOrange = Color(0xFFF59E0B);     // Amber
  static const Color infoBlue = Color(0xFF3B82F6);
  
  // Neutral Colors
  static const Color darkBackground = Color(0xFF0E0E16);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF16213E);
  static const Color lightText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB0B0B0);
  
  // Glassmorphism Colors
  static const Color glassLight = Color(0x33FFFFFF);        // 20% white
  static const Color glassMedium = Color(0x4DFFFFFF);       // 30% white
  static const Color glassHeavy = Color(0x66FFFFFF);        // 40% white
  
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
      hintStyle: bodyMedium.copyWith(color: secondaryText.withValues(alpha: 0.5)),
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
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      labelLarge: labelLarge,
    ),
  );
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryElectricBlue,
      secondary: secondaryPurple,
      surface: Colors.white,
      error: errorRed,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
  );
}
