// Tests for PurchaseService that exercise state and ChangeNotifier behaviour
// without requiring the InAppPurchase platform channel.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetviona_app/services/purchase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── constant ──────────────────────────────────────────────────────────────

  group('kMobilePaidProductId', () {
    test('is non-empty', () {
      expect(kMobilePaidProductId, isNotEmpty);
    });

    test('starts with com.koshkikode.vetviona', () {
      expect(kMobilePaidProductId, startsWith('com.koshkikode.vetviona'));
    });
  });

  // ── PurchaseService initial state ─────────────────────────────────────────

  group('PurchaseService initial state', () {
    late PurchaseService svc;

    setUp(() => svc = PurchaseService());
    tearDown(() => svc.dispose());

    test('isPurchased is false', () => expect(svc.isPurchased, isFalse));
    test('isLoading is false', () => expect(svc.isLoading, isFalse));
    test('errorMessage is null', () => expect(svc.errorMessage, isNull));
    test('product is null', () => expect(svc.product, isNull));
    test('isInitialized is false', () => expect(svc.isInitialized, isFalse));
  });

  // ── PurchaseService.dispose ───────────────────────────────────────────────

  group('PurchaseService.dispose', () {
    test('dispose does not throw when no subscription is active', () {
      final svc = PurchaseService();
      expect(() => svc.dispose(), returnsNormally);
    });
  });

  // ── PurchaseService as ChangeNotifier ─────────────────────────────────────

  group('PurchaseService ChangeNotifier', () {
    test('addListener / removeListener work without error', () {
      final svc = PurchaseService();
      void listener() {}
      svc.addListener(listener);
      svc.removeListener(listener);
      svc.dispose();
    });

    test('hasListeners is false initially', () {
      final svc = PurchaseService();
      // ignore: invalid_use_of_protected_member
      expect(svc.hasListeners, isFalse);
      svc.dispose();
    });

    test('hasListeners is true after addListener', () {
      final svc = PurchaseService();
      void listener() {}
      svc.addListener(listener);
      // ignore: invalid_use_of_protected_member
      expect(svc.hasListeners, isTrue);
      svc.removeListener(listener);
      svc.dispose();
    });
  });
}
