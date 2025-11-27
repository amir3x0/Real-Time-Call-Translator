import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../data/api/api_service.dart';
import '../../widgets/voice_recorder_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLang = 'en';
  String? _voiceSamplePath;

  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    // initialize selected language from SettingsProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
      setState(() => _selectedLang = settingsProv.appLanguage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProv = Provider.of<SettingsProvider>(context);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            ListTile(
              title: const Text('Theme'),
              subtitle: Text(settingsProv.themeMode == ThemeMode.light ? 'Light' : 'Dark'),
              trailing: Switch(
                value: settingsProv.themeMode == ThemeMode.dark,
                onChanged: (v) => settingsProv.toggleTheme(),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('App Language'),
              subtitle: Text(_selectedLang),
              trailing: DropdownButton<String>(
                value: _selectedLang,
                items: const [
                  DropdownMenuItem(value: 'he', child: Text('עברית')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ru', child: Text('Русский')),
                ],
                onChanged: (v) {
                  setState(() => _selectedLang = v ?? 'en');
                  settingsProv.setLanguage(_selectedLang);
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Voice Sample', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  VoiceRecorderWidget(
                    onUpload: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final result = await _api.uploadVoiceSample('user_1', '/mock/path/sample.wav');
                      if (!mounted) return;
                      setState(() {
                        _voiceSamplePath = result['path'];
                      });
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Voice sample uploaded'), behavior: SnackBarBehavior.floating),
                      );
                    },
                    onDelete: () async {
                      await _api.deleteVoiceSample('user_1');
                      setState(() => _voiceSamplePath = null);
                    },
                    onPlay: () async {
                      // Could integrate with AudioService; mock for now
                      await Future.delayed(const Duration(milliseconds: 300));
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _voiceSamplePath == null ? 'No sample uploaded' : _voiceSamplePath!,
                    style: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  authProv.logout();
                  Navigator.pushReplacementNamed(context, '/');
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            )
          ],
          ),
        ),
      ),
    );
  }
}
