import 'dart:ui';
import 'package:flutter/material.dart';

import '../../models/transcription_entry.dart';
import '../../config/app_theme.dart';

/// Widget for displaying transcription/translation panel.
///
/// SRP: Single responsibility - display transcriptions with original + translated text.
///
/// Shows:
/// - Original text in source language
/// - Translated text in target language
/// - Speaker name and timestamp
class TranscriptionPanel extends StatelessWidget {
  const TranscriptionPanel({
    super.key,
    required this.entries,
    this.maxVisible = 3,
    this.showOriginal = true,
    this.showTranslated = true,
  });
  final List<TranscriptionEntry> entries;
  final int maxVisible;
  final bool showOriginal;
  final bool showTranslated;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _buildEmptyState();
    }

    final visibleEntries = entries.take(maxVisible).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(120),
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: visibleEntries
                  .map((entry) => _TranscriptionEntryTile(
                        entry: entry,
                        showOriginal: showOriginal,
                        showTranslated: showTranslated,
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(80),
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    AppTheme.primaryElectricBlue.withAlpha(180),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Listening...',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual transcription entry tile.
///
/// SRP: Display a single transcription entry.
class _TranscriptionEntryTile extends StatelessWidget {
  const _TranscriptionEntryTile({
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
            color: AppTheme.secondaryText.withAlpha(150),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  String _formatLanguages() {
    final source = _languageFlag(entry.sourceLanguage);
    final target = _languageFlag(entry.targetLanguage);
    return '$source → $target';
  }

  String _languageFlag(String code) {
    switch (code.toLowerCase()) {
      case 'he':
      case 'he-il':
        return '🇮🇱';
      case 'en':
      case 'en-us':
        return '🇺🇸';
      case 'ru':
      case 'ru-ru':
        return '🇷🇺';
      default:
        return '🌐';
    }
  }

  Widget _buildOriginalText() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
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
        color: AppTheme.primaryElectricBlue.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryElectricBlue.withAlpha(50)),
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
