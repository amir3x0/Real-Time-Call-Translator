/// Language utility functions for the Real-Time Call Translator app.
///
/// Provides helpers for getting language flags, names, and validation.
/// Uses data from LanguageData but provides a cleaner API.
class LanguageUtils {
  /// Supported language codes
  static const List<String> supportedCodes = ['he', 'en', 'ru'];

  /// Language flags mapped by code
  static const Map<String, String> _flags = {
    'he': '🇮🇱',
    'en': '🇺🇸',
    'ru': '🇷🇺',
  };

  /// Native language names mapped by code
  static const Map<String, String> _nativeNames = {
    'he': 'עברית',
    'en': 'English',
    'ru': 'Русский',
  };

  /// English language names mapped by code
  static const Map<String, String> _englishNames = {
    'he': 'Hebrew',
    'en': 'English',
    'ru': 'Russian',
  };

  /// Get flag emoji for a language code
  static String getFlag(String code) {
    // Normalize: 'en-US' -> 'en'
    final normalized = code.toLowerCase().split('-').first;
    return _flags[normalized] ?? '🌐';
  }

  /// Get native name for a language code
  static String getName(String code) =>
      _nativeNames[code] ?? code.toUpperCase();

  /// Get English name for a language code
  static String getEnglishName(String code) =>
      _englishNames[code] ?? code.toUpperCase();

  /// Check if a language code is supported
  static bool isSupported(String code) => supportedCodes.contains(code);

  /// Get all languages as a list of maps (useful for selectors)
  static List<Map<String, String>> getAllLanguages() {
    return supportedCodes
        .map((code) => {
              'code': code,
              'flag': getFlag(code),
              'name': getName(code),
              'englishName': getEnglishName(code),
            })
        .toList();
  }

  /// Format language display string (flag + name)
  static String formatDisplay(String code) {
    return '${getFlag(code)} ${getName(code)}';
  }

  /// Format language display string with English name
  static String formatDisplayWithEnglish(String code) {
    final native = getName(code);
    final english = getEnglishName(code);
    if (native == english) return '${getFlag(code)} $native';
    return '${getFlag(code)} $native ($english)';
  }
}
