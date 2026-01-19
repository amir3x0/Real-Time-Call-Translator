import 'package:flutter/material.dart';
import '../../models/interim_caption.dart';
import '../../config/constants.dart';
import '../../config/app_theme.dart';

/// WhatsApp-style interim caption bubble with typing indicator.
///
/// Displays real-time transcription as the speaker talks, with:
/// - Speaker name tag (e.g., "[You]", "[John]")
/// - Blinking cursor animation
/// - Smooth text transitions
/// - Lower opacity to indicate interim/unconfirmed status
class InterimCaptionBubble extends StatefulWidget {
  const InterimCaptionBubble({
    super.key,
    required this.caption,
    this.maxWidth = 300,
  });

  final InterimCaption caption;
  final double maxWidth;

  @override
  State<InterimCaptionBubble> createState() => _InterimCaptionBubbleState();
}

class _InterimCaptionBubbleState extends State<InterimCaptionBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;
  late Animation<double> _cursorOpacity;

  @override
  void initState() {
    super.initState();

    // Blinking cursor animation
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AppConstants.interimCursorBlinkMs),
    )..repeat(reverse: true);

    _cursorOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cursorController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AppTheme.isDarkMode(context);

    // Truncate text if too long
    String displayText = widget.caption.text;
    if (displayText.length > AppConstants.interimCaptionMaxLength) {
      displayText =
          '${displayText.substring(0, AppConstants.interimCaptionMaxLength)}...';
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: AppConstants.interimCaptionFadeMs),
      opacity: 0.9,
      child: Container(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          // Cyan-tinted glass effect for interim (different from purple final)
          color: AppTheme.accentCyan.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.accentCyan.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Speaker tag
            _buildSpeakerTag(context, theme),
            const SizedBox(width: 8),

            // Text with blinking cursor
            Flexible(
              child: _buildTextWithCursor(context, theme, displayText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakerTag(BuildContext context, ThemeData theme) {
    final isSelf = widget.caption.isSelf;
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelf
            ? AppTheme.successGreen.withValues(alpha: 0.3)
            : AppTheme.primaryElectricBlue.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        widget.caption.displayTag,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isSelf
              ? (isDark ? Colors.greenAccent : AppTheme.successGreen)
              : (isDark ? Colors.lightBlueAccent : AppTheme.primaryElectricBlue),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildTextWithCursor(BuildContext context, ThemeData theme, String text) {
    final isDark = AppTheme.isDarkMode(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The interim text (italic to indicate unconfirmed)
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : AppTheme.darkText.withValues(alpha: 0.85),
              fontStyle: FontStyle.italic,
              height: 1.3,
            ),
          ),
        ),

        // Blinking cursor
        AnimatedBuilder(
          animation: _cursorOpacity,
          builder: (context, child) {
            return Opacity(
              opacity: _cursorOpacity.value,
              child: Container(
                width: 2,
                height: 16,
                margin: const EdgeInsets.only(left: 2),
                color: AppTheme.accentCyan,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Container widget that displays multiple interim captions stacked.
class InterimCaptionList extends StatelessWidget {
  const InterimCaptionList({
    super.key,
    required this.captions,
    this.maxVisible = 3,
  });

  final List<InterimCaption> captions;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (captions.isEmpty) return const SizedBox.shrink();

    // Show only the most recent captions (up to maxVisible)
    final visibleCaptions = captions.length > maxVisible
        ? captions.sublist(captions.length - maxVisible)
        : captions;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: visibleCaptions.map((caption) {
        return InterimCaptionBubble(
          key: ValueKey('interim_${caption.speakerId}'),
          caption: caption,
        );
      }).toList(),
    );
  }
}
