import 'package:flutter/material.dart';

class FlashBar extends StatefulWidget {
  final String message;
  final Color color;
  final Duration duration;

  const FlashBar({
    super.key,
    required this.message,
    this.color = Colors.redAccent,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<FlashBar> createState() => _FlashBarState();
}

class _FlashBarState extends State<FlashBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _controller.forward();
    Future.delayed(widget.duration, () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      axisAlignment: -1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: widget.color, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)]),
        child: Text(widget.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
