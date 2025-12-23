import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: AppTheme.borderRadiusMedium,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      decoration: AppTheme.glassDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderColor: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _handleSearchChanged,
                        style: AppTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone',
                          hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.secondaryText),
                          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryElectricBlue),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.buttonShadow,
                ),
                child: IconButton(
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                  onPressed: () async {
                    if (!mounted) return;
                    final contacts = Provider.of<ContactsProvider>(context, listen: false);
                    await Navigator.of(context).pushNamed('/contacts/add');
                    if (!mounted) return;
                    // Refresh contacts after returning from add screen
                    contacts.loadContacts();
                  },
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Builder(
            builder: (_) {
              if (contactsProv.isLoading) {
                return ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: 6,
                  itemBuilder: (_, __) => _ShimmerRow(),
                );
              }

              final contacts = contactsProv.contacts;
              final pending = contactsProv.pendingIncoming;

              return RefreshIndicator(
                onRefresh: () async => await contactsProv.refreshContacts(),
                color: AppTheme.primaryElectricBlue,
                backgroundColor: AppTheme.darkCard,
                child: ListView(
                  controller: widget.scrollController,
                  physics: const AlwaysScrollableScrollPhysics(), // Ensure scroll for refresh
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    // Pending Requests Section
                    if (pending.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8, 
                              height: 8, 
                              decoration: const BoxDecoration(color: AppTheme.primaryElectricBlue, shape: BoxShape.circle),
                            ).animate(onPlay: (c) => c.repeat()).fade(duration: 800.ms).scale(begin: const Offset(0.5, 0.5)),
                            const SizedBox(width: 8),
                            Text(
                              'Pending Requests (${pending.length})', 
                              style: AppTheme.labelLarge.copyWith(color: AppTheme.primaryElectricBlue),
                            ),
                          ],
                        ),
                      ),
                      ...pending.map((c) => _buildPendingRequestCard(c, contactsProv)),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          'Contacts (${contacts.length})', 
                          style: AppTheme.labelLarge.copyWith(color: AppTheme.secondaryText),
                        ),
                      ),
                    ],

                    // Contacts List
                    if (contacts.isEmpty && pending.isEmpty) ...[
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.contacts_outlined, size: 48, color: Colors.white.withValues(alpha: 0.4)),
                              ),
                              const SizedBox(height: 16),
                              const Text('No contacts yet', style: AppTheme.titleMedium),
                              const SizedBox(height: 6),
                              Text('Tap the + button to add one', style: AppTheme.bodyMedium.copyWith(color: AppTheme.secondaryText)),
                            ],
                          ).animate().fadeIn().scale(),
                        ),
                      )
                     ] else ...[
                      ...contacts.asMap().entries.map((entry) {
                        final index = entry.key;
                        final c = entry.value;
                        return Dismissible(
                          key: Key(c.id.isEmpty ? 'contact_$index' : c.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withValues(alpha: 0.9),
                              borderRadius: AppTheme.borderRadiusMedium,
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            return await _showDeleteDialog(context, c.displayName);
                          },
                          onDismissed: (_) async {
                            final messenger = ScaffoldMessenger.of(context);
                            await contactsProv.removeContact(c.id);
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Deleted ${c.displayName}'),
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
                      }),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
                  const Text(
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
                  style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Wants to be your friend',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.secondaryText),
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

  Widget _buildContactCard(Contact c, CallProvider callProv, int index) {
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
                  // Select this contact and go to participant selection
                  final contacts = Provider.of<ContactsProvider>(context, listen: false);
                  contacts.clearSelection();
                  contacts.selectContact(c.id);
                  Navigator.pushNamed(context, '/call/select');
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _GradientAvatar(name: c.displayName),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.displayName,
                              style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _LanguageChip(code: c.language),
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: c.isOnline == true ? AppTheme.successGreen : Colors.grey,
                                    boxShadow: c.isOnline == true 
                                        ? [BoxShadow(color: AppTheme.successGreen.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)]
                                        : null,
                                  ),
                                ).animate(
                                  target: c.isOnline == true ? 1 : 0,
                                  onPlay: (controller) => controller.repeat(reverse: true),
                                ).scale(
                                  begin: const Offset(1.0, 1.0), 
                                  end: const Offset(1.2, 1.2), 
                                  duration: 1.seconds,
                                  curve: Curves.easeInOut,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  c.isOnline == true ? 'Online' : 'Offline',
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
                            // Quick call - select and go directly to confirmation
                            final contacts = Provider.of<ContactsProvider>(context, listen: false);
                            contacts.clearSelection();
                            contacts.selectContact(c.id);
                            Navigator.pushNamed(context, '/call/confirm');
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
