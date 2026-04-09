import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/device.dart';
import '../models/person.dart';
import '../models/place.dart';
import '../models/source.dart';
import '../services/gedcom_parser.dart';

class TreeProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  List<Person> persons = [];
  List<Source> sources = [];
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

  // ── Places ─────────────────────────────────────────────────────────────────
  static final List<Place> places = [
    // Europe
    Place(
      name: 'Paris',
      modernCountry: 'France',
      state: 'Île-de-France',
      historicalContext: 'Capital of France; formerly a Roman settlement (Lutetia).',
      colonizer: 'Roman Empire, Franks',
      nativeTribes: 'Parisii (Gauls)',
      romanizedNative: 'Parisii',
      validFrom: DateTime.utc(-52, 1, 1),
    ),
    Place(
      name: 'London',
      modernCountry: 'United Kingdom',
      state: 'England',
      historicalContext: 'Capital of Great Britain; founded by Romans as Londinium.',
      colonizer: 'Roman Empire, Anglo-Saxons, Normans',
      nativeTribes: 'Celtic Britons',
      romanizedNative: 'Britanni',
      validFrom: DateTime.utc(43, 1, 1),
    ),
    Place(
      name: 'Berlin',
      modernCountry: 'Germany',
      state: 'Brandenburg',
      historicalContext: 'Prussian capital, later German Empire and reunified Germany.',
      colonizer: 'Holy Roman Empire, Prussia',
      nativeTribes: 'Germanic tribes (Slavic Hevelli)',
      romanizedNative: 'Hevelli',
      validFrom: DateTime.utc(1237, 1, 1),
    ),
    Place(
      name: 'Rome',
      modernCountry: 'Italy',
      state: 'Lazio',
      historicalContext: 'Centre of the Roman Empire; seat of the Catholic Church.',
      colonizer: 'Roman Republic/Empire',
      nativeTribes: 'Latins, Sabines, Etruscans',
      romanizedNative: 'Latini',
      validFrom: DateTime.utc(-753, 1, 1),
    ),
    Place(
      name: 'Moscow',
      modernCountry: 'Russia',
      state: 'Moscow Oblast',
      historicalContext: 'Capital of the Tsardom of Russia, Soviet Union, and Russian Federation.',
      colonizer: 'Mongol Empire (briefly)',
      nativeTribes: 'Eastern Slavs',
      romanizedNative: 'Moskva',
      validFrom: DateTime.utc(1147, 1, 1),
    ),
    Place(
      name: 'Madrid',
      modernCountry: 'Spain',
      state: 'Community of Madrid',
      historicalContext: 'Capital of the Spanish Empire; centre of colonial administration.',
      colonizer: 'Moorish Caliphate, Castile',
      nativeTribes: 'Carpetani (Iberian)',
      romanizedNative: 'Carpetani',
      validFrom: DateTime.utc(865, 1, 1),
    ),
    Place(
      name: 'Vienna',
      modernCountry: 'Austria',
      state: 'Vienna',
      historicalContext: 'Capital of the Habsburg / Austro-Hungarian Empire.',
      colonizer: 'Roman Empire, Habsburg Dynasty',
      nativeTribes: 'Celtic Boii',
      romanizedNative: 'Boii',
      validFrom: DateTime.utc(15, 1, 1),
    ),
    Place(
      name: 'Warsaw',
      modernCountry: 'Poland',
      state: 'Masovian Voivodeship',
      historicalContext: 'Capital of Poland; occupied by Prussia, Russia, and Nazi Germany.',
      colonizer: 'Prussia, Russia, Nazi Germany',
      nativeTribes: 'Mazovian Poles',
      romanizedNative: 'Mazovia',
      validFrom: DateTime.utc(1300, 1, 1),
    ),
    Place(
      name: 'Istanbul',
      modernCountry: 'Turkey',
      state: 'Istanbul Province',
      historicalContext: 'Constantinople – capital of Byzantine and Ottoman Empires.',
      colonizer: 'Roman/Byzantine Empire, Ottoman Empire',
      nativeTribes: 'Thracians',
      romanizedNative: 'Thraces',
      validFrom: DateTime.utc(330, 1, 1),
    ),
    Place(
      name: 'Belgrade',
      modernCountry: 'Serbia',
      state: 'Belgrade District',
      historicalContext: 'Capital of Serbia; formerly part of Ottoman Empire and Yugoslavia.',
      colonizer: 'Ottoman Empire, Austro-Hungarian Empire',
      nativeTribes: 'Scordisci (Celtic-Illyrian)',
      romanizedNative: 'Singidunum',
      validFrom: DateTime.utc(279, 1, 1),
    ),
    // Asia
    Place(
      name: 'Tokyo',
      modernCountry: 'Japan',
      state: 'Tokyo Metropolis',
      historicalContext: 'Imperial capital of Japan; formerly Edo under Tokugawa Shogunate.',
      colonizer: 'N/A',
      nativeTribes: 'Ainu (historical northern Japan)',
      romanizedNative: 'Ainu',
      validFrom: DateTime.utc(1603, 1, 1),
    ),
    Place(
      name: 'Delhi',
      modernCountry: 'India',
      state: 'Delhi',
      historicalContext: 'Capital of India; seat of the Mughal Empire and British Raj.',
      colonizer: 'Mughal Empire, British East India Company',
      nativeTribes: 'Indigenous North Indian peoples',
      romanizedNative: 'Dilli',
      validFrom: DateTime.utc(1000, 1, 1),
    ),
    Place(
      name: 'Beijing',
      modernCountry: 'China',
      state: 'Beijing Municipality',
      historicalContext: 'Capital of Imperial China under multiple dynasties.',
      colonizer: 'Mongol Yuan Dynasty, Manchu Qing Dynasty',
      nativeTribes: 'Han Chinese, Khitan',
      romanizedNative: 'Běijīng',
      validFrom: DateTime.utc(1045, 1, 1),
    ),
    Place(
      name: 'Mumbai',
      modernCountry: 'India',
      state: 'Maharashtra',
      historicalContext: 'Former Bombay; major port under Portuguese and British colonial rule.',
      colonizer: 'Portuguese Empire, British East India Company',
      nativeTribes: 'Koli fishermen, Aagri',
      romanizedNative: 'Mumbadevi',
      validFrom: DateTime.utc(1534, 1, 1),
    ),
    Place(
      name: 'Tehran',
      modernCountry: 'Iran',
      state: 'Tehran Province',
      historicalContext: 'Capital of Iran; seat of the Qajar and Pahlavi dynasties.',
      colonizer: 'N/A (briefly occupied by Soviets and British)',
      nativeTribes: 'Medes, Persians',
      romanizedNative: 'Tehrān',
      validFrom: DateTime.utc(1796, 1, 1),
    ),
    // Africa
    Place(
      name: 'Cairo',
      modernCountry: 'Egypt',
      state: 'Cairo Governorate',
      historicalContext: 'Near ancient Memphis; capital under Fatimid, Ottoman and modern rule.',
      colonizer: 'Ottoman Empire, British Empire',
      nativeTribes: 'Ancient Egyptians',
      romanizedNative: 'Al-Qāhira',
      validFrom: DateTime.utc(969, 1, 1),
    ),
    Place(
      name: 'Johannesburg',
      modernCountry: 'South Africa',
      state: 'Gauteng',
      historicalContext: 'Founded during the gold rush; shaped by apartheid policies.',
      colonizer: 'British Empire, Boer Republic',
      nativeTribes: 'Sotho-Tswana peoples',
      romanizedNative: 'eGoli',
      validFrom: DateTime.utc(1886, 1, 1),
    ),
    Place(
      name: 'Lagos',
      modernCountry: 'Nigeria',
      state: 'Lagos State',
      historicalContext: 'Major West African port; major centre of the Atlantic slave trade era.',
      colonizer: 'Portuguese, British Empire',
      nativeTribes: 'Awori Yoruba',
      romanizedNative: 'Eko',
      validFrom: DateTime.utc(1400, 1, 1),
    ),
    // Americas
    Place(
      name: 'New York',
      modernCountry: 'United States',
      state: 'New York',
      historicalContext: 'Formerly New Amsterdam (Dutch); became largest US city.',
      colonizer: 'Dutch West India Company, British Empire',
      nativeTribes: 'Lenape',
      romanizedNative: 'Mannahatta',
      validFrom: DateTime.utc(1626, 1, 1),
    ),
    Place(
      name: 'Mexico City',
      modernCountry: 'Mexico',
      state: 'Mexico City',
      historicalContext: 'Built on ruins of Aztec capital Tenochtitlan by Spanish conquistadors.',
      colonizer: 'Spanish Empire',
      nativeTribes: 'Mexica (Aztec)',
      romanizedNative: 'Tenochtitlan',
      validFrom: DateTime.utc(1325, 1, 1),
    ),
    Place(
      name: 'Buenos Aires',
      modernCountry: 'Argentina',
      state: 'Buenos Aires',
      historicalContext: 'Capital of Argentina; founded by Spanish colonists.',
      colonizer: 'Spanish Empire',
      nativeTribes: 'Querandí',
      romanizedNative: 'Querandí',
      validFrom: DateTime.utc(1536, 1, 1),
    ),
    Place(
      name: 'Rio de Janeiro',
      modernCountry: 'Brazil',
      state: 'Rio de Janeiro',
      historicalContext: 'Former capital of Brazil and the Portuguese Empire in the Americas.',
      colonizer: 'Portuguese Empire',
      nativeTribes: 'Tamoio (Tupi)',
      romanizedNative: 'Guanabara',
      validFrom: DateTime.utc(1565, 1, 1),
    ),
    Place(
      name: 'Lima',
      modernCountry: 'Peru',
      state: 'Lima Region',
      historicalContext: 'City of Kings; colonial capital of the Viceroyalty of Peru.',
      colonizer: 'Spanish Empire',
      nativeTribes: 'Ichma (Inca confederation)',
      romanizedNative: 'Limaq',
      validFrom: DateTime.utc(1535, 1, 1),
    ),
    // Oceania
    Place(
      name: 'Sydney',
      modernCountry: 'Australia',
      state: 'New South Wales',
      historicalContext: 'First British penal colony in Australia; site of Port Jackson.',
      colonizer: 'British Empire',
      nativeTribes: 'Eora Nation',
      romanizedNative: 'Cadi',
      validFrom: DateTime.utc(1788, 1, 1),
    ),
    Place(
      name: 'Saint Petersburg',
      modernCountry: 'Russia',
      state: 'Leningrad Oblast',
      historicalContext:
          'Founded by Peter the Great; renamed Petrograd (1914) then Leningrad (1924); reverted 1991.',
      colonizer: 'N/A',
      nativeTribes: 'Ingrian Finns',
      romanizedNative: 'Inkeri',
      validFrom: DateTime.utc(1703, 1, 1),
    ),
  ];

  // ── Database ───────────────────────────────────────────────────────────────
  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'vetviona.db');
    return openDatabase(
      path,
      version: 1,
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
            spouseId TEXT,
            photoPaths TEXT,
            sourceIds TEXT,
            marriageDate TEXT,
            marriagePlace TEXT,
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
            sharedSecret TEXT NOT NULL
          )
        ''');
        // Insert default tree
        await db.insert('trees', {'id': 'default', 'name': 'My Family Tree'});
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

    final deviceMaps = await db.query('devices');
    pairedDevices = deviceMaps.map(Device.fromMap).toList();

    final prefs = await SharedPreferences.getInstance();
    _dateFormat = prefs.getString('dateFormat') ?? 'dd MMM yyyy';
    colonizationLevel = prefs.getInt('colonizationLevel') ?? 0;

    notifyListeners();
  }

  // ── Persons ────────────────────────────────────────────────────────────────
  Future<void> addPerson(Person person) async {
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
    sources.removeWhere((s) => s.id == id);
    notifyListeners();
  }

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
    final imported = await parser.parse(path);
    for (final person in imported) {
      person.treeId = currentTreeId;
      await addPerson(person);
    }
  }

  Future<void> exportGEDCOM(String path) async {
    final parser = GEDCOMParser();
    await parser.export(persons, path);
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
        if (current.spouseId != null) current.spouseId!,
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
    await db.delete('devices');
    persons.clear();
    sources.clear();
    pairedDevices.clear();
    notifyListeners();
  }
}
