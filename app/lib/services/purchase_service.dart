import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

// ── Product IDs ──────────────────────────────────────────────────────────────

/// The store product ID for upgrading from Mobile Free → Mobile Paid.
/// Must match the product configured in Google Play Console and App Store
/// Connect.
const String kMobilePaidProductId = 'com.koshkikode.vetviona.mobile_paid';

// ── PurchaseService ──────────────────────────────────────────────────────────

/// Manages one-time in-app purchases for the Mobile Paid tier.
///
/// Wire this up in `app.dart` using [ChangeNotifierProvider] so the UI can
/// observe [isPurchased] and [isLoading].
///
/// After a successful purchase the receipt is persisted in [SharedPreferences]
/// under the key [_purchasedKey] so it survives app restarts.
///
/// Usage:
/// 1. [init] — call once on startup to restore previous purchases and begin
///    listening for purchase updates.
/// 2. [loadProduct] — fetches product info from the store.
/// 3. [buyMobilePaid] — initiates the purchase flow.
/// 4. [dispose] — clean up the subscription.
class PurchaseService extends ChangeNotifier {
  static const _purchasedKey = 'vetviona_mobile_paid_purchased';

  // ── State ───────────────────────────────────────────────────────────────────

  bool _isPurchased = false;

  /// Whether the Mobile Paid upgrade has been purchased on this device.
  bool get isPurchased => _isPurchased;

  bool _isLoading = false;

  /// True while a store query or purchase transaction is in progress.
  bool get isLoading => _isLoading;

  String? _errorMessage;

  /// Non-null when the most recent operation ended in an error.
  String? get errorMessage => _errorMessage;

  ProductDetails? _product;

  /// Store product details for the Mobile Paid SKU (null until [loadProduct]
  /// completes successfully).
  ProductDetails? get product => _product;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Must be called once after the widget tree is ready.  Restores a previous
  /// purchase and starts listening for store callbacks.
  Future<void> init() async {
    // Restore persisted purchase state.
    final prefs = await SharedPreferences.getInstance();
    _isPurchased = prefs.getBool(_purchasedKey) ?? false;
    // Unlock paid features immediately if a previous purchase was found —
    // this ensures currentAppTier returns mobilePaid on every app restart
    // without requiring the user to go through the store again.
    if (_isPurchased) setMobilePaidUnlocked(true);

    if (!await InAppPurchase.instance.isAvailable()) {
      _errorMessage = 'In-app purchases are not available on this device.';
      notifyListeners();
      return;
    }

    // Listen for purchase updates (new purchases AND restored purchases).
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (dynamic e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );

    // Ask the store to restore any previous purchases so the user is not
    // required to buy again after reinstalling.
    await InAppPurchase.instance.restorePurchases();
  }

  // ── Product loading ─────────────────────────────────────────────────────────

  /// Fetches product details from the store.  Call this before showing the
  /// upgrade UI so you can display the price.
  Future<void> loadProduct() async {
    if (!await InAppPurchase.instance.isAvailable()) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await InAppPurchase.instance.queryProductDetails(
      {kMobilePaidProductId},
    );

    _isLoading = false;

    if (response.error != null) {
      _errorMessage = 'Could not load product info: ${response.error!.message}';
    } else if (response.productDetails.isEmpty) {
      _errorMessage =
          'Product "$kMobilePaidProductId" not found in the store. '
          'Ensure it is configured in the developer console.';
    } else {
      _product = response.productDetails.first;
    }

    notifyListeners();
  }

  // ── Purchase flow ───────────────────────────────────────────────────────────

  /// Initiates the Mobile Paid purchase flow.  The result arrives
  /// asynchronously via [_onPurchaseUpdate].
  Future<void> buyMobilePaid() async {
    if (_product == null) {
      await loadProduct();
      if (_product == null) return;
    }

    if (!await InAppPurchase.instance.isAvailable()) {
      _errorMessage = 'Store is not available.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final purchaseParam = PurchaseParam(productDetails: _product!);
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
    // Purchase result arrives via purchaseStream → _onPurchaseUpdate.
  }

  // ── Purchase update handler ─────────────────────────────────────────────────

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != kMobilePaidProductId) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _deliverPurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        _errorMessage = purchase.error?.message ?? 'Purchase failed.';
        _isLoading = false;
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.canceled) {
        _isLoading = false;
        notifyListeners();
      }

      // Always complete the purchase to tell the store we handled it.
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  /// Persists the purchase and updates state.
  Future<void> _deliverPurchase(PurchaseDetails purchase) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_purchasedKey, true);
    setMobilePaidUnlocked(true);
    _isPurchased = true;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Restore ─────────────────────────────────────────────────────────────────

  /// Manually triggers a purchase restore (useful for a "Restore Purchases"
  /// button in the UI).
  Future<void> restorePurchases() async {
    if (!await InAppPurchase.instance.isAvailable()) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    await InAppPurchase.instance.restorePurchases();
    // Results arrive via _onPurchaseUpdate.
  }

  // ── Disposal ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
