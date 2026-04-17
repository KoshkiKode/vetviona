import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/utils/page_routes.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('fadeSlideRoute', () {
    test('uses CupertinoPageRoute on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final route = fadeSlideRoute<void>(builder: (_) => const SizedBox());

      expect(route, isA<CupertinoPageRoute<void>>());
    });

    testWidgets('uses PageRouteBuilder with fade+slide transition on Android', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final route = fadeSlideRoute<void>(builder: (_) => const SizedBox());
      expect(route, isA<PageRouteBuilder<void>>());

      final pageRoute = route as PageRouteBuilder<void>;
      expect(pageRoute.transitionDuration, const Duration(milliseconds: 280));
      expect(
        pageRoute.reverseTransitionDuration,
        const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(key: ValueKey('host')),
        ),
      );
      final context = tester.element(find.byKey(const ValueKey('host')));

      final transition = pageRoute.transitionsBuilder(
        context,
        const AlwaysStoppedAnimation<double>(1),
        const AlwaysStoppedAnimation<double>(0),
        const SizedBox(),
      );

      expect(transition, isA<FadeTransition>());
      final fade = transition as FadeTransition;
      expect(fade.child, isA<SlideTransition>());
      final slide = fade.child as SlideTransition;
      expect(slide.position.value, Offset.zero);
    });
  });

  group('fadeRoute', () {
    test('always uses PageRouteBuilder, including on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final route = fadeRoute<void>(builder: (_) => const SizedBox());

      expect(route, isA<PageRouteBuilder<void>>());
    });

    testWidgets('uses pure fade transition with expected timings', (
      tester,
    ) async {
      final route = fadeRoute<void>(builder: (_) => const SizedBox());
      final pageRoute = route as PageRouteBuilder<void>;

      expect(pageRoute.transitionDuration, const Duration(milliseconds: 350));
      expect(
        pageRoute.reverseTransitionDuration,
        const Duration(milliseconds: 250),
      );

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(key: ValueKey('host')),
        ),
      );
      final context = tester.element(find.byKey(const ValueKey('host')));

      final transition = pageRoute.transitionsBuilder(
        context,
        const AlwaysStoppedAnimation<double>(1),
        const AlwaysStoppedAnimation<double>(0),
        const SizedBox(),
      );

      expect(transition, isA<FadeTransition>());
      final fade = transition as FadeTransition;
      expect(fade.child, isA<SizedBox>());
    });
  });
}
