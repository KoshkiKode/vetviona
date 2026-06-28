import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/source.dart';

// ── Data models ──────────────────────────────────────────────────────────────

/// A single result from the Open Archives (openarch.nl) API.
class OpenArchivesRecord {
  /// Unique record identifier.
  final String recordId;

  /// Record type, e.g. "birth", "marriage", "death", "other".
  final String recordType;

  /// Date of the event.
  final String? eventDate;

  /// Place of the event.
  final String? eventPlace;

  /// Archive / source name.
  final String? archiveName;

  /// Full record URL on openarch.nl.
  final String recordUrl;

  /// Persons mentioned in this record.
  final List<OpenArchivesPerson> persons;

  /// Additional notes or remarks.
  final String? remarks;

  const OpenArchivesRecord({
    required this.recordId,
    required this.recordType,
    this.eventDate,
    this.eventPlace,
    this.archiveName,
    required this.recordUrl,
    this.persons = const [],
    this.remarks,
  });
}

/// A person mentioned in an Open Archives record.
class OpenArchivesPerson {
  final String? firstName;
  final String? prefix;     // Dutch "tussenvoegsel" (e.g. "van", "de")
  final String? lastName;
  final String? role;       // e.g. "child", "father", "mother", "groom", "bride"
  final String? birthDate;
  final String? birthPlace;
  final String? deathDate;
  final String? age;

  const OpenArchivesPerson({
    this.firstName,
    this.prefix,
    this.lastName,
    this.role,
    this.birthDate,
    this.birthPlace,
    this.deathDate,
    this.age,
  });

  String get fullName {
    final parts = <String>[];
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (prefix != null && prefix!.isNotEmpty) parts.add(prefix!);
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    return parts.join(' ');
  }
}

// ── Service ──────────────────────────────────────────────────────────────────

/// Integration with the **Open Archives** (openarch.nl) API.
///
/// Open Archives aggregates Dutch civil registration records (births,
/// marriages, deaths) from regional and municipal archives across the
/// Netherlands.  The API is **free** and requires **no API key** for
/// basic searches.
///
/// Reference: https://www.openarch.nl/api/docs/
class OpenArchivesService {
  OpenArchivesService._({http.Client? client})
      : _client = client ?? http.Client();

  static final OpenArchivesService instance = OpenArchivesService._();

  factory OpenArchivesService.withClient(http.Client client) =>
      OpenArchivesService._(client: client);

  final http.Client _client;

  static const _baseUrl = 'https://api.openarch.nl/1.0';

  /// Searches Open Archives for civil registration records.
  ///
  /// Parameters:
  /// - [name]: person name to search for (required)
  /// - [eventType]: filter by event type ("birth", "marriage", "death",
  ///   "other", or null for all)
  /// - [eventPlace]: filter by event place
  /// - [eventDateFrom] / [eventDateTo]: date range (YYYY format)
  /// - [page]: 1-based result page
  /// - [perPage]: results per page (default 20, max 100)
  ///
  /// Returns a list of [OpenArchivesRecord]s.
  Future<List<OpenArchivesRecord>> search({
    required String name,
    String? eventType,
    String? eventPlace,
    String? eventDateFrom,
    String? eventDateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final params = <String, String>{
        'name': name,
        'number_show': '$perPage',
        'start': '${(page - 1) * perPage}',
        'lang': 'en',
      };

      if (eventType != null && eventType.isNotEmpty) {
        params['eventtype'] = eventType;
      }
      if (eventPlace != null && eventPlace.isNotEmpty) {
        params['eventplace'] = eventPlace;
      }
      if (eventDateFrom != null && eventDateFrom.isNotEmpty) {
        params['date_from'] = eventDateFrom;
      }
      if (eventDateTo != null && eventDateTo.isNotEmpty) {
        params['date_to'] = eventDateTo;
      }

      final uri =
          Uri.parse('$_baseUrl/records/search.json')
              .replace(queryParameters: params);

      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body);

      // The API may return a list or a wrapper object.
      List<dynamic> records;
      if (json is List) {
        records = json;
      } else if (json is Map<String, dynamic>) {
        records = json['records'] as List<dynamic>? ??
            json['response'] as List<dynamic>? ??
            [];
      } else {
        return [];
      }

      return records
          .map((r) => _parseRecord(r as Map<String, dynamic>))
          .where((r) => r != null)
          .cast<OpenArchivesRecord>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Convenience: search for birth records.
  Future<List<OpenArchivesRecord>> searchBirths({
    required String name,
    String? place,
    String? yearFrom,
    String? yearTo,
  }) =>
      search(
        name: name,
        eventType: 'birth',
        eventPlace: place,
        eventDateFrom: yearFrom,
        eventDateTo: yearTo,
      );

  /// Convenience: search for marriage records.
  Future<List<OpenArchivesRecord>> searchMarriages({
    required String name,
    String? place,
    String? yearFrom,
    String? yearTo,
  }) =>
      search(
        name: name,
        eventType: 'marriage',
        eventPlace: place,
        eventDateFrom: yearFrom,
        eventDateTo: yearTo,
      );

  /// Convenience: search for death records.
  Future<List<OpenArchivesRecord>> searchDeaths({
    required String name,
    String? place,
    String? yearFrom,
    String? yearTo,
  }) =>
      search(
        name: name,
        eventType: 'death',
        eventPlace: place,
        eventDateFrom: yearFrom,
        eventDateTo: yearTo,
      );

  // ── Source builder ────────────────────────────────────────────────────────

  /// Creates a [Source] record from an Open Archives result.
  Source recordToSource(OpenArchivesRecord record, String personId) {
    final info = StringBuffer();
    info.writeln('Type: ${_capitalize(record.recordType)}');
    if (record.eventDate != null) info.writeln('Date: ${record.eventDate}');
    if (record.eventPlace != null) info.writeln('Place: ${record.eventPlace}');
    if (record.archiveName != null) {
      info.writeln('Archive: ${record.archiveName}');
    }
    if (record.persons.isNotEmpty) {
      info.writeln('---');
      for (final person in record.persons) {
        final role = person.role != null ? ' (${person.role})' : '';
        info.writeln('${person.fullName}$role');
        if (person.birthDate != null) {
          info.writeln('  Born: ${person.birthDate}');
        }
        if (person.age != null) info.writeln('  Age: ${person.age}');
      }
    }
    if (record.remarks != null && record.remarks!.isNotEmpty) {
      info.writeln('---');
      info.writeln(record.remarks);
    }

    final citedFacts = <String>[];
    switch (record.recordType.toLowerCase()) {
      case 'birth':
        citedFacts.addAll(['Birth Date', 'Birth Place']);
        break;
      case 'marriage':
        citedFacts.addAll(['Marriage Date', 'Marriage Place']);
        break;
      case 'death':
        citedFacts.addAll(['Death Date', 'Death Place']);
        break;
    }

    return Source(
      id: const Uuid().v4(),
      personId: personId,
      title:
          '${_capitalize(record.recordType)} record — ${record.eventPlace ?? "Netherlands"}',
      type: 'Government Record',
      url: record.recordUrl,
      author: record.archiveName ?? 'Dutch civil registration',
      publisher: 'Open Archives',
      repository: 'Open Archives (openarch.nl)',
      confidence: 'A',
      extractedInfo: info.toString().trim(),
      citedFacts: citedFacts,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  OpenArchivesRecord? _parseRecord(Map<String, dynamic> r) {
    try {
      final id = r['pid'] as String? ??
          r['id']?.toString() ??
          r['guid'] as String? ??
          '';

      final recordType = r['eventtype'] as String? ??
          r['event_type'] as String? ??
          'other';

      // Event date
      String? eventDate;
      final ed = r['eventdate'] ?? r['event_date'];
      if (ed is Map) {
        eventDate = ed['text'] as String? ?? ed['year']?.toString();
      } else if (ed is String) {
        eventDate = ed;
      }

      // Event place
      String? eventPlace;
      final ep = r['eventplace'] ?? r['event_place'];
      if (ep is Map) {
        eventPlace = ep['text'] as String? ?? ep['name'] as String?;
      } else if (ep is String) {
        eventPlace = ep;
      }

      // Archive
      final archiveName =
          r['archive'] as String? ?? r['sourcename'] as String?;

      // Persons
      final personsList = <OpenArchivesPerson>[];
      final rp = r['relations'] ?? r['persons'] ?? r['person'];
      if (rp is List) {
        for (final p in rp) {
          if (p is Map<String, dynamic>) {
            personsList.add(_parsePerson(p));
          }
        }
      } else if (rp is Map<String, dynamic>) {
        personsList.add(_parsePerson(rp));
      }

      // URL
      final url = r['url'] as String? ??
          r['permalink'] as String? ??
          'https://www.openarch.nl/show.php?archive=&identifier=$id';

      return OpenArchivesRecord(
        recordId: id,
        recordType: recordType,
        eventDate: eventDate,
        eventPlace: eventPlace,
        archiveName: archiveName,
        recordUrl: url,
        persons: personsList,
        remarks: r['remarks'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  OpenArchivesPerson _parsePerson(Map<String, dynamic> p) {
    return OpenArchivesPerson(
      firstName: p['firstname'] as String? ?? p['voornaam'] as String?,
      prefix: p['prefix'] as String? ?? p['tussenvoegsel'] as String?,
      lastName: p['lastname'] as String? ?? p['achternaam'] as String?,
      role: p['role'] as String? ?? p['relation_type'] as String?,
      birthDate: p['birthdate'] as String?,
      birthPlace: p['birthplace'] as String?,
      deathDate: p['deathdate'] as String?,
      age: p['age']?.toString(),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
