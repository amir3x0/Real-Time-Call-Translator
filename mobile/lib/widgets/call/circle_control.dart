import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class CircleControl extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool requireLongPress;
  final VoidCallback? onLongPress;
  final double size;

  const CircleControl({
    super.key,
    required this.icon,
    required this.color,
    this.backgroundColor,
    this.onTap,
    this.requireLongPress = false,
    this.onLongPress,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: backgroundColor == null
            ? const LinearGradient(
                colors: [Color(0xFF2E2E80), Color(0xFF7C3AED)],
              )
            : null,
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: (backgroundColor ?? AppTheme.primaryElectricBlue).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.45, color: color),
    );

    return requireLongPress
        ? GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Long-press to end call'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            onLongPress: onLongPress,
            child: child,
          )
        : InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: child,
          );
  }
}

