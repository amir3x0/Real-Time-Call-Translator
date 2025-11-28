import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../providers/call_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../config/app_theme.dart';

class ContactsScreen extends StatefulWidget {
  final ScrollController? scrollController;
  
  const ContactsScreen({super.key, this.scrollController});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ContactsProvider>(context, listen: false).loadContacts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactsProv = Provider.of<ContactsProvider>(context);
    final callProv = Provider.of<CallProvider>(context, listen: false);

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: _buildSearchBar(),
        ).animate()
          .fadeIn(delay: 300.ms, duration: 400.ms),

        // Contacts List
        Expanded(
          child: contactsProv.isLoading
              ? _buildShimmerList()
              : contactsProv.contacts.isEmpty
                  ? _buildEmptyState()
                  : _buildContactsList(contactsProv, callProv),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: AppTheme.glassDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderColor: Colors.white.withValues(alpha: 0.1),
            ),
            child: TextField(
              controller: _searchController,
              style: AppTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.secondaryText.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.search, color: AppTheme.secondaryText),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.person_add, color: AppTheme.primaryElectricBlue),
                  onPressed: () => _openAddContactDialog(context),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onChanged: _handleSearchChanged,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 6,
      itemBuilder: (context, index) => _ShimmerRow(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 50,
              color: AppTheme.secondaryText.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No contacts yet',
            style: AppTheme.titleMedium.copyWith(color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 8),
          Text(
            'Add contacts by phone number',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.secondaryText.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          _buildAddContactButton(),
        ],
      ),
    );
  }

  Widget _buildAddContactButton() {
    return ClipRRect(
      borderRadius: AppTheme.borderRadiusPill,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: AppTheme.glassDecoration(
            color: AppTheme.primaryElectricBlue.withValues(alpha: 0.2),
            borderColor: AppTheme.primaryElectricBlue.withValues(alpha: 0.4),
            borderRadius: AppTheme.radiusPill,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AppTheme.borderRadiusPill,
              onTap: () => _openAddContactDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add, color: AppTheme.primaryElectricBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Add Contact',
                      style: AppTheme.labelLarge.copyWith(color: AppTheme.primaryElectricBlue),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactsList(ContactsProvider contactsProv, CallProvider callProv) {
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: contactsProv.contacts.length,
      itemBuilder: (context, index) {
        final c = contactsProv.contacts[index];
        return Dismissible(
          key: ValueKey(c.id),
          background: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.errorRed.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: AppTheme.borderRadiusMedium,
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            return await _showDeleteDialog(context, c.name);
          },
          onDismissed: (_) async {
            final name = c.name;
            final messenger = ScaffoldMessenger.of(context);
            await contactsProv.removeContact(c.id);
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text('Deleted $name'),
                backgroundColor: AppTheme.darkCard,
                action: SnackBarAction(
                  label: 'Undo',
                  textColor: AppTheme.primaryElectricBlue,
                  onPressed: () => contactsProv.loadContacts(),
                ),
              ),
            );
          },
          child: _buildContactCard(c, callProv, index),
        );
      },
    );
  }

  Future<bool> _showDeleteDialog(BuildContext context, String name) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: AppTheme.borderRadiusMedium,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassDecoration(
                color: AppTheme.darkCard.withValues(alpha: 0.9),
                borderColor: Colors.white.withValues(alpha: 0.1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.errorRed,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Delete Contact',
                    style: AppTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to delete $name?',
                    style: AppTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            'Cancel',
                            style: AppTheme.labelLarge.copyWith(color: AppTheme.secondaryText),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed,
                            borderRadius: AppTheme.borderRadiusSmall,
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              'Delete',
                              style: AppTheme.labelLarge.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ) ?? false;
  }

  Widget _buildContactCard(dynamic c, CallProvider callProv, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: AppTheme.borderRadiusMedium,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: AppTheme.glassDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderColor: Colors.white.withValues(alpha: 0.1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppTheme.borderRadiusMedium,
                onTap: () {
                  callProv.startMockCall();
                  Navigator.pushNamed(context, '/call');
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _GradientAvatar(name: c.name),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _LanguageChip(code: c.languageCode),
                                const SizedBox(width: 8),
                                Text(
                                  c.status,
                                  style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.successGreen, Color(0xFF059669)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.glowShadow(AppTheme.successGreen.withValues(alpha: 0.3)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.call, color: Colors.white, size: 20),
                          onPressed: () {
                            callProv.startMockCall();
                            Navigator.pushNamed(context, '/call');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate()
      .fadeIn(delay: Duration(milliseconds: 100 * index), duration: 400.ms)
      .slideX(begin: 0.1, end: 0);
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      Provider.of<ContactsProvider>(context, listen: false).setSearchQuery(value);
    });
  }

  Future<void> _openAddContactDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final contactsProvider = Provider.of<ContactsProvider>(context, listen: false);
    
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedLanguage = 'en';
    
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Add Contact', style: AppTheme.titleLarge),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Name field
                        ClipRRect(
                          borderRadius: AppTheme.borderRadiusMedium,
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: AppTheme.glassDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderColor: Colors.white.withValues(alpha: 0.2),
                              ),
                              child: TextField(
                                controller: nameController,
                                style: AppTheme.bodyLarge,
                                decoration: InputDecoration(
                                  labelText: 'Name',
                                  labelStyle: AppTheme.bodyMedium,
                                  prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryElectricBlue),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Phone field
                        ClipRRect(
                          borderRadius: AppTheme.borderRadiusMedium,
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: AppTheme.glassDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderColor: Colors.white.withValues(alpha: 0.2),
                              ),
                              child: TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                style: AppTheme.bodyLarge,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  labelStyle: AppTheme.bodyMedium,
                                  hintText: '052-123-4567',
                                  hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.secondaryText.withValues(alpha: 0.5)),
                                  prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primaryElectricBlue),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Language selection
                        Text(
                          'Primary Language',
                          style: AppTheme.bodyMedium.copyWith(color: AppTheme.secondaryText),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildLanguageOption('\u{1F1EE}\u{1F1F1}', 'he', '\u05E2\u05D1\u05E8\u05D9\u05EA', selectedLanguage == 'he', () {
                              setStateDialog(() => selectedLanguage = 'he');
                            }),
                            _buildLanguageOption('\u{1F1FA}\u{1F1F8}', 'en', 'English', selectedLanguage == 'en', () {
                              setStateDialog(() => selectedLanguage = 'en');
                            }),
                            _buildLanguageOption('\u{1F1F7}\u{1F1FA}', 'ru', '\u0420\u0443\u0441\u0441\u043A\u0438\u0439', selectedLanguage == 'ru', () {
                              setStateDialog(() => selectedLanguage = 'ru');
                            }),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // Add button
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: AppTheme.borderRadiusPill,
                            boxShadow: AppTheme.buttonShadow,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: AppTheme.borderRadiusPill,
                              onTap: () {
                                if (nameController.text.trim().isNotEmpty) {
                                  Navigator.of(ctx).pop({
                                    'name': nameController.text.trim(),
                                    'phone': phoneController.text.trim(),
                                    'language': selectedLanguage,
                                  });
                                }
                              },
                              child: Center(
                                child: Text(
                                  'Add Contact',
                                  style: AppTheme.labelLarge.copyWith(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    await contactsProvider.addContact(
      name: result['name']!,
      phone: result['phone']!,
      language: result['language']!,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Added ${result['name']}'),
        backgroundColor: AppTheme.darkCard,
      ),
    );
  }

  Widget _buildLanguageOption(String flag, String code, String name, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryElectricBlue.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: AppTheme.borderRadiusMedium,
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryElectricBlue
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              name,
              style: AppTheme.bodyMedium.copyWith(
                color: isSelected ? Colors.white : AppTheme.secondaryText,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, color: AppTheme.primaryElectricBlue, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String code;
  const _LanguageChip({required this.code});

  static const Map<String, String> _flags = {
    'he': '🇮🇱',
    'en': '🇺🇸',
    'ru': '🇷🇺',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryElectricBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryElectricBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_flags[code] ?? '🌐', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            code.toUpperCase(),
            style: AppTheme.bodyMedium.copyWith(
              fontSize: 11,
              color: AppTheme.primaryElectricBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.darkCard,
      highlightColor: AppTheme.darkSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: AppTheme.borderRadiusMedium,
          ),
        ),
      ),
    );
  }
}

class _GradientAvatar extends StatelessWidget {
  final String name;
  const _GradientAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppTheme.primaryElectricBlue,
      AppTheme.secondaryPurple,
      AppTheme.successGreen,
      const Color(0xFF06B6D4),
    ];
    // Use name hash for consistent color
    final colorIndex = name.hashCode.abs() % colors.length;
    final nextIndex = (colorIndex + 1) % colors.length;
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors[colorIndex], colors[nextIndex]],
        ),
        boxShadow: [
          BoxShadow(
            color: colors[colorIndex].withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
