import 'dart:async';

/// Mock WebSocket service that emits fake live transcription events
class WebSocketService {
  StreamController<String>? _controller;
  Timer? _timer;

  Stream<String> get messages => _controller?.stream ?? const Stream.empty();

  void start(String sessionId) {
    _controller = StreamController<String>.broadcast();
    // Emit periodic mock transcription messages
    int index = 0;
    List<String> messages = [
      'Hello — שלום',
      'Testing 1, 2, 3...',
      'Translating...',
      'התרגום הושלם',
      'Final short message',
    ];
    // Emit first message immediately for responsiveness
    _controller?.add(messages[index % messages.length]);
    index++;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _controller?.add(messages[index % messages.length]);
      index++;
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _controller?.close();
    _controller = null;
  }

  void send(String payload) {
    // In a mock we just echo back after a small delay
    Future.delayed(const Duration(milliseconds: 200), () {
      _controller?.add('ECHO: $payload');
    });
  }
}
