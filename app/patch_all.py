import re

# 1. Patch TreeProvider
path = '/Users/dylancmoore/vetviona/app/lib/providers/tree_provider.dart'
with open(path, 'r') as f: content = f.read()

content = content.replace("import '../models/medical_condition.dart';", "import '../models/medical_condition.dart';\nimport '../models/heritage.dart';\nimport '../models/memory.dart';\nimport '../models/record_hint.dart';")
content = content.replace("List<ResearchTask> researchTasks = [];", "List<ResearchTask> researchTasks = [];\n  List<Heritage> heritages = [];\n  List<Memory> memories = [];\n  List<RecordHint> recordHints = [];")
content = content.replace("researchTasks.clear();", "researchTasks.clear();\n    heritages.clear();\n    memories.clear();\n    recordHints.clear();")

tables = """
        await db.execute('''
          CREATE TABLE heritages (
            id TEXT PRIMARY KEY,
            personId TEXT NOT NULL,
            region TEXT NOT NULL,
            percentage REAL,
            dnaService TEXT,
            dnaResultsUrl TEXT,
            notes TEXT,
            treeId TEXT,
            updatedAt INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE memories (
            id TEXT PRIMARY KEY,
            personId TEXT NOT NULL,
            title TEXT NOT NULL,
            text TEXT NOT NULL,
            date TEXT,
            place TEXT,
            mediaUri TEXT,
            treeId TEXT,
            updatedAt INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE record_hints (
            id TEXT PRIMARY KEY,
            personId TEXT NOT NULL,
            apiSource TEXT NOT NULL,
            externalRecordId TEXT NOT NULL,
            title TEXT NOT NULL,
            summary TEXT,
            recordUrl TEXT NOT NULL,
            imageUrl TEXT,
            confidence REAL NOT NULL,
            status TEXT NOT NULL,
            treeId TEXT,
            discoveredAt INTEGER,
            resolvedAt INTEGER,
            updatedAt INTEGER
          )
        ''');
"""
content = content.replace("await db.insert('trees', {'id': 'default', 'name': 'My Family Tree'});", tables + "\n        await db.insert('trees', {'id': 'default', 'name': 'My Family Tree'});")

crud = """
  // ── Heritage ─────────────────────────────────────────────────────────────
  Future<void> addHeritage(Heritage heritage) async {
    heritage.id = heritage.id.isEmpty ? _uuid.v4() : heritage.id;
    final db = await _database;
    await db.insert('heritages', heritage.toMap());
    heritages.add(heritage);
    notifyListeners();
  }
  Future<void> updateHeritage(Heritage heritage) async {
    final db = await _database;
    await db.update('heritages', heritage.toMap(), where: 'id = ?', whereArgs: [heritage.id]);
    final idx = heritages.indexWhere((h) => h.id == heritage.id);
    if (idx != -1) heritages[idx] = heritage;
    notifyListeners();
  }
  Future<void> deleteHeritage(String id) async {
    final db = await _database;
    await db.delete('heritages', where: 'id = ?', whereArgs: [id]);
    heritages.removeWhere((h) => h.id == id);
    notifyListeners();
  }

  // ── Memories ─────────────────────────────────────────────────────────────
  Future<void> addMemory(Memory memory) async {
    memory.id = memory.id.isEmpty ? _uuid.v4() : memory.id;
    final db = await _database;
    await db.insert('memories', memory.toMap());
    memories.add(memory);
    notifyListeners();
  }
  Future<void> updateMemory(Memory memory) async {
    final db = await _database;
    await db.update('memories', memory.toMap(), where: 'id = ?', whereArgs: [memory.id]);
    final idx = memories.indexWhere((m) => m.id == memory.id);
    if (idx != -1) memories[idx] = memory;
    notifyListeners();
  }
  Future<void> deleteMemory(String id) async {
    final db = await _database;
    await db.delete('memories', where: 'id = ?', whereArgs: [id]);
    memories.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  // ── Record Hints ─────────────────────────────────────────────────────────────
  Future<void> addRecordHint(RecordHint hint) async {
    hint.id = hint.id.isEmpty ? _uuid.v4() : hint.id;
    final db = await _database;
    await db.insert('record_hints', hint.toMap());
    recordHints.add(hint);
    notifyListeners();
  }
  Future<void> updateRecordHint(RecordHint hint) async {
    final db = await _database;
    await db.update('record_hints', hint.toMap(), where: 'id = ?', whereArgs: [hint.id]);
    final idx = recordHints.indexWhere((h) => h.id == hint.id);
    if (idx != -1) recordHints[idx] = hint;
    notifyListeners();
  }
  Future<void> addSourceFromHint(RecordHint hint, Source source) async {
    await addSource(source);
    hint.status = 'accepted';
    await updateRecordHint(hint);
  }
"""
content = content.replace("}\n", crud + "\n}\n")

load_code = """
    final heritageMaps = await db.rawQuery('SELECT * FROM heritages');
    heritages = heritageMaps.map(Heritage.fromMap).toList();
    final memoryMaps = await db.rawQuery('SELECT * FROM memories');
    memories = memoryMaps.map(Memory.fromMap).toList();
    final hintMaps = await db.rawQuery('SELECT * FROM record_hints');
    recordHints = hintMaps.map(RecordHint.fromMap).toList();
"""
content = content.replace("step('Loading devices…', 0.92);", load_code + "\n    step('Loading devices…', 0.92);")
with open(path, 'w') as f: f.write(content)


# 2. Patch on_this_day_screen.dart
path = '/Users/dylancmoore/vetviona/app/lib/screens/on_this_day_screen.dart'
with open(path, 'r') as f: content = f.read()
content = content.replace("pt.marriageDate", "pt.startDate")
content = content.replace("pt.marriagePlace", "pt.startPlace")
content = content.replace("int.parse(pt.startDate.split(' ').last)", "int.parse(pt.startDate!.split(' ').last)")
with open(path, 'w') as f: f.write(content)


# 3. Patch record_search_screen.dart (unused args, dead code)
path = '/Users/dylancmoore/vetviona/app/lib/screens/record_search_screen.dart'
with open(path, 'r') as f: content = f.read()

# Fix the SearchResult class properties
content = content.replace("final FamilySearchRecord? _fsRecord;", "final dynamic fsRecord;")
content = content.replace("final ChroniclingAmericaResult? _caResult;", "final dynamic caResult;")
content = content.replace("final NaraCatalogResult? _naraResult;", "final dynamic naraResult;")
content = content.replace("final OpenArchivesRecord? _oaRecord;", "final dynamic oaRecord;")

content = content.replace("FamilySearchRecord? fsRecord,", "dynamic fsRecord,")
content = content.replace("ChroniclingAmericaResult? caResult,", "dynamic caResult,")
content = content.replace("NaraCatalogResult? naraResult,", "dynamic naraResult,")
content = content.replace("OpenArchivesRecord? oaRecord,", "dynamic oaRecord,")

content = content.replace("_fsRecord = fsRecord", "this.fsRecord = fsRecord")
content = content.replace("_caResult = caResult", "this.caResult = caResult")
content = content.replace("_naraResult = naraResult", "this.naraResult = naraResult")
content = content.replace("_oaRecord = oaRecord", "this.oaRecord = oaRecord")

content = content.replace("result._fsRecord", "result.fsRecord")
content = content.replace("result._caResult", "result.caResult")
content = content.replace("result._naraResult", "result.naraResult")
content = content.replace("result._oaRecord", "result.oaRecord")
with open(path, 'w') as f: f.write(content)

# 4. Patch record_hints_screen.dart
path = '/Users/dylancmoore/vetviona/app/lib/screens/record_hints_screen.dart'
with open(path, 'r') as f: content = f.read()
content = content.replace(
    "await provider.addSourceFromHint(hint);",
    "await provider.addSourceFromHint(hint, Source(id: '', personId: hint.personId, title: hint.title, type: 'Hint', url: hint.recordUrl));"
)
with open(path, 'w') as f: f.write(content)

# 5. Patch sources_page.dart
path = '/Users/dylancmoore/vetviona/app/lib/screens/sources_page.dart'
with open(path, 'r') as f: content = f.read()
content = content.replace("b.confidence.compareTo(a.confidence)", "(b.confidence ?? '').compareTo(a.confidence ?? '')")
content = content.replace("PersonDetailScreen()", "PersonDetailScreen(person: provider.persons.first)")
with open(path, 'w') as f: f.write(content)

# 6. Patch tree_screen.dart
path = '/Users/dylancmoore/vetviona/app/lib/screens/tree_screen.dart'
with open(path, 'r') as f: content = f.read()
content = content.replace("PersonDetailScreen()", "PersonDetailScreen(person: context.read<TreeProvider>().persons.firstWhere((p) => p.id == node.personId))")
with open(path, 'w') as f: f.write(content)

# 7. Patch wall_chart_screen.dart
path = '/Users/dylancmoore/vetviona/app/lib/screens/wall_chart_screen.dart'
with open(path, 'r') as f: content = f.read()
content = content.replace("import 'package:vector_math/vector_math_64.dart';", "import 'package:vector_math/vector_math_64.dart' hide Colors;")
with open(path, 'w') as f: f.write(content)

# 8. Patch record_hints_service.dart
path = '/Users/dylancmoore/vetviona/app/lib/services/record_hints_service.dart'
with open(path, 'r') as f: content = f.read()
content = content.replace("final results = await FamilySearchApiService.instance.searchPerson(", "final results = await FamilySearchApiService.instance.searchRecords(")
content = content.replace("givenName: firstName", "givenName: firstName")
content = content.replace("lastName: lastName", "surname: lastName")
content = content.replace("digitalObjectUrl: result.pageUrl", "recordUrl: result.pageUrl")
with open(path, 'w') as f: f.write(content)
