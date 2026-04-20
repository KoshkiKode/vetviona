// Tests for PurchaseService that exercise state and ChangeNotifier behaviour
// without requiring the InAppPurchase platform channel.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetviona_app/config/app_config.dart';
import 'package:vetviona_app/services/purchase_service.dart';

class _FakeInAppPurchasePlatform extends InAppPurchasePlatform {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  bool available = true;
  ProductDetailsResponse queryResponse = ProductDetailsResponse(
    productDetails: const [],
    notFoundIDs: const [],
  );
  int restorePurchasesCallCount = 0;
  int buyNonConsumableCallCount = 0;
  final List<PurchaseDetails> completedPurchases = <PurchaseDetails>[];
  Set<String>? lastQueryIdentifiers;
  PurchaseParam? lastPurchaseParam;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  void emitPurchases(List<PurchaseDetails> purchases) {
    _controller.add(purchases);
  }

  Future<void> close() => _controller.close();

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    lastQueryIdentifiers = identifiers;
    return queryResponse;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyNonConsumableCallCount += 1;
    lastPurchaseParam = purchaseParam;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restorePurchasesCallCount += 1;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async => false;

  @override
  Future<String> countryCode() async => 'US';
}

ProductDetails _productDetails() => ProductDetails(
  id: kMobilePaidProductId,
  title: 'Vetviona Mobile Paid',
  description: 'Unlocks paid features',
  price: '\$4.99',
  rawPrice: 4.99,
  currencyCode: 'USD',
  currencySymbol: '\$',
);

PurchaseDetails _purchaseDetails({
  required PurchaseStatus status,
  String productId = kMobilePaidProductId,
  bool pendingCompletePurchase = false,
  String? errorMessage,
}) {
  final purchase = PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'test',
    ),
    transactionDate: '1234567890',
    status: status,
  );
  if (errorMessage != null) {
    purchase.error = IAPError(
      source: 'test',
      code: 'purchase_error',
      message: errorMessage,
    );
  }
  purchase.pendingCompletePurchase = pendingCompletePurchase;
  return purchase;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InAppPurchasePlatform originalPlatform;
  late _FakeInAppPurchasePlatform fakePlatform;

  setUpAll(() {
    InAppPurchase.instance;
    originalPlatform = InAppPurchasePlatform.instance;
  });

  tearDownAll(() {
    InAppPurchasePlatform.instance = originalPlatform;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setMobilePaidUnlocked(false);
    fakePlatform = _FakeInAppPurchasePlatform();
    InAppPurchasePlatform.instance = fakePlatform;
  });

  tearDown(() async {
    await fakePlatform.close();
  });

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

  group('PurchaseService store interactions', () {
    late PurchaseService svc;

    setUp(() {
      svc = PurchaseService();
    });

    tearDown(() {
      svc.dispose();
    });

    test(
      'init sets error and skips restore when store is unavailable',
      () async {
        fakePlatform.available = false;

        await svc.init();

        expect(svc.isInitialized, isTrue);
        expect(
          svc.errorMessage,
          'In-app purchases are not available on this device.',
        );
        expect(fakePlatform.restorePurchasesCallCount, 0);
      },
    );

    test(
      'init restores persisted purchase flag and requests restore',
      () async {
        SharedPreferences.setMockInitialValues({
          'vetviona_mobile_paid_purchased': true,
        });
        fakePlatform.available = true;

        await svc.init();

        expect(svc.isPurchased, isTrue);
        expect(svc.isInitialized, isTrue);
        expect(fakePlatform.restorePurchasesCallCount, 1);
      },
    );

    test('loadProduct stores product details on successful response', () async {
      fakePlatform.queryResponse = ProductDetailsResponse(
        productDetails: [_productDetails()],
        notFoundIDs: const [],
      );

      await svc.loadProduct();

      expect(fakePlatform.lastQueryIdentifiers, {kMobilePaidProductId});
      expect(svc.product, isNotNull);
      expect(svc.product!.id, kMobilePaidProductId);
      expect(svc.errorMessage, isNull);
      expect(svc.isLoading, isFalse);
    });

    test('loadProduct sets descriptive error when query fails', () async {
      fakePlatform.queryResponse = ProductDetailsResponse(
        productDetails: const [],
        notFoundIDs: const [kMobilePaidProductId],
        error: IAPError(source: 'test', code: 'query_error', message: 'Boom'),
      );

      await svc.loadProduct();

      expect(svc.product, isNull);
      expect(svc.errorMessage, contains('Could not load product info: Boom'));
      expect(svc.isLoading, isFalse);
    });

    test('buyMobilePaid loads product and calls buyNonConsumable', () async {
      fakePlatform.queryResponse = ProductDetailsResponse(
        productDetails: [_productDetails()],
        notFoundIDs: const [],
      );

      await svc.buyMobilePaid();

      expect(fakePlatform.buyNonConsumableCallCount, 1);
      expect(fakePlatform.lastPurchaseParam, isNotNull);
      expect(
        fakePlatform.lastPurchaseParam!.productDetails.id,
        kMobilePaidProductId,
      );
      expect(svc.isLoading, isTrue);
      expect(svc.errorMessage, isNull);
    });

    test(
      'buyMobilePaid reports store unavailable when product exists',
      () async {
        fakePlatform.queryResponse = ProductDetailsResponse(
          productDetails: [_productDetails()],
          notFoundIDs: const [],
        );
        await svc.loadProduct();
        fakePlatform.available = false;

        await svc.buyMobilePaid();

        expect(fakePlatform.buyNonConsumableCallCount, 0);
        expect(svc.errorMessage, 'Store is not available.');
        expect(svc.isLoading, isFalse);
      },
    );

    test('restorePurchases sets loading and delegates to store', () async {
      await svc.restorePurchases();

      expect(fakePlatform.restorePurchasesCallCount, 1);
      expect(svc.isLoading, isTrue);
      expect(svc.errorMessage, isNull);
    });

    test(
      'purchase stream purchased update unlocks and persists state',
      () async {
        await svc.init();

        final purchase = _purchaseDetails(
          status: PurchaseStatus.purchased,
          pendingCompletePurchase: true,
        );
        fakePlatform.emitPurchases([purchase]);
        await Future<void>.delayed(const Duration(milliseconds: 1));

        final prefs = await SharedPreferences.getInstance();
        expect(svc.isPurchased, isTrue);
        expect(svc.isLoading, isFalse);
        expect(svc.errorMessage, isNull);
        expect(prefs.getBool('vetviona_mobile_paid_purchased'), isTrue);
        expect(fakePlatform.completedPurchases, contains(purchase));
      },
    );

    test(
      'purchase stream error update surfaces message and clears loading',
      () async {
        await svc.init();

        final purchase = _purchaseDetails(
          status: PurchaseStatus.error,
          errorMessage: 'Card declined',
        );
        fakePlatform.emitPurchases([purchase]);
        await Future<void>.delayed(const Duration(milliseconds: 1));

        expect(svc.errorMessage, 'Card declined');
        expect(svc.isLoading, isFalse);
      },
    );
  });
}
