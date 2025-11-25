import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/custom_button.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController(text: "demo@user.com");
  final TextEditingController _passController = TextEditingController(text: "123456");

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
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
              CustomButton(
                text: "Login",
                isLoading: authProvider.isLoading,
                onPressed: () async {
                  bool success = await authProvider.login(
                    _emailController.text,
                    _passController.text,
                  );
                  if (success) {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}