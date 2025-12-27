import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_theme.dart';

/// Animated gradient background used across auth screens.
/// Eliminates duplicate AnimatedBuilder + gradient code from
/// login_screen, register_screen, and register_voice_screen.
class AnimatedGradientBackground extends StatefulWidget {
  /// Primary gradient colors (usually 3)
  final List<Color> colors;
  
  /// Animation duration for the gradient movement
  final Duration duration;
  
  /// Whether to show floating orbs for depth effect
  final bool showOrbs;
  
  /// Optional child widget to display on top
  final Widget? child;

  const AnimatedGradientBackground({
    super.key,
    this.colors = const [
      Color(0xFF0F1630),
      Color(0xFF1B2750),
      Color(0xFF2A3A6B),
    ],
    this.duration = const Duration(seconds: 10),
    this.showOrbs = true,
    this.child,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated Gradient
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.colors,
                  stops: [
                    0.0,
                    _controller.value,
                    1.0,
                  ],
                ),
              ),
            );
          },
        ),

        // Floating orbs for depth
        if (widget.showOrbs) ...[
          // Top-right orb (blue)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryElectricBlue.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                  duration: 4.seconds,
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.2, 1.2),
                ),
          ),

          // Bottom-left orb (purple)
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondaryPurple.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                  duration: 5.seconds,
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.1, 1.1),
                ),
          ),
        ],

        // Optional child
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// A simpler static gradient background for screens that don't need animation
class GradientBackground extends StatelessWidget {
  final List<Color> colors;
  final Widget? child;
  final bool showOrbs;

  const GradientBackground({
    super.key,
    this.colors = const [
      Color(0xFF0F1630),
      Color(0xFF1B2750),
      Color(0xFF2A3A6B),
    ],
    this.child,
    this.showOrbs = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: showOrbs
          ? Stack(
              children: [
                // Top-right orb
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primaryElectricBlue.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom-left orb
                Positioned(
                  bottom: -150,
                  left: -150,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.secondaryPurple.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                if (child != null) child!,
              ],
            )
          : child,
    );
  }
}
