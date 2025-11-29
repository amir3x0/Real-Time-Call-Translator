import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/contacts_provider.dart';
import '../../data/api/api_service.dart';
import '../../utils/language_utils.dart';
import '../../data/mock/mock_data.dart';
import '../../models/user.dart';

/// Add Contact Screen
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
  
  List<User> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;
  bool _hasSearched = false;
  final ApiService _apiService = ApiService();

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

  /// Search users via backend; falls back to mock if unavailable
  Future<void> _searchUser() async {
    final query = _phoneController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a phone number';
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _searchResults = [];
      _hasSearched = true;
    });

    List<User> results = [];
    try {
      debugPrint('[AddContact] Searching for: $query');
      final backendResults = await _apiService.searchUsers(query);
      debugPrint('[AddContact] Backend returned ${backendResults.length} results');
      results = backendResults.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[AddContact] Search error: $e');
    }

    if (results.isEmpty) {
      debugPrint('[AddContact] Falling back to mock data');
      // Fallback to mock search by phone substring
      results = MockData.mockUsers.where((u) {
        final phoneDigits = u.phone.replaceAll(RegExp(r'\D'), '');
        final qDigits = query.replaceAll(RegExp(r'\D'), '');
        return phoneDigits.contains(qDigits) || 
               u.fullName.toLowerCase().contains(query.toLowerCase());
      }).where((u) => u.id != MockData.currentMockUser.id).toList();
      debugPrint('[AddContact] Mock fallback found ${results.length} results');
    }

    if (!mounted) return;

    if (results.isEmpty) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'No matching users found';
        _searchResults = [];
      });
    } else {
      setState(() {
        _isSearching = false;
        _errorMessage = null;
        _searchResults = results;
      });
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
          'Add Contact',
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
                      'Search users by phone number or name to add them to your contacts',
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
            else if (_searchResults.isNotEmpty)
              _buildSearchResultsList()
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
        keyboardType: TextInputType.text, // Supports both phone and name search
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: '050-XXX-XXXX or name',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 18,
          ),
          prefixIcon: Icon(
            Icons.search,
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
                      _errorMessage = null;
                      _hasSearched = false;
                      _searchResults = [];
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
        'Search',
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
            'Searching...',
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
            'No results found',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Results list
  Widget _buildSearchResultsList() {
    final contactsProvider = context.read<ContactsProvider>();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isOnline = user.isOnline;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blueGrey.shade700,
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              user.fullName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Row(
              children: [
                Text(user.phone, style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(width: 10),
                Text(LanguageUtils.getFlag(user.primaryLanguage), style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(LanguageUtils.getName(user.primaryLanguage), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);

                    // Add contact via provider
                    final res = await contactsProvider.addContact(user.id);
                    final ok = res == AddContactResult.success || res == AddContactResult.alreadyExists;

                    if (ok) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('${user.fullName} added to contacts')),
                      );
                      navigator.pop();
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Failed to add contact')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
