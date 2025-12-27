import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// A custom [StreamAudioSource] that wraps a raw PCM stream with a WAV header
/// to allow playback via players that expect standard formats (like ExoPlayer/AVAudioPlayer).
///
/// This implementation handles:
/// - Streaming WAV header followed by PCM data
/// - Graceful error handling for stream interruptions
/// - Initial silence buffer to prevent timeout errors
class PCMStreamSource extends StreamAudioSource {
  final Stream<List<int>> audioStream;
  final int sampleRate;
  final int channels;
  final int bitDepth;

  /// Flag to track if the source has been disposed
  bool _disposed = false;

  PCMStreamSource({
    required this.audioStream,
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitDepth = 16,
  });

  /// Mark this source as disposed to stop yielding data
  void dispose() {
    _disposed = true;
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // If already disposed, return an empty stream to avoid null errors
    if (_disposed) {
      debugPrint('[PCMStreamSource] Source disposed, returning empty stream');
      return StreamAudioResponse(
        sourceLength: null,
        contentLength: null,
        offset: 0,
        stream: const Stream.empty(),
        contentType: 'audio/wav',
      );
    }

    return StreamAudioResponse(
      sourceLength: null,
      contentLength: null,
      offset: 0,
      stream: _createWavStream(),
      contentType: 'audio/wav',
    );
  }

  Stream<List<int>> _createWavStream() async* {
    // Yield WAV header first
    yield _createWavHeader();

    // Inject 2 seconds of silence to prime the player immediately
    // This prevents SocketTimeoutException if the WebSocket stream is initially silent
    // Using smaller chunks to be more responsive
    const silenceChunkSize = 3200; // 100ms of audio at 16kHz, 16-bit mono
    const silenceChunks = 20; // 2 seconds total

    for (int i = 0; i < silenceChunks && !_disposed; i++) {
      yield List<int>.filled(silenceChunkSize, 0);
      // Small delay to prevent overwhelming the buffer
      await Future.delayed(const Duration(milliseconds: 10));
    }

    if (_disposed) {
      debugPrint('[PCMStreamSource] Disposed during silence injection');
      return;
    }

    // Now stream the actual audio data
    try {
      await for (var chunk in audioStream) {
        if (_disposed) {
          debugPrint('[PCMStreamSource] Disposed during audio streaming');
          break;
        }
        if (chunk.isNotEmpty) {
          yield chunk;
        }
      }
    } catch (e) {
      if (!_disposed) {
        debugPrint('[PCMStreamSource] Stream error: $e');
      }
      // Don't rethrow - gracefully end the stream
    }

    debugPrint('[PCMStreamSource] Stream ended');
  }

  Uint8List _createWavHeader() {
    // Use a very large file size for streaming (max signed 32-bit int)
    const int fileSize = 2147483647;
    const int sampleRate = 16000;
    const int channels = 1;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const int blockAlign = channels * bitsPerSample ~/ 8;

    final header = ByteData(44);

    // RIFF chunk
    _writeString(header, 0, 'RIFF');
    header.setUint32(4, fileSize, Endian.little);
    _writeString(header, 8, 'WAVE');

    // fmt chunk
    _writeString(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little); // format (1 = PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    _writeString(header, 36, 'data');
    header.setUint32(40, fileSize - 44, Endian.little); // data size

    return header.buffer.asUint8List();
  }

  void _writeString(ByteData data, int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }
}
