import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../providers/contacts_provider.dart';
import '../../providers/call_provider.dart';
import '../../config/app_theme.dart';
import '../../widgets/shared/glass_card.dart';
import '../../widgets/shared/language_selector.dart';

/// Screen for selecting participants before starting a call.
/// 
/// This screen allows users to:
/// - View their contacts
/// - Select multiple participants (up to 4)
/// - See language info for each participant
/// - Start a translated call with selected participants
class SelectParticipantsScreen extends StatefulWidget {
  const SelectParticipantsScreen({super.key});

  @override
  State<SelectParticipantsScreen> createState() => _SelectParticipantsScreenState();
}

class _SelectParticipantsScreenState extends State<SelectParticipantsScreen> {
  final Set<String> _selectedContactIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  static const int maxParticipants = 4;

  @override
  void initState() {
    super.initState();
    // Ensure contacts are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ContactsProvider>(context, listen: false).loadContacts();
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
                _buildStartCallButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
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
              '${_selectedContactIds.length}/$maxParticipants',
              style: AppTheme.bodyMedium.copyWith(
                color: _selectedContactIds.length >= maxParticipants
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
        hint: 'Search contacts by name or phone...',
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
    if (_selectedContactIds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text(
          'Tap contacts to select them for the call',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.secondaryText.withValues(alpha: 0.7),
          ),
        ),
      ).animate().fadeIn(delay: 200.ms);
    }

    final contactsProv = Provider.of<ContactsProvider>(context);
    final selectedContacts = contactsProv.contacts
        .where((c) => _selectedContactIds.contains(c.id))
        .toList();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: selectedContacts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final contact = selectedContacts[index];
          return GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppTheme.primaryElectricBlue.withValues(alpha: 0.2),
            borderColor: AppTheme.primaryElectricBlue,
            onTap: () => _toggleSelection(contact.id),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  LanguageData.getFlag(contact.languageCode),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  contact.name.split(' ').first,
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.close, size: 16, color: Colors.white70),
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
    final contactsProv = Provider.of<ContactsProvider>(context);
    
    if (contactsProv.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryElectricBlue,
        ),
      );
    }

    var contacts = contactsProv.contacts;
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      contacts = contacts.where((c) {
        return c.name.toLowerCase().contains(_searchQuery) ||
               c.phone.contains(_searchQuery);
      }).toList();
    }

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
              _searchQuery.isEmpty ? 'No contacts yet' : 'No matches found',
              style: AppTheme.titleMedium.copyWith(color: AppTheme.secondaryText),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Add contacts from the Contacts tab',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.secondaryText.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final isSelected = _selectedContactIds.contains(contact.id);
        final canSelect = _selectedContactIds.length < maxParticipants || isSelected;

        return _ContactTile(
          contact: contact,
          isSelected: isSelected,
          canSelect: canSelect,
          onTap: () => _toggleSelection(contact.id),
        ).animate(delay: Duration(milliseconds: 50 * index))
          .fadeIn(duration: 300.ms)
          .slideX(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildStartCallButton() {
    final isEnabled = _selectedContactIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      child: PillButton(
        label: _selectedContactIds.isEmpty
            ? 'Select participants to call'
            : 'Start Call (${_selectedContactIds.length} participant${_selectedContactIds.length > 1 ? 's' : ''})',
        icon: Icons.call,
        onPressed: isEnabled ? _startCall : null,
        gradient: isEnabled
            ? const LinearGradient(colors: [AppTheme.successGreen, Color(0xFF059669)])
            : LinearGradient(colors: [
                Colors.grey.shade700,
                Colors.grey.shade800,
              ]),
        boxShadow: isEnabled
            ? [BoxShadow(
                color: AppTheme.successGreen.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )]
            : null,
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0);
  }

  void _toggleSelection(String contactId) {
    setState(() {
      if (_selectedContactIds.contains(contactId)) {
        _selectedContactIds.remove(contactId);
      } else if (_selectedContactIds.length < maxParticipants) {
        _selectedContactIds.add(contactId);
      }
    });
  }

  void _startCall() {
    if (_selectedContactIds.isEmpty) return;

    final callProv = Provider.of<CallProvider>(context, listen: false);
    
    // For now, start a mock call
    // In production, pass participant user IDs to startCall()
    callProv.startMockCall();
    
    // Navigate to call screen
    Navigator.pushReplacementNamed(context, '/call');
  }
}

/// Individual contact tile in the selection list
class _ContactTile extends StatelessWidget {
  final dynamic contact;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback onTap;

  const _ContactTile({
    required this.contact,
    required this.isSelected,
    required this.canSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GlassCard(
        onTap: canSelect ? onTap : null,
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
                      _getInitials(contact.name),
                      style: AppTheme.titleMedium.copyWith(
                        color: isSelected ? Colors.white : AppTheme.secondaryText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
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
                      LanguageData.getFlag(contact.languageCode),
                      style: const TextStyle(fontSize: 14),
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
                    contact.name,
                    style: AppTheme.bodyLarge.copyWith(
                      color: isSelected ? Colors.white : AppTheme.lightText,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        contact.phone,
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
                        LanguageData.getName(contact.languageCode),
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.secondaryText.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
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
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }
}
