import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../providers/call_provider.dart';
import '../../providers/contacts_provider.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ContactsProvider>(context, listen: false).loadContacts();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactsProv = Provider.of<ContactsProvider>(context);
    final callProv = Provider.of<CallProvider>(context, listen: false);
    final ScrollController scroll = ScrollController();
    double fabScale = 1.0;

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollUpdateNotification) {
            final s = (1.0 - (n.metrics.pixels / 200)).clamp(0.7, 1.0);
            if (fabScale != s) {
              setState(() => fabScale = s);
            }
          }
          return false;
        },
        child: CustomScrollView(
          controller: scroll,
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: true,
              title: const Text('Contacts'),
              actions: const [Icon(Icons.person_outline)],
            ),

            // Sticky search bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchHeader(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search or scan contacts',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () => _openQrScanner(context),
                      ),
                    ),
                    onChanged: _handleSearchChanged,
                  ),
                ),
              ),
            ),

            // Loading shimmer
            if (contactsProv.isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ShimmerRow(),
                  childCount: 6,
                ),
              )
            else if (contactsProv.contacts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(onAdd: () {}),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final c = contactsProv.contacts[index];
                    return Dismissible(
                      key: ValueKey(c.id),
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        final res = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete contact'),
                            content: Text('Delete ${c.name}?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        return res ?? false;
                      },
                      onDismissed: (_) async {
                        final name = c.name;
                        final messenger = ScaffoldMessenger.of(context);
                        await contactsProv.removeContact(c.id);
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Deleted $name'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () => contactsProv.loadContacts(),
                            ),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: _GradientAvatar(name: c.name),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Row(
                            children: [
                              _LanguageChip(code: c.language),
                              const SizedBox(width: 8),
                              Text(c.status),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.call, color: Colors.green),
                            onPressed: () {
                              callProv.startMockCall();
                              Navigator.pushNamed(context, '/call');
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: contactsProv.contacts.length,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: AnimatedScale(
        scale: fabScale,
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton(
          onPressed: () async {
            if (_nameController.text.trim().isEmpty) return;
            await contactsProv.addContact(_nameController.text.trim(), _selectedLanguage);
            _nameController.clear();
          },
          child: const Icon(Icons.add),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Contact name'),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _selectedLanguage,
              items: const [
                DropdownMenuItem(value: 'he', child: Text('🇮🇱 he')),
                DropdownMenuItem(value: 'en', child: Text('🇺🇸 en')),
                DropdownMenuItem(value: 'ru', child: Text('🇷🇺 ru')),
              ],
              onChanged: (v) => setState(() => _selectedLanguage = v ?? 'en'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      Provider.of<ContactsProvider>(context, listen: false).setSearchQuery(value);
    });
  }

  Future<void> _openQrScanner(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final contactsProvider = Provider.of<ContactsProvider>(context, listen: false);
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.black,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scan contact QR',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    if (capture.barcodes.isEmpty) {
                      return;
                    }
                    final barcode = capture.barcodes.firstWhere(
                      (b) => (b.rawValue ?? '').isNotEmpty,
                      orElse: () => capture.barcodes.first,
                    );
                    final value = barcode.rawValue;
                    if (value != null && value.isNotEmpty) {
                      Navigator.of(ctx).pop(value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null || result.isEmpty) return;
    await contactsProvider.addContactFromQr(result);
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Contact added from QR')),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String code;
  const _LanguageChip({required this.code});

  @override
  Widget build(BuildContext context) {
    final label = code.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _SearchHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SearchHeader({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 56;

  @override
  double get minExtent => 56;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

class _ShimmerRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(width: 120, height: 10, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No contacts yet', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add your first contact')),
        ],
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
      const Color(0xFF7C3AED),
      const Color(0xFF3B82F6),
      const Color(0xFF06B6D4),
      const Color(0xFF10B981),
    ];
    colors.shuffle();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [colors.first, colors.last]),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
