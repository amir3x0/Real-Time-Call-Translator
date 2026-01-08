import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contact.dart';
import '../../models/user.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/call_provider.dart';
import '../../utils/language_utils.dart';
import '../../providers/auth_provider.dart';

/// Call Confirmation Screen - מסך אישור שיחה
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

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'אישור שיחה',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Participants preview section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'משתתפים בשיחה',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
                      currentUser.primaryLanguage,
                      selectedContacts.map((c) => c.language).toSet().toList(),
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
                    _buildLanguagesSummary(currentUser, selectedContacts),
                  ],
                ],
              ),
            ),
          ),

          // Bottom action buttons
          _buildActionButtons(context, selectedContacts.isNotEmpty),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? const Color(0xFF00D9FF).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFF00D9FF).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
                          color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'את/ה',
                          style: TextStyle(
                            color: Color(0xFF00D9FF),
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
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
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
                color: Colors.white.withValues(alpha: 0.5),
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
            ? const LinearGradient(
                colors: [Color(0xFF00D9FF), Color(0xFF00B4D8)],
              )
            : LinearGradient(
                colors: [
                  Colors.purple.shade400,
                  Colors.purple.shade600,
                ],
              ),
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
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              'אותה שפה - ללא צורך בתרגום',
              style: TextStyle(
                color: Colors.green.shade300,
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
        color: const Color(0xFF00D9FF).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'תרגום בזמן אמת',
            style: TextStyle(
              color: Color(0xFF00D9FF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Source language
              _buildLanguageChip(sourceLanguage),

              // Arrow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.swap_horiz,
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.7),
                  size: 24,
                ),
              ),

              // Target languages
              ...uniqueTargets.asMap().entries.map((entry) {
                final isLast = entry.key == uniqueTargets.length - 1;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLanguageChip(entry.value),
                    if (!isLast)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '+',
                          style: TextStyle(
                            color: Colors.white54,
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
  Widget _buildLanguageChip(String languageCode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Build languages summary section
  Widget _buildLanguagesSummary(User currentUser, List<Contact> contacts) {
    final allLanguages = <String>{currentUser.primaryLanguage};
    for (final contact in contacts) {
      allLanguages.add(contact.language);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.translate,
                color: Colors.white.withValues(alpha: 0.6),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'סיכום שפות',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
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
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        LanguageUtils.formatDisplay(lang),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ))
                .toList(),
          ),
          if (allLanguages.length > 1) ...[
            const SizedBox(height: 12),
            Text(
              'השיחה תתורגם אוטומטית בין ${allLanguages.length} שפות',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build bottom action buttons
  Widget _buildActionButtons(BuildContext context, bool hasParticipants) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
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
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ביטול',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Start call button
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: hasParticipants ? () => _startCall(context) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey.shade700,
                  disabledForegroundColor: Colors.grey.shade500,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: hasParticipants ? 4 : 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.call,
                      size: 22,
                      color:
                          hasParticipants ? Colors.black : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'התחל שיחה',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: hasParticipants
                            ? Colors.black
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Start the call with selected participants
  Future<void> _startCall(BuildContext context) async {
    final contactsProvider = context.read<ContactsProvider>();
    final callProvider = context.read<CallProvider>();
    final authProvider = context.read<AuthProvider>();
    final selectedContacts = contactsProvider.selectedContacts;

    if (selectedContacts.isEmpty) return;

    // Show loading state could be added here if we had a loading state in UI

    try {
      // Extract user IDs from selected contacts for the API call
      final participantUserIds =
          selectedContacts.map((contact) => contact.contactUserId).toList();

      // Start the call using CallProvider and WAIT for it
      // Pass current user ID for audio routing (to avoid hearing your own translation)
      await callProvider.startCall(
        participantUserIds,
        currentUserId: authProvider.currentUser?.id,
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
