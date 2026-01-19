import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class AnimatedButton extends StatefulWidget {
  final String label;
  final Future<bool> Function() onPressed;
  final double height;

  const AnimatedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 48,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _loading = false;

  Future<void> _handle() async {
    if (_loading) return;
    setState(() => _loading = true);
    final ok = await widget.onPressed();
    if (mounted) setState(() => _loading = false);
    if (!ok) {
      // Shake animation could be added here if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return InkWell(
      onTap: _handle,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF2E2E80), Color(0xFF7C3AED)]
                : [AppTheme.primaryElectricBlue, AppTheme.secondaryPurple],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  widget.label,
                  key: ValueKey(widget.label),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}
