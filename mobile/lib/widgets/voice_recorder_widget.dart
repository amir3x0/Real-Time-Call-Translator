import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'audio/voice_visualizer.dart';
import '../services/voice_recording_service.dart';
import '../config/app_theme.dart';

enum RecorderState { idle, recording, reviewing, uploading, playing }

class VoiceRecorderWidget extends StatefulWidget {
  final Duration maxDuration;
  final Future<void> Function()? onUpload;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onPlay;
  final String? prompt;

  /// Called BEFORE upload starts. Use this to complete registration first.
  /// Return true to proceed with upload, false to cancel.
  final Future<bool> Function()? onBeforeUpload;

  const VoiceRecorderWidget({
    super.key,
    this.maxDuration = const Duration(seconds: 10),
    this.onUpload,
    this.onDelete,
    this.onPlay,
    this.prompt,
    this.onBeforeUpload,
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

  final VoiceRecordingService _recordingService = VoiceRecordingService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _recordedFilePath;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted && _state == RecorderState.playing) {
          setState(() => _state = RecorderState.reviewing);
        }
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _recordTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @visibleForTesting
  void setStateForTesting(RecorderState s) {
    setState(() => _state = s);
  }

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();

    final started = await _recordingService.startRecording();
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not start recording. Please grant microphone permission.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _state = RecorderState.recording;
      _progress = 0.0;
      _recordingDuration = Duration.zero;
    });

    final start = DateTime.now();
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      final elapsed = DateTime.now().difference(start);
      final p = elapsed.inMilliseconds / widget.maxDuration.inMilliseconds;
      if (p >= 1.0) {
        _stopRecording();
      } else {
        setState(() {
          _progress = p;
          _recordingDuration = elapsed;
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();

    final path = await _recordingService.stopRecording();
    if (path != null && mounted) {
      setState(() {
        _state = RecorderState.reviewing;
        _recordedFilePath = path;
      });
    } else if (mounted) {
      setState(() => _state = RecorderState.idle);
    }
  }

  Future<void> _playRecording() async {
    if (_recordedFilePath == null) return;

    HapticFeedback.selectionClick();
    setState(() => _state = RecorderState.playing);

    try {
      await _audioPlayer.setFilePath(_recordedFilePath!);
      await _audioPlayer.play();
      if (widget.onPlay != null) await widget.onPlay!();
    } catch (e) {
      debugPrint('[VoiceRecorder] Error playing: $e');
      if (mounted) {
        setState(() => _state = RecorderState.reviewing);
      }
    }
  }

  Future<void> _deleteRecording() async {
    HapticFeedback.selectionClick();

    await _audioPlayer.stop();
    if (_recordedFilePath != null) {
      await _recordingService.deleteRecording(_recordedFilePath!);
    }

    if (widget.onDelete != null) await widget.onDelete!();

    setState(() {
      _state = RecorderState.idle;
      _recordedFilePath = null;
      _recordingDuration = Duration.zero;
    });
  }

  Future<void> _upload() async {
    if (_recordedFilePath == null) return;

    // Call pre-upload hook if provided (e.g., to complete registration first)
    if (widget.onBeforeUpload != null) {
      setState(() => _state = RecorderState.uploading);
      final shouldProceed = await widget.onBeforeUpload!();
      if (!shouldProceed) {
        if (mounted) setState(() => _state = RecorderState.reviewing);
        return;
      }
    }

    setState(() => _state = RecorderState.uploading);

    try {
      final language = await _recordingService.getUserLanguage();
      final success = await _recordingService.uploadRecording(
        filePath: _recordedFilePath!,
        language: language,
        textContent: widget.prompt ?? 'Voice calibration sample',
      );

      if (success) {
        HapticFeedback.lightImpact();
        if (widget.onUpload != null) await widget.onUpload!();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _state = RecorderState.reviewing);
      }
    } catch (e) {
      debugPrint('[VoiceRecorder] Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _state = RecorderState.reviewing);
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F1630), const Color(0xFF1B2750)]
              : [const Color(0xFFF8FAFC), const Color(0xFFEEF2F7)],
        ),
        borderRadius: AppTheme.borderRadiusMedium,
        border: isDark ? null : Border.all(color: AppTheme.lightDivider),
        boxShadow: isDark ? null : AppTheme.lightCardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _state == RecorderState.recording
                  ? 'Recording...'
                  : _state == RecorderState.reviewing
                      ? 'Review Recording'
                      : _state == RecorderState.playing
                          ? 'Playing...'
                          : 'Voice Calibration',
              style: TextStyle(
                color: AppTheme.getTextColor(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            // Show duration when recording or reviewing
            if (_state == RecorderState.recording ||
                _state == RecorderState.reviewing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _formatDuration(_recordingDuration),
                  style: TextStyle(
                    color: _state == RecorderState.recording
                        ? Colors.redAccent
                        : AppTheme.getSecondaryTextColor(context),
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),

            const SizedBox(height: 16),
            SizedBox(
              width: size.width * 0.4,
              height: size.width * 0.4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // pulse breathing effect when idle (BEHIND the button)
                  if (_state == RecorderState.idle)
                    IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) {
                          final s = 1 + 0.06 * math.sin(_pulse.value * 6.283);
                          return Transform.scale(
                            scale: s,
                            child: Container(
                              width: size.width * 0.32,
                              height: size.width * 0.32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.white.withAlpha(15)
                                    : AppTheme.primaryElectricBlue.withAlpha(25),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // progress ring when recording
                  if (_state == RecorderState.recording)
                    IgnorePointer(
                      child: SizedBox(
                        width: size.width * 0.38,
                        height: size.width * 0.38,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 8,
                          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.redAccent),
                        ),
                      ),
                    ),

                  // mic / stop morphing button (ON TOP - receives taps)
                  GestureDetector(
                    key: const Key('voice-mic-btn'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      debugPrint(
                          '[VoiceRecorder] Button tapped! State: $_state');
                      if (_state == RecorderState.idle) {
                        _startRecording();
                      } else if (_state == RecorderState.recording) {
                        _stopRecording();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      width: size.width * 0.28,
                      height: size.width * 0.28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _state == RecorderState.recording
                              ? [Colors.red.shade700, Colors.redAccent]
                              : isDark
                                  ? const [Color(0xFF2E2E80), Color(0xFF7C3AED)]
                                  : [AppTheme.primaryElectricBlue, AppTheme.secondaryPurple],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _state == RecorderState.recording
                                ? Colors.redAccent.withAlpha(89)
                                : (isDark
                                    ? Colors.purpleAccent.withAlpha(89)
                                    : AppTheme.primaryElectricBlue.withAlpha(60)),
                            blurRadius: 24,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        _state == RecorderState.recording
                            ? Icons.stop_rounded
                            : _state == RecorderState.reviewing ||
                                    _state == RecorderState.playing
                                ? Icons.check_circle_outline
                                : Icons.mic,
                        color: Colors.white,
                        size: _state == RecorderState.recording ? 36 : 42,
                      ),
                    ),
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
              activeColor: _state == RecorderState.recording
                  ? Colors.redAccent
                  : (isDark ? Colors.purpleAccent : AppTheme.primaryElectricBlue),
              inactiveColor: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              _state == RecorderState.recording
                  ? "Keep speaking naturally - we're learning your voice"
                  : _state == RecorderState.reviewing
                      ? 'Review your recording and upload when ready'
                      : _state == RecorderState.playing
                          ? 'Playing your recording...'
                          : (widget.prompt ??
                              'Tap the mic and speak naturally'),
              style: TextStyle(color: AppTheme.getSecondaryTextColor(context)),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // review controls
            if (_state == RecorderState.reviewing ||
                _state == RecorderState.playing)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _pillButton(
                    _state == RecorderState.playing
                        ? Icons.pause
                        : Icons.play_arrow,
                    _state == RecorderState.playing ? 'Pause' : 'Play',
                    _playRecording,
                  ),
                  const SizedBox(width: 12),
                  _pillButton(Icons.delete_outline, 'Delete', _deleteRecording),
                  const SizedBox(width: 12),
                  _pillButton(
                    Icons.cloud_upload_outlined,
                    'Upload',
                    _upload,
                    key: const Key('voice-upload-button'),
                    isPrimary: true,
                  ),
                ],
              ),

            // uploading indicator
            if (_state == RecorderState.uploading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: isDark ? Colors.purpleAccent : AppTheme.primaryElectricBlue),
                    ),
                    const SizedBox(width: 8),
                    Text('Uploading your voice sample...',
                        style: TextStyle(color: AppTheme.getSecondaryTextColor(context))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(IconData icon, String label, VoidCallback onTap,
      {Key? key, bool isPrimary = false}) {
    final isDark = AppTheme.isDarkMode(context);
    final primaryColor = isDark ? Colors.purpleAccent : AppTheme.primaryElectricBlue;
    final defaultColor = isDark ? Colors.white : AppTheme.darkText;
    final defaultBgColor = isDark ? Colors.white.withAlpha(20) : Colors.grey.shade200;
    final defaultBorderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary
              ? primaryColor.withAlpha(50)
              : defaultBgColor,
          border: Border.all(
            color: isPrimary ? primaryColor : defaultBorderColor,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(icon, color: isPrimary ? primaryColor : defaultColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? primaryColor : defaultColor,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
