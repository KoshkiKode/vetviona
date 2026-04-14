import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/tree_provider.dart';

/// Provides AirDrop / Nearby Share / system-share-sheet style sync.
///
/// The user exports their tree as a `.vetviona` backup file and shares it
/// through the operating system's native share sheet.  On iOS / macOS this
/// triggers AirDrop alongside other options; on Android it surfaces Nearby
/// Share, Google Drive, email, and more.
///
/// The receiving device imports the file via the GEDCOM-or-JSON import flow
/// already available on the Home Screen and Settings.
///
/// This service is available to **all** tiers, but the recipient merge is
/// read-only for free-tier devices (limited to [freeMobilePersonLimit]).
class ShareSyncService {
  ShareSyncService._();
  static final instance = ShareSyncService._();

  /// Exports the current tree as a `.vetviona` (JSON) backup file and opens
  /// the platform share sheet.
  ///
  /// Returns `true` if the share sheet was presented; `false` if the export
  /// failed or the platform is unsupported (e.g. web).
  Future<bool> shareTree(TreeProvider tree) async {
    if (kIsWeb) {
      debugPrint('[ShareSyncService] Web platform not supported.');
      return false;
    }

    try {
      final json = await tree.exportBackupJson();
      final dir = await getTemporaryDirectory();
      final treeName = _sanitizeFileName(tree.currentTreeName);
      final file = File('${dir.path}/$treeName.vetviona');
      await file.writeAsString(json, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: '${tree.currentTreeName} — Vetviona Family Tree',
          text: 'Open this file in Vetviona to import the family tree.',
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[ShareSyncService] Share failed: $e');
      return false;
    }
  }

  /// Replaces any characters that are not safe in a file name.
  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w\s\-.]'), '_').trim();
  }
}
