import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vetviona_app/services/database_maintenance.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vetviona_db_test');
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<String> makeDatabase(int version) async {
    final path = '${tmp.path}/vetviona.db';
    final db = await openDatabase(
      path,
      version: version,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)');
        await db.insert('notes', {'body': 'family history'});
      },
    );
    await db.close();
    return path;
  }

  test('readDatabaseVersion returns the stored user_version', () async {
    final path = await makeDatabase(13);
    expect(await readDatabaseVersion(path), 13);
    expect(await readDatabaseVersion('${tmp.path}/missing.db'), 0);
  });

  test('a database pending an upgrade is copied before the upgrade', () async {
    final path = await makeDatabase(13);
    final backupDir = Directory('${tmp.path}/backups');

    final copy = await backupDatabaseBeforeUpgrade(
      dbPath: path,
      backupDir: backupDir,
      currentSchema: 14,
    );

    expect(copy, isNotNull);
    expect(await readDatabaseVersion(copy!.path), 13);
    final db = await openDatabase(copy.path);
    try {
      expect(await db.rawQuery('SELECT body FROM notes'), [
        {'body': 'family history'},
      ]);
    } finally {
      await db.close();
    }
  });

  test('a current-schema database is not copied', () async {
    final path = await makeDatabase(14);
    final backupDir = Directory('${tmp.path}/backups');
    final copy = await backupDatabaseBeforeUpgrade(
      dbPath: path,
      backupDir: backupDir,
      currentSchema: 14,
    );
    expect(copy, isNull);
    expect(backupDir.existsSync(), isFalse);
  });

  test('a database that does not exist yet is not copied', () async {
    final copy = await backupDatabaseBeforeUpgrade(
      dbPath: '${tmp.path}/none.db',
      backupDir: Directory('${tmp.path}/backups'),
      currentSchema: 14,
    );
    expect(copy, isNull);
  });

  test('only the newest backups are kept', () async {
    final path = await makeDatabase(13);
    final backupDir = Directory('${tmp.path}/backups');
    for (var i = 0; i < 5; i++) {
      await backupDatabaseFile(
        dbPath: path,
        backupDir: backupDir,
        fromVersion: 13,
        keep: 3,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    final remaining = backupDir.listSync().whereType<File>().toList();
    expect(remaining, hasLength(3));
  });

  test('a healthy database passes quick_check', () async {
    final path = await makeDatabase(14);
    final db = await openDatabase(path);
    try {
      expect(await quickCheckPasses(db), isTrue);
    } finally {
      await db.close();
    }
  });
}
