import 'package:flutter/material.dart';
import '../data/api/api_service.dart';

class ContactItem {
  final String id;
  final String name;
  final String language;
  final String status;

  ContactItem({
    required this.id,
    required this.name,
    required this.language,
    required this.status,
  });
}

class ContactsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<ContactItem> _contacts = [];
  bool _isLoading = false;

  List<ContactItem> get contacts => _contacts;
  bool get isLoading => _isLoading;

  Future<void> loadContacts() async {
    _isLoading = true;
    notifyListeners();
    final list = await _apiService.getContacts();
    _contacts = list
        .map((c) => ContactItem(
              id: c['id'],
              name: c['name'],
              language: c['language'],
              status: c['status'],
            ))
        .toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addContact(String name, String language) async {
    _isLoading = true;
    notifyListeners();
    final created = await _apiService.createContact(name, language);
    _contacts.add(ContactItem(
      id: created['id'],
      name: created['name'],
      language: created['language'],
      status: created['status'],
    ));
    _isLoading = false;
    notifyListeners();
  }

  Future<void> removeContact(String id) async {
    _isLoading = true;
    notifyListeners();
    await _apiService.deleteContact(id);
    _contacts.removeWhere((c) => c.id == id);
    _isLoading = false;
    notifyListeners();
  }
}
