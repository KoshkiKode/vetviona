import 'package:flutter/foundation.dart';

/// Centralised configuration for the Vetviona AWS-hosted backend.
///
/// All HTTP-talking services in the app (license verification, account/sync,
/// optional cloud tree backup, app-version checks) read their base URL from
/// here so the production hostname is wired in exactly once.
///
/// The default URL is the public production endpoint baked into release
/// builds.  Dev / staging / self-hosted instances can override it at build
/// time:
///
/// ```bash
/// flutter run --dart-define=LICENSE_BACKEND_URL=http://127.0.0.1:8080
/// flutter build apk --release \
///   --dart-define=LICENSE_BACKEND_URL=https://staging.api.vetviona.koshkikode.com
/// ```
///
/// Offline-first guarantee: the app NEVER blocks startup, editing, or local
/// sync on this URL being reachable.  Network calls are opportunistic, time
/// out quickly, and surface as a banner rather than a hard error.
class BackendConfig {
  BackendConfig._();

  /// Production AWS endpoint that ships with release builds of every
  /// platform (Android · iOS · Windows · macOS · Linux).
  ///
  /// This is intentionally a stable HTTPS hostname (Route 53 → ACM cert →
  /// API Gateway / ALB → Lambda or Fargate task — see
  /// `backend/DEPLOY-AWS.md`).
  static const String productionBaseUrl =
      'https://license.koshkikode.com';

  /// Compile-time override.  Empty string (the default) means "use
  /// [productionBaseUrl]".  Set with `--dart-define=LICENSE_BACKEND_URL=...`.
  static const String _override = String.fromEnvironment(
    'LICENSE_BACKEND_URL',
    defaultValue: '',
  );

  /// Base URL used by every backend-talking service.  Trailing slashes are
  /// trimmed.  In release builds plain-`http://` is rejected and the URL
  /// falls back to [productionBaseUrl] so a misconfigured CI build can never
  /// silently downgrade users to clear-text auth.
  static String get baseUrl {
    final raw = _override.isNotEmpty ? _override : productionBaseUrl;
    final trimmed = raw.replaceFirst(RegExp(r'/+$'), '');
    if (kReleaseMode && trimmed.startsWith('http://')) {
      assert(
        false,
        'LICENSE_BACKEND_URL must use https:// in release builds. '
        'Got: $trimmed',
      );
      return productionBaseUrl;
    }
    return trimmed;
  }

  /// True when the configured URL uses TLS.  Used by the UI to surface a
  /// warning banner when a developer has pointed the app at a clear-text
  /// dev backend.
  static bool get isHttps => baseUrl.startsWith('https://');

  /// Maximum wall-clock time any single backend HTTP call is allowed to
  /// take before we give up and let the app fall back to fully-offline
  /// behaviour.  Keep this short — every call must be optional.
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Shorter timeout for the opportunistic version-check ping at launch so
  /// a slow network never delays the app becoming usable.
  static const Duration versionCheckTimeout = Duration(seconds: 6);
}
