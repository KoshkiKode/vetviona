import re

path = '/Users/dylancmoore/vetviona/app/lib/providers/tree_provider.dart'
with open(path, 'r') as f:
    content = f.read()

# Add imports
content = content.replace(
    "import '../models/medical_condition.dart';",
    "import '../models/medical_condition.dart';\nimport '../models/memory.dart';\nimport '../models/record_hint.dart';"
)

# Add State
content = content.replace(
    "List<ResearchTask> researchTasks = [];",
    "List<ResearchTask> researchTasks = [];\n  List<Memory> memories = [];\n  List<RecordHint> recordHints = [];"
)

# Update clearDatabase
content = content.replace(
    "researchTasks.clear();",
    "researchTasks.clear();\n    memories.clear();\n    recordHints.clear();"
)

# DB creation (add tables) - just add it right before the trees insert
tables = """
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
            sourceApi TEXT NOT NULL,
            title TEXT NOT NULL,
            collectionTitle TEXT,
            date TEXT,
            place TEXT,
            recordUrl TEXT,
            imageUrl TEXT,
            isPending INTEGER NOT NULL DEFAULT 1,
            relevanceScore REAL,
            treeId TEXT,
            updatedAt INTEGER
          )
        ''');
"""
content = content.replace(
    "await db.insert('trees', {'id': 'default', 'name': 'My Family Tree'});",
    f"{tables}\n        await db.insert('trees', {{'id': 'default', 'name': 'My Family Tree'}});"
)

# DB indexes
indexes = """
        await db.execute('CREATE INDEX idx_memories_personId ON memories(personId)');
        await db.execute('CREATE INDEX idx_hints_personId ON record_hints(personId)');
"""
content = content.replace(
    "await db.execute(\n            'CREATE INDEX idx_tasks_personId ON research_tasks(personId)');",
    "await db.execute(\n            'CREATE INDEX idx_tasks_personId ON research_tasks(personId)');\n" + indexes
)

# Add CRUD operations at the end of the class
crud = """
  // ── Memories ───────────────────────────────────────────────────────────────
  Future<void> addMemory(Memory memory) async {
    memory.id = memory.id.isEmpty ? _uuid.v4() : memory.id;
    memory.treeId = currentTreeId;
    memory.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.insert('memories', memory.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    memories.add(memory);
    _emitDelta(persons: []); // Hack to trigger sync for now
    notifyListeners();
  }

  Future<void> updateMemory(Memory memory) async {
    memory.treeId ??= currentTreeId;
    memory.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.update('memories', memory.toMap(),
        where: 'id = ?', whereArgs: [memory.id]);
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

  // ── Record Hints ───────────────────────────────────────────────────────────
  Future<void> addRecordHint(RecordHint hint) async {
    hint.id = hint.id.isEmpty ? _uuid.v4() : hint.id;
    hint.treeId = currentTreeId;
    hint.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.insert('record_hints', hint.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    recordHints.add(hint);
    notifyListeners();
  }

  Future<void> updateRecordHint(RecordHint hint) async {
    hint.treeId ??= currentTreeId;
    hint.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.update('record_hints', hint.toMap(),
        where: 'id = ?', whereArgs: [hint.id]);
    final idx = recordHints.indexWhere((h) => h.id == hint.id);
    if (idx != -1) recordHints[idx] = hint;
    notifyListeners();
  }

  Future<void> addSourceFromHint(RecordHint hint, Source source) async {
    await addSource(source);
    hint.isPending = false;
    await updateRecordHint(hint);
  }
"""

content = content.replace("}\n", f"{crud}\n}}\n")

# Modify loadPersons to also load memories and recordHints
load_code = """
    step('Loading memories & hints...', 0.88);
    final memoryMaps = await db.rawQuery(
      'SELECT m.* FROM memories m INNER JOIN persons p ON m.personId = p.id WHERE p.treeId = ?',
      [currentTreeId],
    );
    memories = memoryMaps.map(Memory.fromMap).toList();

    final hintMaps = await db.rawQuery(
      'SELECT h.* FROM record_hints h INNER JOIN persons p ON h.personId = p.id WHERE p.treeId = ?',
      [currentTreeId],
    );
    recordHints = hintMaps.map(RecordHint.fromMap).toList();
"""

content = content.replace("step('Loading devices…', 0.92);", f"{load_code}\n    step('Loading devices…', 0.92);")

with open(path, 'w') as f:
    f.write(content)
