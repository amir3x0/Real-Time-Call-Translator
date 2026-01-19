import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../providers/auth_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../models/contact.dart';
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

  // Multi-select mode state
  bool _isMultiSelectMode = false;

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

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        // Clear selection when exiting multi-select mode
        Provider.of<ContactsProvider>(context, listen: false).clearSelection();
      }
    });
  }

  void _startGroupCall() {
    final contactsProvider =
        Provider.of<ContactsProvider>(context, listen: false);
    if (contactsProvider.selectedCount > 0) {
      Navigator.pushNamed(context, '/call/confirm');
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsProv = Provider.of<ContactsProvider>(context);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search bar and add button
            _buildSearchHeader(contactsProv),

            // Selected participants chips (when in multi-select mode)
            if (_isMultiSelectMode && contactsProv.selectedCount > 0)
              _buildSelectedChips(contactsProv),

            // Main content
            Expanded(
              child: Builder(
                builder: (_) {
                  if (contactsProv.isLoading) {
                    return ListView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: 6,
                      itemBuilder: (_, __) => _ShimmerRow(),
                    );
                  }

                  final contacts = contactsProv.contacts;
                  final pending = contactsProv.pendingIncoming;

                  return RefreshIndicator(
                    onRefresh: () async => await contactsProv.refreshContacts(),
                    color: AppTheme.primaryElectricBlue,
                    backgroundColor: AppTheme.getCardColor(context),
                    child: ListView(
                      controller: widget.scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: 180, // Space for FAB + nav bar
                      ),
                      children: [
                        // Pending Requests Section
                        if (pending.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Pending Requests (${pending.length})',
                            isPending: true,
                          ),
                          ...pending.map(
                              (c) => _buildPendingRequestCard(c, contactsProv)),
                          const SizedBox(height: 16),
                          _buildSectionHeader('Contacts (${contacts.length})'),
                        ],

                        // Contacts List
                        if (contacts.isEmpty && pending.isEmpty) ...[
                          _buildEmptyState(),
                        ] else ...[
                          ...contacts.asMap().entries.map((entry) {
                            final index = entry.key;
                            final c = entry.value;
                            return Dismissible(
                              key: Key(c.id.isEmpty ? 'contact_$index' : c.id),
                              direction: _isMultiSelectMode
                                  ? DismissDirection.none
                                  : DismissDirection.endToStart,
                              background: _buildDismissBackground(),
                              confirmDismiss: (_) async {
                                return await _showDeleteDialog(
                                    context, c.displayName);
                              },
                              onDismissed: (_) =>
                                  _handleContactDismissed(c, contactsProv),
                              child: _buildContactCard(
                                  c, contactsProv, index),
                            );
                          }),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        // Floating Action Button for Group Call
        Positioned(
          right: 16,
          bottom: 110, // Above the floating nav bar (70px + 24px + margin)
          child: _buildFAB(contactsProv),
        ),
      ],
    );
  }

  Widget _buildSearchHeader(ContactsProvider contactsProv) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppTheme.borderRadiusMedium,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  decoration: AppTheme.themedGlassDecoration(context),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _handleSearchChanged,
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.getTextColor(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name or phone',
                      hintStyle: AppTheme.bodyMedium
                          .copyWith(color: AppTheme.getSecondaryTextColor(context)),
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.primaryElectricBlue),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.getButtonGradient(context),
              shape: BoxShape.circle,
              boxShadow: AppTheme.buttonShadow,
            ),
            child: IconButton(
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              onPressed: () async {
                if (!mounted) return;
                final contacts =
                    Provider.of<ContactsProvider>(context, listen: false);
                await Navigator.of(context).pushNamed('/contacts/add');
                if (!mounted) return;
                contacts.loadContacts();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedChips(ContactsProvider contactsProv) {
    final selectedContacts = contactsProv.selectedContacts;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Clear all button
          GestureDetector(
            onTap: () {
              contactsProv.clearSelection();
              _toggleMultiSelectMode();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppTheme.errorRed.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, size: 16, color: AppTheme.errorRed),
                  SizedBox(width: 4),
                  Text('Clear',
                      style: TextStyle(color: AppTheme.errorRed, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Selected contact chips
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selectedContacts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final contact = selectedContacts[index];
                return _buildSelectedChip(contact, contactsProv);
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildSelectedChip(Contact contact, ContactsProvider contactsProv) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryElectricBlue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primaryElectricBlue.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            contact.languageFlag,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            contact.displayName.split(' ').first,
            style: AppTheme.bodyMedium.copyWith(
              color: isDark ? Colors.white : AppTheme.primaryElectricBlue,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => contactsProv.toggleSelection(contact.id),
            child: Icon(
              Icons.close,
              size: 16,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppTheme.primaryElectricBlue.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isPending = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          if (isPending) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primaryElectricBlue,
                shape: BoxShape.circle,
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .fade(duration: 800.ms)
                .scale(begin: const Offset(0.5, 0.5)),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: AppTheme.labelLarge.copyWith(
              color: isPending
                  ? AppTheme.primaryElectricBlue
                  : AppTheme.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = AppTheme.isDarkMode(context);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.contacts_outlined,
                size: 48,
                color: AppTheme.getSecondaryTextColor(context).withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No contacts yet',
              style: AppTheme.titleMedium.copyWith(
                color: AppTheme.getTextColor(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the + button to add one',
              style:
                  AppTheme.bodyMedium.copyWith(color: AppTheme.getSecondaryTextColor(context)),
            ),
          ],
        ).animate().fadeIn().scale(),
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.9),
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  void _handleContactDismissed(Contact c, ContactsProvider contactsProv) async {
    final messenger = ScaffoldMessenger.of(context);
    await contactsProv.removeContact(c.id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted ${c.displayName}'),
        backgroundColor: AppTheme.getCardColor(context),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppTheme.primaryElectricBlue,
          onPressed: () => contactsProv.loadContacts(),
        ),
      ),
    );
  }

  Widget _buildFAB(ContactsProvider contactsProv) {
    final hasSelection = contactsProv.selectedCount > 0;

    if (_isMultiSelectMode && hasSelection) {
      // Show "Start Group Call" button when contacts are selected
      return FloatingActionButton.extended(
        onPressed: _startGroupCall,
        backgroundColor: AppTheme.successGreen,
        icon: const Icon(Icons.videocam, color: Colors.white),
        label: Text(
          'Call (${contactsProv.selectedCount})',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ).animate().scale(duration: 200.ms);
    }

    // Default FAB for entering multi-select mode
    return FloatingActionButton(
      onPressed: _toggleMultiSelectMode,
      backgroundColor: _isMultiSelectMode
          ? AppTheme.getSecondaryTextColor(context)
          : AppTheme.primaryElectricBlue,
      child: Icon(
        _isMultiSelectMode ? Icons.close : Icons.group_add,
        color: Colors.white,
      ),
    ).animate().scale(duration: 200.ms);
  }

  Widget _buildPendingRequestCard(Contact c, ContactsProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryElectricBlue.withValues(alpha: 0.1),
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(
          color: AppTheme.primaryElectricBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          _GradientAvatar(name: c.displayName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.displayName,
                  style: AppTheme.titleMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Wants to be your friend',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.getSecondaryTextColor(context)),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.errorRed),
                onPressed: () => provider.rejectContactRequest(c.id),
                tooltip: 'Decline',
              ),
              Container(
                decoration: const BoxDecoration(
                  color: AppTheme.successGreen,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.check, color: Colors.white, size: 20),
                  onPressed: () => provider.acceptContactRequest(c.id),
                  tooltip: 'Accept',
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideX();
  }

  Widget _buildContactCard(
    Contact c,
    ContactsProvider contactsProv,
    int index,
  ) {
    final isSelected = contactsProv.isSelected(c.id);
    final canSelect = contactsProv.canSelectMore || isSelected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: AppTheme.borderRadiusMedium,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryElectricBlue.withValues(alpha: 0.15)
                  : (AppTheme.isDarkMode(context)
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white),
              borderRadius: AppTheme.borderRadiusMedium,
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryElectricBlue
                    : (AppTheme.isDarkMode(context)
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppTheme.lightDivider),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: AppTheme.isDarkMode(context) ? null : AppTheme.lightCardShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppTheme.borderRadiusMedium,
                // Only respond to tap in multi-select mode
                onTap: _isMultiSelectMode && canSelect
                    ? () => contactsProv.toggleSelection(c.id)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Checkbox (only in multi-select mode)
                      if (_isMultiSelectMode) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppTheme.primaryElectricBlue
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryElectricBlue
                                  : AppTheme.getSecondaryTextColor(context).withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                      ],
                      _GradientAvatar(name: c.displayName),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.displayName,
                              style: AppTheme.titleMedium
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _LanguageChip(code: c.language),
                                const SizedBox(width: 8),
                                _OnlineIndicator(isOnline: c.isOnline ?? false),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Quick call button (only when not in multi-select mode)
                      if (!_isMultiSelectMode)
                        Builder(
                          builder: (context) {
                            final isDark = AppTheme.isDarkMode(context);
                            return Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? const [
                                          AppTheme.successGreen,
                                          Color(0xFF059669)
                                        ]
                                      : const [
                                          Color(0xFF34D399), // Brighter green
                                          Color(0xFF10B981), // Emerald
                                        ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: isDark
                                    ? AppTheme.glowShadow(
                                        AppTheme.successGreen.withValues(alpha: 0.3),
                                      )
                                    : [
                                        BoxShadow(
                                          color: AppTheme.successGreen.withValues(alpha: 0.35),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.call,
                                    color: Colors.white, size: 20),
                                onPressed: () => _initiateCall(context, c),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 400.ms)
        .slideX(begin: 0.1, end: 0);
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      Provider.of<ContactsProvider>(context, listen: false)
          .setSearchQuery(value);
    });
  }

  Future<bool> _showDeleteDialog(BuildContext context, String name) async {
    final isDark = AppTheme.isDarkMode(context);

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
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkCard.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: AppTheme.borderRadiusMedium,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : AppTheme.lightDivider,
                    ),
                    boxShadow: isDark ? null : AppTheme.lightCardShadow,
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
                        style: AppTheme.titleLarge.copyWith(
                          color: AppTheme.getTextColor(ctx),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Are you sure you want to delete $name?',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.getSecondaryTextColor(ctx),
                        ),
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
                                style: AppTheme.labelLarge
                                    .copyWith(color: AppTheme.getSecondaryTextColor(ctx)),
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
                                  style: AppTheme.labelLarge
                                      .copyWith(color: Colors.white),
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
        ) ??
        false;
  }

  Future<void> _initiateCall(BuildContext context, Contact contact) async {
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final currentUser = authProvider.currentUser!;
      final token = await authProvider.checkAuthStatus();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      await callProvider.startCall(
        [contact.contactUserId],
        currentUserId: currentUser.id,
        token: token,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loader

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/call/active',
        (route) => route.isFirst,
        arguments: {
          'contacts': [contact]
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start call: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }
}

// ==================== Helper Widgets ====================

class _OnlineIndicator extends StatelessWidget {
  final bool isOnline;
  const _OnlineIndicator({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? AppTheme.successGreen : Colors.grey,
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: AppTheme.successGreen.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        )
            .animate(
              target: isOnline ? 1 : 0,
              onPlay: (controller) => controller.repeat(reverse: true),
            )
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.2, 1.2),
              duration: 1.seconds,
              curve: Curves.easeInOut,
            ),
        const SizedBox(width: 4),
        Text(
          isOnline ? 'Online' : 'Offline',
          style: AppTheme.bodyMedium.copyWith(
            fontSize: 12,
            color: AppTheme.getSecondaryTextColor(context),
          ),
        ),
      ],
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
    final isDark = AppTheme.isDarkMode(context);

    return Shimmer.fromColors(
      baseColor: isDark ? AppTheme.darkCard : Colors.grey.shade200,
      highlightColor: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.grey.shade200,
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
