import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated_button.dart';
import '../../widgets/flash_bar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController(text: "demo@user.com");
  final TextEditingController _passController = TextEditingController(text: "123456");
  String? _error;

  bool _isValidEmail(String v) => v.contains('@');
  bool _isValidPass(String v) => v.length >= 6;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Subtle animated gradient background
          AnimatedContainer(
            duration: const Duration(seconds: 3),
            curve: Curves.easeInOut,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F1630), Color(0xFF1B2750)],
              ),
            ),
          ),
          SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.translate, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "Call Translator",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null) FlashBar(message: _error!),
              const SizedBox(height: 12),
              AnimatedButton(
                label: "Login",
                onPressed: () async {
                  final emailOk = _isValidEmail(_emailController.text);
                  final passOk = _isValidPass(_passController.text);
                  if (!emailOk || !passOk) {
                    setState(() => _error = 'Invalid credentials');
                    return false;
                  }
                  final success = await authProvider.login(
                    _emailController.text,
                    _passController.text,
                  );
                  if (success) {
                    if (mounted) Navigator.pushReplacementNamed(context, '/home');
                    return true;
                  } else {
                    setState(() => _error = 'Login failed');
                    return false;
                  }
                },
              ),
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }
}