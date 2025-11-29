import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../contacts/contacts_screen.dart';
import '../settings/settings_screen.dart';
import '../../config/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _backgroundController;
  final ScrollController _scrollController = ScrollController();
  bool _isNavVisible = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final currentOffset = _scrollController.offset;
    final delta = currentOffset - _lastScrollOffset;
    
    if (delta > 10 && _isNavVisible) {
      setState(() => _isNavVisible = false);
    } else if (delta < -10 && !_isNavVisible) {
      setState(() => _isNavVisible = true);
    }
    
    _lastScrollOffset = currentOffset;
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent keyboard from pushing nav bar
      body: Stack(
        children: [
          // Animated Gradient Background
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: const [
                      Color(0xFF0F1630),
                      Color(0xFF1B2750),
                      Color(0xFF2A3A6B),
                    ],
                    stops: [
                      0.0,
                      _backgroundController.value,
                      1.0,
                    ],
                  ),
                ),
              );
            },
          ),

          // Floating orbs for depth
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryElectricBlue.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondaryPurple.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                _buildAppBar()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: -0.2, end: 0),

                // Start Call Hero Button (only on Contacts tab)
                if (_currentIndex == 0) ...[
                  const SizedBox(height: 16),
                  _buildStartCallButton()
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
                ],

                // Body Content
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),

          // Floating Navigation Dock
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _isNavVisible ? 24 : -100,
            left: 40,
            right: 40,
            child: _buildFloatingNavBar()
              .animate()
              .fadeIn(delay: 500.ms, duration: 400.ms)
              .slideY(begin: 0.5, end: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // App Logo/Title
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: AppTheme.borderRadiusSmall,
              boxShadow: AppTheme.glowShadow(AppTheme.primaryElectricBlue.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.translate,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Translator',
                  style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  _getSubtitle(),
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Profile Button
          ClipRRect(
            borderRadius: AppTheme.borderRadiusSmall,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 44,
                height: 44,
                decoration: AppTheme.glassDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: AppTheme.radiusSmall,
                ),
                child: IconButton(
                  icon: const Icon(Icons.person_outline, color: Colors.white70),
                  onPressed: () {
                    // Navigate to profile
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSubtitle() {
    switch (_currentIndex) {
      case 0:
        return 'Your contacts';
      case 1:
        return 'Call history';
      case 2:
        return 'Preferences';
      default:
        return '';
    }
  }

  Widget _buildStartCallButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: AppTheme.borderRadiusLarge,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryElectricBlue.withValues(alpha: 0.3),
                  AppTheme.secondaryPurple.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: AppTheme.borderRadiusLarge,
              border: Border.all(
                color: AppTheme.primaryElectricBlue.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppTheme.borderRadiusLarge,
                onTap: () {
                  Navigator.pushNamed(context, '/call/select');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.glowShadow(AppTheme.primaryElectricBlue),
                        ),
                        child: const Icon(
                          Icons.call,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Translated Call',
                              style: AppTheme.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Select participants to call',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    Widget child;
    switch (_currentIndex) {
      case 0:
        child = ContactsScreen(scrollController: _scrollController);
        break;
      case 1:
        child = _buildRecentCalls();
        break;
      case 2:
        child = const SettingsScreen();
        break;
      default:
        child = const SizedBox();
    }
    return child;
  }

  Widget _buildRecentCalls() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history,
              size: 40,
              color: AppTheme.secondaryText.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No recent calls',
            style: AppTheme.titleMedium.copyWith(color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 8),
          Text(
            'Your call history will appear here',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.secondaryText.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    return ClipRRect(
      borderRadius: AppTheme.borderRadiusPill,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: AppTheme.darkCard.withValues(alpha: 0.8),
            borderRadius: AppTheme.borderRadiusPill,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.contacts_outlined, Icons.contacts, 'Contacts'),
              _buildNavItem(1, Icons.history_outlined, Icons.history, 'Recents'),
              _buildNavItem(2, Icons.settings_outlined, Icons.settings, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryElectricBlue.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: AppTheme.borderRadiusPill,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppTheme.primaryElectricBlue : AppTheme.secondaryText,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.primaryElectricBlue : AppTheme.secondaryText,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}