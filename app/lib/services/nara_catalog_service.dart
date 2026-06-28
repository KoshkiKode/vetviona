import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/source.dart';

// ── Data models ──────────────────────────────────────────────────────────────

/// A single result from the NARA Catalog API.
class NaraCatalogResult {
  /// NARA internal identifier.
  final String naId;

  /// Record title.
  final String title;

  /// Creator / originating agency.
  final String? creator;

  /// Date range as free text (e.g. "1917 - 1919").
  final String? dateRange;

  /// Series / record group description.
  final String? series;

  /// Human-readable URL to the NARA catalog page.
  final String catalogUrl;

  /// URL to a digital object (image/PDF) if one exists.
  final String? digitalObjectUrl;

  /// General Records Type (e.g. "Textual Records", "Photographs").
  final String? generalRecordsType;

  /// Scope and content note.
  final String? scopeNote;

  const NaraCatalogResult({
    required this.naId,
    required this.title,
    this.creator,
    this.dateRange,
    this.series,
    required this.catalogUrl,
    this.digitalObjectUrl,
    this.generalRecordsType,
    this.scopeNote,
  });
}

// ── Service ──────────────────────────────────────────────────────────────────

/// Integration with the **National Archives and Records Administration (NARA)**
/// Catalog API.
///
/// Provides search access to millions of US federal records — military service,
/// immigration / naturalisation, census indexes, land records, pension files,
/// and more.
///
/// The API is **completely free** and requires **no API key**.
///
/// Reference: https://www.archives.gov/developer
class NaraCatalogService {
  NaraCatalogService._({http.Client? client})
      : _client = client ?? http.Client();

  static final NaraCatalogService instance = NaraCatalogService._();

  factory NaraCatalogService.withClient(http.Client client) =>
      NaraCatalogService._(client: client);

  final http.Client _client;

  static const _baseUrl = 'https://catalog.archives.gov/api/v2';

  /// Searches the NARA catalog for records matching [query].
  ///
  /// Optional filters:
  /// - [dateStart] / [dateEnd]: limit by date range (free text, e.g. "1850")
  /// - [recordType]: filter by record type (e.g. "item", "series",
  ///   "fileUnit", "recordGroup")
  /// - [limit]: results per page (max 100, default 20)
  /// - [offset]: pagination offset
  ///
  /// Returns a list of [NaraCatalogResult]s, or empty on error.
  Future<List<NaraCatalogResult>> search({
    required String query,
    String? dateStart,
    String? dateEnd,
    String? recordType,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final params = <String, String>{
        'q': query,
        'limit': '$limit',
        'offset': '$offset',
      };

      if (dateStart != null && dateStart.isNotEmpty) {
        params['date.start'] = dateStart;
      }
      if (dateEnd != null && dateEnd.isNotEmpty) {
        params['date.end'] = dateEnd;
      }
      if (recordType != null && recordType.isNotEmpty) {
        params['level'] = recordType;
      }

      final uri =
          Uri.parse('$_baseUrl/records').replace(queryParameters: params);

      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final body = json['body'] as Map<String, dynamic>? ?? {};
      final hits = body['hits'] as Map<String, dynamic>? ?? {};
      final results = hits['hits'] as List<dynamic>? ?? [];

      return results.map((hit) => _parseHit(hit as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches a single record by its NARA ID.
  Future<NaraCatalogResult?> getRecord(String naId) async {
    try {
      final uri = Uri.parse('$_baseUrl/records/$naId');

      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final body = json['body'] as Map<String, dynamic>? ?? {};
      return _parseRecord(body, naId);
    } catch (_) {
      return null;
    }
  }

  /// Searches specifically for military records.
  Future<List<NaraCatalogResult>> searchMilitary({
    required String query,
    String? dateStart,
    String? dateEnd,
    int limit = 20,
  }) async {
    // Add "military" context to the query for more relevant results
    final militaryQuery = '$query military service';
    return search(
      query: militaryQuery,
      dateStart: dateStart,
      dateEnd: dateEnd,
      limit: limit,
    );
  }

  /// Searches specifically for immigration and naturalisation records.
  Future<List<NaraCatalogResult>> searchImmigration({
    required String query,
    String? dateStart,
    String? dateEnd,
    int limit = 20,
  }) async {
    final immigrationQuery = '$query immigration naturaliz';
    return search(
      query: immigrationQuery,
      dateStart: dateStart,
      dateEnd: dateEnd,
      limit: limit,
    );
  }

  /// Searches specifically for census records.
  Future<List<NaraCatalogResult>> searchCensus({
    required String query,
    String? year,
    int limit = 20,
  }) async {
    final censusQuery = '$query census';
    return search(
      query: censusQuery,
      dateStart: year,
      dateEnd: year,
      limit: limit,
    );
  }

  // ── Source builder ────────────────────────────────────────────────────────

  /// Creates a [Source] record from a NARA catalog result.
  Source resultToSource(NaraCatalogResult result, String personId) {
    final info = StringBuffer();
    if (result.creator != null) info.writeln('Creator: ${result.creator}');
    if (result.dateRange != null) info.writeln('Date: ${result.dateRange}');
    if (result.series != null) info.writeln('Series: ${result.series}');
    if (result.generalRecordsType != null) {
      info.writeln('Type: ${result.generalRecordsType}');
    }
    if (result.scopeNote != null && result.scopeNote!.isNotEmpty) {
      info.writeln('---');
      info.writeln(result.scopeNote!.length > 500
          ? '${result.scopeNote!.substring(0, 497)}…'
          : result.scopeNote);
    }
    info.writeln('NARA ID: ${result.naId}');

    return Source(
      id: const Uuid().v4(),
      personId: personId,
      title: result.title,
      type: 'Government Record',
      url: result.catalogUrl,
      author: result.creator ?? 'National Archives',
      publisher: 'National Archives and Records Administration',
      repository: 'NARA Catalog (catalog.archives.gov)',
      confidence: 'A',
      extractedInfo: info.toString().trim(),
      citedFacts: const [],
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  NaraCatalogResult _parseHit(Map<String, dynamic> hit) {
    final source = hit['_source'] as Map<String, dynamic>? ?? {};
    final naId = source['naId']?.toString() ?? hit['_id']?.toString() ?? '';
    final title = source['title'] as String? ?? 'Untitled Record';

    // Creator
    String? creator;
    final creators = source['creators'] as List<dynamic>?;
    if (creators != null && creators.isNotEmpty) {
      final first = creators.first;
      if (first is Map) {
        creator = first['heading'] as String? ?? first['name'] as String?;
      } else if (first is String) {
        creator = first;
      }
    }

    // Date range
    String? dateRange;
    final dates = source['dates'] as List<dynamic>?;
    if (dates != null && dates.isNotEmpty) {
      final first = dates.first;
      if (first is Map) {
        dateRange = first['qualifiedDateRange'] as String? ??
            first['dateQualifier'] as String?;
      }
    }
    dateRange ??= source['date'] as String?;

    // Series
    String? series;
    final parentSeries = source['parentSeries'] as Map<String, dynamic>?;
    if (parentSeries != null) {
      series = parentSeries['title'] as String?;
    }

    // Digital objects
    String? digitalObjectUrl;
    final objects = source['digitalObjects'] as List<dynamic>?;
    if (objects != null && objects.isNotEmpty) {
      final first = objects.first as Map<String, dynamic>?;
      digitalObjectUrl = first?['objectUrl'] as String? ??
          first?['thumbnailUrl'] as String?;
    }

    // General records type
    final generalRecordsType =
        source['generalRecordsTypes'] as String? ??
        (source['generalRecordsTypes'] is List
            ? (source['generalRecordsTypes'] as List).join(', ')
            : null);

    // Scope note
    final scopeNote = source['scopeAndContentNote'] as String?;

    return NaraCatalogResult(
      naId: naId,
      title: title,
      creator: creator,
      dateRange: dateRange,
      series: series,
      catalogUrl: 'https://catalog.archives.gov/id/$naId',
      digitalObjectUrl: digitalObjectUrl,
      generalRecordsType: generalRecordsType,
      scopeNote: scopeNote,
    );
  }

  NaraCatalogResult _parseRecord(Map<String, dynamic> body, String naId) {
    final record = body['record'] as Map<String, dynamic>? ?? body;
    return _parseHit({'_source': record, '_id': naId});
  }
}
