import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../config/backend_config.dart';
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
  static const _kMfaEnabledKey = 'license_backend_mfa_enabled';
  static const _kDevicesKey = 'license_backend_devices';

  // Secure-storage keys (Keychain / Keystore / DPAPI / Secret Service).
  static const _kSecureSessionToken = 'license_backend_session_token';
  static const _kSecureSessionExpiry = 'license_backend_session_expiry';
  static const _kSecureSessionMfa = 'license_backend_session_mfa';

  LicenseBackendService({
    http.Client? client,
    String? baseUrl,
    FlutterSecureStorage? secureStorage,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? BackendConfig.baseUrl).replaceFirst(
          RegExp(r'/+$'),
          '',
        ),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final http.Client _client;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  /// Read-only access to the resolved backend base URL.  Useful for sibling
  /// services (cloud tree sync, version check) that should hit the same host
  /// the user authenticated against.
  String get baseUrl => _baseUrl;

  // ── State ───────────────────────────────────────────────────────────────────
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Machine-readable code matching [errorMessage] when applicable.  e.g.
  /// `mfa_required` so the login screen can show the MFA code field.
  String? _lastErrorCode;
  String? get lastErrorCode => _lastErrorCode;

  String? _accountEmail;
  String? get accountEmail => _accountEmail;

  /// Phase 2: short-lived HMAC-signed session token issued by the backend.
  /// Replaces the legacy practice of replaying the password on every call.
  /// Persisted in [FlutterSecureStorage] (Keychain / Keystore / DPAPI /
  /// Secret Service) so the OS — not SharedPreferences — protects it.
  String? _sessionToken;
  DateTime? _sessionExpiresAt;
  bool _sessionMfa = false;

  String? get sessionToken => _sessionToken;
  DateTime? get sessionExpiresAt => _sessionExpiresAt;

  /// True when the cached session token was minted after a successful MFA
  /// challenge — endpoints requiring step-up auth (gift initiate, change
  /// password) check this client-side to avoid an extra round-trip.
  bool get hasMfaSession => _sessionMfa;

  /// True when we have a non-expired session token.
  bool get hasActiveSession {
    if (_sessionToken == null || _sessionExpiresAt == null) return false;
    return DateTime.now().isBefore(_sessionExpiresAt!);
  }

  /// True when the account has TOTP MFA enabled on the backend.  Cached
  /// across launches so the UI can show the right toggle state offline.
  bool _mfaEnabled = false;
  bool get mfaEnabled => _mfaEnabled;

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

  /// True when the service has enough state to invoke account-management
  /// endpoints.  After Phase 2 this means "signed in" — the actual auth
  /// material (Bearer session token) is supplied transparently by
  /// [_authHeaders].  Networking failures (expired/missing token) surface
  /// through [errorMessage] when the call eventually fails.
  bool get canManageAccount => isSignedIn;

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
    _mfaEnabled = prefs.getBool(_kMfaEnabledKey) ?? false;
    _devices = _decodeDevices(prefs.getString(_kDevicesKey));
    await _loadSessionFromSecureStorage();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadSessionFromSecureStorage() async {
    try {
      _sessionToken = await _secureStorage.read(key: _kSecureSessionToken);
      final expiryRaw = await _secureStorage.read(key: _kSecureSessionExpiry);
      if (expiryRaw != null) {
        _sessionExpiresAt = DateTime.tryParse(expiryRaw);
      }
      final mfaRaw = await _secureStorage.read(key: _kSecureSessionMfa);
      _sessionMfa = mfaRaw == 'true';
      // Drop expired tokens proactively so isSignedIn is honest.
      if (_sessionExpiresAt != null &&
          DateTime.now().isAfter(_sessionExpiresAt!)) {
        await _clearSessionInSecureStorage();
      }
    } catch (e) {
      // FlutterSecureStorage can throw on platforms without keychain
      // (e.g. some Linux desktops missing libsecret).  Treat as "no session"
      // and let the user sign in again.
      debugPrint('Secure session load failed: $e');
      _sessionToken = null;
      _sessionExpiresAt = null;
      _sessionMfa = false;
    }
  }

  Future<void> _persistSessionToSecureStorage() async {
    try {
      if (_sessionToken == null) {
        await _clearSessionInSecureStorage();
        return;
      }
      await _secureStorage.write(key: _kSecureSessionToken, value: _sessionToken);
      await _secureStorage.write(
        key: _kSecureSessionExpiry,
        value: _sessionExpiresAt?.toIso8601String() ?? '',
      );
      await _secureStorage.write(
        key: _kSecureSessionMfa, value: _sessionMfa ? 'true' : 'false');
    } catch (e) {
      debugPrint('Secure session persist failed: $e');
    }
  }

  Future<void> _clearSessionInSecureStorage() async {
    try {
      await _secureStorage.delete(key: _kSecureSessionToken);
      await _secureStorage.delete(key: _kSecureSessionExpiry);
      await _secureStorage.delete(key: _kSecureSessionMfa);
    } catch (_) {/* ignore */}
  }

  /// Build the headers to send with an authenticated request.  Prefers the
  /// active Bearer session token; falls back to nothing extra when no
  /// session is available (the request body must then carry email+password).
  Map<String, String> _authHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (hasActiveSession) {
      headers['Authorization'] = 'Bearer $_sessionToken';
    }
    return headers;
  }

  void _applySession(Map<String, dynamic>? sessionJson) {
    if (sessionJson == null) return;
    final token = sessionJson['token']?.toString();
    if (token == null || token.isEmpty) return;
    final expSec = (sessionJson['expiresAt'] is num)
        ? (sessionJson['expiresAt'] as num).toInt()
        : null;
    _sessionToken = token;
    _sessionExpiresAt = expSec != null
        ? DateTime.fromMillisecondsSinceEpoch(expSec * 1000, isUtc: true)
        : DateTime.now().add(const Duration(hours: 24));
    _sessionMfa = sessionJson['mfa'] == true;
  }

  /// Map a 429 (rate-limit / lockout) or other auth failure to a user-friendly
  /// message.  Returns the message and stores it in [_errorMessage].
  String _mapAuthError(int statusCode, Map<String, dynamic> body) {
    final msg = body['message']?.toString() ?? 'Request failed.';
    if (statusCode == 429) {
      final retry = body['retryAfterSeconds'];
      if (retry is num) {
        return '$msg Please try again in ${retry.toInt()} seconds.';
      }
    }
    return msg;
  }

  // ── Core verification ────────────────────────────────────────────────────────
  Future<bool> verifyLicense({
    required String email,
    required String password,
    String? mfaCode,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deviceId = await _getOrCreateDeviceId();
      final body = <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'appType': _currentAppType,
        'os': _currentOs,
        'deviceId': deviceId,
        'appVersion': BuildMetadata.appVersion,
      };
      if (mfaCode != null && mfaCode.trim().isNotEmpty) {
        body['mfaCode'] = mfaCode.trim();
      }
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/license/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(BackendConfig.requestTimeout);

      final body2 = _decodeJsonMap(response.body);
      if (response.statusCode != 200 || body2['ok'] != true) {
        _errorMessage = _mapAuthError(response.statusCode, body2);
        // Surface MFA-required as a distinct, machine-readable error so the
        // login screen can show the MFA code field instead of a generic
        // "wrong password" message.
        if (body2['code'] == 'mfa_required') {
          _errorMessage = 'MFA code required.';
          _lastErrorCode = 'mfa_required';
        } else {
          _lastErrorCode = null;
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _lastErrorCode = null;

      final entitlements = (body2['entitlements'] as Map?)
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

      // Parse extra fields returned by the new backend.
      _emailVerified = body2['emailVerified'] == true;
      _mfaEnabled = body2['mfaEnabled'] == true;
      _applyLicensesDetail(
        (body2['licensesDetail'] as Map?)?.cast<String, dynamic>(),
      );
      _applySession((body2['session'] as Map?)?.cast<String, dynamic>());
      await _persistSessionToSecureStorage();

      final rawDevices =
          (body2['devices'] as List?)
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
      await prefs.setBool(_kMfaEnabledKey, _mfaEnabled);
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
  /// Uses the cached session token (Bearer) — no password required after the
  /// initial sign-in.
  Future<bool> syncAccount() async {
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
            Uri.parse('$_baseUrl/v1/account/sync'),
            headers: _authHeaders(),
            body: jsonEncode(<String, dynamic>{}),
          )
          .timeout(BackendConfig.requestTimeout);

      final body = _decodeJsonMap(response.body);
      if (response.statusCode != 200 || body['ok'] != true) {
        if (response.statusCode == 401) {
          // Session was revoked or expired — clear it so the UI re-prompts.
          await _clearSessionInSecureStorage();
          _sessionToken = null;
          _sessionExpiresAt = null;
          _sessionMfa = false;
        }
        _errorMessage = _mapAuthError(response.statusCode, body);
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
  /// Also redeems open vouchers (tokens not tied to a specific email).
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

  /// Creates one or more open voucher tokens (admin only).
  /// Callers must supply the [adminSecret] configured on the backend.
  /// Returns the list of generated tokens on success, or null on failure.
  Future<List<String>?> createVoucher({
    required String adminSecret,
    required String licenseType,
    int quantity = 1,
    String? fromEmail,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/license/voucher/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'adminSecret': adminSecret,
              'licenseType': licenseType,
              'quantity': quantity,
              'fromEmail': ?fromEmail,
              'notes': ?notes,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final body = _decodeJsonMap(response.body);
      _isLoading = false;
      if (response.statusCode == 200 && body['ok'] == true) {
        final rawVouchers = body['vouchers'] as List?;
        final tokens = rawVouchers
            ?.whereType<Map>()
            .map((v) => v['token']?.toString() ?? '')
            .where((t) => t.isNotEmpty)
            .toList();
        _errorMessage = null;
        notifyListeners();
        return tokens ?? [];
      }
      _errorMessage = body['message']?.toString() ?? 'Voucher creation failed.';
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Could not reach the server.';
      notifyListeners();
      return null;
    }
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
    String? mfaCode,
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
      final reqBody = <String, dynamic>{
        'email': _accountEmail,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      };
      if (mfaCode != null && mfaCode.isNotEmpty) reqBody['mfaCode'] = mfaCode;
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/account/change-password'),
            headers: _authHeaders(),
            body: jsonEncode(reqBody),
          )
          .timeout(BackendConfig.requestTimeout);

      final body = _decodeJsonMap(response.body);
      _isLoading = false;
      if (response.statusCode == 200 && body['ok'] == true) {
        // Server invalidated the old session — caller must re-sign-in.
        await _clearSessionInSecureStorage();
        _sessionToken = null;
        _sessionExpiresAt = null;
        _sessionMfa = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      _errorMessage = _mapAuthError(response.statusCode, body);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Could not reach the server.';
      notifyListeners();
      return false;
    }
  }

  // ── Phase 2: Password reset (no current session required) ────────────────
  Future<bool> requestPasswordReset({required String email}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/account/password-reset/request'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(BackendConfig.requestTimeout);
      final body = _decodeJsonMap(response.body);
      _isLoading = false;
      if (response.statusCode == 200 && body['ok'] == true) {
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      _errorMessage = _mapAuthError(response.statusCode, body);
      notifyListeners();
      return false;
    } catch (_) {
      _isLoading = false;
      _errorMessage = 'Could not reach the server.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/account/password-reset'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'token': token.trim().toUpperCase(),
              'newPassword': newPassword,
            }),
          )
          .timeout(BackendConfig.requestTimeout);
      final body = _decodeJsonMap(response.body);
      _isLoading = false;
      if (response.statusCode == 200 && body['ok'] == true) {
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      _errorMessage = _mapAuthError(response.statusCode, body);
      notifyListeners();
      return false;
    } catch (_) {
      _isLoading = false;
      _errorMessage = 'Could not reach the server.';
      notifyListeners();
      return false;
    }
  }

  // ── Phase 2: TOTP MFA enroll / disable ───────────────────────────────────
  /// Begins MFA enrollment.  Returns a map with `secret` (base32) and
  /// `otpauthUri` (for QR codes), or null on failure.
  Future<Map<String, dynamic>?> startMfaEnrollment() async {
    if (!hasActiveSession) {
      _errorMessage = 'Not signed in.';
      notifyListeners();
      return null;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/account/mfa/enroll/start'),
            headers: _authHeaders(),
            body: jsonEncode(<String, dynamic>{}),
          )
          .timeout(BackendConfig.requestTimeout);
      final body = _decodeJsonMap(response.body);
      _isLoading = false;
      if (response.statusCode == 200 && body['ok'] == true) {
        _errorMessage = null;
        notifyListeners();
        return body;
      }
      _errorMessage = _mapAuthError(response.statusCode, body);
      notifyListeners();
      return null;
    } catch (_) {
      _isLoading = false;
      _errorMessage = 'Could not reach the server.';
      notifyListeners();
      return null;
    }
  }

  /// Confirms MFA enrollment by submitting a 6-digit code from the
  /// authenticator app.  Returns the list of single-use recovery codes on
  /// success — the caller MUST display them and prompt the user to save them.
  Future<List<String>?> confirmMfaEnrollment({required String code}) async {
    if (!hasActiveSession) {
      _errorMessage = 'Not signed in.';
      notifyListeners();
      return null;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/account/mfa/enroll/confirm'),
            headers: _authHeaders(),
            body: jsonEncode({'code': code.trim()}),
          )
          .timeout(BackendConfig.requestTimeout);
      final body = _decodeJsonMap(response.body);
      _isLoading = false;
      if (response.statusCode == 200 && body['ok'] == true) {
        _mfaEnabled = true;
        // Token version was bumped; force re-sign-in.
        await _clearSessionInSecureStorage();
        _sessionToken = null;
        _sessionExpiresAt = null;
        _sessionMfa = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kMfaEnabledKey, true);
        final codes = (body['recoveryCodes'] as List?)
            ?.map((c) => c.toString())
            .toList() ?? const <String>[];
        notifyListeners();
        return codes;
      }
      _errorMessage = _mapAuthError(response.statusCode, body);
      notifyListeners();
      return null;
    } catch (_) {
      _isLoading = false;
      _errorMessage = 'Could not reach the server.';
      notifyListeners();
      return null;
    }
  }

  /// Disables MFA.  Server requires step-up auth (Bearer with mfa=true OR
  /// password + valid mfaCode); pass [mfaCode] when the cached session is
  /// not MFA-elevated.
  Future<bool> disableMfa({String? currentPassword, String? mfaCode}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final body = <String, dynamic>{};
      if (currentPassword != null) {
        body['email'] = _accountEmail;
        body['password'] = currentPassword;
      }
      if (mfaCode != null && mfaCode.isNotEmpty) body['mfaCode'] = mfaCode;
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/account/mfa/disable'),
            headers: _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(BackendConfig.requestTimeout);
      final resp = _decodeJsonMap(response.body);
      _isLoading = false;
      if (response.statusCode == 200 && resp['ok'] == true) {
        _mfaEnabled = false;
        await _clearSessionInSecureStorage();
        _sessionToken = null;
        _sessionExpiresAt = null;
        _sessionMfa = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kMfaEnabledKey, false);
        notifyListeners();
        return true;
      }
      _errorMessage = _mapAuthError(response.statusCode, resp);
      notifyListeners();
      return false;
    } catch (_) {
      _isLoading = false;
      _errorMessage = 'Could not reach the server.';
      notifyListeners();
      return false;
    }
  }

  /// Revokes all session tokens for this account on every device.  After
  /// success the local session is cleared and the user must sign in again.
  Future<bool> revokeAllSessions() async {
    if (!hasActiveSession) {
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
            Uri.parse('$_baseUrl/v1/account/session/revoke-all'),
            headers: _authHeaders(),
            body: jsonEncode(<String, dynamic>{}),
          )
          .timeout(BackendConfig.requestTimeout);
      final body = _decodeJsonMap(response.body);
      _isLoading = false;
      if (response.statusCode == 200 && body['ok'] == true) {
        await _clearSessionInSecureStorage();
        _sessionToken = null;
        _sessionExpiresAt = null;
        _sessionMfa = false;
        notifyListeners();
        return true;
      }
      _errorMessage = _mapAuthError(response.statusCode, body);
      notifyListeners();
      return false;
    } catch (_) {
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
    _mfaEnabled = false;
    _appleLicenseStatus = 'none';
    _androidLicenseStatus = 'none';
    _desktopLicenseStatus = 'none';
    _outgoingGifts = const [];
    _incomingGifts = const [];
    _devices = const [];
    _accountEmail = null;
    _sessionToken = null;
    _sessionExpiresAt = null;
    _sessionMfa = false;
    _errorMessage = null;
    await _clearSessionInSecureStorage();

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
      _kMfaEnabledKey,
      _kDevicesKey,
    ]) {
      await prefs.remove(key);
    }
    notifyListeners();
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Generic helper for authenticated POST actions.  Sends Bearer auth when
  /// available; falls back to nothing extra in the body (the server already
  /// rejects unauthenticated requests).
  Future<bool> _accountAction({
    required String endpoint,
    required Map<String, dynamic> extraFields,
    required void Function(Map<String, dynamic>) onSuccess,
    String? successMessage,
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
            Uri.parse('$_baseUrl$endpoint'),
            headers: _authHeaders(),
            body: jsonEncode({
              ...extraFields,
            }),
          )
          .timeout(BackendConfig.requestTimeout);

      final body = _decodeJsonMap(response.body);
      _isLoading = false;
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['ok'] == true) {
        onSuccess(body);
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      if (response.statusCode == 401) {
        await _clearSessionInSecureStorage();
        _sessionToken = null;
        _sessionExpiresAt = null;
        _sessionMfa = false;
      }
      _errorMessage = _mapAuthError(response.statusCode, body);
      _lastErrorCode = body['code']?.toString();
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
      _mfaEnabled = account['mfaEnabled'] == true;

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
