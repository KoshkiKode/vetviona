import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/source.dart';

// ── Data models ──────────────────────────────────────────────────────────────

/// A historical record returned from the FamilySearch API.
class FamilySearchRecord {
  final String recordId;
  final String title;
  final String? collectionTitle;
  final String? recordType; // "Birth", "Death", "Marriage", "Census", etc.
  final String? eventDate;
  final String? eventPlace;
  final String? personName;
  final String? fatherName;
  final String? motherName;
  final String? spouseName;
  final String? gender;
  final String? age;
  final String recordUrl;
  final String? imageUrl;
  final Map<String, String> fields; // all extracted key-value fields

  const FamilySearchRecord({
    required this.recordId,
    required this.title,
    this.collectionTitle,
    this.recordType,
    this.eventDate,
    this.eventPlace,
    this.personName,
    this.fatherName,
    this.motherName,
    this.spouseName,
    this.gender,
    this.age,
    required this.recordUrl,
    this.imageUrl,
    this.fields = const {},
  });
}

/// A person from the FamilySearch Family Tree.
class FamilySearchTreePerson {
  final String personId; // e.g. "KW7S-BBQ"
  final String? displayName;
  final String? givenName;
  final String? surname;
  final String? gender;
  final String? birthDate;
  final String? birthPlace;
  final String? deathDate;
  final String? deathPlace;
  final bool living;
  final String profileUrl;

  const FamilySearchTreePerson({
    required this.personId,
    this.displayName,
    this.givenName,
    this.surname,
    this.gender,
    this.birthDate,
    this.birthPlace,
    this.deathDate,
    this.deathPlace,
    this.living = false,
    required this.profileUrl,
  });
}

// ── Service ──────────────────────────────────────────────────────────────────

/// Full FamilySearch API integration.
///
/// The FamilySearch API (https://www.familysearch.org/developers/) provides:
/// - Historical record search across billions of indexed records
/// - Family Tree person search
/// - Record hints / auto-matching
///
/// **Authentication**: FamilySearch uses OAuth 2.0 with PKCE.  This service
/// scaffolds the auth flow — you need a registered app key from
/// https://www.familysearch.org/developers/  to complete it.
///
/// While unauthenticated, the service still provides:
/// - Direct URL construction for known person IDs
/// - Source record creation helpers
/// - Record search via the public search endpoint
class FamilySearchApiService extends ChangeNotifier {
  FamilySearchApiService._({http.Client? client})
      : _client = client ?? http.Client();

  static final FamilySearchApiService instance = FamilySearchApiService._();

  factory FamilySearchApiService.withClient(http.Client client) =>
      FamilySearchApiService._(client: client);

  final http.Client _client;
  final _secureStorage = const FlutterSecureStorage();

  // ── Configuration ─────────────────────────────────────────────────────────
  // Register at https://www.familysearch.org/developers/ to obtain these.
  // Set via environment or configure in settings.

  static const _prodBaseUrl = 'https://api.familysearch.org';
  static const _sandboxBaseUrl = 'https://sandbox.familysearch.org';

  String? _appKey;
  String? _accessToken;
  bool _useSandbox = true;
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;
  String get _baseUrl => _useSandbox ? _sandboxBaseUrl : _prodBaseUrl;

  // ── Auth management ───────────────────────────────────────────────────────

  /// Loads saved credentials from secure storage.
  Future<void> loadCredentials() async {
    try {
      _appKey = await _secureStorage.read(key: 'fs_app_key');
      _accessToken = await _secureStorage.read(key: 'fs_access_token');
      final sandbox = await _secureStorage.read(key: 'fs_use_sandbox');
      _useSandbox = sandbox != 'false';
      _isAuthenticated = _accessToken != null && _accessToken!.isNotEmpty;
      notifyListeners();
    } catch (_) {}
  }

  /// Saves the app key for future sessions.
  Future<void> setAppKey(String appKey) async {
    _appKey = appKey;
    await _secureStorage.write(key: 'fs_app_key', value: appKey);
    notifyListeners();
  }

  /// Sets whether to use the sandbox or production API.
  Future<void> setSandboxMode(bool sandbox) async {
    _useSandbox = sandbox;
    await _secureStorage.write(
        key: 'fs_use_sandbox', value: sandbox.toString());
    notifyListeners();
  }

  /// Saves an OAuth access token obtained through the browser auth flow.
  Future<void> setAccessToken(String token) async {
    _accessToken = token;
    _isAuthenticated = true;
    await _secureStorage.write(key: 'fs_access_token', value: token);
    notifyListeners();
  }

  /// Clears saved credentials and logs out.
  Future<void> logout() async {
    _accessToken = null;
    _isAuthenticated = false;
    await _secureStorage.delete(key: 'fs_access_token');
    notifyListeners();
  }

  /// Returns the OAuth authorisation URL to open in a browser.
  ///
  /// The user completes login in the browser, and the redirect brings back
  /// an authorization code that can be exchanged for an access token.
  String getAuthUrl({required String redirectUri}) {
    final params = {
      'response_type': 'code',
      'client_id': _appKey ?? '',
      'redirect_uri': redirectUri,
    };
    return Uri.parse('$_baseUrl/cis-web/oauth2/v3/authorization')
        .replace(queryParameters: params)
        .toString();
  }

  /// Exchanges an authorization code for an access token.
  Future<bool> exchangeCodeForToken({
    required String code,
    required String redirectUri,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/cis-web/oauth2/v3/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'client_id': _appKey ?? '',
          'redirect_uri': redirectUri,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final token = json['access_token'] as String?;
        if (token != null) {
          await setAccessToken(token);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> get _authHeaders => {
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        if (_appKey != null && _accessToken == null)
          'Authorization': 'Bearer $_appKey',
      };

  // ── Record search ─────────────────────────────────────────────────────────

  /// Searches FamilySearch historical records.
  ///
  /// This uses the records search endpoint which is available with or without
  /// authentication (authenticated users get more results).
  Future<List<FamilySearchRecord>> searchRecords({
    String? givenName,
    String? surname,
    String? birthDate,
    String? birthPlace,
    String? deathDate,
    String? deathPlace,
    String? marriageDate,
    String? marriagePlace,
    String? fatherName,
    String? motherName,
    String? spouseName,
    int count = 20,
    int offset = 0,
  }) async {
    try {
      final params = <String, String>{
        'count': '$count',
        'offset': '$offset',
      };

      if (givenName != null) params['q.givenName'] = givenName;
      if (surname != null) params['q.surname'] = surname;
      if (birthDate != null) params['q.birthLikeDate'] = birthDate;
      if (birthPlace != null) params['q.birthLikePlace'] = birthPlace;
      if (deathDate != null) params['q.deathLikeDate'] = deathDate;
      if (deathPlace != null) params['q.deathLikePlace'] = deathPlace;
      if (marriageDate != null) params['q.marriageLikeDate'] = marriageDate;
      if (marriagePlace != null) params['q.marriageLikePlace'] = marriagePlace;
      if (fatherName != null) params['q.fatherGivenName'] = fatherName;
      if (motherName != null) params['q.motherGivenName'] = motherName;
      if (spouseName != null) params['q.spouseGivenName'] = spouseName;

      final uri = Uri.parse(
              '$_baseUrl/platform/records/search')
          .replace(queryParameters: params);

      final response = await _client
          .get(uri, headers: _authHeaders)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final entries = json['entries'] as List<dynamic>? ?? [];

      return entries.map((e) {
        final entry = e as Map<String, dynamic>;
        return _parseRecordEntry(entry);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Searches the FamilySearch Family Tree for persons.
  Future<List<FamilySearchTreePerson>> searchPersons({
    String? givenName,
    String? surname,
    String? birthDate,
    String? birthPlace,
    String? deathDate,
    String? deathPlace,
    int count = 20,
  }) async {
    if (!_isAuthenticated) return [];
    try {
      final params = <String, String>{
        'count': '$count',
      };
      if (givenName != null) params['q.givenName'] = givenName;
      if (surname != null) params['q.surname'] = surname;
      if (birthDate != null) params['q.birthLikeDate'] = birthDate;
      if (birthPlace != null) params['q.birthLikePlace'] = birthPlace;
      if (deathDate != null) params['q.deathLikeDate'] = deathDate;
      if (deathPlace != null) params['q.deathLikePlace'] = deathPlace;

      final uri = Uri.parse('$_baseUrl/platform/tree/search')
          .replace(queryParameters: params);

      final response = await _client
          .get(uri, headers: _authHeaders)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final entries = json['entries'] as List<dynamic>? ?? [];

      return entries
          .map((e) => _parseTreePersonEntry(e as Map<String, dynamic>))
          .where((p) => p != null)
          .cast<FamilySearchTreePerson>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches record hints for a FamilySearch person ID.
  ///
  /// Requires authentication. Returns matching historical records that
  /// FamilySearch has auto-matched to this person.
  Future<List<FamilySearchRecord>> getRecordHints(String personId) async {
    if (!_isAuthenticated) return [];
    try {
      final uri =
          Uri.parse('$_baseUrl/platform/tree/persons/$personId/matches');

      final response = await _client
          .get(uri, headers: _authHeaders)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final entries = json['entries'] as List<dynamic>? ?? [];

      return entries
          .map((e) => _parseRecordEntry(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── URL helpers ───────────────────────────────────────────────────────────

  /// Canonical FamilySearch person URL for a given person ID.
  String personUrl(String personId) =>
      'https://www.familysearch.org/tree/person/details/$personId';

  /// Canonical FamilySearch record URL for a given record ID (ark).
  String recordUrl(String recordId) =>
      'https://www.familysearch.org/ark:/$recordId';

  // ── Source builder ────────────────────────────────────────────────────────

  /// Creates a [Source] from a FamilySearch historical record.
  Source recordToSource(FamilySearchRecord record, String personId) {
    final info = StringBuffer();
    if (record.collectionTitle != null) {
      info.writeln('Collection: ${record.collectionTitle}');
    }
    if (record.recordType != null) {
      info.writeln('Record Type: ${record.recordType}');
    }
    if (record.eventDate != null) info.writeln('Date: ${record.eventDate}');
    if (record.eventPlace != null) info.writeln('Place: ${record.eventPlace}');
    if (record.personName != null) info.writeln('Name: ${record.personName}');
    if (record.fatherName != null) {
      info.writeln('Father: ${record.fatherName}');
    }
    if (record.motherName != null) {
      info.writeln('Mother: ${record.motherName}');
    }
    if (record.spouseName != null) {
      info.writeln('Spouse: ${record.spouseName}');
    }
    if (record.gender != null) info.writeln('Gender: ${record.gender}');
    if (record.age != null) info.writeln('Age: ${record.age}');

    // Add any extra fields not already listed
    for (final entry in record.fields.entries) {
      if (!info.toString().contains(entry.key)) {
        info.writeln('${entry.key}: ${entry.value}');
      }
    }

    final citedFacts = <String>[];
    final type = record.recordType?.toLowerCase() ?? '';
    if (type.contains('birth')) {
      citedFacts.addAll(['Birth Date', 'Birth Place']);
    }
    if (type.contains('death')) {
      citedFacts.addAll(['Death Date', 'Death Place']);
    }
    if (type.contains('marriage')) {
      citedFacts.addAll(['Marriage Date', 'Marriage Place']);
    }
    if (type.contains('census') || type.contains('residence')) {
      citedFacts.add('Name');
    }

    return Source(
      id: const Uuid().v4(),
      personId: personId,
      title: record.title,
      type: 'Online Database',
      url: record.recordUrl,
      author: 'FamilySearch contributors',
      publisher: record.collectionTitle ?? 'FamilySearch',
      repository: 'FamilySearch (familysearch.org)',
      confidence: 'A',
      extractedInfo: info.toString().trim(),
      citedFacts: citedFacts,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── Private parsers ───────────────────────────────────────────────────────

  FamilySearchRecord _parseRecordEntry(Map<String, dynamic> entry) {
    final content = entry['content'] as Map<String, dynamic>? ?? {};
    final gedcomx = content['gedcomx'] as Map<String, dynamic>? ?? content;

    // Extract persons
    final persons = gedcomx['persons'] as List<dynamic>? ?? [];
    String? personName;
    String? gender;
    String? age;
    final fields = <String, String>{};

    if (persons.isNotEmpty) {
      final principal = persons.first as Map<String, dynamic>;
      final display = principal['display'] as Map<String, dynamic>?;
      personName = display?['name'] as String?;
      gender = display?['gender'] as String?;

      // Extract all fields from the person
      final personFields = principal['fields'] as List<dynamic>? ?? [];
      for (final f in personFields) {
        final field = f as Map<String, dynamic>;
        final label = field['label'] as String? ??
            field['type'] as String? ??
            'Unknown';
        final values = field['values'] as List<dynamic>?;
        if (values != null && values.isNotEmpty) {
          final val = values.first as Map<String, dynamic>;
          final text = val['text'] as String?;
          if (text != null) fields[label] = text;
        }
      }
    }

    // Extract event details
    String? eventDate;
    String? eventPlace;
    String? recordType;

    final sourceDescriptions =
        gedcomx['sourceDescriptions'] as List<dynamic>? ?? [];
    String? collectionTitle;
    String? recordId = entry['id'] as String? ?? '';

    if (sourceDescriptions.isNotEmpty) {
      final sd = sourceDescriptions.first as Map<String, dynamic>;
      final titles = sd['titles'] as List<dynamic>?;
      if (titles != null && titles.isNotEmpty) {
        collectionTitle =
            (titles.first as Map<String, dynamic>)['value'] as String?;
      }
    }

    // Extract from relationships / events
    final events = <Map<String, dynamic>>[];
    for (final p in persons) {
      final person = p as Map<String, dynamic>;
      final facts = person['facts'] as List<dynamic>? ?? [];
      for (final fact in facts) {
        events.add(fact as Map<String, dynamic>);
      }
    }

    if (events.isNotEmpty) {
      final primaryEvent = events.first;
      recordType = _cleanType(primaryEvent['type'] as String?);
      final date = primaryEvent['date'] as Map<String, dynamic>?;
      eventDate = date?['original'] as String? ?? date?['formal'] as String?;
      final place = primaryEvent['place'] as Map<String, dynamic>?;
      eventPlace = place?['original'] as String?;
    }

    // Build title
    final title = _buildRecordTitle(
        personName, recordType, collectionTitle, eventDate);

    // Get father/mother/spouse from relationships
    String? fatherName;
    String? motherName;
    String? spouseName;
    final relationships = gedcomx['relationships'] as List<dynamic>? ?? [];
    for (final r in relationships) {
      final rel = r as Map<String, dynamic>;
      final type = rel['type'] as String? ?? '';
      if (type.contains('ParentChild')) {
        // Check if this person is the child
        final p1Display =
            (rel['person1'] as Map<String, dynamic>?)?['display'] as Map?;
        final p2Display =
            (rel['person2'] as Map<String, dynamic>?)?['display'] as Map?;
        if (p1Display != null) {
          final g = p1Display['gender'] as String? ?? '';
          if (g.toLowerCase() == 'male') {
            fatherName ??= p1Display['name'] as String?;
          } else {
            motherName ??= p1Display['name'] as String?;
          }
        }
      } else if (type.contains('Couple')) {
        final p2Display =
            (rel['person2'] as Map<String, dynamic>?)?['display'] as Map?;
        spouseName ??= p2Display?['name'] as String?;
      }
    }

    final url = entry['links']?['record']?['href'] as String? ??
        (recordId.isNotEmpty
            ? 'https://www.familysearch.org/ark:/$recordId'
            : 'https://www.familysearch.org');

    return FamilySearchRecord(
      recordId: recordId,
      title: title,
      collectionTitle: collectionTitle,
      recordType: recordType,
      eventDate: eventDate,
      eventPlace: eventPlace,
      personName: personName,
      fatherName: fatherName,
      motherName: motherName,
      spouseName: spouseName,
      gender: gender,
      age: fields['Age'] ?? fields['age'],
      recordUrl: url,
      imageUrl: entry['links']?['image']?['href'] as String?,
      fields: fields,
    );
  }

  FamilySearchTreePerson? _parseTreePersonEntry(Map<String, dynamic> entry) {
    try {
      final content = entry['content'] as Map<String, dynamic>? ?? {};
      final gedcomx = content['gedcomx'] as Map<String, dynamic>? ?? content;
      final persons = gedcomx['persons'] as List<dynamic>? ?? [];
      if (persons.isEmpty) return null;

      final person = persons.first as Map<String, dynamic>;
      final display = person['display'] as Map<String, dynamic>? ?? {};
      final id = person['id'] as String? ?? '';

      return FamilySearchTreePerson(
        personId: id,
        displayName: display['name'] as String?,
        givenName: display['givenName'] as String?,
        surname: display['familyName'] as String?,
        gender: display['gender'] as String?,
        birthDate: display['birthDate'] as String?,
        birthPlace: display['birthPlace'] as String?,
        deathDate: display['deathDate'] as String?,
        deathPlace: display['deathPlace'] as String?,
        living: display['living'] as bool? ?? false,
        profileUrl: personUrl(id),
      );
    } catch (_) {
      return null;
    }
  }

  String? _cleanType(String? type) {
    if (type == null) return null;
    // FamilySearch uses URIs like "http://gedcomx.org/Birth"
    final parts = type.split('/');
    return parts.last;
  }

  String _buildRecordTitle(
    String? personName,
    String? recordType,
    String? collectionTitle,
    String? eventDate,
  ) {
    final parts = <String>[];
    if (personName != null) parts.add(personName);
    if (recordType != null) parts.add('— $recordType');
    if (eventDate != null) parts.add('($eventDate)');
    if (parts.isEmpty && collectionTitle != null) return collectionTitle;
    return parts.isEmpty ? 'FamilySearch Record' : parts.join(' ');
  }
}
