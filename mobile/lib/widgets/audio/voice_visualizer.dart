import 'dart:math';
import 'package:flutter/material.dart';

/// Displays animated audio bars that react to recording intensity.
/// Used during onboarding / voice cloning to give instant feedback.
class VoiceVisualizer extends StatefulWidget {
  /// Whether the visualizer should animate with high energy.
  final bool isActive;

  /// Number of bars to render.
  final int barCount;

  /// Maximum bar height in logical pixels.
  final double maxBarHeight;

  /// Width of each bar.
  final double barWidth;

  /// Spacing between bars.
  final double spacing;

  /// Color used when the recorder is active.
  final Color activeColor;

  /// Color used when the recorder is idle.
  final Color inactiveColor;

  /// Interval for regenerating bar heights.
  final Duration animationDuration;

  const VoiceVisualizer({
    super.key,
    this.isActive = false,
    this.barCount = 24,
    this.maxBarHeight = 82,
    this.barWidth = 4,
    this.spacing = 2,
    this.activeColor = const Color(0xFF7C3AED),
    this.inactiveColor = const Color(0xFF1F1F46),
    this.animationDuration = const Duration(milliseconds: 180),
  });

  @override
  State<VoiceVisualizer> createState() => _VoiceVisualizerState();
}

class _VoiceVisualizerState extends State<VoiceVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _values;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _values = List<double>.filled(widget.barCount, 0.1, growable: false);
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..addListener(_handleTick)
     ..repeat();
  }

  @override
  void didUpdateWidget(covariant VoiceVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barCount != widget.barCount) {
      _values = List<double>.filled(widget.barCount, 0.1, growable: false);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTick);
    _controller.dispose();
    super.dispose();
  }

  void _handleTick() {
    final target = widget.isActive ? 1.0 : 0.2;
    setState(() {
      for (var i = 0; i < _values.length; i++) {
        final variance = widget.isActive ? _random.nextDouble() : _random.nextDouble() * 0.3;
        final next = max(0.05, min(1.0, target * variance));
        // Ease current height towards the new random value to keep animation smooth.
        _values[i] = (_values[i] * 0.55) + (next * 0.45);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.maxBarHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.barCount, (index) {
          final value = _values[index];
          final height = value * widget.maxBarHeight;
          final color = Color.lerp(widget.inactiveColor, widget.activeColor, value) ?? widget.activeColor;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
            child: AnimatedContainer(
              duration: widget.animationDuration,
              curve: Curves.easeOut,
              width: widget.barWidth,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(widget.barWidth),
              ),
            ),
          );
        }),
      ),
    );
  }
}
