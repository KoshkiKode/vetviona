import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../config/build_metadata.dart';

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

class LicenseBackendService extends ChangeNotifier {
  static const Uuid _uuid = Uuid();
  static const String _configuredBaseUrl = String.fromEnvironment(
    'LICENSE_BACKEND_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  static const _kDeviceIdKey = 'license_backend_device_id';
  static const _kAccountEmailKey = 'license_backend_account_email';
  static const _kMobileVerifiedKey = 'license_backend_mobile_verified';
  static const _kDesktopVerifiedKey = 'license_backend_desktop_verified';
  static const _kMobileEntitlementKey = 'license_backend_mobile_entitled';
  static const _kDesktopEntitlementKey = 'license_backend_desktop_entitled';
  static const _kDevicesKey = 'license_backend_devices';

  LicenseBackendService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? _configuredBaseUrl).replaceFirst(
        RegExp(r'/+$'),
        '',
      );

  final http.Client _client;
  final String _baseUrl;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _accountEmail;
  String? get accountEmail => _accountEmail;

  bool _mobileVerified = false;
  bool _desktopVerified = false;

  bool _mobileEntitled = false;
  bool _desktopEntitled = false;

  List<LicenseDeviceRecord> _devices = const [];
  List<LicenseDeviceRecord> get devices => _devices;

  bool get isCurrentTierVerified {
    switch (currentAppTier) {
      case AppTier.mobileFree:
        return true;
      case AppTier.mobilePaid:
        return _mobileVerified;
      case AppTier.desktopPro:
        return _desktopVerified;
    }
  }

  String get _currentAppType =>
      currentAppTier == AppTier.desktopPro ? 'desktop' : 'mobile';

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

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accountEmail = prefs.getString(_kAccountEmailKey);
    _mobileVerified = prefs.getBool(_kMobileVerifiedKey) ?? false;
    _desktopVerified = prefs.getBool(_kDesktopVerifiedKey) ?? false;
    _mobileEntitled = prefs.getBool(_kMobileEntitlementKey) ?? false;
    _desktopEntitled = prefs.getBool(_kDesktopEntitlementKey) ?? false;
    _devices = _decodeDevices(prefs.getString(_kDevicesKey));
    _isInitialized = true;
    notifyListeners();
  }

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
      _mobileEntitled = entitlements?['mobile'] == true;
      _desktopEntitled = entitlements?['desktop'] == true;

      if (_currentAppType == 'mobile' && !_mobileEntitled) {
        _errorMessage = 'This account does not include a mobile paid license.';
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

      if (_currentAppType == 'mobile') {
        _mobileVerified = true;
      } else {
        _desktopVerified = true;
      }
      _accountEmail = email.trim();

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
      await prefs.setBool(_kMobileVerifiedKey, _mobileVerified);
      await prefs.setBool(_kDesktopVerifiedKey, _desktopVerified);
      await prefs.setBool(_kMobileEntitlementKey, _mobileEntitled);
      await prefs.setBool(_kDesktopEntitlementKey, _desktopEntitled);
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

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
