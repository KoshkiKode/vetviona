import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/utils/platform_utils.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('platform flags', () {
    test('iOS flags are consistent', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(isIOS, isTrue);
      expect(isMacOS, isFalse);
      expect(isAndroid, isFalse);
      expect(isCupertino, isTrue);
      expect(isMobile, isTrue);
      expect(isDesktop, isFalse);
    });

    test('macOS flags are consistent', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      expect(isIOS, isFalse);
      expect(isMacOS, isTrue);
      expect(isAndroid, isFalse);
      expect(isCupertino, isTrue);
      expect(isMobile, isFalse);
      expect(isDesktop, isTrue);
    });

    test('Android flags are consistent', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(isIOS, isFalse);
      expect(isMacOS, isFalse);
      expect(isAndroid, isTrue);
      expect(isCupertino, isFalse);
      expect(isMobile, isTrue);
      expect(isDesktop, isFalse);
    });
  });

  group('adaptiveScrollPhysics', () {
    test('uses bouncing physics on Cupertino platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(adaptiveScrollPhysics(), isA<BouncingScrollPhysics>());

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(adaptiveScrollPhysics(), isA<BouncingScrollPhysics>());
    });

    test('uses clamping physics on non-Cupertino platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(adaptiveScrollPhysics(), isA<ClampingScrollPhysics>());

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(adaptiveScrollPhysics(), isA<ClampingScrollPhysics>());
    });
  });

  group('systemUiStyleFor', () {
    test('returns dark-icons style for light surfaces', () {
      final style = systemUiStyleFor(
        backgroundColor: Colors.white,
        surfaceBrightness: Brightness.light,
      );

      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
      expect(style.systemNavigationBarColor, Colors.white);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    });

    test('returns light-icons style for dark surfaces', () {
      final style = systemUiStyleFor(
        backgroundColor: Colors.black,
        surfaceBrightness: Brightness.dark,
      );

      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
      expect(style.systemNavigationBarColor, Colors.black);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
    });
  });

  group('pickDateAdaptive', () {
    testWidgets('uses Material date picker on Android', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      final pickedFuture = pickDateAdaptive(
        context,
        initialDate: DateTime(2024, 6, 15),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );

      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final picked = await pickedFuture;
      expect(picked, DateTime(2024, 6, 15));
    });

    testWidgets('uses Cupertino date picker on iOS and returns chosen value', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      final pickedFuture = pickDateAdaptive(
        context,
        initialDate: DateTime(2024, 6, 15),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);

      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      picker.onDateTimeChanged(DateTime(2025, 1, 2));

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final picked = await pickedFuture;
      expect(picked, DateTime(2025, 1, 2));
    });

    testWidgets('uses default min/max bounds when omitted on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      final pickedFuture = pickDateAdaptive(
        context,
        initialDate: DateTime(2024, 6, 15),
      );

      await tester.pumpAndSettle();
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.minimumDate, DateTime(1700));
      expect(picker.maximumDate, DateTime(2100));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await pickedFuture, isNull);
    });
  });
}
