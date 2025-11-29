import 'package:flutter/foundation.dart';

import '../models/contact.dart';
import '../models/user.dart';
import '../data/api/api_service.dart';

/// Result of adding a contact
enum AddContactResult {
  success,
  userNotFound,
  alreadyExists,
  error,
}

/// Provider for managing contacts with multi-selection support.
/// 
/// This provider handles:
/// - Loading and caching contacts from the real backend API
/// - Searching/filtering contacts
/// - Multi-selection for group calls (up to 3 contacts)
/// - Adding new contacts
class ContactsProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  final Set<String> _selectedContactIds = {};
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;

  // Maximum number of contacts that can be selected (4 participants total including user)
  static const int maxSelectable = 3;

  // ========== Getters ==========
  
  /// Filtered contacts based on search query
  List<Contact> get contacts => List.unmodifiable(_filteredContacts);
  
  /// All contacts without filtering
  List<Contact> get allContacts => List.unmodifiable(_allContacts);
  
  /// Currently selected contacts
  List<Contact> get selectedContacts => _allContacts
      .where((c) => _selectedContactIds.contains(c.id))
      .toList();
  
  /// Number of selected contacts
  int get selectedCount => _selectedContactIds.length;
  
  /// Whether any contacts are selected
  bool get hasSelection => _selectedContactIds.isNotEmpty;
  
  /// Whether maximum selection is reached
  bool get isMaxSelected => _selectedContactIds.length >= maxSelectable;

  /// Whether more contacts can be selected
  bool get canSelectMore => _selectedContactIds.length < maxSelectable;
  
  /// Loading state
  bool get isLoading => _isLoading;
  
  /// Error message if any
  String? get error => _error;
  
  /// Current search query
  String get searchQuery => _searchQuery;

  // ========== Loading ==========
  
  /// Load contacts from API
  Future<void> loadContacts() async {
    if (_initialized && _allContacts.isNotEmpty) {
      notifyListeners();
      return;
    }

    _setLoading(true);
    _error = null;

    try {
      final contactsData = await _api.getContacts();
      _allContacts = contactsData.map((json) => Contact.fromJson(json)).toList();
      _applyFilter();
      _initialized = true;
    } catch (e) {
      _error = 'Failed to load contacts: $e';
      debugPrint(_error);
    } finally {
      _setLoading(false);
    }
  }

  /// Force refresh contacts
  Future<void> refreshContacts() async {
    _initialized = false;
    _allContacts.clear();
    await loadContacts();
  }

  // ========== Search & Filter ==========
  
  /// Set search query and filter contacts
  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applyFilter();
  }

  /// Clear search query
  void clearSearch() {
    _searchQuery = '';
    _applyFilter();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredContacts = List.from(_allContacts);
    } else {
      _filteredContacts = _allContacts.where((contact) {
        final nameMatch = contact.displayName.toLowerCase().contains(_searchQuery);
        final phoneMatch = (contact.phone ?? '')
            .replaceAll(RegExp(r'\D'), '')
            .contains(_searchQuery.replaceAll(RegExp(r'\D'), ''));
        return nameMatch || phoneMatch;
      }).toList();
    }
    notifyListeners();
  }

  // ========== Selection ==========
  
  /// Check if a contact is selected
  bool isSelected(String contactId) => _selectedContactIds.contains(contactId);

  /// Toggle selection for a contact
  void toggleSelection(String contactId) {
    if (_selectedContactIds.contains(contactId)) {
      _selectedContactIds.remove(contactId);
    } else if (_selectedContactIds.length < maxSelectable) {
      _selectedContactIds.add(contactId);
    }
    notifyListeners();
  }

  /// Select a contact (if not at max)
  void selectContact(String contactId) {
    if (_selectedContactIds.length < maxSelectable) {
      _selectedContactIds.add(contactId);
      notifyListeners();
    }
  }

  /// Deselect a contact
  void deselectContact(String contactId) {
    if (_selectedContactIds.remove(contactId)) {
      notifyListeners();
    }
  }

  /// Clear all selections
  void clearSelection() {
    if (_selectedContactIds.isNotEmpty) {
      _selectedContactIds.clear();
      notifyListeners();
    }
  }

  /// Select multiple contacts at once
  void selectContacts(List<String> contactIds) {
    for (final id in contactIds) {
      if (_selectedContactIds.length >= maxSelectable) break;
      _selectedContactIds.add(id);
    }
    notifyListeners();
  }

  // ========== Contact Management ==========
  
  /// Search for users by query (for adding new contacts)
  Future<List<User>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final results = await _api.searchUsers(query);
      return results.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Search users error: $e');
      return [];
    }
  }

  /// Add a contact by user ID
  Future<AddContactResult> addContact(String userId) async {
    _setLoading(true);
    _error = null;

    try {
      // Check if already in contacts
      if (_allContacts.any((c) => c.contactUserId == userId)) {
        return AddContactResult.alreadyExists;
      }

      await _api.addContact(userId);
      await refreshContacts();
      return AddContactResult.success;
    } catch (e) {
      if (e.toString().contains('409') || e.toString().contains('already')) {
        return AddContactResult.alreadyExists;
      }
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        return AddContactResult.userNotFound;
      }
      _error = 'Failed to add contact: $e';
      debugPrint(_error);
      return AddContactResult.error;
    } finally {
      _setLoading(false);
    }
  }

  /// Remove a contact
  Future<bool> removeContact(String contactId) async {
    _setLoading(true);
    try {
      await _api.deleteContact(contactId);
      _allContacts.removeWhere((c) => c.id == contactId);
      _selectedContactIds.remove(contactId);
      _applyFilter();
      return true;
    } catch (e) {
      _error = 'Failed to remove contact: $e';
      debugPrint(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Toggle favorite status (calls backend if available)
  Future<bool> toggleFavorite(String contactId) async {
    try {
      // Update locally first for instant feedback
      final index = _allContacts.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        final contact = _allContacts[index];
        _allContacts[index] = contact.copyWith(isFavorite: !contact.isFavorite);
        _applyFilter();
      }
      
      // Backend API call can be added here when endpoint is implemented
      
      return true;
    } catch (e) {
      debugPrint('Failed to toggle favorite: $e');
      return false;
    }
  }

  // ========== Helpers ==========
  
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Get a contact by ID
  Contact? getContactById(String contactId) {
    return _allContacts.cast<Contact?>().firstWhere(
      (c) => c!.id == contactId,
      orElse: () => null,
    );
  }

  /// Get contacts sorted by favorites first, then by name
  List<Contact> get sortedContacts {
    final sorted = List<Contact>.from(_filteredContacts);
    sorted.sort((a, b) {
      // Favorites first
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      // Online users next
      if ((a.isOnline ?? false) && !(b.isOnline ?? false)) return -1;
      if (!(a.isOnline ?? false) && (b.isOnline ?? false)) return 1;
      // Then by name
      return a.displayName.compareTo(b.displayName);
    });
    return sorted;
  }

  /// Get online contacts count
  int get onlineCount => _allContacts.where((c) => c.isOnline ?? false).length;
}
