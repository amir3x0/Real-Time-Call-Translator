import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/call_provider.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ContactsProvider>(context, listen: false).loadContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final contactsProv = Provider.of<ContactsProvider>(context);
    final callProv = Provider.of<CallProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: contactsProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: contactsProv.contacts.length,
                    itemBuilder: (context, index) {
                      final c = contactsProv.contacts[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(c.name[0])),
                        title: Text(c.name),
                        subtitle: Text('${c.status} • ${c.language}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.call, color: Colors.green),
                              onPressed: () {
                                // Start a mock call to this contact
                                callProv.startMockCall();
                                Navigator.pushNamed(context, '/call');
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await contactsProv.removeContact(c.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(hintText: 'Contact name'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedLanguage,
                        items: const [
                          DropdownMenuItem(value: 'he', child: Text('🇮🇱 he')),
                          DropdownMenuItem(value: 'en', child: Text('🇺🇸 en')),
                          DropdownMenuItem(value: 'ru', child: Text('🇷🇺 ru')),
                        ],
                        onChanged: (v) => setState(() => _selectedLanguage = v ?? 'en'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (_nameController.text.trim().isEmpty) return;
                          await contactsProv.addContact(_nameController.text.trim(), _selectedLanguage);
                          _nameController.clear();
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
