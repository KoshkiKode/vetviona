/// Every independently versioned contract in the app, in one place.
///
/// The app version, the SQLite schema, the backup container, the RootLoop wire
/// protocol and the backend HTTP API all evolve at different speeds. Keeping
/// the numbers together (and covered by `versions_test.dart`) is what lets old
/// backups, old paired devices and old databases keep working after an upgrade.
class AppVersions {
  AppVersions._();

  /// SQLite schema version passed to `openDatabase(version: ...)`. Bump it
  /// together with an `onUpgrade` step and a fixture-based migration test.
  static const int schema = 14;

  /// Backup container written by this build.
  /// 1 = legacy plain JSON, 2 = zip container with manifest (see BackupService).
  static const int backupFormat = 1;

  /// Oldest backup container this build can still restore.
  static const int backupFormatMin = 1;

  /// RootLoop wire protocol spoken by this build.
  /// 1 = AES-256-GCM with SHA-256(secret) key, 2 = authenticated envelope v2.
  static const int rootLoopProtocol = 1;

  /// Oldest RootLoop protocol this build still accepts from paired devices.
  static const int rootLoopProtocolMin = 1;

  /// Backend HTTP API version (the `/v1/...` path prefix).
  static const int api = 1;

  /// True if a backup written as [format] can be restored by this build.
  static bool canRestoreBackup(int format) =>
      format >= backupFormatMin && format <= backupFormat;

  /// True if a peer speaking [protocol] can talk to this build.
  static bool canSpeakRootLoop(int protocol) =>
      protocol >= rootLoopProtocolMin && protocol <= rootLoopProtocol;
}

/// Compares two dotted version strings numerically (`1.10.0` > `1.9.3`).
/// A trailing build number (`1.2.3+4`) or pre-release suffix is ignored.
/// Returns a negative number, zero or a positive number like [Comparable].
int compareVersions(String a, String b) {
  List<int> parse(String v) {
    final core = v.split(RegExp(r'[+\-]')).first.trim();
    return core
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }

  final pa = parse(a);
  final pb = parse(b);
  final length = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}
