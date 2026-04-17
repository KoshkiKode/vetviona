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
    test('returns a valid AppTier value', () {
      expect(AppTier.values, contains(currentAppTier));
    });

    // The concrete tier depends on the host platform and any --dart-define
    // flags, so we only assert the consistency invariant here.
    test('isProTier is false iff currentAppTier is mobileFree', () {
      if (currentAppTier == AppTier.mobileFree) {
        expect(isProTier, false);
      } else {
        expect(isProTier, true);
      }
    });
  });

  group('isProTier', () {
    test('returns a bool', () {
      expect(isProTier, isA<bool>());
    });
  });

  group('isPaidDesktop', () {
    test('returns a bool', () {
      expect(isPaidDesktop, isA<bool>());
    });
  });

  group('setMobilePaidUnlocked', () {
    // The test runner executes on a desktop platform so currentAppTier is
    // always desktopPro regardless of the unlock flag.  We still exercise the
    // setter to ensure it doesn't throw and the call path is covered.
    test('can be called with true without throwing', () {
      expect(() => setMobilePaidUnlocked(true), returnsNormally);
    });

    test('can be called with false without throwing', () {
      expect(() => setMobilePaidUnlocked(false), returnsNormally);
    });

    test('isProTier remains true on desktop after unlock=false', () {
      setMobilePaidUnlocked(false);
      // On the test host (Linux desktop) the tier is always desktopPro.
      expect(isProTier, isTrue);
    });
  });
}
