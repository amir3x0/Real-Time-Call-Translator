import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../utils/language_utils.dart';
import 'glass_card.dart';

/// Language information model
class LanguageInfo {
  final String code;
  final String flag;
  final String name;
  final String englishName;

  const LanguageInfo({
    required this.code,
    required this.flag,
    required this.name,
    required this.englishName,
  });
}

/// Centralized language data to avoid duplication across screens
class LanguageData {
  static List<LanguageInfo> get supportedLanguages =>
      LanguageUtils.getAllLanguages()
          .map((data) => LanguageInfo(
                code: data['code']!,
                flag: data['flag']!,
                name: data['name']!,
                englishName: data['englishName']!,
              ))
          .toList();

  /// Get language info by code
  static LanguageInfo? getByCode(String code) {
    try {
      return supportedLanguages.firstWhere((lang) => lang.code == code);
    } catch (_) {
      return null;
    }
  }

  /// Get flag emoji for a language code
  static String getFlag(String code) {
    return getByCode(code)?.flag ?? '\u{1F310}';
  }

  /// Get native name for a language code
  static String getName(String code) {
    return getByCode(code)?.name ?? code.toUpperCase();
  }

  /// Get English name for a language code
  static String getEnglishName(String code) {
    return getByCode(code)?.englishName ?? code.toUpperCase();
  }
}

/// A reusable language selector widget with glassmorphism style
class LanguageSelector extends StatelessWidget {
  final String? selectedCode;
  final ValueChanged<String> onLanguageSelected;
  final String? label;
  final bool showNativeNames;
  final bool compact;

  const LanguageSelector({
    super.key,
    this.selectedCode,
    required this.onLanguageSelected,
    this.label,
    this.showNativeNames = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: compact ? 8 : 12,
          runSpacing: compact ? 8 : 12,
          children: LanguageData.supportedLanguages.map((lang) {
            final isSelected = selectedCode == lang.code;
            return _LanguageChip(
              language: lang,
              isSelected: isSelected,
              onTap: () => onLanguageSelected(lang.code),
              showNativeName: showNativeNames,
              compact: compact,
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Individual language chip
class _LanguageChip extends StatelessWidget {
  final LanguageInfo language;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showNativeName;
  final bool compact;

  const _LanguageChip({
    required this.language,
    required this.isSelected,
    required this.onTap,
    this.showNativeName = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 12,
      ),
      color: isSelected
          ? AppTheme.primaryElectricBlue.withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.05),
      borderColor: isSelected
          ? AppTheme.primaryElectricBlue
          : Colors.white.withValues(alpha: 0.1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            language.flag,
            style: TextStyle(fontSize: compact ? 20 : 24),
          ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            showNativeName ? language.name : language.englishName,
            style:
                (compact ? AppTheme.bodyMedium : AppTheme.bodyLarge).copyWith(
              color: isSelected ? Colors.white : AppTheme.secondaryText,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            SizedBox(width: compact ? 6 : 8),
            Icon(
              Icons.check_circle,
              color: AppTheme.primaryElectricBlue,
              size: compact ? 16 : 20,
            ),
          ],
        ],
      ),
    );
  }
}

/// A dropdown-style language selector
class LanguageDropdown extends StatelessWidget {
  final String? selectedCode;
  final ValueChanged<String> onLanguageSelected;
  final String? hint;

  const LanguageDropdown({
    super.key,
    this.selectedCode,
    required this.onLanguageSelected,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCode,
          hint: Text(
            hint ?? 'Select language',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.secondaryText.withValues(alpha: 0.7),
            ),
          ),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppTheme.secondaryText),
          dropdownColor: AppTheme.darkCard,
          borderRadius: AppTheme.borderRadiusMedium,
          isExpanded: true,
          items: LanguageData.supportedLanguages.map((lang) {
            return DropdownMenuItem<String>(
              value: lang.code,
              child: Row(
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text(
                    lang.name,
                    style: AppTheme.bodyLarge.copyWith(color: Colors.white),
                  ),
                ],
              ),
            );
          }).toList(),
          selectedItemBuilder: (context) {
            return LanguageData.supportedLanguages.map((lang) {
              return Row(
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text(
                    lang.name,
                    style: AppTheme.bodyLarge.copyWith(color: Colors.white),
                  ),
                ],
              );
            }).toList();
          },
          onChanged: (value) {
            if (value != null) {
              onLanguageSelected(value);
            }
          },
        ),
      ),
    );
  }
}

/// A small language badge for display purposes
class LanguageBadge extends StatelessWidget {
  final String languageCode;
  final bool showName;
  final double? size;

  const LanguageBadge({
    super.key,
    required this.languageCode,
    this.showName = false,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final language = LanguageData.getByCode(languageCode);
    final flag = language?.flag ?? '\u{1F310}';
    final name = language?.name ?? languageCode.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: AppTheme.borderRadiusSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(flag, style: TextStyle(fontSize: size ?? 16)),
          if (showName) ...[
            const SizedBox(width: 6),
            Text(
              name,
              style: AppTheme.bodyMedium.copyWith(
                fontSize: (size ?? 16) * 0.75,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
