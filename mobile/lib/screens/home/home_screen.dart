import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/call_provider.dart';
import '../call/active_call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Mock Contacts Data
  final List<Map<String, dynamic>> _contacts = [
    {'name': 'Daniel Fraimovich', 'lang': '🇷🇺', 'status': 'Online'},
    {'name': 'Dr. Dan Lemberg', 'lang': '🇮🇱', 'status': 'Away'},
    {'name': 'John Doe', 'lang': '🇺🇸', 'status': 'Offline'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Call Translator"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {},
          )
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: "Contacts"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Recents"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_currentIndex == 0) {
      return ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final contact = _contacts[index];
          return ListTile(
            leading: CircleAvatar(child: Text(contact['name'][0])),
            title: Text(contact['name']),
            subtitle: Text("${contact['status']} • ${contact['lang']}"),
            trailing: IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () {
                // START MOCK CALL
                Provider.of<CallProvider>(context, listen: false).startMockCall();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ActiveCallScreen()),
                );
              },
            ),
          );
        },
      );
    } else if (_currentIndex == 1) {
      return const Center(child: Text("Recent Calls History"));
    } else {
      return const Center(child: Text("Settings Screen"));
    }
  }
}