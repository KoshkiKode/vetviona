import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// True when the app is running on a platform that should use
/// Cupertino-style navigation (native iOS swipe-back gesture, right-to-left
/// slide transition).
bool get _isCupertinoPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Platform-adaptive push route.
///
/// - **iOS / macOS** → `CupertinoPageRoute`: native right-to-left slide +
///   swipe-back-to-pop gesture.
/// - **Android / Windows / Linux** → custom fade+slight-upward-slide that
///   feels snappier than the default Android ripple expand.
Route<T> fadeSlideRoute<T>({required WidgetBuilder builder}) {
  if (_isCupertinoPlatform) {
    return CupertinoPageRoute<T>(builder: builder);
  }
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final slideCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: fadeCurve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
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
/// Always uses a cross-fade regardless of platform.
Route<T> fadeRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: child,
      );
    },
  );
}
