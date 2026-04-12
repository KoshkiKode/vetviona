import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/device.dart';
import '../models/life_event.dart';
import '../models/medical_condition.dart';
import '../models/partnership.dart';
import '../models/person.dart';
import '../models/research_task.dart';
import '../models/source.dart';
import '../services/gedcom_parser.dart';

class TreeProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  List<Person> persons = [];
  List<Source> sources = [];
  List<Partnership> partnerships = [];
  List<LifeEvent> lifeEvents = [];
  List<MedicalCondition> medicalConditions = [];
  List<ResearchTask> researchTasks = [];

  // ── Live-change stream ─────────────────────────────────────────────────────

  /// Broadcast stream that emits a delta payload after every local write
  /// operation.  [SyncService] subscribes to this so it can push changes to
  /// all active peers in real time.
  ///
  /// The payload has the same shape as [exportForSync] but contains only the
  /// record(s) that were just modified.
  final _liveChangeController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get liveChanges => _liveChangeController.stream;

  /// Emits a delta containing [persons], [partnerships], [sources], and
  /// [lifeEvents] (any of which may be empty) to [liveChanges].
  void _emitDelta({
    List<Map<String, dynamic>> persons = const [],
    List<Map<String, dynamic>> partnerships = const [],
    List<Map<String, dynamic>> sources = const [],
    List<Map<String, dynamic>> lifeEvents = const [],
  }) {
    if (_liveChangeController.hasListener) {
      _liveChangeController.add({
        'persons': persons,
        'partnerships': partnerships,
        'sources': sources,
        'lifeEvents': lifeEvents,
      });
    }
  }

  /// Full tree records — each entry holds both the UUID and display name.
  List<Map<String, String>> trees = [];

  /// Convenience list of tree names (preserved for legacy callers).
  List<String> get treeNames => trees.map((t) => t['name']!).toList();

  /// Display name of the currently active tree.
  String get currentTreeName => trees
      .firstWhere(
        (t) => t['id'] == currentTreeId,
        orElse: () => {'id': currentTreeId, 'name': 'My Family Tree'},
      )['name']!;

  String currentTreeId = 'default';
  List<Device> pairedDevices = [];

  String? _currentUser;
  bool get isLoggedIn => _currentUser != null;
  String? get currentUser => _currentUser;

  /// This installation's persistent device ID.  Generated once and stored in
  /// SharedPreferences so it survives app restarts.
  String _localDeviceId = '';
  String get localDeviceId => _localDeviceId;

  int colonizationLevel = 0; // 0=none 1=colonizers 2=native
  String _dateFormat = 'dd MMM yyyy';
  String get dateFormat => _dateFormat;

  /// The ID of the "home person" — the default focal point for tree views.
  String? _homePersonId;
  String? get homePersonId => _homePersonId;

  // ── Loading progress ───────────────────────────────────────────────────────
  /// True once [loadPersons] has completed its first full load.
  bool isLoaded = false;

  /// Human-readable description of the current load step.
  String loadingMessage = 'Starting…';

  /// Fractional progress 0.0 → 1.0 during [loadPersons].
  double loadingProgress = 0.0;

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

  static bool _ffiInitialized = false;

  Future<Database> _initDb() async {
    // On desktop platforms sqflite needs the FFI implementation.
    // Guard with a static flag so initialization happens at most once.
    if (!kIsWeb &&
        !_ffiInitialized &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    return openDatabase(
      path,
      version: 8,
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
            treeId TEXT,
            occupation TEXT,
            nationality TEXT,
            maidenName TEXT,
            burialDate TEXT,
            burialPlace TEXT,
            birthCoord TEXT,
            deathCoord TEXT,
            burialCoord TEXT,
            birthPostalCode TEXT,
            deathPostalCode TEXT,
            burialPostalCode TEXT,
            isPrivate INTEGER NOT NULL DEFAULT 0,
            preferredSourceIds TEXT,
            causeOfDeath TEXT,
            bloodType TEXT,
            eyeColour TEXT,
            hairColour TEXT,
            height TEXT,
            religion TEXT,
            education TEXT,
            aliases TEXT,
            updatedAt INTEGER
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
            citedFacts TEXT,
            author TEXT,
            publisher TEXT,
            publicationDate TEXT,
            repository TEXT,
            volumePage TEXT,
            retrievalDate TEXT,
            confidence TEXT,
            treeId TEXT,
            updatedAt INTEGER
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
            treeId TEXT,
            notes TEXT,
            ceremonyType TEXT,
            sourceIds TEXT,
            witnesses TEXT,
            updatedAt INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE life_events (
            id TEXT PRIMARY KEY,
            personId TEXT NOT NULL,
            title TEXT NOT NULL,
            date TEXT,
            place TEXT,
            notes TEXT,
            treeId TEXT,
            updatedAt INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE medical_conditions (
            id TEXT PRIMARY KEY,
            personId TEXT NOT NULL,
            condition TEXT NOT NULL,
            category TEXT NOT NULL,
            ageOfOnset TEXT,
            notes TEXT,
            treeId TEXT,
            attachmentPaths TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE research_tasks (
            id TEXT PRIMARY KEY,
            personId TEXT,
            title TEXT NOT NULL,
            notes TEXT,
            status TEXT NOT NULL DEFAULT 'todo',
            priority TEXT NOT NULL DEFAULT 'normal',
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
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE persons ADD COLUMN occupation TEXT',
          );
          await db.execute(
            'ALTER TABLE persons ADD COLUMN nationality TEXT',
          );
          await db.execute(
            'ALTER TABLE persons ADD COLUMN maidenName TEXT',
          );
          await db.execute(
            'ALTER TABLE persons ADD COLUMN burialDate TEXT',
          );
          await db.execute(
            'ALTER TABLE persons ADD COLUMN burialPlace TEXT',
          );
          await db.execute('''
            CREATE TABLE life_events (
              id TEXT PRIMARY KEY,
              personId TEXT NOT NULL,
              title TEXT NOT NULL,
              date TEXT,
              place TEXT,
              notes TEXT,
              treeId TEXT
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE persons ADD COLUMN birthCoord TEXT');
          await db.execute('ALTER TABLE persons ADD COLUMN deathCoord TEXT');
          await db.execute('ALTER TABLE persons ADD COLUMN burialCoord TEXT');
          await db.execute('ALTER TABLE persons ADD COLUMN birthPostalCode TEXT');
          await db.execute('ALTER TABLE persons ADD COLUMN deathPostalCode TEXT');
          await db.execute('ALTER TABLE persons ADD COLUMN burialPostalCode TEXT');
        }
        if (oldVersion < 6) {
          await db.execute(
              'ALTER TABLE persons ADD COLUMN isPrivate INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE persons ADD COLUMN preferredSourceIds TEXT');
          await db.execute('''
            CREATE TABLE medical_conditions (
              id TEXT PRIMARY KEY,
              personId TEXT NOT NULL,
              condition TEXT NOT NULL,
              category TEXT NOT NULL,
              ageOfOnset TEXT,
              notes TEXT,
              treeId TEXT,
              attachmentPaths TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE research_tasks (
              id TEXT PRIMARY KEY,
              personId TEXT,
              title TEXT NOT NULL,
              notes TEXT,
              status TEXT NOT NULL DEFAULT 'todo',
              priority TEXT NOT NULL DEFAULT 'normal',
              treeId TEXT
            )
          ''');
        }
        if (oldVersion < 7) {
          await db.execute('ALTER TABLE persons ADD COLUMN causeOfDeath TEXT');
          await db.execute('ALTER TABLE persons ADD COLUMN bloodType TEXT');
          await db.execute('ALTER TABLE persons ADD COLUMN eyeColour TEXT');
          await db.execute('ALTER TABLE persons ADD COLUMN hairColour TEXT');
          await db.execute('ALTER TABLE persons ADD COLUMN height TEXT');
          await db.execute('ALTER TABLE persons ADD COLUMN religion TEXT');
          await db.execute('ALTER TABLE persons ADD COLUMN education TEXT');
          await db.execute('ALTER TABLE persons ADD COLUMN aliases TEXT');
          await db.execute('ALTER TABLE sources ADD COLUMN author TEXT');
          await db.execute('ALTER TABLE sources ADD COLUMN publisher TEXT');
          await db.execute(
              'ALTER TABLE sources ADD COLUMN publicationDate TEXT');
          await db.execute('ALTER TABLE sources ADD COLUMN repository TEXT');
          await db.execute('ALTER TABLE sources ADD COLUMN volumePage TEXT');
          await db.execute(
              'ALTER TABLE sources ADD COLUMN retrievalDate TEXT');
          await db.execute('ALTER TABLE sources ADD COLUMN confidence TEXT');
          await db.execute('ALTER TABLE sources ADD COLUMN treeId TEXT');
          await db.execute('ALTER TABLE partnerships ADD COLUMN notes TEXT');
          await db.execute(
              'ALTER TABLE partnerships ADD COLUMN ceremonyType TEXT');
          await db.execute(
              'ALTER TABLE partnerships ADD COLUMN sourceIds TEXT');
          await db.execute(
              'ALTER TABLE partnerships ADD COLUMN witnesses TEXT');
        }
        if (oldVersion < 8) {
          // Add updatedAt timestamp column to all synced tables.
          // Existing rows get NULL (treated as 0 during merge).
          await db.execute(
              'ALTER TABLE persons ADD COLUMN updatedAt INTEGER');
          await db.execute(
              'ALTER TABLE partnerships ADD COLUMN updatedAt INTEGER');
          await db.execute(
              'ALTER TABLE sources ADD COLUMN updatedAt INTEGER');
          await db.execute(
              'ALTER TABLE life_events ADD COLUMN updatedAt INTEGER');
        }
      },
    );
  }

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> loadPersons() async {
    void _step(String message, double progress) {
      loadingMessage = message;
      loadingProgress = progress;
      notifyListeners();
    }

    _step('Opening database…', 0.0);
    final db = await _database;

    _step('Loading family trees…', 0.05);
    final treeMaps = await db.query('trees');
    trees = treeMaps
        .map((m) => {
              'id': m['id'] as String,
              'name': m['name'] as String,
            })
        .toList();
    if (trees.isEmpty) {
      await db.insert('trees', {'id': 'default', 'name': 'My Family Tree'});
      trees = [
        {'id': 'default', 'name': 'My Family Tree'}
      ];
    }

    _step('Loading people…', 0.15);
    final personMaps = await db.query(
      'persons',
      where: 'treeId = ?',
      whereArgs: [currentTreeId],
    );
    persons = personMaps.map(Person.fromMap).toList();

    _step('Loading sources…', 0.35);
    final sourceMaps = await db.rawQuery(
      'SELECT s.* FROM sources s INNER JOIN persons p ON s.personId = p.id WHERE p.treeId = ?',
      [currentTreeId],
    );
    sources = sourceMaps.map(Source.fromMap).toList();

    _step('Loading partnerships…', 0.50);
    final partnershipMaps = await db.query(
      'partnerships',
      where: 'treeId = ?',
      whereArgs: [currentTreeId],
    );
    partnerships = partnershipMaps.map(Partnership.fromMap).toList();

    _step('Loading life events…', 0.62);
    final lifeEventMaps = await db.rawQuery(
      'SELECT le.* FROM life_events le INNER JOIN persons p ON le.personId = p.id WHERE p.treeId = ?',
      [currentTreeId],
    );
    lifeEvents = lifeEventMaps.map(LifeEvent.fromMap).toList();

    _step('Loading medical history…', 0.74);
    final medicalMaps = await db.rawQuery(
      'SELECT mc.* FROM medical_conditions mc INNER JOIN persons p ON mc.personId = p.id WHERE p.treeId = ?',
      [currentTreeId],
    );
    medicalConditions = medicalMaps.map(MedicalCondition.fromMap).toList();

    _step('Loading research tasks…', 0.84);
    final taskMaps = await db.query(
      'research_tasks',
      where: 'treeId = ?',
      whereArgs: [currentTreeId],
    );
    researchTasks = taskMaps.map(ResearchTask.fromMap).toList();

    _step('Loading devices…', 0.92);
    final deviceMaps = await db.query('devices');
    pairedDevices = deviceMaps.map(Device.fromMap).toList();

    _step('Loading preferences…', 0.96);
    final prefs = await SharedPreferences.getInstance();
    _dateFormat = prefs.getString('dateFormat') ?? 'dd MMM yyyy';
    colonizationLevel = prefs.getInt('colonizationLevel') ?? 0;
    _homePersonId = prefs.getString('homePersonId');

    // Stable per-installation ID used by the sync service.
    _localDeviceId = prefs.getString('localDeviceId') ?? '';
    if (_localDeviceId.isEmpty) {
      _localDeviceId = _uuid.v4();
      await prefs.setString('localDeviceId', _localDeviceId);
    }

    loadingMessage = 'Ready';
    loadingProgress = 1.0;
    isLoaded = true;
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
    person.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.insert('persons', person.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    persons.add(person);
    _emitDelta(persons: [person.toMap()]);
    notifyListeners();
  }

  Future<void> updatePerson(Person person) async {
    person.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.update('persons', person.toMap(),
        where: 'id = ?', whereArgs: [person.id]);
    final idx = persons.indexWhere((p) => p.id == person.id);
    if (idx != -1) persons[idx] = person;
    _emitDelta(persons: [person.toMap()]);
    notifyListeners();
  }

  Future<void> deletePerson(String id) async {
    final db = await _database;
    await db.delete('persons', where: 'id = ?', whereArgs: [id]);
    // Cascade-delete all data associated with this person.
    await db.delete('partnerships',
        where: 'person1Id = ? OR person2Id = ?', whereArgs: [id, id]);
    partnerships.removeWhere(
        (pt) => pt.person1Id == id || pt.person2Id == id);
    await db.delete('sources', where: 'personId = ?', whereArgs: [id]);
    sources.removeWhere((s) => s.personId == id);
    await db.delete('life_events', where: 'personId = ?', whereArgs: [id]);
    lifeEvents.removeWhere((e) => e.personId == id);
    await db.delete('medical_conditions',
        where: 'personId = ?', whereArgs: [id]);
    medicalConditions.removeWhere((mc) => mc.personId == id);
    await db.delete('research_tasks',
        where: 'personId = ?', whereArgs: [id]);
    researchTasks.removeWhere((t) => t.personId == id);
    // Remove this person's ID from other persons' parentIds / childIds
    for (final p in persons) {
      final hadParent = p.parentIds.remove(id);
      final hadChild = p.childIds.remove(id);
      if (hadParent || hadChild) {
        p.parentRelTypes.remove(id);
        await db.update('persons', p.toMap(),
            where: 'id = ?', whereArgs: [p.id]);
      }
    }
    persons.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  // ── Sources ────────────────────────────────────────────────────────────────
  Future<void> addSource(Source source) async {
    source.id = source.id.isEmpty ? _uuid.v4() : source.id;
    source.updatedAt = DateTime.now().millisecondsSinceEpoch;
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
    _emitDelta(sources: [source.toMap()]);
    notifyListeners();
  }

  Future<void> updateSource(Source source) async {
    source.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.update('sources', source.toMap(),
        where: 'id = ?', whereArgs: [source.id]);
    final idx = sources.indexWhere((s) => s.id == source.id);
    if (idx != -1) sources[idx] = source;
    _emitDelta(sources: [source.toMap()]);
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
    partnership.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.insert('partnerships', partnership.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    partnerships.add(partnership);
    _emitDelta(partnerships: [partnership.toMap()]);
    notifyListeners();
  }

  Future<void> updatePartnership(Partnership partnership) async {
    partnership.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.update('partnerships', partnership.toMap(),
        where: 'id = ?', whereArgs: [partnership.id]);
    final idx = partnerships.indexWhere((p) => p.id == partnership.id);
    if (idx != -1) partnerships[idx] = partnership;
    _emitDelta(partnerships: [partnership.toMap()]);
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

  // ── Life Events ────────────────────────────────────────────────────────────
  Future<void> addLifeEvent(LifeEvent event) async {
    event.id = event.id.isEmpty ? _uuid.v4() : event.id;
    final person = persons.firstWhere((p) => p.id == event.personId,
        orElse: () => throw StateError('Person with id ${event.personId} not found'));
    event.treeId = person.treeId;
    event.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.insert('life_events', event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    lifeEvents.add(event);
    _emitDelta(lifeEvents: [event.toMap()]);
    notifyListeners();
  }

  Future<void> updateLifeEvent(LifeEvent event) async {
    event.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.update('life_events', event.toMap(),
        where: 'id = ?', whereArgs: [event.id]);
    final idx = lifeEvents.indexWhere((e) => e.id == event.id);
    if (idx != -1) lifeEvents[idx] = event;
    _emitDelta(lifeEvents: [event.toMap()]);
    notifyListeners();
  }

  Future<void> deleteLifeEvent(String id) async {
    final db = await _database;
    await db.delete('life_events', where: 'id = ?', whereArgs: [id]);
    lifeEvents.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Returns all life events for the given [personId].
  List<LifeEvent> lifeEventsFor(String personId) =>
      lifeEvents.where((e) => e.personId == personId).toList();

  // ── Medical Conditions ─────────────────────────────────────────────────────
  Future<void> addMedicalCondition(MedicalCondition condition) async {
    condition.id = condition.id.isEmpty ? _uuid.v4() : condition.id;
    final person = persons.firstWhere((p) => p.id == condition.personId,
        orElse: () =>
            throw StateError('Person ${condition.personId} not found'));
    condition.treeId = person.treeId;
    final db = await _database;
    await db.insert('medical_conditions', condition.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    medicalConditions.add(condition);
    notifyListeners();
  }

  Future<void> updateMedicalCondition(MedicalCondition condition) async {
    final db = await _database;
    await db.update('medical_conditions', condition.toMap(),
        where: 'id = ?', whereArgs: [condition.id]);
    final idx =
        medicalConditions.indexWhere((mc) => mc.id == condition.id);
    if (idx != -1) medicalConditions[idx] = condition;
    notifyListeners();
  }

  Future<void> deleteMedicalCondition(String id) async {
    final db = await _database;
    await db.delete('medical_conditions', where: 'id = ?', whereArgs: [id]);
    medicalConditions.removeWhere((mc) => mc.id == id);
    notifyListeners();
  }

  /// Returns all medical conditions recorded for [personId].
  List<MedicalCondition> medicalConditionsFor(String personId) =>
      medicalConditions.where((mc) => mc.personId == personId).toList();

  // ── Research Tasks ─────────────────────────────────────────────────────────
  Future<void> addResearchTask(ResearchTask task) async {
    task.id = task.id.isEmpty ? _uuid.v4() : task.id;
    task.treeId = currentTreeId;
    final db = await _database;
    await db.insert('research_tasks', task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    researchTasks.add(task);
    notifyListeners();
  }

  Future<void> updateResearchTask(ResearchTask task) async {
    final db = await _database;
    await db.update('research_tasks', task.toMap(),
        where: 'id = ?', whereArgs: [task.id]);
    final idx = researchTasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) researchTasks[idx] = task;
    notifyListeners();
  }

  Future<void> deleteResearchTask(String id) async {
    final db = await _database;
    await db.delete('research_tasks', where: 'id = ?', whereArgs: [id]);
    researchTasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// Returns all research tasks linked to [personId].
  List<ResearchTask> researchTasksFor(String personId) =>
      researchTasks.where((t) => t.personId == personId).toList();

  // ── Trees ──────────────────────────────────────────────────────────────────
  Future<String> addTree(String name) async {
    final id = _uuid.v4();
    final db = await _database;
    await db.insert('trees', {'id': id, 'name': name});
    trees.add({'id': id, 'name': name});
    notifyListeners();
    return id;
  }

  Future<void> renameTree(String treeId, String newName) async {
    final db = await _database;
    await db.update('trees', {'name': newName},
        where: 'id = ?', whereArgs: [treeId]);
    final idx = trees.indexWhere((t) => t['id'] == treeId);
    if (idx != -1) trees[idx] = {'id': treeId, 'name': newName};
    notifyListeners();
  }

  Future<void> switchTree(String treeId) async {
    currentTreeId = treeId;
    await loadPersons();
  }

  Future<void> deleteTree(String treeId) async {
    if (treeId == 'default') return;
    final db = await _database;
    // Find all person IDs belonging to this tree so we can delete their sources.
    final personMaps = await db.query('persons',
        columns: ['id'], where: 'treeId = ?', whereArgs: [treeId]);
    final personIds = personMaps.map((m) => m['id'] as String).toList();
    if (personIds.isNotEmpty) {
      final placeholders = personIds.map((_) => '?').join(',');
      await db.delete('sources',
          where: 'personId IN ($placeholders)', whereArgs: personIds);
      sources.removeWhere(
          (s) => personIds.contains(s.personId));
      await db.delete('life_events',
          where: 'personId IN ($placeholders)', whereArgs: personIds);
      lifeEvents.removeWhere((e) => personIds.contains(e.personId));
      await db.delete('medical_conditions',
          where: 'personId IN ($placeholders)', whereArgs: personIds);
      medicalConditions.removeWhere((mc) => personIds.contains(mc.personId));
    }
    await db.delete('trees', where: 'id = ?', whereArgs: [treeId]);
    await db.delete('persons', where: 'treeId = ?', whereArgs: [treeId]);
    await db.delete('partnerships',
        where: 'treeId = ?', whereArgs: [treeId]);
    await db.delete('research_tasks',
        where: 'treeId = ?', whereArgs: [treeId]);
    researchTasks.removeWhere((t) => t.treeId == treeId);
    trees.removeWhere((t) => t['id'] == treeId);
    if (currentTreeId == treeId) {
      currentTreeId = 'default';
    }
    await loadPersons();
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  static const _uuidLength = 36; // UUID v4 string length
  static const _sha256HexLength = 64; // SHA-256 hex digest length

  /// Generates a SHA-256 hash of [password] using [salt].
  static String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  Future<bool> register(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'user_$username';
    if (prefs.containsKey(key)) return false;
    final salt = _uuid.v4();
    final hash = _hashPassword(password, salt);
    await prefs.setString(key, '$salt:$hash');
    _currentUser = username;
    notifyListeners();
    return true;
  }

  Future<bool> login(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('user_$username');
    if (stored == null) return false;
    // Support both new hashed format (salt:hash) and legacy plaintext.
    final parts = stored.split(':');
    bool valid;
    if (parts.length == 2 &&
        parts[0].length == _uuidLength &&
        parts[1].length == _sha256HexLength) {
      // New format: salt (UUID) : SHA-256 hash
      final salt = parts[0];
      final hash = parts[1];
      valid = _hashPassword(password, salt) == hash;
    } else {
      // Legacy plaintext — migrate to hashed format on successful login.
      valid = stored == password;
      if (valid) {
        final salt = _uuid.v4();
        final hash = _hashPassword(password, salt);
        await prefs.setString('user_$username', '$salt:$hash');
      }
    }
    if (valid) {
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

  Future<void> setHomePersonId(String? id) async {
    _homePersonId = id?.isEmpty ?? true ? null : id;
    final prefs = await SharedPreferences.getInstance();
    if (_homePersonId == null) {
      await prefs.remove('homePersonId');
    } else {
      await prefs.setString('homePersonId', _homePersonId!);
    }
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
      try {
        await addPerson(person);
      } on StateError {
        // Free-tier person limit reached — stop importing and notify caller.
        throw StateError(
          'Import stopped: free tier limit of $freeMobilePersonLimit people '
          'reached after importing ${persons.length} people. '
          'Upgrade to add more.',
        );
      }
    }
    for (final partnership in result.partnerships) {
      partnership.treeId = currentTreeId;
      await addPartnership(partnership);
    }
    for (final event in result.lifeEvents) {
      // Only add if the person was successfully imported.
      if (persons.any((p) => p.id == event.personId)) {
        final treeEvent = LifeEvent(
          id: event.id,
          personId: event.personId,
          title: event.title,
          date: event.date,
          place: event.place,
          notes: event.notes,
          treeId: currentTreeId,
        );
        await addLifeEvent(treeEvent);
      }
    }
    for (final source in result.sources) {
      if (persons.any((p) => p.id == source.personId)) {
        source.treeId = currentTreeId;
        await addSource(source);
      }
    }
  }

  Future<void> exportGEDCOM(String path,
      {bool includeLivingData = false}) async {
    // Private persons are always excluded from GEDCOM exports.
    // Living persons (no death date) are exported as generic placeholders
    // unless [includeLivingData] is true.
    final publicPersons = persons.where((p) => !p.isPrivate).toList();
    final publicPersonIds = publicPersons.map((p) => p.id).toSet();
    final publicPartnerships = partnerships
        .where((pt) =>
            publicPersonIds.contains(pt.person1Id) &&
            publicPersonIds.contains(pt.person2Id))
        .toList();
    final parser = GEDCOMParser();
    await parser.export(publicPersons, publicPartnerships, path,
        includeLivingData: includeLivingData,
        lifeEvents: lifeEvents
            .where((e) => publicPersonIds.contains(e.personId))
            .toList());
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

  /// Updates an existing device record.  Used by [SyncService] to record the
  /// remote device's real UUID after the first successful pairing sync.
  Future<void> updateDevice(String oldId, Device updated) async {
    final db = await _database;
    await db.delete('devices', where: 'id = ?', whereArgs: [oldId]);
    await db.insert('devices', updated.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    final idx = pairedDevices.indexWhere((d) => d.id == oldId);
    if (idx != -1) pairedDevices[idx] = updated;
    notifyListeners();
  }

  // ── Sync ───────────────────────────────────────────────────────────────────

  /// Serialises the current tree (persons, partnerships, sources) into a plain
  /// Dart map suitable for encryption and transmission.
  Map<String, dynamic> exportForSync() {
    // Private persons are excluded from sync — their data stays strictly local.
    final publicPersons = persons.where((p) => !p.isPrivate).toList();
    final publicPersonIds = publicPersons.map((p) => p.id).toSet();
    return {
      'persons': publicPersons.map((p) => p.toMap()).toList(),
      'partnerships': partnerships
          .where((pt) =>
              publicPersonIds.contains(pt.person1Id) &&
              publicPersonIds.contains(pt.person2Id))
          .map((p) => p.toMap())
          .toList(),
      'sources': sources
          .where((s) => publicPersonIds.contains(s.personId))
          .map((s) => s.toMap())
          .toList(),
      'lifeEvents': lifeEvents
          .where((e) => publicPersonIds.contains(e.personId))
          .map((e) => e.toMap())
          .toList(),
    };
  }

  /// Merges incoming tree data from a peer using a **last-modified-wins**
  /// strategy: for each incoming record the local and incoming [updatedAt]
  /// timestamps are compared and the newer record is kept.  Records that lack
  /// a timestamp (legacy data) are treated as timestamp 0, so they never
  /// silently overwrite a locally edited record but are still accepted when
  /// the local copy is also unversioned.
  ///
  /// This enables true concurrent editing: a desktop user, a phone user, and
  /// a laptop user can all edit the same tree simultaneously and their changes
  /// will merge correctly on the next sync — rather than whoever syncs last
  /// winning at the whole-payload level.
  ///
  /// New records are always accepted (subject to the free-tier person cap).
  /// Returns the number of brand-new persons that were added.
  Future<int> importFromSync(Map<String, dynamic> data) async {
    final db = await _database;

    // Determine whether a per-session cap applies (Desktop Pro ← free mobile).
    final senderTier = data['senderTier'] as String?;
    final sessionCap =
        (currentAppTier == AppTier.desktopPro && senderTier == 'mobileFree')
            ? freeMobilePersonLimit
            : null;

    final inPersons =
        ((data['persons'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                [])
            .map(Person.fromMap)
            .toList();
    final inPartnerships =
        ((data['partnerships'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [])
            .map(Partnership.fromMap)
            .toList();
    final inSources =
        ((data['sources'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                [])
            .map(Source.fromMap)
            .toList();
    final inLifeEvents =
        ((data['lifeEvents'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                [])
            .map(LifeEvent.fromMap)
            .toList();

    int added = 0;

    // ── Persons ──────────────────────────────────────────────────────────────
    for (final person in inPersons) {
      final existing = persons.where((p) => p.id == person.id).firstOrNull;
      final isNew = existing == null;
      if (isNew) {
        if (isAtPersonLimit) continue;
        if (sessionCap != null && added >= sessionCap) continue;
      } else {
        // Concurrent merge: skip if local record is strictly newer.
        // Both timestamps default to 0 when absent, so two un-versioned
        // records are treated equally and the incoming one is accepted
        // (preserves pre-v8 last-write-wins behaviour for old data).
        final localTs = existing.updatedAt ?? 0;
        final incomingTs = person.updatedAt ?? 0;
        if (localTs > 0 && incomingTs <= localTs) continue;
      }
      person.treeId = currentTreeId;
      await db.insert('persons', person.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      if (isNew) added++;
    }

    // ── Partnerships ──────────────────────────────────────────────────────────
    for (final partnership in inPartnerships) {
      final existing =
          partnerships.where((p) => p.id == partnership.id).firstOrNull;
      if (existing != null) {
        final localTs = existing.updatedAt ?? 0;
        final incomingTs = partnership.updatedAt ?? 0;
        if (localTs > 0 && incomingTs <= localTs) continue;
      }
      partnership.treeId = currentTreeId;
      await db.insert('partnerships', partnership.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // ── Sources ───────────────────────────────────────────────────────────────
    for (final source in inSources) {
      final existing = sources.where((s) => s.id == source.id).firstOrNull;
      if (existing != null) {
        final localTs = existing.updatedAt ?? 0;
        final incomingTs = source.updatedAt ?? 0;
        if (localTs > 0 && incomingTs <= localTs) continue;
      }
      await db.insert('sources', source.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // ── Life Events ───────────────────────────────────────────────────────────
    for (final event in inLifeEvents) {
      final existing =
          lifeEvents.where((e) => e.id == event.id).firstOrNull;
      if (existing != null) {
        final localTs = existing.updatedAt ?? 0;
        final incomingTs = event.updatedAt ?? 0;
        if (localTs > 0 && incomingTs <= localTs) continue;
      }
      await db.insert('life_events', event.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await loadPersons();
    return added;
  }

  // ── Clear DB ───────────────────────────────────────────────────────────────
  Future<void> clearDatabase() async {
    final db = await _database;
    await db.delete('persons');
    await db.delete('sources');
    await db.delete('partnerships');
    await db.delete('life_events');
    await db.delete('medical_conditions');
    await db.delete('research_tasks');
    persons.clear();
    sources.clear();
    partnerships.clear();
    lifeEvents.clear();
    medicalConditions.clear();
    researchTasks.clear();
    notifyListeners();
  }

  // ── Backup & Restore ───────────────────────────────────────────────────────

  /// Exports the entire tree to a JSON string (for backup).
  Future<String> exportBackupJson() async {
    final personIds = persons.map((p) => p.id).toSet();
    final data = <String, dynamic>{
      'version': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'persons': persons.map((p) => p.toMap()).toList(),
      'partnerships': partnerships.map((p) => p.toMap()).toList(),
      'sources': sources
          .where((s) => personIds.contains(s.personId))
          .map((s) => s.toMap())
          .toList(),
      'lifeEvents': lifeEvents
          .where((e) => personIds.contains(e.personId))
          .map((e) => e.toMap())
          .toList(),
    };
    return jsonEncode(data);
  }

  /// Imports from a JSON backup string, replacing current tree data.
  Future<void> importBackupJson(String json) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final db = await _database;

    // Gather existing person IDs for this tree to delete related records.
    final personMaps = await db.query('persons',
        columns: ['id'], where: 'treeId = ?', whereArgs: [currentTreeId]);
    final existingIds = personMaps.map((m) => m['id'] as String).toList();

    if (existingIds.isNotEmpty) {
      final placeholders = existingIds.map((_) => '?').join(',');
      await db.delete('life_events',
          where: 'personId IN ($placeholders)', whereArgs: existingIds);
      await db.delete('sources',
          where: 'personId IN ($placeholders)', whereArgs: existingIds);
    }
    await db.delete('persons',
        where: 'treeId = ?', whereArgs: [currentTreeId]);
    await db.delete('partnerships',
        where: 'treeId = ?', whereArgs: [currentTreeId]);

    final inPersons =
        ((data['persons'] as List?)?.cast<Map<String, dynamic>>() ?? [])
            .map(Person.fromMap)
            .toList();
    final inPartnerships =
        ((data['partnerships'] as List?)?.cast<Map<String, dynamic>>() ?? [])
            .map(Partnership.fromMap)
            .toList();
    final inSources =
        ((data['sources'] as List?)?.cast<Map<String, dynamic>>() ?? [])
            .map(Source.fromMap)
            .toList();
    final inLifeEvents =
        ((data['lifeEvents'] as List?)?.cast<Map<String, dynamic>>() ?? [])
            .map(LifeEvent.fromMap)
            .toList();

    for (final person in inPersons) {
      person.treeId = currentTreeId;
      await db.insert('persons', person.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final partnership in inPartnerships) {
      partnership.treeId = currentTreeId;
      await db.insert('partnerships', partnership.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final source in inSources) {
      await db.insert('sources', source.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final event in inLifeEvents) {
      event.treeId = currentTreeId;
      await db.insert('life_events', event.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await loadPersons();
  }

  // ── Duplicate Detection ────────────────────────────────────────────────────

  /// Returns groups of persons that are likely duplicates.
  /// Groups by: same normalized name, or same first word + birth years within 2 years.
  List<List<Person>> findDuplicates() {
    final groups = <List<Person>>[];
    final processed = <String>{};

    String normalize(String name) =>
        name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9 ]'), '');

    for (int i = 0; i < persons.length; i++) {
      if (processed.contains(persons[i].id)) continue;
      final group = <Person>[persons[i]];
      final nameA = normalize(persons[i].name);
      final firstWordA =
          nameA.split(' ').where((w) => w.isNotEmpty).firstOrNull ?? '';
      final birthYearA = persons[i].birthDate?.year;

      for (int j = i + 1; j < persons.length; j++) {
        if (processed.contains(persons[j].id)) continue;
        final nameB = normalize(persons[j].name);
        final firstWordB =
            nameB.split(' ').where((w) => w.isNotEmpty).firstOrNull ?? '';
        final birthYearB = persons[j].birthDate?.year;

        final sameName = nameA == nameB;
        final sameFirstAndNearBirth = firstWordA.isNotEmpty &&
            firstWordA == firstWordB &&
            birthYearA != null &&
            birthYearB != null &&
            (birthYearA - birthYearB).abs() <= 2;

        if (sameName || sameFirstAndNearBirth) {
          group.add(persons[j]);
          processed.add(persons[j].id);
        }
      }

      if (group.length > 1) {
        processed.add(persons[i].id);
        groups.add(group);
      }
    }

    return groups;
  }

  /// Merges [mergeId] into [keepId]: references updated, fields copied, all
  /// associated records (sources, life events, partnerships) re-pointed to
  /// [keepId], then the now-empty duplicate is deleted.
  Future<void> mergePersons(String keepId, String mergeId) async {
    final keepIdx = persons.indexWhere((p) => p.id == keepId);
    final mergeIdx = persons.indexWhere((p) => p.id == mergeId);
    if (keepIdx == -1 || mergeIdx == -1) return;

    final keep = persons[keepIdx];
    final merge = persons[mergeIdx];
    final db = await _database;

    // Update all other persons that reference mergeId in parentIds / childIds.
    for (final p in persons) {
      if (p.id == keepId || p.id == mergeId) continue;
      bool changed = false;
      if (p.parentIds.contains(mergeId)) {
        p.parentIds.remove(mergeId);
        if (!p.parentIds.contains(keepId)) p.parentIds.add(keepId);
        changed = true;
      }
      if (p.childIds.contains(mergeId)) {
        p.childIds.remove(mergeId);
        if (!p.childIds.contains(keepId)) p.childIds.add(keepId);
        changed = true;
      }
      if (changed) {
        await db.update('persons', p.toMap(),
            where: 'id = ?', whereArgs: [p.id]);
      }
    }

    // Re-point sources from mergeId → keepId so they are preserved.
    for (final source in sources.where((s) => s.personId == mergeId).toList()) {
      source.personId = keepId;
      await db.update('sources', source.toMap(),
          where: 'id = ?', whereArgs: [source.id]);
    }

    // Re-point life events from mergeId → keepId.
    for (final event in lifeEvents.where((e) => e.personId == mergeId).toList()) {
      event.personId = keepId;
      await db.update('life_events', event.toMap(),
          where: 'id = ?', whereArgs: [event.id]);
    }

    // Re-point medical conditions from mergeId → keepId.
    for (final mc in medicalConditions.where((m) => m.personId == mergeId).toList()) {
      mc.personId = keepId;
      await db.update('medical_conditions', mc.toMap(),
          where: 'id = ?', whereArgs: [mc.id]);
    }

    // Re-point research tasks linked to mergeId → keepId.
    for (final task in researchTasks.where((t) => t.personId == mergeId).toList()) {
      task.personId = keepId;
      await db.update('research_tasks', task.toMap(),
          where: 'id = ?', whereArgs: [task.id]);
    }

    // Re-point partnerships: replace mergeId with keepId, but only when keep
    // is not already a partner in the same relationship (avoid duplicates).
    // Build a Set of partner IDs already linked to keepId for O(1) look-up.
    final keepPartnerIds = partnerships
        .where((p) => p.person1Id == keepId || p.person2Id == keepId)
        .map((p) => p.person1Id == keepId ? p.person2Id : p.person1Id)
        .toSet();
    for (final pt in partnerships
        .where((p) => p.person1Id == mergeId || p.person2Id == mergeId)
        .toList()) {
      final otherId =
          pt.person1Id == mergeId ? pt.person2Id : pt.person1Id;
      // Skip if the kept person already has a partnership with this person.
      if (keepPartnerIds.contains(otherId)) continue;
      if (pt.person1Id == mergeId) {
        pt.person1Id = keepId;
      } else {
        pt.person2Id = keepId;
      }
      await db.update('partnerships', pt.toMap(),
          where: 'id = ?', whereArgs: [pt.id]);
    }

    // Merge photo paths (dedup).
    for (final path in merge.photoPaths) {
      if (!keep.photoPaths.contains(path)) keep.photoPaths.add(path);
    }

    // Merge notes (append if different).
    if (merge.notes != null && merge.notes!.isNotEmpty) {
      if (keep.notes == null || keep.notes!.isEmpty) {
        keep.notes = merge.notes;
      } else if (keep.notes != merge.notes) {
        keep.notes = '${keep.notes}\n${merge.notes}';
      }
    }

    // Copy birth info if keep has none.
    if (keep.birthDate == null && merge.birthDate != null) {
      keep.birthDate = merge.birthDate;
      keep.birthPlace = merge.birthPlace;
    }

    await updatePerson(keep);
    // deletePerson(mergeId) will find no sources/events/partnerships left for
    // mergeId (all migrated above) and cleanly removes the person record.
    await deletePerson(mergeId);
  }
}
