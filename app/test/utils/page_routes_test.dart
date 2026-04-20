import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/utils/page_routes.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('fadeSlideRoute', () {
    test('uses CupertinoPageRoute on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final route = fadeSlideRoute<void>(builder: (_) => const SizedBox());

      expect(route, isA<CupertinoPageRoute<void>>());
    });

    test('uses CupertinoPageRoute on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

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
      expect(pageRoute.transitionDuration, const Duration(milliseconds: 320));
      expect(
        pageRoute.reverseTransitionDuration,
        const Duration(milliseconds: 260),
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
      expect(pageRoute.opaque, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('pageBuilder builds the provided widget on Android', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final route = fadeSlideRoute<void>(builder: (_) => const Text('hello'));
      final pageRoute = route as PageRouteBuilder<void>;

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(key: ValueKey('host')),
        ),
      );
      final context = tester.element(find.byKey(const ValueKey('host')));
      final widget = pageRoute.pageBuilder(
        context,
        const AlwaysStoppedAnimation<double>(1),
        const AlwaysStoppedAnimation<double>(0),
      );
      expect(widget, isA<Text>());
      debugDefaultTargetPlatformOverride = null;
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

      expect(pageRoute.transitionDuration, const Duration(milliseconds: 320));
      expect(
        pageRoute.reverseTransitionDuration,
        const Duration(milliseconds: 260),
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

    testWidgets('pageBuilder builds the provided widget', (tester) async {
      final route = fadeRoute<void>(builder: (_) => const Text('world'));
      final pageRoute = route as PageRouteBuilder<void>;

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(key: ValueKey('host')),
        ),
      );
      final context = tester.element(find.byKey(const ValueKey('host')));
      final widget = pageRoute.pageBuilder(
        context,
        const AlwaysStoppedAnimation<double>(1),
        const AlwaysStoppedAnimation<double>(0),
      );
      expect(widget, isA<Text>());
    });
  });
}
