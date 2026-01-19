import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/contacts_provider.dart';
import '../../data/services/contact_service.dart';
import '../../utils/language_utils.dart';
import '../../models/user.dart';
import '../../config/app_theme.dart';

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
  final ContactService _contactService = ContactService();

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

  /// Search users via backend
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

    try {
      debugPrint('[AddContact] Searching for: $query');
      final backendResults = await _contactService.searchUsers(query);
      debugPrint(
          '[AddContact] Backend returned ${backendResults.length} results');

      final results =
          backendResults.map((json) => User.fromJson(json)).toList();

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
    } catch (e) {
      debugPrint('[AddContact] Search error: $e');
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorMessage = 'Search failed. Please try again.';
        _searchResults = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppTheme.getScreenGradientColors(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              _buildAppBar(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Instructions
                      _buildInstructionsCard(),

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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.close,
              color: AppTheme.getTextColor(context),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              'Add Contact',
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.getTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // Balance the close button
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.accentCyan.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(
          color: isDark
              ? AppTheme.accentCyan.withValues(alpha: 0.3)
              : AppTheme.lightDivider,
        ),
        boxShadow: isDark ? null : AppTheme.lightCardShadow,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: isDark ? AppTheme.accentCyan : AppTheme.primaryElectricBlue,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Search users by phone number or name to add them to your contacts',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.getSecondaryTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build phone number input field
  Widget _buildPhoneInput() {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(
          color: _phoneFocusNode.hasFocus
              ? AppTheme.primaryElectricBlue
              : (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppTheme.lightDivider),
        ),
        boxShadow: isDark ? null : AppTheme.lightCardShadow,
      ),
      child: TextField(
        controller: _phoneController,
        focusNode: _phoneFocusNode,
        style: AppTheme.bodyLarge.copyWith(
          letterSpacing: 1,
          color: AppTheme.getTextColor(context),
        ),
        keyboardType: TextInputType.text, // Supports both phone and name search
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: '050-XXX-XXXX or name',
          hintStyle: AppTheme.bodyMedium.copyWith(
            color: AppTheme.getSecondaryTextColor(context),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.getSecondaryTextColor(context),
          ),
          suffixIcon: _phoneController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: AppTheme.getSecondaryTextColor(context),
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
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.getButtonGradient(context),
        borderRadius: AppTheme.borderRadiusMedium,
        boxShadow: AppTheme.buttonShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSearching ? null : _searchUser,
          borderRadius: AppTheme.borderRadiusMedium,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 20, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Search',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
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
            color: AppTheme.primaryElectricBlue,
          ),
          const SizedBox(height: 16),
          Text(
            'Searching...',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.getSecondaryTextColor(context),
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
        color: AppTheme.errorRed.withValues(alpha: 0.1),
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(
          color: AppTheme.errorRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.errorRed,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppTheme.errorRed,
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
            color: AppTheme.getSecondaryTextColor(context).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Results list
  Widget _buildSearchResultsList() {
    final contactsProvider = context.read<ContactsProvider>();
    final isDark = AppTheme.isDarkMode(context);

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
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: AppTheme.borderRadiusMedium,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppTheme.lightDivider,
            ),
            boxShadow: isDark ? null : AppTheme.lightCardShadow,
          ),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: Center(
                child: Text(
                  user.fullName.isNotEmpty
                      ? user.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            title: Text(
              user.fullName,
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.getTextColor(context),
              ),
            ),
            subtitle: Row(
              children: [
                Flexible(
                  child: Text(
                    user.phone,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.getSecondaryTextColor(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  LanguageUtils.getFlag(user.primaryLanguage),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    LanguageUtils.getName(user.primaryLanguage),
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.getSecondaryTextColor(context),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                    color: isOnline ? AppTheme.successGreen : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen,
                    borderRadius: AppTheme.borderRadiusSmall,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);

                        // Add contact via provider
                        final res = await contactsProvider.addContact(user.id);
                        final ok = res == AddContactResult.success ||
                            res == AddContactResult.alreadyExists;

                        if (ok) {
                          messenger.showSnackBar(
                            SnackBar(
                              content:
                                  Text('${user.fullName} added to contacts'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                          navigator.pop();
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Failed to add contact'),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                        }
                      },
                      borderRadius: AppTheme.borderRadiusSmall,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'Add',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
