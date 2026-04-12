import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/config/app_config.dart';

void main() {
  group('AppTier', () {
    test('has exactly three values', () {
      expect(AppTier.values, hasLength(3));
    });

    test('contains mobileFree', () {
      expect(AppTier.values, contains(AppTier.mobileFree));
    });

    test('contains mobilePaid', () {
      expect(AppTier.values, contains(AppTier.mobilePaid));
    });

    test('contains desktopPro', () {
      expect(AppTier.values, contains(AppTier.desktopPro));
    });

    test('all three tiers are distinct', () {
      expect(AppTier.mobileFree, isNot(equals(AppTier.mobilePaid)));
      expect(AppTier.mobileFree, isNot(equals(AppTier.desktopPro)));
      expect(AppTier.mobilePaid, isNot(equals(AppTier.desktopPro)));
    });
  });

  group('freeMobilePersonLimit', () {
    test('is 100', () {
      expect(freeMobilePersonLimit, 100);
    });

    test('is a positive integer', () {
      expect(freeMobilePersonLimit, greaterThan(0));
    });
  });

  group('currentAppTier', () {
    // On the Linux test runner there are no compile-time PAID/MOBILE_PAID
    // flags set, so the tier is desktopPro (the Linux platform branch fires).
    test('returns a valid AppTier value', () {
      expect(AppTier.values, contains(currentAppTier));
    });

    test('is desktopPro on the Linux CI runner (no PAID flags set)', () {
      // This assertion documents the expected behaviour in the standard test
      // environment.  If the test suite is ever run with --dart-define=PAID=true
      // on a mobile platform this expectation would not apply.
      expect(currentAppTier, AppTier.desktopPro);
    });
  });

  group('isProTier', () {
    test('returns a bool', () {
      expect(isProTier, isA<bool>());
    });

    test('is true when currentAppTier is not mobileFree', () {
      // On the Linux CI runner currentAppTier == desktopPro, so isProTier
      // must be true.
      if (currentAppTier != AppTier.mobileFree) {
        expect(isProTier, true);
      } else {
        expect(isProTier, false);
      }
    });
  });
}
