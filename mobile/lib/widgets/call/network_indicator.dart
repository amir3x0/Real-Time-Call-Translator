import 'package:flutter/material.dart';

class NetworkIndicator extends StatelessWidget {
  final List<dynamic> participants;
  const NetworkIndicator({super.key, required this.participants});

  Color _qualityColor(String q) {
    switch (q) {
      case 'excellent':
        return Colors.greenAccent;
      case 'good':
        return Colors.lightGreen;
      case 'fair':
        return Colors.amber;
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qualities = participants.map((p) => p.connectionQuality ?? 'fair').toList();
    final worst = qualities.contains('poor')
        ? 'poor'
        : (qualities.contains('fair') ? 'fair' : (qualities.contains('good') ? 'good' : 'excellent'));
    final color = _qualityColor(worst);

    return SizedBox(
      width: 36,
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar(8, 8, color),
          const SizedBox(width: 2),
          _bar(8, 14, color),
          const SizedBox(width: 2),
          _bar(8, 20, color),
        ],
      ),
    );
  }

  Widget _bar(double w, double h, Color c) => AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        width: w,
        height: h,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
      );
}
