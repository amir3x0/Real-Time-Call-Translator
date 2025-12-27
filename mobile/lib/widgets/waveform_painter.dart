import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progress;
  final Color color;

  WaveformPainter({
    required this.amplitudes,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final barCount = amplitudes.length;
    final barWidth = size.width / (barCount * 2);

    for (int i = 0; i < barCount; i++) {
      final amp = amplitudes[i];
      // subtle breathing animation
      final animAmp = amp * (0.7 + 0.3 * (0.5 + 0.5 * (math.sin(progress * 6.283 + i * 0.3))));
      final barHeight = animAmp * size.height * 0.25;
      final x = i * barWidth * 2 + barWidth;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, size.height - 16),
          width: barWidth,
          height: barHeight,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.amplitudes != amplitudes || oldDelegate.color != color;
  }
}
