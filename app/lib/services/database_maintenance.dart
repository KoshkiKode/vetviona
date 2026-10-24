import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Reads the `user_version` stored in the SQLite file at [dbPath].
///
/// Returns 0 when the file is missing or has never been versioned. The WAL is
/// checkpointed first so that a copy of the main file is complete.
Future<int> readDatabaseVersion(String dbPath) async {
  if (!File(dbPath).existsSync()) return 0;
  final db = await openDatabase(dbPath);
  try {
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
    return await db.getVersion();
  } finally {
    await db.close();
  }
}

/// Copies the database into [backupDir] when an upgrade from an older schema
/// is pending. Returns the new copy, or null when nothing needs backing up.
Future<File?> backupDatabaseBeforeUpgrade({
  required String dbPath,
  required Directory backupDir,
  required int currentSchema,
  int keep = 3,
}) async {
  final from = await readDatabaseVersion(dbPath);
  if (from == 0 || from >= currentSchema) return null;
  return backupDatabaseFile(
    dbPath: dbPath,
    backupDir: backupDir,
    fromVersion: from,
    keep: keep,
  );
}

/// Copies [dbPath] to a timestamped file in [backupDir] and prunes the oldest
/// copies so that at most [keep] remain.
Future<File> backupDatabaseFile({
  required String dbPath,
  required Directory backupDir,
  required int fromVersion,
  int keep = 3,
}) async {
  await backupDir.create(recursive: true);
  final stamp =
      DateTime.now().microsecondsSinceEpoch.toString().padLeft(16, '0');
  final target =
      File(p.join(backupDir.path, 'vetviona-$stamp-v$fromVersion.db'));
  await File(dbPath).copy(target.path);

  final copies = backupDir
      .listSync()
      .whereType<File>()
      .where((f) => _isBackupName(p.basename(f.path)))
      .toList()
    ..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
  for (final old in copies.skip(keep)) {
    await old.delete();
  }
  return target;
}

/// True when `PRAGMA quick_check` reports no structural problems.
Future<bool> quickCheckPasses(Database db) async {
  final rows = await db.rawQuery('PRAGMA quick_check');
  return rows.isNotEmpty && rows.every((row) => row.values.first == 'ok');
}

bool _isBackupName(String name) =>
    RegExp(r'^vetviona-\d{16}-v\d+\.db$').hasMatch(name);
