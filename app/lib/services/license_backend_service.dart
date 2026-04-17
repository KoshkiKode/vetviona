import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../config/build_metadata.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class LicenseDeviceRecord {
  final String id;
  final String appType;
  final String os;
  final String firstVerifiedAt;
  final String lastVerifiedAt;

  const LicenseDeviceRecord({
    required this.id,
    required this.appType,
    required this.os,
    required this.firstVerifiedAt,
    required this.lastVerifiedAt,
  });

  factory LicenseDeviceRecord.fromJson(Map<String, dynamic> json) {
    return LicenseDeviceRecord(
      id: json['id']?.toString() ?? '',
      appType: json['appType']?.toString() ?? '',
      os: json['os']?.toString() ?? '',
      firstVerifiedAt: json['firstVerifiedAt']?.toString() ?? '',
      lastVerifiedAt: json['lastVerifiedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'appType': appType,
    'os': os,
    'firstVerifiedAt': firstVerifiedAt,
    'lastVerifiedAt': lastVerifiedAt,
  };
}

/// Represents a pending license gift/transfer (outgoing or incoming).
class LicensePendingGift {
  final String id;
  final String licenseType;

  /// Non-null for outgoing gifts (the recipient).
  final String? toEmail;

  /// Non-null for incoming gifts (the sender).
  final String? fromEmail;

  final String expiresAt;
  final String createdAt;

  const LicensePendingGift({
    required this.id,
    required this.licenseType,
    this.toEmail,
    this.fromEmail,
    required this.expiresAt,
    required this.createdAt,
  });

  factory LicensePendingGift.fromOutgoingJson(Map<String, dynamic> json) {
    return LicensePendingGift(
      id: json['id']?.toString() ?? '',
      licenseType: json['licenseType']?.toString() ?? '',
      toEmail: json['toEmail']?.toString(),
      expiresAt: json['expiresAt']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  factory LicensePendingGift.fromIncomingJson(Map<String, dynamic> json) {
    return LicensePendingGift(
      id: json['id']?.toString() ?? '',
      licenseType: json['licenseType']?.toString() ?? '',
      fromEmail: json['fromEmail']?.toString(),
      expiresAt: json['expiresAt']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class LicenseBackendService extends ChangeNotifier {
  static const Uuid _uuid = Uuid();
  static const String _configuredBaseUrl = String.fromEnvironment(
    'LICENSE_BACKEND_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  // ── Persisted keys ──────────────────────────────────────────────────────────
  static const _kDeviceIdKey = 'license_backend_device_id';
  static const _kAccountEmailKey = 'license_backend_account_email';
  static const _kAppleVerifiedKey = 'license_backend_apple_verified';
  static const _kAndroidVerifiedKey = 'license_backend_android_verified';
  static const _kDesktopVerifiedKey = 'license_backend_desktop_verified';
  static const _kAppleEntitlementKey = 'license_backend_apple_entitled';
  static const _kAndroidEntitlementKey = 'license_backend_android_entitled';
  static const _kDesktopEntitlementKey = 'license_backend_desktop_entitled';
  static const _kEmailVerifiedKey = 'license_backend_email_verified';
  static const _kDevicesKey = 'license_backend_devices';

  LicenseBackendService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? _configuredBaseUrl).replaceFirst(
        RegExp(r'/+$'),
        '',
      );

  final http.Client _client;
  final String _baseUrl;

  // ── State ───────────────────────────────────────────────────────────────────
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _accountEmail;
  String? get accountEmail => _accountEmail;

  /// In-memory only — cleared on app restart and sign-out.
  String? _cachedPassword;

  /// True if the account email has been verified on the server.
  bool _emailVerified = false;
  bool get emailVerified => _emailVerified;

  // Persisted verification flags (was the license ever verified on this device).
  bool _appleVerified = false;
  bool _androidVerified = false;
  bool _desktopVerified = false;

  // Current entitlement flags (updated from server; reflects gifted-out status).
  bool _appleEntitled = false;
  bool _androidEntitled = false;
  bool _desktopEntitled = false;

  bool get appleEntitled => _appleEntitled;
  bool get androidEntitled => _androidEntitled;
  bool get desktopEntitled => _desktopEntitled;

  /// Per-license status: `'active'`, `'gifted_out'`, or `'none'`.
  String _appleLicenseStatus = 'none';
  String _androidLicenseStatus = 'none';
  String _desktopLicenseStatus = 'none';

  String get appleLicenseStatus => _appleLicenseStatus;
  String get androidLicenseStatus => _androidLicenseStatus;
  String get desktopLicenseStatus => _desktopLicenseStatus;

  List<LicenseDeviceRecord> _devices = const [];
  List<LicenseDeviceRecord> get devices => _devices;

  List<LicensePendingGift> _outgoingGifts = const [];
  List<LicensePendingGift> get outgoingGifts => _outgoingGifts;

  List<LicensePendingGift> _incomingGifts = const [];
  List<LicensePendingGift> get incomingGifts => _incomingGifts;

  /// True when the user has signed in and the password is cached in memory.
  bool get isSignedIn => _accountEmail != null;
  bool get canManageAccount => isSignedIn && _cachedPassword != null;

  // ── Derived ─────────────────────────────────────────────────────────────────
  bool get isCurrentTierVerified {
    switch (currentAppTier) {
      case AppTier.mobileFree:
        return true;
      case AppTier.mobilePaid:
        return defaultTargetPlatform == TargetPlatform.iOS
            ? _appleVerified
            : _androidVerified;
      case AppTier.desktopPro:
        return _desktopVerified;
    }
  }

  /// The license type key sent to the backend for this device/platform.
  String get _currentAppType {
    if (currentAppTier == AppTier.desktopPro) return 'desktop';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'apple' : 'android';
  }

  String get _currentOs {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'unknown';
    }
  }

  // ── Initialisation ───────────────────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accountEmail = prefs.getString(_kAccountEmailKey);
    _appleVerified = prefs.getBool(_kAppleVerifiedKey) ?? false;
    _androidVerified = prefs.getBool(_kAndroidVerifiedKey) ?? false;
    _desktopVerified = prefs.getBool(_kDesktopVerifiedKey) ?? false;
    _appleEntitled = prefs.getBool(_kAppleEntitlementKey) ?? false;
    _androidEntitled = prefs.getBool(_kAndroidEntitlementKey) ?? false;
    _desktopEntitled = prefs.getBool(_kDesktopEntitlementKey) ?? false;
    _emailVerified = prefs.getBool(_kEmailVerifiedKey) ?? false;
    _devices = _decodeDevices(prefs.getString(_kDevicesKey));
    _isInitialized = true;
    notifyListeners();
  }

  // ── Core verification ────────────────────────────────────────────────────────
  Future<bool> verifyLicense({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deviceId = await _getOrCreateDeviceId();
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/license/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
              'appType': _currentAppType,
              'os': _currentOs,
              'deviceId': deviceId,
              'appVersion': BuildMetadata.appVersion,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final body = _decodeJsonMap(response.body);
      if (response.statusCode != 200 || body['ok'] != true) {
        _errorMessage =
            body['message']?.toString() ?? 'Could not verify your license.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final entitlements = (body['entitlements'] as Map?)
          ?.cast<String, dynamic>();
      _appleEntitled = entitlements?['apple'] == true;
      _androidEntitled = entitlements?['android'] == true;
      _desktopEntitled = entitlements?['desktop'] == true;

      if (_currentAppType == 'apple' && !_appleEntitled) {
        _errorMessage = 'This account does not include an Apple (iOS) license.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      if (_currentAppType == 'android' && !_androidEntitled) {
        _errorMessage = 'This account does not include an Android license.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      if (_currentAppType == 'desktop' && !_desktopEntitled) {
        _errorMessage = 'This account does not include a desktop license.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (_currentAppType == 'apple') {
        _appleVerified = true;
      } else if (_currentAppType == 'android') {
        _androidVerified = true;
      } else {
        _desktopVerified = true;
      }
      _accountEmail = email.trim();
      _cachedPassword = password;

      // Parse extra fields returned by the new backend.
      _emailVerified = body['emailVerified'] == true;
      _applyLicensesDetail(
        (body['licensesDetail'] as Map?)?.cast<String, dynamic>(),
      );

      final rawDevices =
          (body['devices'] as List?)
              ?.whereType<Map>()
              .map(
                (m) => LicenseDeviceRecord.fromJson(m.cast<String, dynamic>()),
              )
              .toList() ??
          const <LicenseDeviceRecord>[];
      _devices = rawDevices;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccountEmailKey, _accountEmail!);
      await prefs.setBool(_kAppleVerifiedKey, _appleVerified);
      await prefs.setBool(_kAndroidVerifiedKey, _androidVerified);
      await prefs.setBool(_kDesktopVerifiedKey, _desktopVerified);
      await prefs.setBool(_kAppleEntitlementKey, _appleEntitled);
      await prefs.setBool(_kAndroidEntitlementKey, _androidEntitled);
      await prefs.setBool(_kDesktopEntitlementKey, _desktopEntitled);
      await prefs.setBool(_kEmailVerifiedKey, _emailVerified);
      await prefs.setString(
        _kDevicesKey,
        jsonEncode(_devices.map((e) => e.toJson()).toList()),
      );

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      debugPrint('License verification failed: $e');
      _errorMessage =
          'Could not reach the license server. Check your internet or backend URL.';
      notifyListeners();
      return false;
    }
  }

  // ── Account sync ─────────────────────────────────────────────────────────────
  /// Fetches the latest account state from the backend and updates local fields.
  /// Requires [canManageAccount] to be true (cached password in memory).
  Future<bool> syncAccount() async {
    if (_accountEmail == null || _cachedPassword == null) {
      _errorMessage = 'Not signed in.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/account/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _accountEmail,
              'password': _cachedPassword,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final body = _decodeJsonMap(response.body);
      if (response.statusCode != 200 || body['ok'] != true) {
        _errorMessage = body['message']?.toString() ?? 'Sync failed.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _applySyncResponse(body);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      debugPrint('Account sync failed: $e');
      _errorMessage = 'Sync failed. Check your connection.';
      notifyListeners();
      return false;
    }
  }

  // ── Gift / transfer ──────────────────────────────────────────────────────────
  /// Initiates a license transfer to [toEmail].  Requires email verification on
  /// the sender's account.
  Future<bool> initiateGift({
    required String licenseType,
    required String toEmail,
  }) async {
    return _accountAction(
      endpoint: '/v1/license/gift/initiate',
      extraFields: {'licenseType': licenseType, 'toEmail': toEmail.trim()},
      onSuccess: (body) => _applySyncResponse(body),
    );
  }

  /// Cancels an outgoing gift.  Pass [giftId] or [licenseType].
  Future<bool> cancelGift({String? giftId, String? licenseType}) async {
    assert(
      giftId != null || licenseType != null,
      'Provide giftId or licenseType',
    );
    final extra = <String, dynamic>{};
    if (giftId != null) extra['giftId'] = giftId;
    if (licenseType != null) extra['licenseType'] = licenseType;
    return _accountAction(
      endpoint: '/v1/license/gift/cancel',
      extraFields: extra,
      onSuccess: (body) => _applySyncResponse(body),
    );
  }

  /// Claims an incoming gift using a [token] (from email) or [giftId] (from sync).
  Future<bool> claimGift({String? token, String? giftId}) async {
    assert(token != null || giftId != null, 'Provide token or giftId');
    final extra = <String, dynamic>{};
    if (token != null) extra['token'] = token.trim().toUpperCase();
    if (giftId != null) extra['giftId'] = giftId;
    return _accountAction(
      endpoint: '/v1/license/gift/claim',
      extraFields: extra,
      onSuccess: (body) => _applySyncResponse(body),
    );
  }

  // ── Email verification ────────────────────────────────────────────────────────
  Future<bool> verifyEmail({required String token}) async {
    if (_accountEmail == null) {
      _errorMessage = 'Not signed in.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/account/verify-email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _accountEmail,
              'token': token.trim().toUpperCase(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      final body = _decodeJsonMap(response.body);
      _isLoading = false;
      if (response.statusCode == 200 && body['ok'] == true) {
        _emailVerified = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kEmailVerifiedKey, true);
        notifyListeners();
        return true;
      }
      _errorMessage = body['message']?.toString() ?? 'Verification failed.';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Could not reach the server.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendVerification() async {
    return _accountAction(
      endpoint: '/v1/account/resend-verification',
      extraFields: const {},
      onSuccess: (_) {},
      successMessage: 'Verification email sent.',
    );
  }

  // ── Security ─────────────────────────────────────────────────────────────────
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_accountEmail == null) {
      _errorMessage = 'Not signed in.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/account/change-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _accountEmail,
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final body = _decodeJsonMap(response.body);
      _isLoading = false;
      if (response.statusCode == 200 && body['ok'] == true) {
        _cachedPassword = newPassword;
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      _errorMessage = body['message']?.toString() ?? 'Password change failed.';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Could not reach the server.';
      notifyListeners();
      return false;
    }
  }

  // ── Sign out ─────────────────────────────────────────────────────────────────
  /// Clears all cached credentials and verification state.
  Future<void> signOut() async {
    _appleVerified = false;
    _androidVerified = false;
    _desktopVerified = false;
    _appleEntitled = false;
    _androidEntitled = false;
    _desktopEntitled = false;
    _emailVerified = false;
    _appleLicenseStatus = 'none';
    _androidLicenseStatus = 'none';
    _desktopLicenseStatus = 'none';
    _outgoingGifts = const [];
    _incomingGifts = const [];
    _devices = const [];
    _accountEmail = null;
    _cachedPassword = null;
    _errorMessage = null;

    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _kAccountEmailKey,
      _kAppleVerifiedKey,
      _kAndroidVerifiedKey,
      _kDesktopVerifiedKey,
      _kAppleEntitlementKey,
      _kAndroidEntitlementKey,
      _kDesktopEntitlementKey,
      _kEmailVerifiedKey,
      _kDevicesKey,
    ]) {
      await prefs.remove(key);
    }
    notifyListeners();
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Generic helper for authenticated POST actions.
  Future<bool> _accountAction({
    required String endpoint,
    required Map<String, dynamic> extraFields,
    required void Function(Map<String, dynamic>) onSuccess,
    String? successMessage,
  }) async {
    if (_accountEmail == null || _cachedPassword == null) {
      _errorMessage = 'Not signed in.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _accountEmail,
              'password': _cachedPassword,
              ...extraFields,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final body = _decodeJsonMap(response.body);
      _isLoading = false;
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['ok'] == true) {
        onSuccess(body);
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      _errorMessage = body['message']?.toString() ?? 'Request failed.';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      debugPrint('$endpoint failed: $e');
      _errorMessage = 'Could not reach the server.';
      notifyListeners();
      return false;
    }
  }

  void _applySyncResponse(Map<String, dynamic> body) {
    final account = (body['account'] as Map?)?.cast<String, dynamic>();
    if (account != null) {
      _emailVerified = account['emailVerified'] == true;

      final entitlements = (account['entitlements'] as Map?)
          ?.cast<String, dynamic>();
      _appleEntitled = entitlements?['apple'] == true;
      _androidEntitled = entitlements?['android'] == true;
      _desktopEntitled = entitlements?['desktop'] == true;

      _applyLicensesDetail(
        (account['licensesDetail'] as Map?)?.cast<String, dynamic>(),
      );

      // Intentionally sync the verified flags from current server entitlements.
      // If a user transfers their license to someone else and then syncs,
      // `_appleVerified` is cleared so the app correctly blocks access until
      // they either cancel the transfer or acquire a new license.
      // This is the desired UX — a transferred license should revoke local
      // access after the next sync, not persist indefinitely on device.
      _appleVerified = _appleEntitled;
      _androidVerified = _androidEntitled;
      _desktopVerified = _desktopEntitled;

      _outgoingGifts = _decodeGiftList(
        account['outgoingGifts'],
        incoming: false,
      );

      _devices = _decodeDevicesFromList(account['devices']);
    }

    _incomingGifts = _decodeGiftList(body['incomingGifts'], incoming: true);

    // Persist updated entitlement state.
    _persistEntitlements();
  }

  void _applyLicensesDetail(Map<String, dynamic>? detail) {
    if (detail == null) return;
    _appleLicenseStatus = detail['apple']?.toString() ?? 'none';
    _androidLicenseStatus = detail['android']?.toString() ?? 'none';
    _desktopLicenseStatus = detail['desktop']?.toString() ?? 'none';
  }

  Future<void> _persistEntitlements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAppleVerifiedKey, _appleVerified);
    await prefs.setBool(_kAndroidVerifiedKey, _androidVerified);
    await prefs.setBool(_kDesktopVerifiedKey, _desktopVerified);
    await prefs.setBool(_kAppleEntitlementKey, _appleEntitled);
    await prefs.setBool(_kAndroidEntitlementKey, _androidEntitled);
    await prefs.setBool(_kDesktopEntitlementKey, _desktopEntitled);
    await prefs.setBool(_kEmailVerifiedKey, _emailVerified);
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kDeviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _uuid.v4();
    await prefs.setString(_kDeviceIdKey, created);
    return created;
  }

  static Map<String, dynamic> _decodeJsonMap(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
      if (parsed is Map) return parsed.cast<String, dynamic>();
    } catch (_) {}
    return const <String, dynamic>{};
  }

  static List<LicenseDeviceRecord> _decodeDevices(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return const [];
      return parsed
          .whereType<Map>()
          .map((m) => LicenseDeviceRecord.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<LicenseDeviceRecord> _decodeDevicesFromList(dynamic list) {
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => LicenseDeviceRecord.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  static List<LicensePendingGift> _decodeGiftList(
    dynamic list, {
    required bool incoming,
  }) {
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map(
          (m) => incoming
              ? LicensePendingGift.fromIncomingJson(m.cast<String, dynamic>())
              : LicensePendingGift.fromOutgoingJson(m.cast<String, dynamic>()),
        )
        .toList();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
