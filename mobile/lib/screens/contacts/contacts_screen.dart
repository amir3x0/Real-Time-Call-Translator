import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/call_provider.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ContactsProvider>(context, listen: false).loadContacts();
    });
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
                    decoration: const InputDecoration(
                      hintText: 'Search contacts...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) {},
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
                        color: Colors.redAccent,
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
                        await contactsProv.removeContact(c.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Deleted $name'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () => contactsProv.loadContacts(),
                            ),
                          ),
                        );
                      },
                      child: ListTile(
                        leading: _GradientAvatar(name: c.name),
                        title: Text(c.name),
                        subtitle: Text('${c.status} • ${c.language}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () {
                            callProv.startMockCall();
                            Navigator.pushNamed(context, '/call');
                          },
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
