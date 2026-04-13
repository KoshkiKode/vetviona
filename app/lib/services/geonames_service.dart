import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/place.dart';

/// Lazy-loading service that queries the bundled GeoNames cities SQLite
/// database (32,444 cities with population > ~1,000, sourced from GeoNames.org
/// via the geonamescache data package).
///
/// The database is copied from app assets to a writable path on first use.
/// All subsequent queries hit the local copy directly.
///
/// This is entirely optional: if the asset is missing the service silently
/// returns an empty list, so the core compile-in places still work.
class GeonamesService {
  GeonamesService._();
  static final GeonamesService instance = GeonamesService._();

  static const String _assetPath = 'assets/geonames_cities.db';
  static const String _dbFileName = 'geonames_cities.db';
  static const int _maxResults = 60;

  Database? _db;
  bool _initialised = false;
  bool _unavailable = false;

  /// Initialise (copy asset → writable path) if not already done.
  /// Safe to call multiple times – idempotent.
  Future<void> init() async {
    if (_initialised || _unavailable) return;
    try {
      final dbsPath = await getDatabasesPath();
      final path = join(dbsPath, _dbFileName);

      if (!File(path).existsSync()) {
        final ByteData data = await rootBundle.load(_assetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(path).writeAsBytes(bytes, flush: true);
      }

      _db = await openDatabase(path, readOnly: true);
      _initialised = true;
    } catch (_) {
      _unavailable = true;
    }
  }

  /// Returns true once the database has been successfully opened.
  bool get isAvailable => _initialised && _db != null;

  /// Search for places matching [query] (name, country, or state).
  /// Returns up to [_maxResults] [Place] objects sorted by population desc.
  ///
  /// Uses FTS5 for prefix matching when available, falling back to LIKE.
  Future<List<Place>> search(String query, {DateTime? eventDate}) async {
    if (!_initialised) await init();
    if (!isAvailable || query.trim().isEmpty) return const [];

    final q = query.trim();

    List<Map<String, Object?>> rows;
    try {
      // FTS5 prefix search: "kent*" matches "Kent", "Kentucky", etc.
      final ftsQuery = q.split(RegExp(r'\s+')).map((t) => '$t*').join(' ');
      rows = await _db!.rawQuery(
        '''SELECT p.name, p.country, p.iso3, p.continent, p.state, p.population
           FROM places p
           JOIN places_fts f ON p.id = f.rowid
           WHERE places_fts MATCH ?
           ORDER BY p.population DESC
           LIMIT $_maxResults''',
        [ftsQuery],
      );
    } catch (_) {
      // Fall back to LIKE search if FTS fails
      try {
        rows = await _db!.rawQuery(
          '''SELECT name, country, iso3, continent, state, population
             FROM places
             WHERE name LIKE ? OR country LIKE ? OR state LIKE ?
             ORDER BY population DESC
             LIMIT $_maxResults''',
          ['%$q%', '%$q%', '%$q%'],
        );
      } catch (_) {
        return const [];
      }
    }

    return rows.map((r) {
      return Place(
        continent: (r['continent'] as String?) ?? '',
        name: (r['name'] as String?) ?? '',
        modernCountry: (r['country'] as String?) ?? '',
        iso3: (r['iso3'] as String?) ?? '',
        state: (r['state'] as String?) ?? '',
        historicalContext: 'City/town – GeoNames global database.',
      );
    }).toList();
  }

  /// Close the database (called on app dispose if needed).
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initialised = false;
  }
}
