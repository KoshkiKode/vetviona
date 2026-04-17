import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/page_routes.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.account_tree_outlined,
      title: 'Welcome to Vetviona',
      subtitle:
          'Your private family history, stored only on your device — no cloud, no subscription.',
      detail: 'Works fully offline. Your data stays with you.',
    ),
    _OnboardingPageData(
      icon: Icons.person_add_alt_1_outlined,
      title: 'Start with yourself',
      subtitle:
          'Add people to your tree with names, photos, birth dates, life events, and more.',
      detail:
          'Tap the + button on the home screen to add your first family member.',
    ),
    _OnboardingPageData(
      icon: Icons.family_restroom_outlined,
      title: 'Link your family',
      subtitle:
          'Connect parents, children and spouses. Vetviona draws the tree diagram automatically.',
      detail:
          'Open any person\'s profile and use "Add Relationship" to link them.',
    ),
    _OnboardingPageData(
      icon: Icons.account_tree_outlined,
      title: 'Explore your tree',
      subtitle:
          'Visualise your family as an interactive tree, pedigree fan chart, or descendants diagram.',
      detail: 'Access diagrams from the side menu or a person\'s profile page.',
    ),
    _OnboardingPageData(
      icon: Icons.sync_alt_outlined,
      title: 'Sync with family',
      subtitle:
          'Share your tree with relatives nearby using RootLoop™ — a direct, encrypted WiFi or Bluetooth link.',
      detail:
          'No internet required. Open Settings → RootLoop™ Sync to get started.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingDone', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        fadeRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final isLastPage = _currentPage == _pages.length - 1;
    final total = _pages.length;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Gradient background ──────────────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        colorScheme.primary.withValues(alpha: 0.22),
                        colorScheme.surface,
                      ]
                    : [
                        colorScheme.primary.withValues(alpha: 0.09),
                        colorScheme.surface,
                      ],
              ),
            ),
          ),
          // ── Decorative orb ───────────────────────────────────────────────
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.tertiary
                    .withValues(alpha: isDark ? 0.10 : 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.secondary
                    .withValues(alpha: isDark ? 0.08 : 0.05),
              ),
            ),
          ),
          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Top bar: skip (left) + step counter (right) ────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skip button — top LEFT
                      TextButton(
                        onPressed: _finish,
                        child: const Text('Skip'),
                      ),
                      // Step counter
                      Text(
                        '${_currentPage + 1} of $total',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
                // ── Pages ──────────────────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, i) {
                      final page = _pages[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Glass-style icon container
                            ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        colorScheme.primary.withValues(alpha: 0.85),
                                        colorScheme.primary,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: colorScheme.onPrimary
                                          .withValues(alpha: 0.20),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.primary
                                            .withValues(alpha: 0.28),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    page.icon,
                                    size: 48,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              page.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              page.subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.55,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            // ── Tip chip ─────────────────────────────────
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: colorScheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tips_and_updates_outlined,
                                      size: 14,
                                      color: colorScheme.primary),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      page.detail,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color:
                                                colorScheme.onSurfaceVariant,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // ── Dot indicators ─────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentPage == i ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? colorScheme.primary
                            : colorScheme.primary.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // ── CTA button ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _nextPage,
                      child: Text(isLastPage ? 'Get Started' : 'Next'),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String detail;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.detail,
  });
}
