import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/contacts_provider_new.dart';
import '../../utils/language_utils.dart';
import '../../data/mock/mock_data.dart';
import '../../models/user.dart';

/// Add Contact Screen - מסך הוספת איש קשר
/// 
/// Allows users to search for other users by phone number
/// and add them to their contacts list.
class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  
  User? _foundUser;
  bool _isSearching = false;
  String? _errorMessage;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus on the phone field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _phoneFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  /// Search for a user by phone number
  Future<void> _searchUser() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      setState(() {
        _errorMessage = 'נא להזין מספר טלפון';
        _foundUser = null;
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _foundUser = null;
      _hasSearched = true;
    });

    // Simulate network delay for mock
    await Future.delayed(const Duration(milliseconds: 500));

    // Search in mock data
    final user = MockData.findUserByPhone(phone);
    
    if (!mounted) return;

    if (user != null) {
      // Check if this is the current user
      if (user.id == MockData.currentMockUser.id) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'לא ניתן להוסיף את עצמך כאיש קשר';
          _foundUser = null;
        });
        return;
      }

      // Check if already a contact
      final contactsProvider = context.read<ContactsProvider>();
      final isAlreadyContact = contactsProvider.contacts.any(
        (c) => c.contactUser.id == user.id,
      );

      if (isAlreadyContact) {
        setState(() {
          _isSearching = false;
          _errorMessage = '${user.fullName} כבר קיים ברשימת אנשי הקשר שלך';
          _foundUser = null;
        });
        return;
      }

      setState(() {
        _isSearching = false;
        _foundUser = user;
      });
    } else {
      setState(() {
        _isSearching = false;
        _errorMessage = 'לא נמצא משתמש עם מספר טלפון זה';
        _foundUser = null;
      });
    }
  }

  /// Add the found user as a contact
  Future<void> _addContact() async {
    if (_foundUser == null) return;

    final contactsProvider = context.read<ContactsProvider>();
    final result = await contactsProvider.addContactByPhone(_foundUser!.phone);

    if (!mounted) return;

    switch (result) {
      case AddContactResult.success:
        // Show success message and go back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_foundUser!.fullName} נוסף לאנשי הקשר'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
        break;

      case AddContactResult.alreadyExists:
        setState(() {
          _errorMessage = 'איש קשר זה כבר קיים';
          _foundUser = null;
        });
        break;

      case AddContactResult.userNotFound:
        setState(() {
          _errorMessage = 'משתמש לא נמצא';
          _foundUser = null;
        });
        break;

      case AddContactResult.error:
        setState(() {
          _errorMessage = 'שגיאה בהוספת איש קשר';
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'הוספת איש קשר',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF00D9FF),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'חפש משתמשים לפי מספר טלפון כדי להוסיף אותם לאנשי הקשר שלך',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Phone input field
            _buildPhoneInput(),

            const SizedBox(height: 16),

            // Search button
            _buildSearchButton(),

            const SizedBox(height: 24),

            // Results section
            if (_isSearching)
              _buildLoadingIndicator()
            else if (_errorMessage != null)
              _buildErrorMessage()
            else if (_foundUser != null)
              _buildUserPreviewCard()
            else if (_hasSearched)
              _buildNoResultMessage(),
          ],
        ),
      ),
    );
  }

  /// Build phone number input field
  Widget _buildPhoneInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _phoneFocusNode.hasFocus
              ? const Color(0xFF00D9FF)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: TextField(
        controller: _phoneController,
        focusNode: _phoneFocusNode,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          letterSpacing: 1,
        ),
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: '050-XXX-XXXX',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 18,
          ),
          prefixIcon: Icon(
            Icons.phone,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          suffixIcon: _phoneController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    _phoneController.clear();
                    setState(() {
                      _foundUser = null;
                      _errorMessage = null;
                      _hasSearched = false;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _searchUser(),
      ),
    );
  }

  /// Build search button
  Widget _buildSearchButton() {
    return ElevatedButton.icon(
      onPressed: _isSearching ? null : _searchUser,
      icon: const Icon(Icons.search, size: 20),
      label: const Text(
        'חיפוש',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00D9FF),
        foregroundColor: Colors.black,
        disabledBackgroundColor: Colors.grey.shade700,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Build loading indicator
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF00D9FF),
          ),
          const SizedBox(height: 16),
          Text(
            'מחפש...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Build error message
  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build no result message
  Widget _buildNoResultMessage() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.person_search,
            size: 60,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'לא נמצאו תוצאות',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Build user preview card when found
  Widget _buildUserPreviewCard() {
    final user = _foundUser!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Success indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'משתמש נמצא!',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // User avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade400,
                  Colors.purple.shade600,
                ],
              ),
            ),
            child: user.avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      user.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          user.fullName.isNotEmpty 
                              ? user.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      user.fullName.isNotEmpty 
                          ? user.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 16),

          // User name
          Text(
            user.fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // Phone number
          Text(
            user.phone,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 12),

          // Language info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  LanguageUtils.getFlag(user.primaryLanguage),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  LanguageUtils.getName(user.primaryLanguage),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Online status
          if (user.isOnline) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'מחובר/ת',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Add contact button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addContact,
              icon: const Icon(Icons.person_add),
              label: const Text(
                'הוסף לאנשי קשר',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
