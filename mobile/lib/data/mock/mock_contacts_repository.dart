import '../../models/user.dart';
import '../../models/contact.dart';
import 'mock_data.dart';

/// Result of adding a contact
enum AddContactResult {
  success,
  userNotFound,
  alreadyExists,
  error,
}

/// Mock repository for contacts operations.
/// 
/// Simulates backend API calls with realistic delays.
/// Uses MockData for the underlying data.
class MockContactsRepository {
  final String _currentUserId;
  final List<Contact> _contacts = [];
  bool _initialized = false;

  MockContactsRepository({required String currentUserId})
      : _currentUserId = currentUserId;

  /// Initialize contacts from mock data
  void _ensureInitialized() {
    if (_initialized) return;
    _contacts.addAll(MockData.getMockContactsForUser(_currentUserId));
    _initialized = true;
  }

  /// Get all contacts for the current user
  Future<List<Contact>> getContacts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _ensureInitialized();
    return List.unmodifiable(_contacts);
  }

  /// Find a user by phone number
  Future<User?> findUserByPhone(String phone) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return MockData.findUserByPhone(phone);
  }

  /// Find a user by ID
  Future<User?> findUserById(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return MockData.findUserById(userId);
  }

  /// Add a new contact
  Future<Contact> addContact(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _ensureInitialized();

    final user = MockData.findUserById(userId);
    if (user == null) {
      throw Exception('User not found');
    }

    // Check if already exists
    if (_contacts.any((c) => c.contactUserId == userId)) {
      throw Exception('Contact already exists');
    }

    final contact = Contact(
      id: 'contact_${DateTime.now().millisecondsSinceEpoch}',
      userId: _currentUserId,
      contactUserId: user.id,
      contactName: null,
      isBlocked: false,
      isFavorite: false,
      addedAt: DateTime.now(),
      createdAt: DateTime.now(),
      // Joined user info
      fullName: user.fullName,
      phone: user.phone,
      primaryLanguage: user.primaryLanguage,
      isOnline: user.isOnline,
      avatarUrl: user.avatarUrl,
    );

    _contacts.add(contact);
    return contact;
  }

  /// Remove a contact
  Future<void> deleteContact(String contactId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _contacts.removeWhere((c) => c.id == contactId);
  }

  /// Update contact nickname
  Future<Contact> updateNickname(String contactId, String? nickname) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index == -1) {
      throw Exception('Contact not found');
    }

    final updated = _contacts[index].copyWith(contactName: nickname);
    _contacts[index] = updated;
    return updated;
  }

  /// Toggle favorite status
  Future<Contact> toggleFavorite(String contactId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index == -1) {
      throw Exception('Contact not found');
    }

    final updated = _contacts[index].copyWith(
      isFavorite: !_contacts[index].isFavorite,
    );
    _contacts[index] = updated;
    return updated;
  }

  /// Check if a user is already in contacts
  bool isInContacts(String userId) {
    _ensureInitialized();
    return _contacts.any((c) => c.contactUserId == userId);
  }
}
