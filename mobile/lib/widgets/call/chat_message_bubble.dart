import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/transcription_entry.dart';
import '../../config/app_theme.dart';

/// Individual chat message bubble for transcription display.
///
/// Displays a single message with:
/// - Different styling for self vs other participants
/// - Participant name and timestamp
/// - Original text subtitle for others (shows both translation + original)
/// - Animated entrance
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.entry,
    required this.isSelf,
    this.animate = true,
    this.showOriginalSubtitle = true,
  });

  final TranscriptionEntry entry;
  final bool isSelf;
  final bool animate;
  final bool showOriginalSubtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    // Theme-aware bubble gradients
    const selfGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0D7377), // Teal
        Color(0xFF14919B), // Cyan
      ],
    );

    const otherGradientDark = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF2D2D4A),
        Color(0xFF1E1E35),
      ],
    );

    final otherGradientLight = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.grey.shade100,
        Colors.grey.shade200,
      ],
    );

    final bubble = Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.only(
          left: isSelf ? 48 : 8,
          right: isSelf ? 8 : 48,
          top: 4,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment:
              isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Participant name label
            Padding(
              padding: EdgeInsets.only(
                left: isSelf ? 0 : 12,
                right: isSelf ? 12 : 0,
                bottom: 4,
              ),
              child: Text(
                isSelf ? 'You' : entry.participantName,
                style: AppTheme.bodySmall.copyWith(
                  color:
                      isSelf ? AppTheme.accentCyan : AppTheme.secondaryPurple,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            // Message bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isSelf
                    ? selfGradient
                    : (isDark ? otherGradientDark : otherGradientLight),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isSelf ? 18 : 4),
                  bottomRight: Radius.circular(isSelf ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelf ? AppTheme.accentCyan : Colors.black)
                        .withValues(alpha: isDark ? 0.2 : 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primary text
                  Text(
                    _getPrimaryText(),
                    style: AppTheme.bodyMedium.copyWith(
                      color: isSelf
                          ? Colors.white
                          : (isDark ? Colors.white : AppTheme.darkText),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  // Original text subtitle (for non-self messages)
                  if (_shouldShowSubtitle())
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '(${entry.originalText})',
                        style: AppTheme.bodySmall.copyWith(
                          color: isSelf
                              ? Colors.white.withValues(alpha: 0.6)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : AppTheme.lightSecondaryText),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Timestamp
            Padding(
              padding: EdgeInsets.only(
                left: isSelf ? 0 : 12,
                right: isSelf ? 12 : 0,
                top: 4,
              ),
              child: Text(
                _formatTime(entry.timestamp),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.getSecondaryTextColor(context)
                      .withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (animate) {
      return bubble
          .animate()
          .fadeIn(duration: 250.ms, curve: Curves.easeOut)
          .slideY(
            begin: 0.3,
            end: 0,
            duration: 250.ms,
            curve: Curves.easeOutCubic,
          );
    }

    return bubble;
  }

  /// Get primary display text
  String _getPrimaryText() {
    if (isSelf) {
      // Self: show original (what I said)
      return entry.originalText;
    } else {
      // Others: show translation (in my language)
      return entry.translatedText.isNotEmpty
          ? entry.translatedText
          : entry.originalText;
    }
  }

  /// Whether to show original text as subtitle
  bool _shouldShowSubtitle() {
    if (isSelf) return false; // Don't show subtitle for self
    if (!showOriginalSubtitle) return false; // Disabled by option
    if (entry.originalText.isEmpty) return false;
    if (entry.originalText == entry.translatedText) return false; // Same text
    return true;
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
