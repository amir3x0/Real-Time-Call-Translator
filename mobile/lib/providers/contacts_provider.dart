import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/contact.dart';
import '../models/user.dart';
import '../data/api/api_service.dart';
import '../data/websocket/websocket_service.dart';
import 'lobby_provider.dart';

/// Result of adding a contact
enum AddContactResult {
  success,
  userNotFound,
  alreadyExists,
  error,
}

/// Provider for managing contacts with multi-selection support.
class ContactsProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  LobbyProvider? _lobbyProvider;
  StreamSubscription? _lobbyEventsSub;

  void updateLobbyProvider(LobbyProvider lobbyProvider) {
    if (_lobbyProvider == lobbyProvider) return;
    _lobbyProvider = lobbyProvider;
    _lobbyEventsSub?.cancel();
    _listenToLobbyEvents();
  }

  ContactsProvider();

  void _listenToLobbyEvents() {
    _lobbyEventsSub = _lobbyProvider?.events.listen((event) {
      if (event.type == WSMessageType.contactRequest) {
        refreshContacts();
      } else if (event.type == WSMessageType.userStatusChanged) {
        final data = event.data;
        if (data != null) {
          updateContactStatus(data['user_id'] as String? ?? '',
              data['is_online'] as bool? ?? false);
        }
      }
    });
  }

  @override
  void dispose() {
    _lobbyEventsSub?.cancel();
    super.dispose();
  }

  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  List<Contact> _pendingIncoming = [];
  List<Contact> _pendingOutgoing = [];
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

  /// Incoming friend requests
  List<Contact> get pendingIncoming => List.unmodifiable(_pendingIncoming);

  /// Outgoing pending requests
  List<Contact> get pendingOutgoing => List.unmodifiable(_pendingOutgoing);

  /// All contacts without filtering
  List<Contact> get allContacts => List.unmodifiable(_allContacts);

  /// Currently selected contacts
  List<Contact> get selectedContacts =>
      _allContacts.where((c) => _selectedContactIds.contains(c.id)).toList();

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

      // Parse main contacts
      final contactsConfig = contactsData['contacts'] as List? ?? [];
      final mainContacts = contactsConfig
          .map((json) {
            if (json is Map<String, dynamic>) {
              return Contact.fromJson(json);
            }
            return null;
          })
          .whereType<Contact>()
          .toList();

      // Parse incoming requests
      final incomingConfig = contactsData['pending_incoming'] as List? ?? [];
      final incoming = incomingConfig
          .map((json) {
            if (json is! Map<String, dynamic>) return null;

            // Transform request format to Contact for UI
            final requester = json['requester'];
            if (requester == null) return null;

            return Contact(
              id: json['request_id'] ??
                  json['contact_id'] ??
                  '', // Use request_id for actions
              userId: requester['id'], // Requester is the 'user'
              contactUserId: '', // Not needed for UI here
              contactName: requester['full_name'],
              addedAt:
                  DateTime.tryParse(json['added_at'] ?? '') ?? DateTime.now(),
              fullName: requester['full_name'],
              phone: requester['phone'],
              primaryLanguage: requester['primary_language'],
              isOnline: requester['is_online'],
              status: 'pending',
            );
          })
          .whereType<Contact>()
          .toList();

      // Parse outgoing requests
      final outgoingConfig = contactsData['pending_outgoing'] as List? ?? [];
      final outgoing = outgoingConfig
          .map((json) {
            if (json is Map<String, dynamic>) {
              return Contact.fromJson(json);
            }
            return null;
          })
          .whereType<Contact>()
          .toList();

      _allContacts = mainContacts.cast<Contact>();
      _pendingIncoming = incoming.cast<Contact>();
      _pendingOutgoing = outgoing.cast<Contact>();

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
    _pendingIncoming.clear();
    _pendingOutgoing.clear();
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
        final nameMatch =
            contact.displayName.toLowerCase().contains(_searchQuery);
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

  /// Accept a friend request
  Future<bool> acceptContactRequest(String requestId) async {
    _setLoading(true);
    try {
      await _api.acceptContactRequest(requestId);
      await refreshContacts();
      return true;
    } catch (e) {
      _error = 'Failed to accept request: $e';
      debugPrint(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reject a friend request
  Future<bool> rejectContactRequest(String requestId) async {
    _setLoading(true);
    try {
      await _api.rejectContactRequest(requestId);
      _pendingIncoming.removeWhere((c) => c.id == requestId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to reject request: $e';
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

  /// Update contact online status
  void updateContactStatus(String contactUserId, bool isOnline) {
    bool updated = false;
    for (int i = 0; i < _allContacts.length; i++) {
      if (_allContacts[i].contactUserId == contactUserId) {
        _allContacts[i] = _allContacts[i].copyWith(isOnline: isOnline);
        updated = true;
        break;
      }
    }
    if (updated) {
      _applyFilter();
    }
  }
}
