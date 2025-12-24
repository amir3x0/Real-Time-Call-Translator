import 'dart:async';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

/// A custom [StreamAudioSource] that wraps a raw PCM stream with a WAV header
/// to allow playback via players that expect standard formats (like ExtPlayer/AVAudioPlayer).
class PCMStreamSource extends StreamAudioSource {
  final Stream<List<int>> audioStream;
  final int sampleRate;
  final int channels;
  final int bitDepth;

  PCMStreamSource({
    required this.audioStream,
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitDepth = 16,
  });

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // We ignore start/end for live stream
    return StreamAudioResponse(
      sourceLength: null,
      contentLength: null,
      offset: 0,
      stream: _createWavStream(),
      contentType: 'audio/wav',
    );
  }

  Stream<List<int>> _createWavStream() async* {
    yield _createWavHeader();
    await for (var chunk in audioStream) {
      yield chunk;
    }
  }

  Uint8List _createWavHeader() {
    // Total size is unknown (-1 technically not supported in all RIFF, but MaxInt works for streams usually)
    // Or we use a very large number.
    const int fileSize = 2147483647; // Max Signed 32-bit Int
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
