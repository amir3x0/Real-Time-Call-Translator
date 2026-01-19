import 'package:flutter/material.dart';
import '../../models/live_caption.dart';
import '../../config/app_theme.dart';

/// Stylized bubble that floats above the active participant.
class LiveCaptionBubble extends StatelessWidget {
  const LiveCaptionBubble({
    super.key,
    required this.data,
    this.alignment = Alignment.center,
    this.opacity = 1,
  });

  final LiveCaptionData data;
  final Alignment alignment;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );

    return Align(
      alignment: alignment,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: opacity,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF4C1D95), Color(0xFF6D28D9)]
                  : [AppTheme.primaryElectricBlue, AppTheme.secondaryPurple],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data.fromAi)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.auto_fix_high, color: Colors.white, size: 16),
                ),
              Flexible(
                child: Text(
                  data.text,
                  style: textStyle,
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
