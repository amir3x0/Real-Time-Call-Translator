import 'package:flutter/material.dart';
import '../data/api/api_service.dart';

class ContactItem {
  final String id;
  final String name;
  final String phone;
  final String languageCode;
  final String status;

  ContactItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.languageCode,
    required this.status,
  });
}

class ContactsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<ContactItem> _allContacts = [];
  List<ContactItem> _visibleContacts = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<ContactItem> get contacts => List.unmodifiable(_visibleContacts);
  bool get isLoading => _isLoading;

  Future<void> loadContacts() async {
    _setLoading(true);
    final list = await _apiService.getContacts();
    _allContacts
      ..clear()
      ..addAll(list.map(_mapToContact));
    _applyFilter();
    _setLoading(false);
  }

  Future<void> addContact({
    required String name,
    required String phone,
    required String language,
  }) async {
    _setLoading(true);
    final created = await _apiService.createContact(name, language, phone: phone);
    _allContacts.add(_mapToContact(created));
    _applyFilter();
    _setLoading(false);
  }

  Future<void> removeContact(String id) async {
    _setLoading(true);
    await _apiService.deleteContact(id);
    _allContacts.removeWhere((c) => c.id == id);
    _applyFilter();
    _setLoading(false);
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applyFilter();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _visibleContacts = List<ContactItem>.from(_allContacts);
    } else {
      // Search by name OR phone number
      _visibleContacts = _allContacts
          .where((c) =>
              c.name.toLowerCase().contains(_searchQuery) ||
              c.phone.replaceAll(RegExp(r'[^0-9]'), '').contains(
                  _searchQuery.replaceAll(RegExp(r'[^0-9]'), '')))
          .toList(growable: false);
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  ContactItem _mapToContact(Map<String, dynamic> json) {
    return ContactItem(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      phone: json['phone'] ?? '',
      languageCode: json['language'] ?? 'en',
      status: json['status'] ?? 'offline',
    );
  }
}
