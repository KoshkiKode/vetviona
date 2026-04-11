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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // ── Logo + name ───────────────────────────────────────────────
              ScaleTransition(
                scale: _logoScale,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          Icons.park_outlined,
                          size: 52,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              // ── Progress section ──────────────────────────────────────────
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
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 1),
              // ── Company name ──────────────────────────────────────────────
              FadeTransition(
                opacity: _logoFade,
                child: Text(
                  BuildMetadata.companyName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            colorScheme.onSurfaceVariant.withOpacity(0.5),
                        letterSpacing: 1.5,
                      ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
