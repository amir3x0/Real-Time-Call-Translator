import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/contact.dart';
import '../../providers/contacts_provider.dart';
import '../../config/app_theme.dart';
import '../../widgets/shared/glass_card.dart';

/// Screen for selecting participants before starting a call.
/// 
/// This updated version uses the new ContactsProvider with:
/// - Contact model that references User
/// - Multi-selection support (up to 3 contacts = 4 participants with current user)
/// - Navigation to CallConfirmationScreen
class SelectParticipantsScreen extends StatefulWidget {
  const SelectParticipantsScreen({super.key});

  @override
  State<SelectParticipantsScreen> createState() => _SelectParticipantsScreenState();
}

class _SelectParticipantsScreenState extends State<SelectParticipantsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Ensure contacts are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactsProvider>().loadContacts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F1630),
                  Color(0xFF1B2750),
                  Color(0xFF2A3A6B),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildSelectedChips(),
                Expanded(child: _buildContactsList()),
                _buildContinueButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final contactsProvider = context.watch<ContactsProvider>();
    final selectedCount = contactsProvider.selectedCount;
    const maxSelectable = ContactsProvider.maxSelectable;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () {
              // Clear selection before going back
              contactsProvider.clearSelection();
              Navigator.pop(context);
            },
          ),
          Expanded(
            child: Text(
              'Select Participants',
              style: AppTheme.titleLarge,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: AppTheme.borderRadiusPill,
            ),
            child: Text(
              '$selectedCount/$maxSelectable',
              style: AppTheme.bodyMedium.copyWith(
                color: selectedCount >= maxSelectable
                    ? AppTheme.warningOrange
                    : AppTheme.secondaryText,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GlassTextField(
        controller: _searchController,
        hint: 'Search by name or phone...',
        prefixIcon: Icons.search,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildSelectedChips() {
    final contactsProvider = context.watch<ContactsProvider>();
    final selectedContacts = contactsProvider.selectedContacts;

    if (selectedContacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text(
          'Tap contacts to select for the call',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.secondaryText.withValues(alpha: 0.7),
          ),
        ),
      ).animate().fadeIn(delay: 200.ms);
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: false, // LTR layout
        itemCount: selectedContacts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final contact = selectedContacts[index];
          return GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppTheme.primaryElectricBlue.withValues(alpha: 0.2),
            borderColor: AppTheme.primaryElectricBlue,
            onTap: () => contactsProvider.toggleSelection(contact.id),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.close, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  contact.displayName.split(' ').first,
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  contact.languageFlag,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ).animate().scale(
            duration: 200.ms,
            curve: Curves.easeOut,
          );
        },
      ),
    );
  }

  Widget _buildContactsList() {
    final contactsProvider = context.watch<ContactsProvider>();
    
    if (contactsProvider.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryElectricBlue,
        ),
      );
    }

    var contacts = contactsProvider.contacts;
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      contacts = contacts.where((c) {
        return c.displayName.toLowerCase().contains(_searchQuery) ||
               (c.phone ?? '').contains(_searchQuery);
      }).toList();
    }

    // Filter out blocked contacts
    contacts = contacts.where((c) => !c.isBlocked).toList();

    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppTheme.secondaryText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No contacts' : 'No results found',
              style: AppTheme.titleMedium.copyWith(color: AppTheme.secondaryText),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Add contacts from the "Contacts" tab',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.secondaryText.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Group by favorite status
    final favorites = contacts.where((c) => c.isFavorite).toList();
    final others = contacts.where((c) => !c.isFavorite).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Favorites section
        if (favorites.isNotEmpty) ...[
          _buildSectionHeader('Favorites', Icons.star),
          ...favorites.asMap().entries.map((entry) => 
            _buildContactTile(entry.value, contactsProvider, entry.key)
          ),
          const SizedBox(height: 16),
        ],
        
        // All contacts section
        if (others.isNotEmpty) ...[
          _buildSectionHeader('Contacts', Icons.people),
          ...others.asMap().entries.map((entry) => 
            _buildContactTile(entry.value, contactsProvider, entry.key + favorites.length)
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppTheme.secondaryText.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.secondaryText.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(Contact contact, ContactsProvider provider, int index) {
    final isSelected = provider.isSelected(contact.id);
    final canSelect = provider.canSelectMore || isSelected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GlassCard(
        onTap: canSelect ? () => provider.toggleSelection(contact.id) : null,
        padding: const EdgeInsets.all(16),
        color: isSelected
            ? AppTheme.primaryElectricBlue.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderColor: isSelected
            ? AppTheme.primaryElectricBlue
            : Colors.white.withValues(alpha: 0.1),
        child: Row(
          children: [
            // Avatar with language flag
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? AppTheme.primaryGradient
                        : LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.1),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          ),
                  ),
                  child: Center(
                    child: Text(
                      contact.avatarLetter,
                      style: AppTheme.titleMedium.copyWith(
                        color: isSelected ? Colors.white : AppTheme.secondaryText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Language flag
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      contact.languageFlag,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                // Online indicator
                if (contact.isOnline == true)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.darkBackground,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(width: 16),

            // Name and phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    style: AppTheme.bodyLarge.copyWith(
                      color: isSelected ? Colors.white : AppTheme.lightText,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        contact.phone ?? '',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.secondaryText.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\u2022',
                        style: TextStyle(color: AppTheme.secondaryText.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        contact.languageName,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.secondaryText.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppTheme.primaryElectricBlue
                    : Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryElectricBlue
                      : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 50 * index))
      .fadeIn(duration: 300.ms)
      .slideX(begin: -0.1, end: 0);
  }

  Widget _buildContinueButton() {
    final contactsProvider = context.watch<ContactsProvider>();
    final selectedCount = contactsProvider.selectedCount;
    final isEnabled = selectedCount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      child: PillButton(
        label: selectedCount == 0
            ? 'Select participants to continue'
            : 'Continue with $selectedCount participant${selectedCount > 1 ? 's' : ''}',
        icon: Icons.arrow_forward,
        onPressed: isEnabled ? _continueToConfirmation : null,
        gradient: isEnabled
            ? const LinearGradient(colors: [AppTheme.primaryElectricBlue, Color(0xFF0099FF)])
            : LinearGradient(colors: [
                Colors.grey.shade700,
                Colors.grey.shade800,
              ]),
        boxShadow: isEnabled
            ? [BoxShadow(
                color: AppTheme.primaryElectricBlue.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )]
            : null,
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0);
  }

  void _continueToConfirmation() {
    // Navigate to call confirmation screen
    Navigator.pushNamed(context, '/call/confirm');
  }
}
