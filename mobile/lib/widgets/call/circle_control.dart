import 'package:flutter/material.dart';

class CircleControl extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool requireLongPress;
  final VoidCallback? onLongPress;

  const CircleControl({
    super.key,
    required this.icon,
    required this.color,
    this.onTap,
    this.requireLongPress = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF2E2E80), Color(0xFF7C3AED)],
        ),
      ),
      child: Icon(icon, size: 32, color: color),
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
