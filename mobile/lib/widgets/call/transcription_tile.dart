import 'package:flutter/material.dart';
import '../../models/transcription_entry.dart';
import '../../config/app_theme.dart';
import '../../utils/language_utils.dart';

/// Individual transcription entry tile.
///
/// SRP: Display a single transcription entry.
class TranscriptionTile extends StatelessWidget {
  const TranscriptionTile({
    super.key,
    required this.entry,
    required this.showOriginal,
    required this.showTranslated,
  });

  final TranscriptionEntry entry;
  final bool showOriginal;
  final bool showTranslated;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker name and time
          _buildHeader(),
          const SizedBox(height: 4),
          // Original text (if enabled)
          if (showOriginal && entry.originalText.isNotEmpty)
            _buildOriginalText(),
          // Translated text (if enabled)
          if (showTranslated && entry.translatedText.isNotEmpty)
            _buildTranslatedText(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppTheme.secondaryPurple,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          entry.participantName,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.secondaryPurple,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          _formatLanguages(),
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.secondaryText
                .withValues(alpha: 0.6), // Using withValues for alpha
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  String _formatLanguages() {
    final source = LanguageUtils.getFlag(entry.sourceLanguage);
    final target = LanguageUtils.getFlag(entry.targetLanguage);
    return '$source → $target';
  }

  Widget _buildOriginalText() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.glassLight, // Use defined glass color
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🗣️',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.originalText,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslatedText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryElectricBlue
            .withValues(alpha: 0.12), // ~30 alpha in 0-255 is ~0.12
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.primaryElectricBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💬',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.translatedText,
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
