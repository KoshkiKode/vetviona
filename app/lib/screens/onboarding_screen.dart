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
      icon: Icons.account_tree,
      title: 'Welcome to Vetviona',
      subtitle: 'Your private family history, stored only on your device.',
    ),
    _OnboardingPageData(
      icon: Icons.person_add_alt_1,
      title: 'Start with yourself',
      subtitle:
          'Add family members, record their birth dates, photos, and life events.',
    ),
    _OnboardingPageData(
      icon: Icons.sync_alt,
      title: 'Build your family tree',
      subtitle:
          'Link parents and children, explore the diagram, and sync with family members nearby.',
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
        duration: const Duration(milliseconds: 300),
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
                        colorScheme.primary.withOpacity(0.2),
                        colorScheme.surface,
                      ]
                    : [
                        colorScheme.primary.withOpacity(0.08),
                        colorScheme.surface,
                      ],
              ),
            ),
          ),
          // ── Decorative orb ───────────────────────────────────────────────
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.tertiary
                    .withOpacity(isDark ? 0.12 : 0.07),
              ),
            ),
          ),
          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: Stack(
              children: [
                if (!isLastPage)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: TextButton(
                      onPressed: _finish,
                      child: const Text('Skip'),
                    ),
                  ),
                Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _pages.length,
                        onPageChanged: (i) =>
                            setState(() => _currentPage = i),
                        itemBuilder: (context, i) {
                          final page = _pages[i];
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Glass-style icon container
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 8, sigmaY: 8),
                                    child: Container(
                                      width: 112,
                                      height: 112,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            colorScheme.primary
                                                .withOpacity(0.8),
                                            colorScheme.primary,
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(32),
                                        border: Border.all(
                                          color: colorScheme.onPrimary
                                              .withOpacity(0.2),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorScheme.primary
                                                .withOpacity(0.3),
                                            blurRadius: 20,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        page.icon,
                                        size: 52,
                                        color: colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 36),
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
                                const SizedBox(height: 16),
                                Text(
                                  page.subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        height: 1.5,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Page dots indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin:
                              const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? colorScheme.primary
                                : colorScheme.primary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 40),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _nextPage,
                          child: Text(
                              isLastPage ? 'Get Started' : 'Next'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
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

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
