import 'dart:ui';
import 'package:flutter/material.dart';

import '../../models/transcription_entry.dart';
import '../../config/app_theme.dart';
import 'transcription_tile.dart';

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
            color: Colors.black.withValues(alpha: 0.47), // 120/255 ~ 0.47
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: visibleEntries
                  .map((entry) => TranscriptionTile(
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
            color: Colors.black.withValues(alpha: 0.31), // 80/255 ~ 0.31
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
                    AppTheme.primaryElectricBlue
                        .withValues(alpha: 0.7), // 180/255 ~ 0.7
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
