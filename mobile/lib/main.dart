import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/contacts_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/register_voice_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/call/active_call_screen.dart';
import 'screens/contacts/contacts_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
              '/': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/call': (context) => const ActiveCallScreen(),
              '/contacts': (context) => const ContactsScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/register': (context) => const RegisterScreen(),
              '/register/voice': (context) => const RegisterVoiceScreen(),
            },
          );
        },
      ),
    );
  }
}
