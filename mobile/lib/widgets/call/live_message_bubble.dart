import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// Live message bubble for real-time interim transcription in chat view.
///
/// Displays a "typing indicator" style bubble showing what someone
/// is currently saying (before final translation).
///
/// Features:
/// - Speaker name tag with color coding (self vs others)
/// - Blinking cursor animation
/// - Italic text to indicate interim/unconfirmed status
/// - Distinct styling from final messages (lighter, bordered)
class LiveMessageBubble extends StatefulWidget {
  const LiveMessageBubble({
    super.key,
    required this.text,
    required this.speakerName,
    required this.isSelf,
    this.maxLength = 150,
  });

  final String text;
  final String speakerName;
  final bool isSelf;
  final int maxLength;

  @override
  State<LiveMessageBubble> createState() => _LiveMessageBubbleState();
}

class _LiveMessageBubbleState extends State<LiveMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;
  late Animation<double> _cursorOpacity;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: AppConstants.interimCursorBlinkMs),
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
    // Truncate if too long
    String displayText = widget.text;
    if (displayText.length > widget.maxLength) {
      displayText = '${displayText.substring(0, widget.maxLength)}...';
    }

    return Align(
      alignment: widget.isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.only(
          left: widget.isSelf ? 48 : 8,
          right: widget.isSelf ? 8 : 48,
          top: 4,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment:
              widget.isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Speaker label with typing indicator
            Padding(
              padding: EdgeInsets.only(
                left: widget.isSelf ? 0 : 12,
                right: widget.isSelf ? 12 : 0,
                bottom: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.isSelf ? 'You' : widget.speakerName,
                    style: AppTheme.bodySmall.copyWith(
                      color: (widget.isSelf
                              ? AppTheme.accentCyan
                              : AppTheme.secondaryPurple)
                          .withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Typing dots animation
                  _buildTypingDots(),
                ],
              ),
            ),
            // Interim bubble (distinct from final)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // Lighter, semi-transparent background
                color: (widget.isSelf
                        ? AppTheme.accentCyan
                        : AppTheme.secondaryPurple)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(widget.isSelf ? 18 : 4),
                  bottomRight: Radius.circular(widget.isSelf ? 4 : 18),
                ),
                border: Border.all(
                  color: (widget.isSelf
                          ? AppTheme.accentCyan
                          : AppTheme.secondaryPurple)
                      .withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Interim text (italic)
                  Flexible(
                    child: Text(
                      displayText,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.getTextColor(context).withValues(alpha: 0.85),
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
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
                          height: 18,
                          margin: const EdgeInsets.only(left: 2, bottom: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: AppTheme.getSecondaryTextColor(context).withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        )
            .animate(
              delay: Duration(milliseconds: index * 150),
              onComplete: (c) => c.repeat(reverse: true),
            )
            .fadeIn(duration: 300.ms)
            .then()
            .fadeOut(duration: 300.ms);
      }),
    );
  }
}
