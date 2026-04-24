import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart' as ndef_android;
import 'package:nfc_manager/nfc_manager_ios.dart' as ndef_ios;
import 'package:nfc_manager/ndef_record.dart';

// ── NfcSyncService ───────────────────────────────────────────────────────────

/// NFC session mode.
enum NfcMode {
  /// Reading a tag written by another Vetviona device.
  reading,

  /// Writing this device's sync URL to a tag so another device can read it.
  writing,
}

/// Represents the current state of the NFC sync service.
enum NfcSyncStatus {
  idle,
  checking,
  readyToTap,
  processing,
  success,
  error,
  unavailable,
}

/// Provides NFC tap-to-pair for RootLoop™ sync.
///
/// **Flow — Host device (writes the tag)**
/// 1. Call [startWriting] with the `vetviona://host:port?secret=xxx` URL.
/// 2. The session begins; `status` becomes [NfcSyncStatus.readyToTap].
/// 3. User taps their phone/tablet to an NFC-capable peer device or a blank
///    NFC tag.  The URL is written as an NDEF URI record.
/// 4. `status` becomes [NfcSyncStatus.success] and [stopSession] is called.
///
/// **Flow — Client device (reads the tag / peer)**
/// 1. Call [startReading]; `status` becomes [NfcSyncStatus.readyToTap].
/// 2. User taps the NFC tag or host device.
/// 3. [onUrlRead] fires with the `vetviona://…` URL.
/// 4. The caller parses the URL and initiates the WiFi sync.
///
/// **Platform notes**
/// - Android: Full read + write.  Requires `android.permission.NFC` and the
///   `<uses-feature android:name="android.hardware.nfc" android:required="false"/>`
///   declaration in AndroidManifest.xml.
/// - iOS: Read-only (Apple restricts writing NDEF to external hardware NFC
///   tags via Core NFC). The `com.apple.developer.nfc.readersession.formats`
///   entitlement (`NDEF`) and `NFCReaderUsageDescription` in Info.plist are
///   required.
/// - Desktop / Web: [checkAvailability] returns [NfcAvailability.unsupported]
///   and all session calls are no-ops.
class NfcSyncService extends ChangeNotifier {
  NfcSyncService._();
  static final NfcSyncService instance = NfcSyncService._();

  // ── State ────────────────────────────────────────────────────────────────────

  NfcSyncStatus _status = NfcSyncStatus.idle;
  NfcSyncStatus get status => _status;

  NfcMode? _mode;
  NfcMode? get mode => _mode;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  NfcAvailability _availability = NfcAvailability.unsupported;
  NfcAvailability get availability => _availability;

  bool get isAvailable => _availability == NfcAvailability.enabled;

  // ── Internals ─────────────────────────────────────────────────────────────────

  /// URL pending write to the next discovered tag.
  String? _pendingWriteUrl;

  /// Called when a tag is successfully read in [NfcMode.reading].
  void Function(String url)? _onUrlRead;

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Checks and caches NFC availability.  Safe to call on any platform.
  Future<void> checkAvailability() async {
    if (_isDesktopOrWeb) {
      _availability = NfcAvailability.unsupported;
      _setStatus(NfcSyncStatus.unavailable, 'NFC not available on this platform.');
      return;
    }

    _setStatus(NfcSyncStatus.checking, 'Checking NFC availability…');

    try {
      _availability = await NfcManager.instance.checkAvailability();
      switch (_availability) {
        case NfcAvailability.enabled:
          _setStatus(NfcSyncStatus.idle, null);
        case NfcAvailability.disabled:
          _setStatus(NfcSyncStatus.unavailable, 'NFC is disabled. Enable it in device settings.');
        case NfcAvailability.unsupported:
          _setStatus(NfcSyncStatus.unavailable, 'NFC not supported on this device.');
      }
    } catch (e) {
      _availability = NfcAvailability.unsupported;
      _setStatus(NfcSyncStatus.unavailable, 'NFC check failed: $e');
    }
  }

  /// Starts an NFC session that writes [syncUrl] to the next tapped tag.
  ///
  /// [syncUrl] should be a `vetviona://host:port?secret=xxx` string.
  ///
  /// On iOS, writing external NFC tags is **not** supported by Core NFC; the
  /// write mode is a no-op on that platform (only Android can write).
  Future<void> startWriting(String syncUrl) async {
    if (_isDesktopOrWeb || !isAvailable) return;

    // iOS cannot write NFC tags via Core NFC — skip silently.
    if (!kIsWeb && Platform.isIOS) {
      _setStatus(NfcSyncStatus.unavailable,
          'NFC tag writing is not supported on iOS. Use QR code pairing instead.');
      return;
    }

    _pendingWriteUrl = syncUrl;
    _mode = NfcMode.writing;
    _setStatus(NfcSyncStatus.readyToTap, 'Hold your device near an NFC tag to write the pairing info.');

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: _onTagDiscoveredForWrite,
        noPlatformSoundsAndroid: false,
      );
    } catch (e) {
      _setStatus(NfcSyncStatus.error, 'Failed to start NFC session: $e');
      _pendingWriteUrl = null;
      _mode = null;
    }
  }

  /// Starts an NFC session that reads a Vetviona pairing URL from the next
  /// tapped tag.
  ///
  /// [onUrlRead] is called with the `vetviona://…` URL when a matching tag is
  /// found.  The session is then automatically stopped.
  ///
  /// [alertMessageIos] is the message shown in the iOS NFC system sheet.
  Future<void> startReading({
    required void Function(String url) onUrlRead,
    String alertMessageIos = 'Hold near the other device to receive pairing info.',
  }) async {
    if (_isDesktopOrWeb || !isAvailable) return;

    _onUrlRead = onUrlRead;
    _mode = NfcMode.reading;
    _setStatus(NfcSyncStatus.readyToTap, 'Hold your device near the other device\'s NFC to pair.');

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: _onTagDiscoveredForRead,
        alertMessageIos: alertMessageIos,
        invalidateAfterFirstReadIos: true,
      );
    } catch (e) {
      _setStatus(NfcSyncStatus.error, 'Failed to start NFC session: $e');
      _onUrlRead = null;
      _mode = null;
    }
  }

  /// Stops any active NFC session.
  Future<void> stopSession({String? errorMessage}) async {
    try {
      await NfcManager.instance.stopSession(
        errorMessageIos: errorMessage,
      );
    } catch (_) {
      // Session may already be closed.
    }
    _pendingWriteUrl = null;
    _onUrlRead = null;
    _mode = null;
    if (_status != NfcSyncStatus.success && _status != NfcSyncStatus.error) {
      _setStatus(NfcSyncStatus.idle, null);
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────────

  Future<void> _onTagDiscoveredForWrite(NfcTag tag) async {
    final url = _pendingWriteUrl;
    if (url == null) return;

    _setStatus(NfcSyncStatus.processing, 'Writing pairing info to NFC tag…');

    final message = _buildNdefMessage(url);
    if (message == null) {
      await stopSession(errorMessage: 'Could not build NDEF message.');
      _setStatus(NfcSyncStatus.error, 'Failed to encode pairing info.');
      return;
    }

    // Android write path.
    final ndefAndroid = ndef_android.NdefAndroid.from(tag);
    if (ndefAndroid != null) {
      try {
        await ndefAndroid.writeNdefMessage(message);
        await NfcManager.instance.stopSession();
        _pendingWriteUrl = null;
        _mode = null;
        _setStatus(NfcSyncStatus.success, 'NFC tag written — tap it on the other device to pair.');
        return;
      } catch (e) {
        await stopSession(errorMessage: 'Write failed.');
        _setStatus(NfcSyncStatus.error, 'NFC write failed: $e');
        return;
      }
    }

    await stopSession(errorMessage: 'Tag is not NDEF-writable.');
    _setStatus(NfcSyncStatus.error, 'This NFC tag cannot be written to.');
  }

  Future<void> _onTagDiscoveredForRead(NfcTag tag) async {
    _setStatus(NfcSyncStatus.processing, 'Reading NFC tag…');

    NdefMessage? message;

    // Android read path.
    final ndefAndroid = ndef_android.NdefAndroid.from(tag);
    if (ndefAndroid != null) {
      message = ndefAndroid.cachedNdefMessage;
    }

    // iOS read path.
    if (message == null) {
      final ndefIos = ndef_ios.NdefIos.from(tag);
      if (ndefIos != null) {
        message = ndefIos.cachedNdefMessage;
      }
    }

    if (message == null || message.records.isEmpty) {
      await stopSession(errorMessage: 'No pairing data on this tag.');
      _setStatus(NfcSyncStatus.error, 'No pairing data found on NFC tag.');
      return;
    }

    final url = _extractVetvionaUrl(message);
    if (url == null) {
      await stopSession(errorMessage: 'Not a Vetviona tag.');
      _setStatus(NfcSyncStatus.error, 'This NFC tag does not contain Vetviona pairing data.');
      return;
    }

    await NfcManager.instance.stopSession(alertMessageIos: 'Paired successfully!');
    _mode = null;
    _setStatus(NfcSyncStatus.success, 'NFC pairing data received.');

    _onUrlRead?.call(url);
    _onUrlRead = null;
  }

  /// Builds an NDEF message with a single URI record containing [url].
  ///
  /// The URI record uses TNF 0x01 (Well-Known) with type byte 0x55 ('U').
  /// Payload prefix byte 0x00 means "no abbreviation" — the full URI follows.
  static NdefMessage? _buildNdefMessage(String url) {
    try {
      final uriBytes = url.codeUnits;
      // Payload = [0x00 (no abbreviation), ...url bytes]
      final payload = Uint8List(1 + uriBytes.length);
      payload[0] = 0x00;
      for (int i = 0; i < uriBytes.length; i++) {
        payload[1 + i] = uriBytes[i];
      }

      final record = NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList([0x55]), // 'U' = URI
        identifier: Uint8List(0),
        payload: payload,
      );

      return NdefMessage(records: [record]);
    } catch (_) {
      return null;
    }
  }

  /// Extracts a `vetviona://…` URL from an [NdefMessage], or returns null.
  static String? _extractVetvionaUrl(NdefMessage message) {
    for (final record in message.records) {
      if (record.typeNameFormat == TypeNameFormat.wellKnown &&
          record.type.length == 1 &&
          record.type[0] == 0x55 /* 'U' */) {
        final payload = record.payload;
        if (payload.length < 2) continue;
        // First byte is the URI identifier code (prefix abbreviation).
        // 0x00 = no abbreviation; other values prepend a standard URI scheme.
        final prefixCode = payload[0];
        final uriBody = String.fromCharCodes(payload.sublist(1));
        final prefix = _uriPrefixFor(prefixCode);
        final fullUri = prefix + uriBody;
        if (fullUri.startsWith('vetviona://')) return fullUri;
      }
    }
    return null;
  }

  /// Maps the NFC Forum URI identifier code to its prefix string.
  static String _uriPrefixFor(int code) => switch (code) {
        0x01 => 'http://www.',
        0x02 => 'https://www.',
        0x03 => 'http://',
        0x04 => 'https://',
        _ => '',
      };

  void _setStatus(NfcSyncStatus status, String? message) {
    _status = status;
    _statusMessage = message;
    notifyListeners();
  }

  /// True on desktop and web platforms where NFC hardware is unavailable.
  static bool get _isDesktopOrWeb {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => false,
      _ => true,
    };
  }
}
