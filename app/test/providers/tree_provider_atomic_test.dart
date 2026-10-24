import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vetviona_app/models/life_event.dart';
import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/models/source.dart';
import 'package:vetviona_app/providers/tree_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String docsDir;

  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => docsDir);
  });

  late TreeProvider provider;

  setUp(() async {
    // A fresh file-backed database per test keeps triggers and rows isolated.
    docsDir = Directory.systemTemp.createTempSync('vetviona_provider').path;
    SharedPreferences.setMockInitialValues({});
    provider = TreeProvider();
    await provider.loadPersons();
  });

  tearDown(() {
    Directory(docsDir).deleteSync(recursive: true);
  });

  Future<void> addAliceAndBob() async {
    await provider.addPerson(Person(id: 'a', name: 'Alice'));
    await provider.addPerson(Person(id: 'b', name: 'Bob'));
  }

  test('deletePerson changes nothing when a cascade step fails', () async {
    await addAliceAndBob();
    await provider.addPartnership(
      Partnership(id: 'pt', person1Id: 'a', person2Id: 'b', status: 'married'),
    );
    final db = await provider.debugDatabase;
    await db.execute(
      "CREATE TRIGGER block_delete BEFORE DELETE ON partnerships "
      "BEGIN SELECT RAISE(ABORT, 'blocked'); END;",
    );

    await expectLater(provider.deletePerson('a'), throwsA(anything));

    expect(provider.persons.map((p) => p.id), containsAll(['a', 'b']));
    expect(provider.partnerships, hasLength(1));
    expect(await db.query('persons', where: 'id = ?', whereArgs: ['a']),
        hasLength(1));

    await db.execute('DROP TRIGGER block_delete');
    await provider.deletePerson('a');
    expect(provider.persons.map((p) => p.id), ['b']);
    expect(provider.partnerships, isEmpty);
  });

  test('importBackupJson is all-or-nothing', () async {
    await addAliceAndBob();
    final db = await provider.debugDatabase;
    await db.execute(
      "CREATE TRIGGER block_source BEFORE INSERT ON sources "
      "BEGIN SELECT RAISE(ABORT, 'blocked'); END;",
    );
    final incoming = jsonEncode({
      'persons': [Person(id: 'x', name: 'Xavier').toMap()],
      'sources': [
        Source(
          id: 's',
          personId: 'x',
          title: 'Parish register',
          type: 'Document',
          url: 'https://example.com',
        ).toMap(),
      ],
    });

    await expectLater(provider.importBackupJson(incoming), throwsA(anything));

    final ids = (await db.query('persons')).map((row) => row['id']).toList();
    expect(ids, unorderedEquals(['a', 'b']));
  });

  test('updatePerson drops a link that would make someone their own ancestor',
      () async {
    await provider.addPerson(Person(id: 'a', name: 'A', childIds: ['b']));
    await provider.addPerson(
        Person(id: 'b', name: 'B', parentIds: ['a'], childIds: ['c']));
    await provider.addPerson(Person(id: 'c', name: 'C', parentIds: ['b']));

    final a = provider.persons.firstWhere((p) => p.id == 'a');
    a.parentIds = ['c'];
    await provider.updatePerson(a);

    expect(provider.persons.firstWhere((p) => p.id == 'a').parentIds, isEmpty);
  });

  test('exportShareJson leaves out private people and everything attached',
      () async {
    await provider.addPerson(Person(id: 'pub', name: 'Public Person'));
    await provider.addPerson(
        Person(id: 'priv', name: 'Secret Person', isPrivate: true));
    await provider.addPartnership(
      Partnership(
        id: 'pt',
        person1Id: 'pub',
        person2Id: 'priv',
        status: 'married',
      ),
    );
    await provider.addLifeEvent(
      LifeEvent(id: 'e', personId: 'priv', title: 'Birth'),
    );

    final json = await provider.exportShareJson();
    expect(json, isNot(contains('Secret Person')));

    final data = jsonDecode(json) as Map<String, dynamic>;
    expect(
      (data['persons'] as List).map((m) => (m as Map)['name']),
      ['Public Person'],
    );
    expect(data['partnerships'], isEmpty);
    expect(data['lifeEvents'], isEmpty);
    expect(data['medicalConditions'], isEmpty);
  });
}
