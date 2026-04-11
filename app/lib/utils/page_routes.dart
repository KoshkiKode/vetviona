import 'package:flutter/material.dart';

/// Returns a [PageRouteBuilder] that fades + slides the new page in from
/// slightly below.  Used throughout the app so all screen transitions feel
/// cohesive rather than relying on the per-platform Material/Cupertino default.
Route<T> fadeSlideRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeCurve =
          CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final slideCurve =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: fadeCurve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(slideCurve),
          child: child,
        ),
      );
    },
  );
}

/// Pure-fade replacement route — used for `pushReplacement` calls (e.g.
/// onboarding → home, login → register) where a slide feels wrong.
Route<T> fadeRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
  );
}
