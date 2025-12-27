import 'dart:async';

/// Mock audio service: simulates recording and playback and emits audio chunks
class AudioService {
	StreamController<List<int>>? _chunksController;
	Timer? _timer;
	bool _isRecording = false;

	Stream<List<int>> get chunks => _chunksController?.stream ?? const Stream.empty();

	void startRecording() {
		if (_isRecording) return;
		_isRecording = true;
		_chunksController = StreamController<List<int>>.broadcast();
		int count = 0;
		_timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
			// Generate mock audio chunk as bytes
			final chunk = List<int>.filled(1600, count % 255);
			_chunksController?.add(chunk);
			count++;
		});
	}

	void stopRecording() {
		if (!_isRecording) return;
		_isRecording = false;
		_timer?.cancel();
		_timer = null;
		_chunksController?.close();
		_chunksController = null;
	}

	Future<void> playAudio(List<int> bytes) async {
		// Mock play by waiting a short time
		await Future.delayed(const Duration(milliseconds: 300));
	}
}
