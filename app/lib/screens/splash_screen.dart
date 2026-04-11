import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/build_metadata.dart';
import '../providers/tree_provider.dart';

/// Animated splash screen shown while [TreeProvider] completes its initial
/// data load.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _logoFade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Gradient background ─────────────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        colorScheme.primary.withOpacity(0.25),
                        colorScheme.surface,
                        colorScheme.surfaceContainerLow,
                      ]
                    : [
                        colorScheme.primary.withOpacity(0.12),
                        colorScheme.surface,
                        colorScheme.surfaceContainerLow,
                      ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // ── Decorative blurred orb (top-left) ───────────────────────────
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withOpacity(isDark ? 0.18 : 0.1),
              ),
            ),
          ),
          // ── Decorative blurred orb (bottom-right) ───────────────────────
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.tertiary.withOpacity(isDark ? 0.15 : 0.08),
              ),
            ),
          ),
          // ── Main content ────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  // ── Logo + name ─────────────────────────────────────────
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: Column(
                        children: [
                          // Glass-style logo container
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      colorScheme.primary.withOpacity(0.75),
                                      colorScheme.primary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: colorScheme.onPrimary
                                        .withOpacity(0.25),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary
                                          .withOpacity(0.35),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.park_outlined,
                                  size: 52,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            BuildMetadata.appName,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your family story',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  // ── Progress section ──────────────────────────────────────
                  FadeTransition(
                    opacity: _logoFade,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: provider.loadingProgress > 0
                                ? provider.loadingProgress
                                : null,
                            minHeight: 6,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            provider.loadingMessage,
                            key: ValueKey(provider.loadingMessage),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 1),
                  // ── Company name ──────────────────────────────────────────
                  FadeTransition(
                    opacity: _logoFade,
                    child: Text(
                      BuildMetadata.companyName,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: colorScheme.onSurfaceVariant
                                .withOpacity(0.5),
                            letterSpacing: 1.5,
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
