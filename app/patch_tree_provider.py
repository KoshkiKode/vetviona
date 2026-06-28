path = 'lib/providers/tree_provider.dart'
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
    // Use copyWith to update the status since fields are final
    final updatedHint = hint.copyWith(status: 'accepted');
    await updateRecordHint(updatedHint);
  }
"""

if crud not in content:
    # Append safely to the end before the last closing brace
    last_brace_index = content.rfind('}')
    content = content[:last_brace_index] + crud + "\n" + content[last_brace_index:]

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
