import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/lobby_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/contacts_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'models/call.dart';
import 'screens/auth/register_voice_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/call/active_call_screen.dart';
import 'screens/call/select_participants_screen.dart';
import 'screens/call/call_confirmation_screen.dart';
import 'screens/call/incoming_call_screen.dart';
import 'screens/contacts/contacts_screen.dart';
import 'screens/contacts/add_contact_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'data/services/auth_service.dart';
import 'data/services/contact_service.dart';
import 'data/services/call_api_service.dart';
import 'data/websocket/websocket_service.dart';
import 'services/permission_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AppConfig to load runtime backend host/port from SharedPreferences
  await AppConfig.initialize();

  // Initialize settings provider with local theme preference
  final settingsProvider = SettingsProvider();
  await settingsProvider.initialize();

  final authService = AuthService();
  final contactService = ContactService();
  final callApiService = CallApiService();
  final lobbyWsService = WebSocketService();
  final callWsService = WebSocketService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(
          create: (_) => CallProvider(
            wsService: callWsService,
            apiService: callApiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LobbyProvider(
            wsService: lobbyWsService,
            apiService: callApiService,
          ),
        ),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProxyProvider<LobbyProvider, ContactsProvider>(
          create: (_) => ContactsProvider(contactService),
          update: (_, lobbyProvider, contactsProvider) =>
              contactsProvider!..updateLobbyProvider(lobbyProvider),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isAuthChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Setup callbacks and connect to lobby on start if logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupLogoutCallback();
      _initAuth();
    });
  }

  /// Check authentication status on startup
  Future<void> _initAuth() async {
    // Request microphone permission on first launch (before any call)
    await _requestInitialPermissions();

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final lobbyProvider = Provider.of<LobbyProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    final token = await authProvider.checkAuthStatus();

    if (mounted) {
      if (token != null) {
        debugPrint('[MyApp] User is authenticated, connecting to lobby...');
        // Connect to lobby with the valid token and userId
        if (authProvider.currentUser != null) {
          lobbyProvider.connect(token, authProvider.currentUser!.id);
          // Apply server theme preference (server wins)
          settingsProvider.applyServerTheme(authProvider.currentUser!.themePreference);
        }
      } else {
        debugPrint('[MyApp] User is NOT authenticated, waiting for login...');
      }

      setState(() {
        _isAuthChecked = true;
      });
    }
  }

  /// Setup callback to disconnect from Lobby when user logs out
  void _setupLogoutCallback() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final lobbyProvider = Provider.of<LobbyProvider>(context, listen: false);

    authProvider.setOnLogoutCallback(() {
      lobbyProvider.disconnect();
    });
  }

  /// Request permissions on first app launch
  Future<void> _requestInitialPermissions() async {
    if (await PermissionService.shouldRequestMicrophonePermission()) {
      debugPrint('[MyApp] First launch - requesting microphone permission...');
      final granted = await PermissionService.requestMicrophonePermission();
      debugPrint(
          '[MyApp] Microphone permission ${granted ? 'granted' : 'denied'}');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground - reconnect to lobby if authenticated
        debugPrint('[App] Resumed - checking connection...');
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final lobbyProvider =
            Provider.of<LobbyProvider>(context, listen: false);
        final callProvider = Provider.of<CallProvider>(context, listen: false);

        if (authProvider.isAuthenticated) {
          // FIX: Check if we are in an active call to avoid disrupting it
          if (callProvider.status == CallStatus.ongoing ||
              callProvider.status == CallStatus.ringing ||
              callProvider.status == CallStatus.initiating ||
              lobbyProvider.incomingCall != null) {
            debugPrint(
                '[App] In active/ringing/initiating call - skipping Lobby reconnection');
            return;
          }

          debugPrint(
              '[App] User authenticated, reconnecting/refreshing connection...');
          // We can get the token from shared prefs or auth provider
          SharedPreferences.getInstance().then((prefs) {
            final token = prefs.getString('user_token');
            final userId = prefs.getString('user_id');
            if (token != null && userId != null) {
              lobbyProvider.connect(token, userId);
            }
          });
        }
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is in background
        debugPrint('[App] Paused/Inactive');
        break;

      case AppLifecycleState.detached:
        debugPrint('[App] Detached');
        break;

      case AppLifecycleState.hidden:
        break;
    }
  }

  // Removed _connectToLobby as it is replaced by _initAuth and explicit calls

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'Real-Time Call Translator',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          // If auth hasn't been checked yet, show a splash screen/loader
          // Otherwise, navigate based on authentication state
          home: !_isAuthChecked
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : (context.read<AuthProvider>().isAuthenticated
                  ? const HomeScreen()
                  : const LoginScreen()),
          routes: {
            // Auth Flow
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/register/voice': (context) => const RegisterVoiceScreen(),

            // Main App
            '/home': (context) => const HomeScreen(),

            // Call Flow (ordered)
            '/call/select': (context) => const SelectParticipantsScreen(),
            '/call/confirm': (context) => const CallConfirmationScreen(),
            '/call/incoming': (context) => const IncomingCallScreen(),
            '/call/active': (context) => const ActiveCallScreen(),

            // Contacts
            '/contacts': (context) => const ContactsScreen(),
            '/contacts/add': (context) => const AddContactScreen(),

            // Settings
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
