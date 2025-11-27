import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/voice_visualizer.dart';

enum RecorderState { idle, recording, reviewing, uploading }

class VoiceRecorderWidget extends StatefulWidget {
  final Duration maxDuration;
  final Future<void> Function()? onUpload;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onPlay;

  const VoiceRecorderWidget({
    super.key,
    this.maxDuration = const Duration(seconds: 10),
    this.onUpload,
    this.onDelete,
    this.onPlay,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  RecorderState _state = RecorderState.idle;
  late AnimationController _pulse;
  Timer? _recordTimer;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    HapticFeedback.mediumImpact();
    setState(() {
      _state = RecorderState.recording;
      _progress = 0.0;
    });
    final start = DateTime.now();
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      final elapsed = DateTime.now().difference(start);
      final p = elapsed.inMilliseconds / widget.maxDuration.inMilliseconds;
      if (p >= 1.0) {
        _stopRecording();
      } else {
        setState(() => _progress = p);
      }
    });
  }

  void _stopRecording() {
    _recordTimer?.cancel();
    setState(() => _state = RecorderState.reviewing);
  }

  Future<void> _upload() async {
    setState(() => _state = RecorderState.uploading);
    await Future.delayed(const Duration(seconds: 2));
    if (widget.onUpload != null) await widget.onUpload!();
    if (mounted) {
      HapticFeedback.lightImpact();
      setState(() => _state = RecorderState.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1630), Color(0xFF1B2750)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _state == RecorderState.recording
                  ? 'Voiceprint Creation'
                  : 'Voice Calibration',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: size.width * 0.6,
              height: size.width * 0.6,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // progress ring when recording
                  if (_state == RecorderState.recording)
                    SizedBox(
                      width: size.width * 0.55,
                      height: size.width * 0.55,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                      ),
                    ),

                  // mic / stop morphing button
                  GestureDetector(
                    onTap: () {
                      if (_state == RecorderState.idle) {
                        _startRecording();
                      } else if (_state == RecorderState.recording) {
                        _stopRecording();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      width: size.width * 0.4,
                      height: size.width * 0.4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E2E80), Color(0xFF7C3AED)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purpleAccent.withAlpha(89),
                            blurRadius: 24,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        _state == RecorderState.recording ? Icons.stop_rounded : Icons.mic,
                        color: Colors.white,
                        size: _state == RecorderState.recording ? 48 : 56,
                      ),
                    ),
                  ),

                  // pulse breathing effect when idle
                  if (_state == RecorderState.idle)
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) {
                        final s = 1 + 0.06 * math.sin(_pulse.value * 6.283);
                        return Transform.scale(
                          scale: s,
                          child: Container(
                            width: size.width * 0.48,
                            height: size.width * 0.48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withAlpha(15),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            VoiceVisualizer(
              isActive: _state == RecorderState.recording,
              maxBarHeight: 76,
              barWidth: 5,
              spacing: 3,
              activeColor: Colors.purpleAccent,
              inactiveColor: Colors.white12,
            ),
            const SizedBox(height: 20),
            Text(
              _state == RecorderState.recording
                  ? 'Keep speaking naturally — we’re learning your tone'
                  : 'Tap the mic and read the playful prompt aloud',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),

            // review controls
            if (_state == RecorderState.reviewing)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _pillButton(Icons.play_arrow, 'Play', () async {
                    HapticFeedback.selectionClick();
                    if (widget.onPlay != null) await widget.onPlay!();
                  }),
                  const SizedBox(width: 12),
                  _pillButton(Icons.delete_outline, 'Delete', () async {
                    HapticFeedback.selectionClick();
                    if (widget.onDelete != null) await widget.onDelete!();
                    setState(() => _state = RecorderState.idle);
                  }),
                  const SizedBox(width: 12),
                  _pillButton(Icons.cloud_upload_outlined, 'Upload', () async {
                    await _upload();
                  }),
                ],
              ),

            // uploading indicator
            if (_state == RecorderState.uploading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    SizedBox(width: 8),
                    Text('Uploading...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
