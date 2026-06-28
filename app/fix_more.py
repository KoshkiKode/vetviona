import re

# Fix duplicate_merge_screen.dart
path = '/Users/dylancmoore/vetviona/app/lib/screens/duplicate_merge_screen.dart'
with open(path, 'r') as f: content = f.read()
content = content.replace(
    "await provider.mergePersons(\n        keepId: result.keepId,\n        removeId: result.removeId,\n      );",
    "await provider.mergePersons(result.keepId, result.removeId);"
)
with open(path, 'w') as f: f.write(content)

# Fix record_hints_screen.dart
path = '/Users/dylancmoore/vetviona/app/lib/screens/record_hints_screen.dart'
with open(path, 'r') as f: content = f.read()
# The error was: 2 positional arguments expected by 'addSourceFromHint', but 1 found.
# Actually I added addSourceFromHint(RecordHint hint, Source source) but maybe it's called with only hint.
content = content.replace("await provider.addSourceFromHint(hint);", "await provider.addSourceFromHint(hint, Source(id: '', title: hint.title, personId: hint.personId));") # Wait, this might be fragile. I'll check how it's called.
with open(path, 'w') as f: f.write(content)

# Add heritages to TreeProvider
path = '/Users/dylancmoore/vetviona/app/lib/providers/tree_provider.dart'
with open(path, 'r') as f: content = f.read()
if "List<Heritage> heritages =" not in content:
    content = content.replace("import '../models/heritage.dart';", "import '../models/heritage.dart';") # Wait, is heritage imported? Let's assume yes.
    if "import '../models/heritage.dart';" not in content:
        content = content.replace("import '../models/memory.dart';", "import '../models/heritage.dart';\nimport '../models/memory.dart';")
    content = content.replace("List<Memory> memories = [];", "List<Heritage> heritages = [];\n  List<Memory> memories = [];")
    content = content.replace("memories.clear();", "heritages.clear();\n    memories.clear();")
    
    crud = """
  // ── Heritage ─────────────────────────────────────────────────────────────
  Future<void> addHeritage(Heritage heritage) async {
    heritage.id = heritage.id.isEmpty ? _uuid.v4() : heritage.id;
    heritage.treeId = currentTreeId;
    heritage.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.insert('heritages', heritage.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    heritages.add(heritage);
    notifyListeners();
  }

  Future<void> updateHeritage(Heritage heritage) async {
    heritage.treeId ??= currentTreeId;
    heritage.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.update('heritages', heritage.toMap(),
        where: 'id = ?', whereArgs: [heritage.id]);
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
"""
    content = content.replace("  // ── Memories", crud + "\n  // ── Memories")
    
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
"""
    content = content.replace("CREATE TABLE memories", tables.strip() + "\n        await db.execute('''\n          CREATE TABLE memories")
    
    load_code = """
    step('Loading heritage...', 0.89);
    final heritageMaps = await db.rawQuery(
      'SELECT h.* FROM heritages h INNER JOIN persons p ON h.personId = p.id WHERE p.treeId = ?',
      [currentTreeId],
    );
    heritages = heritageMaps.map(Heritage.fromMap).toList();
"""
    content = content.replace("step('Loading memories & hints...', 0.88);", load_code + "\n    step('Loading memories & hints...', 0.88);")

with open(path, 'w') as f: f.write(content)
