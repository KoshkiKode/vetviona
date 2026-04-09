import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/device.dart';
import '../models/partnership.dart';
import '../models/person.dart';
import '../models/source.dart';
import '../services/gedcom_parser.dart';

class TreeProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  List<Person> persons = [];
  List<Source> sources = [];
  List<Partnership> partnerships = [];
  List<String> treeNames = [];
  String currentTreeId = 'default';
  List<Device> pairedDevices = [];

  String? _currentUser;
  bool get isLoggedIn => _currentUser != null;
  String? get currentUser => _currentUser;

  int colonizationLevel = 0; // 0=none 1=colonizers 2=native
  String _dateFormat = 'dd MMM yyyy';
  String get dateFormat => _dateFormat;

  Database? _db;
  static const _uuid = Uuid();
  static const _dbName = 'vetviona.db';

  /// Returns the maximum number of people allowed per tree for this build.
  int? get personLimit =>
      currentAppTier == AppTier.mobileFree ? freeMobilePersonLimit : null;

  // ── Database ───────────────────────────────────────────────────────────────
  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE trees (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE persons (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            birthDate TEXT,
            birthPlace TEXT,
            deathDate TEXT,
            deathPlace TEXT,
            gender TEXT,
            parentIds TEXT,
            childIds TEXT,
            photoPaths TEXT,
            sourceIds TEXT,
            parentRelTypes TEXT,
            notes TEXT,
            treeId TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sources (
            id TEXT PRIMARY KEY,
            personId TEXT NOT NULL,
            title TEXT NOT NULL,
            type TEXT NOT NULL,
            url TEXT NOT NULL,
            imagePath TEXT,
            extractedInfo TEXT,
            citedFacts TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE devices (
            id TEXT PRIMARY KEY,
            sharedSecret TEXT NOT NULL,
            tier TEXT NOT NULL DEFAULT 'mobileFree'
          )
        ''');
        await db.execute('''
          CREATE TABLE partnerships (
            id TEXT PRIMARY KEY,
            person1Id TEXT NOT NULL,
            person2Id TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'married',
            startDate TEXT,
            startPlace TEXT,
            endDate TEXT,
            endPlace TEXT,
            treeId TEXT
          )
        ''');
        await db.insert('trees', {'id': 'default', 'name': 'My Family Tree'});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE devices ADD COLUMN tier TEXT NOT NULL DEFAULT 'mobileFree'",
          );
        }
        if (oldVersion < 3) {
          // Add new persons columns (old spouseId / marriageDate / marriagePlace
          // columns are kept in place — SQLite cannot drop them — but are no
          // longer read by the app.)
          await db.execute(
            'ALTER TABLE persons ADD COLUMN parentRelTypes TEXT',
          );
          // Create partnerships table
          await db.execute('''
            CREATE TABLE partnerships (
              id TEXT PRIMARY KEY,
              person1Id TEXT NOT NULL,
              person2Id TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'married',
              startDate TEXT,
              startPlace TEXT,
              endDate TEXT,
              endPlace TEXT,
              treeId TEXT
            )
          ''');
          // Migrate existing spouseId + marriageDate + marriagePlace → partnerships
          final personMaps = await db.query('persons');
          // Track processed pairs to avoid duplicate partnership records
          final processed = <Set<String>>{};
          for (final row in personMaps) {
            final personId = row['id'] as String;
            final spouseId = row['spouseId'] as String?;
            if (spouseId == null || spouseId.isEmpty) continue;
            final pair = {personId, spouseId};
            if (processed.any((p) => p.containsAll(pair))) continue;
            processed.add(pair);
            final sortedIds = [personId, spouseId]..sort();
            await db.insert('partnerships', {
              'id': 'mig_${sortedIds[0]}_${sortedIds[1]}',
              'person1Id': personId,
              'person2Id': spouseId,
              'status': 'married',
              'startDate': row['marriageDate'],
              'startPlace': row['marriagePlace'],
              'endDate': null,
              'endPlace': null,
              'treeId': row['treeId'],
            });
          }
        }
      },
    );
  }

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> loadPersons() async {
    final db = await _database;
    final treeMaps = await db.query('trees');
    treeNames = treeMaps.map((m) => m['name'] as String).toList();
    if (treeNames.isEmpty) {
      await db.insert('trees', {'id': 'default', 'name': 'My Family Tree'});
      treeNames = ['My Family Tree'];
    }

    final personMaps = await db.query(
      'persons',
      where: 'treeId = ?',
      whereArgs: [currentTreeId],
    );
    persons = personMaps.map(Person.fromMap).toList();

    final sourceMaps = await db.query('sources');
    sources = sourceMaps.map(Source.fromMap).toList();

    final partnershipMaps = await db.query(
      'partnerships',
      where: 'treeId = ?',
      whereArgs: [currentTreeId],
    );
    partnerships = partnershipMaps.map(Partnership.fromMap).toList();

    final deviceMaps = await db.query('devices');
    pairedDevices = deviceMaps.map(Device.fromMap).toList();

    final prefs = await SharedPreferences.getInstance();
    _dateFormat = prefs.getString('dateFormat') ?? 'dd MMM yyyy';
    colonizationLevel = prefs.getInt('colonizationLevel') ?? 0;

    notifyListeners();
  }

  // ── Persons ────────────────────────────────────────────────────────────────
  bool get isAtPersonLimit {
    final limit = personLimit;
    if (limit == null) return false;
    return persons.length >= limit;
  }

  Future<void> addPerson(Person person) async {
    if (isAtPersonLimit) {
      throw StateError(
        'Free tier limit reached: this tree already has $freeMobilePersonLimit people. '
        'Upgrade to Mobile Paid or Desktop Pro to add more.',
      );
    }
    person.id = person.id.isEmpty ? _uuid.v4() : person.id;
    person.treeId = currentTreeId;
    final db = await _database;
    await db.insert('persons', person.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    persons.add(person);
    notifyListeners();
  }

  Future<void> updatePerson(Person person) async {
    final db = await _database;
    await db.update('persons', person.toMap(),
        where: 'id = ?', whereArgs: [person.id]);
    final idx = persons.indexWhere((p) => p.id == person.id);
    if (idx != -1) persons[idx] = person;
    notifyListeners();
  }

  Future<void> deletePerson(String id) async {
    final db = await _database;
    await db.delete('persons', where: 'id = ?', whereArgs: [id]);
    // Remove all partnerships involving this person
    await db.delete('partnerships',
        where: 'person1Id = ? OR person2Id = ?', whereArgs: [id, id]);
    partnerships.removeWhere(
        (pt) => pt.person1Id == id || pt.person2Id == id);
    persons.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  // ── Sources ────────────────────────────────────────────────────────────────
  Future<void> addSource(Source source) async {
    source.id = source.id.isEmpty ? _uuid.v4() : source.id;
    final db = await _database;
    await db.insert('sources', source.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    sources.add(source);
    if (source.personId.isNotEmpty) {
      final idx = persons.indexWhere((p) => p.id == source.personId);
      if (idx != -1 && !persons[idx].sourceIds.contains(source.id)) {
        persons[idx].sourceIds.add(source.id);
        await db.update('persons', persons[idx].toMap(),
            where: 'id = ?', whereArgs: [persons[idx].id]);
      }
    }
    notifyListeners();
  }

  Future<void> updateSource(Source source) async {
    final db = await _database;
    await db.update('sources', source.toMap(),
        where: 'id = ?', whereArgs: [source.id]);
    final idx = sources.indexWhere((s) => s.id == source.id);
    if (idx != -1) sources[idx] = source;
    notifyListeners();
  }

  Future<void> deleteSource(String id) async {
    final db = await _database;
    await db.delete('sources', where: 'id = ?', whereArgs: [id]);
    final srcIdx = sources.indexWhere((s) => s.id == id);
    if (srcIdx != -1) {
      final personId = sources[srcIdx].personId;
      final pIdx = persons.indexWhere((p) => p.id == personId);
      if (pIdx != -1) {
        persons[pIdx].sourceIds.remove(id);
        await db.update('persons', persons[pIdx].toMap(),
            where: 'id = ?', whereArgs: [persons[pIdx].id]);
      }
    }
    sources.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  // ── Partnerships ───────────────────────────────────────────────────────────
  Future<void> addPartnership(Partnership partnership) async {
    partnership.id = partnership.id.isEmpty ? _uuid.v4() : partnership.id;
    partnership.treeId = currentTreeId;
    final db = await _database;
    await db.insert('partnerships', partnership.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    partnerships.add(partnership);
    notifyListeners();
  }

  Future<void> updatePartnership(Partnership partnership) async {
    final db = await _database;
    await db.update('partnerships', partnership.toMap(),
        where: 'id = ?', whereArgs: [partnership.id]);
    final idx = partnerships.indexWhere((p) => p.id == partnership.id);
    if (idx != -1) partnerships[idx] = partnership;
    notifyListeners();
  }

  Future<void> deletePartnership(String id) async {
    final db = await _database;
    await db.delete('partnerships', where: 'id = ?', whereArgs: [id]);
    partnerships.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  /// Returns all partnerships that include [personId] as either partner.
  List<Partnership> partnershipsFor(String personId) => partnerships
      .where((p) => p.person1Id == personId || p.person2Id == personId)
      .toList();

  /// Returns the IDs of all partners of [personId].
  List<String> partnerIdsFor(String personId) => partnershipsFor(personId)
      .map((p) => p.person1Id == personId ? p.person2Id : p.person1Id)
      .toList();

  /// Returns the persons whose [parentIds] contains BOTH partners in [p],
  /// i.e. the children born/adopted into this specific union.
  List<Person> childrenOfPartnership(Partnership p) => persons
      .where((child) =>
          child.parentIds.contains(p.person1Id) &&
          child.parentIds.contains(p.person2Id))
      .toList();

  // ── Trees ──────────────────────────────────────────────────────────────────
  Future<void> addTree(String name) async {
    final id = _uuid.v4();
    final db = await _database;
    await db.insert('trees', {'id': id, 'name': name});
    treeNames.add(name);
    notifyListeners();
  }

  Future<void> switchTree(String treeId) async {
    currentTreeId = treeId;
    await loadPersons();
  }

  Future<void> deleteTree(String treeId) async {
    if (treeId == 'default') return;
    final db = await _database;
    await db.delete('trees', where: 'id = ?', whereArgs: [treeId]);
    await db.delete('persons', where: 'treeId = ?', whereArgs: [treeId]);
    await db.delete('partnerships',
        where: 'treeId = ?', whereArgs: [treeId]);
    if (currentTreeId == treeId) {
      currentTreeId = 'default';
    }
    await loadPersons();
  }

  // ── Auth ───────────────────────────────────────────────────────────────────
  Future<bool> register(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'user_$username';
    if (prefs.containsKey(key)) return false;
    await prefs.setString(key, password);
    _currentUser = username;
    notifyListeners();
    return true;
  }

  Future<bool> login(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('user_$username');
    if (stored == password) {
      _currentUser = username;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // ── Settings ───────────────────────────────────────────────────────────────
  Future<void> setDateFormat(String format) async {
    _dateFormat = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dateFormat', format);
    notifyListeners();
  }

  Future<void> setColonizationLevel(int level) async {
    colonizationLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('colonizationLevel', level);
    notifyListeners();
  }

  // ── Search ─────────────────────────────────────────────────────────────────
  List<Person> searchPersons(String query) {
    final q = query.toLowerCase();
    return persons.where((p) {
      return p.name.toLowerCase().contains(q) ||
          (p.birthPlace?.toLowerCase().contains(q) ?? false) ||
          (p.deathPlace?.toLowerCase().contains(q) ?? false) ||
          (p.notes?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ── GEDCOM ─────────────────────────────────────────────────────────────────
  Future<void> importGEDCOM(String path) async {
    final parser = GEDCOMParser();
    final result = await parser.parse(path);
    for (final person in result.persons) {
      person.treeId = currentTreeId;
      await addPerson(person);
    }
    for (final partnership in result.partnerships) {
      partnership.treeId = currentTreeId;
      await addPartnership(partnership);
    }
  }

  Future<void> exportGEDCOM(String path) async {
    final parser = GEDCOMParser();
    await parser.export(persons, partnerships, path);
  }

  // ── Relationship BFS ───────────────────────────────────────────────────────
  List<String> findRelationshipPath(String fromId, String toId) {
    if (fromId == toId) return [fromId];
    final personMap = {for (final p in persons) p.id: p};
    final queue = Queue<List<String>>();
    final visited = <String>{};
    queue.add([fromId]);
    visited.add(fromId);

    while (queue.isNotEmpty) {
      final path = queue.removeFirst();
      final currentId = path.last;
      final current = personMap[currentId];
      if (current == null) continue;

      final neighbors = <String>[
        ...current.parentIds,
        ...current.childIds,
        // Traverse all partnerships (supports multiple partners)
        ...partnerIdsFor(currentId),
      ];

      for (final neighborId in neighbors) {
        if (visited.contains(neighborId)) continue;
        final newPath = [...path, neighborId];
        if (neighborId == toId) return newPath;
        visited.add(neighborId);
        queue.add(newPath);
      }
    }
    return [];
  }

  // ── Devices ────────────────────────────────────────────────────────────────
  Future<void> addDevice(Device device) async {
    final db = await _database;
    await db.insert('devices', device.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    pairedDevices.add(device);
    notifyListeners();
  }

  Future<void> removeDevice(String id) async {
    final db = await _database;
    await db.delete('devices', where: 'id = ?', whereArgs: [id]);
    pairedDevices.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  // ── Clear DB ───────────────────────────────────────────────────────────────
  Future<void> clearDatabase() async {
    final db = await _database;
    await db.delete('persons');
    await db.delete('sources');
    await db.delete('partnerships');
    await db.delete('devices');
    persons.clear();
    sources.clear();
    partnerships.clear();
    pairedDevices.clear();
    notifyListeners();
  }
}
