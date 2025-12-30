import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/websocket/websocket_service.dart';
import '../models/call.dart';
import 'incoming_call_handler.dart';
import '../data/api/api_service.dart';

/// Manages the "Global" WebSocket connection (Lobby).
///
/// Responsibilities:
/// - Connects to the Lobby on login
/// - Listens for Incoming Calls
/// - Listens for Contact Requests
/// - Listens for User Status Updates (Online/Offline)
class LobbyProvider with ChangeNotifier {
  final WebSocketService _wsService;
  final ApiService _apiService;

  StreamSubscription<WSMessage>? _wsSub;
  bool _isConnected = false;

  // Incoming Call Handler
  late final IncomingCallHandler _incomingCallHandler;

  // Events stream for other providers (e.g. ContactsProvider)
  final _eventController = StreamController<WSMessage>.broadcast();

  LobbyProvider({
    required WebSocketService wsService,
    required ApiService apiService,
  })  : _wsService = wsService,
        _apiService = apiService {
    _incomingCallHandler = IncomingCallHandler(_apiService, notifyListeners);
  }

  // === Getters ===
  bool get isConnected => _isConnected;
  Stream<WSMessage> get events => _eventController.stream;

  // Incoming Call State
  Call? get incomingCall => _incomingCallHandler.incomingCall;
  CallStatus? get incomingCallStatus => _incomingCallHandler.incomingCallStatus;
  String? get incomingCallerName => _incomingCallHandler.incomingCallerName;

  // === Connection Management ===

  /// Connect to the Lobby (Global Namespace)
  Future<void> connect(String token) async {
    debugPrint('[LobbyProvider] Connecting to Lobby...');
    final success = await _wsService.connect('lobby', token: token);

    if (success) {
      _isConnected = true;
      _wsSub?.cancel();
      _wsSub = _wsService.messages.listen(_handleWebSocketMessage);
      debugPrint('[LobbyProvider] Connected to Lobby');
    } else {
      _isConnected = false;
      debugPrint('[LobbyProvider] Failed to connect to Lobby');
    }
    notifyListeners();
  }

  /// Disconnect from Lobby (Logout)
  void disconnect() {
    debugPrint('[LobbyProvider] Disconnecting from Lobby...');
    _wsSub?.cancel();
    _wsService.disconnect();
    _isConnected = false;
    notifyListeners();
  }

  // === Message Handling ===

  void _handleWebSocketMessage(WSMessage message) {
    // Broadcast for other listeners (e.g. ContactsProvider)
    if (!_eventController.isClosed) {
      _eventController.add(message);
    }

    switch (message.type) {
      case WSMessageType.incomingCall:
        _incomingCallHandler.handleIncomingCall(message.data);
        notifyListeners();
        break;

      // Status changes and Contact requests are handled by ContactsProvider
      // listening to the event stream, but we can store last state here if needed.

      case WSMessageType.error:
        debugPrint('[LobbyProvider] WebSocket error: ${message.data}');
        break;

      default:
        break;
    }
  }

  // === Incoming Call Actions ===

  Future<Map<String, dynamic>?> acceptIncomingCall() async {
    return _incomingCallHandler.acceptIncomingCall();
    // Note: The actual navigation and switching to CallProvider happens in the UI
  }

  Future<void> rejectIncomingCall() async {
    await _incomingCallHandler.rejectIncomingCall();
    notifyListeners();
  }

  @override
  void dispose() {
    _eventController.close();
    _wsSub?.cancel();
    _wsService.disconnect();
    _incomingCallHandler.dispose();
    super.dispose();
  }
}
