import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contact.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/call_provider.dart';
import '../../utils/language_utils.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_theme.dart';

/// Call Confirmation Screen
///
/// Displays a preview of selected participants and their languages
/// before initiating the call. Shows:
/// - Current user (initiator) at the top
/// - Selected contacts with their language info
/// - Visual language translation preview
/// - Start and Cancel buttons
class CallConfirmationScreen extends StatelessWidget {
  const CallConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final contactsProvider = context.watch<ContactsProvider>();
    final selectedContacts = contactsProvider.selectedContacts;
    final currentUser = context.read<AuthProvider>().currentUser!;
    final gradientColors = AppTheme.getScreenGradientColors(context);

    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
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
              _buildAppBar(context),

              // Participants preview section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'Call Participants',
                        style: AppTheme.labelLarge.copyWith(
                          color: AppTheme.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Current user (initiator) card
                      _buildParticipantCard(
                        context,
                        name: currentUser.fullName,
                        language: currentUser.primaryLanguage,
                        isCurrentUser: true,
                      ),

                      const SizedBox(height: 12),

                      // Translation flow indicator
                      if (selectedContacts.isNotEmpty) ...[
                        _buildTranslationFlowIndicator(
                          context,
                          currentUser.primaryLanguage,
                          selectedContacts
                              .map((c) => c.language)
                              .toSet()
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Selected contacts
                      ...selectedContacts.map((contact) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildParticipantCard(
                              context,
                              name: contact.displayName,
                              language: contact.language,
                              isCurrentUser: false,
                              onRemove: () {
                                contactsProvider.toggleSelection(contact.id);
                              },
                            ),
                          )),

                      // Languages summary
                      if (selectedContacts.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildLanguagesSummary(
                            context, currentUser.primaryLanguage, selectedContacts),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom action buttons
              _buildActionButtons(context, selectedContacts.isNotEmpty),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.getTextColor(context)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              'Confirm Call',
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.getTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  /// Build a participant card showing name, language, and optional remove button
  Widget _buildParticipantCard(
    BuildContext context, {
    required String name,
    required String language,
    required bool isCurrentUser,
    VoidCallback? onRemove,
  }) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.accentCyan.withValues(alpha: 0.1)
            : isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.accentCyan.withValues(alpha: 0.3)
              : isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          _buildAvatar(name, isCurrentUser),
          const SizedBox(width: 14),

          // Name and language info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextColor(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: AppTheme.accentCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      LanguageUtils.getFlag(language),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      LanguageUtils.getName(language),
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Remove button (not for current user)
          if (!isCurrentUser && onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: Icon(
                Icons.close,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  /// Build avatar widget
  Widget _buildAvatar(String name, bool isCurrentUser) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isCurrentUser
            ? LinearGradient(
                colors: [
                  AppTheme.accentCyan,
                  AppTheme.accentCyan.withValues(alpha: 0.7)
                ],
              )
            : AppTheme.purpleGradient,
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Build translation flow indicator showing language arrows
  Widget _buildTranslationFlowIndicator(
    BuildContext context,
    String sourceLanguage,
    List<String> targetLanguages,
  ) {
    // Remove source language from targets if present
    final uniqueTargets =
        targetLanguages.where((l) => l != sourceLanguage).toList();

    if (uniqueTargets.isEmpty) {
      // Same language - no translation needed
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withValues(alpha: 0.1),
          borderRadius: AppTheme.borderRadiusMedium,
          border:
              Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
            SizedBox(width: 8),
            Text(
              'Same language - no translation needed',
              style: TextStyle(
                color: AppTheme.successGreen,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.accentCyan.withValues(alpha: 0.05),
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(
          color: AppTheme.accentCyan.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Real-time Translation',
            style: TextStyle(
              color: AppTheme.accentCyan,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Source language
              _buildLanguageChip(context, sourceLanguage),

              // Arrow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.swap_horiz,
                  color: AppTheme.accentCyan.withValues(alpha: 0.7),
                  size: 24,
                ),
              ),

              // Target languages
              ...uniqueTargets.asMap().entries.map((entry) {
                final isLast = entry.key == uniqueTargets.length - 1;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLanguageChip(context, entry.value),
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '+',
                          style: TextStyle(
                            color: AppTheme.getSecondaryTextColor(context),
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// Build language chip widget
  Widget _buildLanguageChip(BuildContext context, String languageCode) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LanguageUtils.getFlag(languageCode),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 6),
          Text(
            LanguageUtils.getName(languageCode),
            style: TextStyle(
              color: AppTheme.getTextColor(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Build languages summary section
  Widget _buildLanguagesSummary(
      BuildContext context, String currentUserLang, List<Contact> contacts) {
    final isDark = AppTheme.isDarkMode(context);
    final allLanguages = <String>{currentUserLang};
    for (final contact in contacts) {
      allLanguages.add(contact.language);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.translate,
                color: AppTheme.getSecondaryTextColor(context),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Languages Summary',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allLanguages
                .map((lang) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        LanguageUtils.formatDisplay(lang),
                        style: TextStyle(
                          color: AppTheme.getTextColor(context),
                          fontSize: 13,
                        ),
                      ),
                    ))
                .toList(),
          ),
          if (allLanguages.length > 1) ...[
            const SizedBox(height: 12),
            Text(
              'Call will be auto-translated between ${allLanguages.length} languages',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.getSecondaryTextColor(context),
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build bottom action buttons
  Widget _buildActionButtons(BuildContext context, bool hasParticipants) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel button
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                // Clear selection and go back
                context.read<ContactsProvider>().clearSelection();
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.getTextColor(context),
                side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.borderRadiusMedium,
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextColor(context),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Start call button
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: hasParticipants ? AppTheme.primaryGradient : null,
                color: hasParticipants ? null : Colors.grey.shade700,
                borderRadius: AppTheme.borderRadiusMedium,
                boxShadow: hasParticipants ? AppTheme.buttonShadow : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: hasParticipants ? () => _startCall(context) : null,
                  borderRadius: AppTheme.borderRadiusMedium,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.call,
                          size: 22,
                          color: hasParticipants
                              ? Colors.white
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Start Call',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: hasParticipants
                                ? Colors.white
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Start the call with selected participants
  Future<void> _startCall(BuildContext context) async {
    debugPrint('[CallConfirmation] _startCall button pressed!');
    final contactsProvider = context.read<ContactsProvider>();
    final callProvider = context.read<CallProvider>();
    final authProvider = context.read<AuthProvider>();
    final selectedContacts = contactsProvider.selectedContacts;

    debugPrint(
        '[CallConfirmation] Selected contacts: ${selectedContacts.length}');
    if (selectedContacts.isEmpty) {
      debugPrint('[CallConfirmation] No contacts selected - returning early');
      return;
    }

    try {
      // Extract user IDs from selected contacts for the API call
      final participantUserIds =
          selectedContacts.map((contact) => contact.contactUserId).toList();

      final currentUser = authProvider.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final token = await authProvider.checkAuthStatus();
      if (token == null) throw Exception('Authentication token missing');

      // Start the call using CallProvider and WAIT for it
      await callProvider.startCall(
        participantUserIds,
        currentUserId: currentUser.id,
        token: token,
      );

      // Clear selection after starting call
      contactsProvider.clearSelection();

      if (context.mounted) {
        // Navigate to active call screen only on success
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/call/active',
          (route) => route.isFirst,
          arguments: {
            'contacts': selectedContacts,
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}
