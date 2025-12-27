import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
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

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProxyProvider<CallProvider, ContactsProvider>(
          create: (_) => ContactsProvider(),
          update: (_, callProvider, contactsProvider) =>
              contactsProvider!..updateCallProvider(callProvider),
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final callProvider = Provider.of<CallProvider>(context, listen: false);

    final token = await authProvider.checkAuthStatus();

    if (mounted) {
      if (token != null) {
        debugPrint('[MyApp] User is authenticated, connecting to lobby...');
        // Connect to lobby with the valid token
        callProvider.connectToLobby(token: token);
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
    final callProvider = Provider.of<CallProvider>(context, listen: false);

    authProvider.setOnLogoutCallback(() {
      callProvider.disconnectFromLobby();
    });
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
        final callProvider = Provider.of<CallProvider>(context, listen: false);

        if (authProvider.isAuthenticated) {
          // FIX: Check if we are in an active call to avoid disrupting it
          if (callProvider.status == CallStatus.active ||
              callProvider.status == CallStatus.ringing ||
              callProvider.incomingCall != null) {
            debugPrint(
                '[App] In active/ringing call - skipping Lobby reconnection');
            return;
          }

          debugPrint(
              '[App] User authenticated, reconnecting/refreshing connection...');
          // We can get the token from shared prefs or auth provider
          SharedPreferences.getInstance().then((prefs) {
            final token = prefs.getString('user_token');
            if (token != null) {
              callProvider.connectToLobby(token: token);
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
