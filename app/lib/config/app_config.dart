import 'dart:io';

import 'package:flutter/foundation.dart';

/// Compile-time flag set to `true` when building the paid desktop version.
/// Pass with `--dart-define=PAID=true`.
const bool _isPaidDesktop = bool.fromEnvironment('PAID', defaultValue: false);

/// Compile-time flag set to `true` when building the paid mobile version.
/// Pass with `--dart-define=MOBILE_PAID=true`.
const bool _isMobilePaid =
    bool.fromEnvironment('MOBILE_PAID', defaultValue: false);

/// The three distinct pricing tiers in Vetviona.
enum AppTier {
  /// Free Android / iOS app — QR-code pairing, manual WiFi sync, and
  /// AirDrop/Nearby Share; 100-person limit per tree.
  mobileFree,

  /// Paid Android / iOS app — both RootLoop™ Auto and Manual, no person cap.
  mobilePaid,

  /// Paid desktop (Windows · macOS · Linux) — unlimited, all sync modes,
  /// supports connecting both mobile tiers.
  desktopPro,
}

/// The tier this build is running as, determined at runtime from the current
/// platform combined with compile-time flags.
AppTier get currentAppTier {
  if (!kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    return AppTier.desktopPro;
  }
  if (_isMobilePaid) return AppTier.mobilePaid;
  return AppTier.mobileFree;
}

/// Maximum number of people per tree allowed on the free mobile tier.
const int freeMobilePersonLimit = 100;

/// Whether this build is the paid desktop version (used for the lock screen).
bool get isPaidDesktop => _isPaidDesktop;

/// Whether the current tier is a paid / pro tier (mobilePaid or desktopPro).
/// Free mobile users can start an HTTP server for QR-code-based and manual
/// WiFi sync; advanced auto-discovery sync modes (WiFi Auto-Scan via mDNS,
/// Bluetooth BLE scanning/advertising) require this to return `true`.
/// AirDrop / Nearby Share file sharing and manual connect (including via
/// Tailscale addresses) are available to all tiers.
bool get isProTier => currentAppTier != AppTier.mobileFree;
