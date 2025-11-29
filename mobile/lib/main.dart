import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/contacts_provider.dart';
import 'services/heartbeat_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/register_voice_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/call/active_call_screen.dart';
import 'screens/call/select_participants_screen.dart';
import 'screens/call/call_confirmation_screen.dart';
import 'screens/contacts/contacts_screen.dart';
import 'screens/contacts/add_contact_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'config/app_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final HeartbeatService _heartbeatService = HeartbeatService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground - start heartbeat
        debugPrint('[App] Resumed - starting heartbeat');
        _startHeartbeatIfLoggedIn();
        break;
      
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is in background - stop heartbeat
        debugPrint('[App] Paused/Inactive - stopping heartbeat');
        _heartbeatService.stop();
        break;
      
      case AppLifecycleState.detached:
        // App is being terminated
        debugPrint('[App] Detached - cleaning up');
        _heartbeatService.stop();
        break;
      
      case AppLifecycleState.hidden:
        // App is hidden (iOS)
        debugPrint('[App] Hidden - stopping heartbeat');
        _heartbeatService.stop();
        break;
    }
  }

  Future<void> _startHeartbeatIfLoggedIn() async {
    // Check if user is logged in (retrieve from your auth provider/storage)
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final sessionId = prefs.getString('session_id') ?? 'default_session';
    
    if (userId != null && userId.isNotEmpty) {
      final wsUrl = '${AppConfig.wsUrl}/ws/$sessionId';
      await _heartbeatService.start(
        wsUrl: wsUrl,
        userId: userId,
        sessionId: sessionId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ContactsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Real-Time Call Translator',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            initialRoute: '/',
            routes: {
              // Auth Flow
              '/': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/register/voice': (context) => const RegisterVoiceScreen(),
              
              // Main App
              '/home': (context) => const HomeScreen(),
              
              // Call Flow (ordered)
              '/call/select': (context) => const SelectParticipantsScreen(),
              '/call/confirm': (context) => const CallConfirmationScreen(),
              '/call/active': (context) => const ActiveCallScreen(),
              
              // Contacts
              '/contacts': (context) => const ContactsScreen(),
              '/contacts/add': (context) => const AddContactScreen(),
              
              // Settings
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}
