import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/person.dart';
import '../models/source.dart';

// ── Data model ────────────────────────────────────────────────────────────────

/// A WikiTree profile as returned by the `getProfile` / `searchPerson` API.
class WikiTreeProfile {
  final int id;

  /// WikiTree page name / profile ID — e.g. `"Churchill-4"`.
  final String wikiTreeId;

  final String? firstName;
  final String? middleName;
  final String? lastName;
  final DateTime? birthDate;
  final String? birthPlace;
  final DateTime? deathDate;
  final String? deathPlace;

  /// `"Male"`, `"Female"`, or `null`.
  final String? gender;

  final String? occupation;

  /// Full biography text as stored on WikiTree (may contain wiki markup).
  final String? bio;

  /// WikiTree IDs of direct parent profiles.
  final List<String> parentWikiTreeIds;

  /// WikiTree IDs of child profiles.
  final List<String> childWikiTreeIds;

  /// WikiTree IDs of spouse profiles.
  final List<String> spouseWikiTreeIds;

  const WikiTreeProfile({
    required this.id,
    required this.wikiTreeId,
    this.firstName,
    this.middleName,
    this.lastName,
    this.birthDate,
    this.birthPlace,
    this.deathDate,
    this.deathPlace,
    this.gender,
    this.occupation,
    this.bio,
    this.parentWikiTreeIds = const [],
    this.childWikiTreeIds = const [],
    this.spouseWikiTreeIds = const [],
  });

  /// Best display name from available name parts.
  String get displayName {
    final parts = <String>[
      if (firstName?.isNotEmpty ?? false) firstName!,
      if (middleName?.isNotEmpty ?? false) middleName!,
      if (lastName?.isNotEmpty ?? false) lastName!,
    ];
    return parts.isEmpty ? wikiTreeId : parts.join(' ');
  }

  factory WikiTreeProfile.fromJson(Map<String, dynamic> json) {
    // Collect parent IDs from Father / Mother objects
    final parents = <String>[];
    for (final key in ['Father', 'Mother']) {
      final val = json[key];
      if (val is Map) {
        final name = val['Name'] as String?;
        if (name != null && name.isNotEmpty) parents.add(name);
      }
    }

    // Collect child IDs
    final children = <String>[];
    final rawChildren = json['Children'];
    if (rawChildren is List) {
      for (final c in rawChildren) {
        if (c is Map) {
          final name = c['Name'] as String?;
          if (name != null && name.isNotEmpty) children.add(name);
        }
      }
    } else if (rawChildren is Map) {
      for (final c in rawChildren.values) {
        if (c is Map) {
          final name = c['Name'] as String?;
          if (name != null && name.isNotEmpty) children.add(name);
        }
      }
    }

    // Collect spouse IDs
    final spouses = <String>[];
    final rawSpouses = json['Spouses'];
    if (rawSpouses is List) {
      for (final s in rawSpouses) {
        if (s is Map) {
          final name = s['Name'] as String?;
          if (name != null && name.isNotEmpty) spouses.add(name);
        }
      }
    } else if (rawSpouses is Map) {
      for (final s in rawSpouses.values) {
        if (s is Map) {
          final name = s['Name'] as String?;
          if (name != null && name.isNotEmpty) spouses.add(name);
        }
      }
    }

    return WikiTreeProfile(
      id: (json['Id'] as num? ?? 0).toInt(),
      wikiTreeId: json['Name'] as String? ?? '',
      firstName: _nullIfEmpty(json['FirstName'] as String?),
      middleName: _nullIfEmpty(json['MiddleName'] as String?),
      lastName: _nullIfEmpty(json['LastName'] as String?),
      birthDate: _parseWikiTreeDate(json['BirthDate'] as String?),
      birthPlace: _nullIfEmpty(json['BirthLocation'] as String?),
      deathDate: _parseWikiTreeDate(json['DeathDate'] as String?),
      deathPlace: _nullIfEmpty(json['DeathLocation'] as String?),
      gender: _nullIfEmpty(json['Gender'] as String?),
      occupation: _nullIfEmpty(json['Occupation'] as String?),
      bio: _nullIfEmpty(json['Bio'] as String?),
      parentWikiTreeIds: parents,
      childWikiTreeIds: children,
      spouseWikiTreeIds: spouses,
    );
  }

  /// Parses WikiTree date strings like `"1920-00-00"` (year only) or
  /// `"1874-11-30"` (full date).  Returns `null` for fully unknown dates.
  static DateTime? _parseWikiTreeDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == '0000-00-00') return null;
    try {
      final parts = raw.split('-');
      final year = int.tryParse(parts[0]) ?? 0;
      if (year == 0) return null;
      final month = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
      final day = parts.length > 2 ? (int.tryParse(parts[2]) ?? 1) : 1;
      return DateTime(year, month.clamp(1, 12), day.clamp(1, 31));
    } catch (_) {
      return null;
    }
  }

  static String? _nullIfEmpty(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
}

// ── WikiTree login result ─────────────────────────────────────────────────────

enum WikiTreeLoginResult { success, wrongPassword, notFound, networkError }

// ── WikiTreeService ───────────────────────────────────────────────────────────

/// Wraps the WikiTree Apps API (`https://api.wikitree.com/api.php`).
///
/// All public profiles are accessible without authentication.  Account-specific
/// operations (GEDCOM export, watchlist, editing) require a logged-in session.
///
/// Authentication is cookie-based: [login] POSTs `clientLogin`, captures the
/// `wikitree_wtb` session cookie from `Set-Cookie`, and stores it in
/// [SharedPreferences].  Every subsequent request that needs auth includes the
/// cookie as the `Cookie` header.
class WikiTreeService extends ChangeNotifier {
  WikiTreeService._();
  static final WikiTreeService instance = WikiTreeService._();

  static const _base = 'https://api.wikitree.com/api.php';
  static const _ua = 'Vetviona/1.0 (genealogy; contact@vetviona.app)';

  // ── Auth state ────────────────────────────────────────────────────────────

  String? _cookie;
  String? _loggedInUser;

  bool get isLoggedIn => _loggedInUser != null && _cookie != null;
  String? get loggedInUser => _loggedInUser;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString('wikitree_cookie');
    _loggedInUser = prefs.getString('wikitree_user');
    notifyListeners();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Authenticates with WikiTree.  Stores the session cookie and username on
  /// success.  Returns a [WikiTreeLoginResult] describing the outcome.
  Future<WikiTreeLoginResult> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(_base),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': _ua,
        },
        body: {
          'action': 'clientLogin',
          'email': email,
          'password': password,
          'doLogin': '1',
        },
      ).timeout(const Duration(seconds: 20));

      // Extract session cookie
      final setCookie = response.headers['set-cookie'] ?? '';
      final cookieMatch =
          RegExp(r'(wikidb_wtb|wikitree_wtb)=([^;]+)').firstMatch(setCookie);

      final body = _decodeBody(response.body);
      final loginResult = body['clientLogin'] as Map<String, dynamic>?;
      final result = loginResult?['result'] as String? ?? '';

      if (result == 'Success') {
        final username = loginResult?['username'] as String? ??
            loginResult?['userid']?.toString() ??
            email;

        // Store cookie + username
        final cookie = cookieMatch != null
            ? '${cookieMatch.group(1)}=${cookieMatch.group(2)}'
            : null;
        final prefs = await SharedPreferences.getInstance();
        if (cookie != null) {
          await prefs.setString('wikitree_cookie', cookie);
          _cookie = cookie;
        }
        await prefs.setString('wikitree_user', username);
        _loggedInUser = username;
        notifyListeners();
        return WikiTreeLoginResult.success;
      } else if (result == 'WrongPassword') {
        return WikiTreeLoginResult.wrongPassword;
      } else if (result == 'NoProfile' || result == 'NotFound') {
        return WikiTreeLoginResult.notFound;
      }
      return WikiTreeLoginResult.networkError;
    } catch (_) {
      return WikiTreeLoginResult.networkError;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wikitree_cookie');
    await prefs.remove('wikitree_user');
    _cookie = null;
    _loggedInUser = null;
    notifyListeners();
  }

  // ── API helpers ───────────────────────────────────────────────────────────

  Map<String, String> _authHeaders() => {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': _ua,
        if (_cookie != null) 'Cookie': _cookie!,
      };

  Map<String, dynamic> _decodeBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Extracts the first profile map from the diverse response shapes WikiTree
  /// returns (array vs object, `profile` wrapper vs flat).
  Map<String, dynamic>? _extractProfile(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      final first = raw[0];
      if (first is Map) {
        return (first['profile'] as Map<String, dynamic>?) ??
            (first as Map<String, dynamic>);
      }
    } else if (raw is Map) {
      // Some endpoints return {"0": {...}} or {"profile": {...}}
      final zero = raw['0'];
      if (zero is Map) {
        return (zero['profile'] as Map<String, dynamic>?) ??
            (zero as Map<String, dynamic>);
      }
      return (raw['profile'] as Map<String, dynamic>?);
    }
    return null;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns a [WikiTreeProfile] for the given WikiTree page name / ID.
  ///
  /// Does **not** require authentication — any public profile can be read.
  Future<WikiTreeProfile?> getProfile(String wikiTreeId) async {
    try {
      final response = await http.post(
        Uri.parse(_base),
        headers: _authHeaders(),
        body: {
          'action': 'getProfile',
          'key': wikiTreeId,
          'fields':
              'Id,Name,FirstName,MiddleName,LastName,RealName,BirthDate,'
              'BirthDateDecade,BirthLocation,DeathDate,DeathDateDecade,'
              'DeathLocation,Gender,Father,Mother,Bio,Spouses,Children,'
              'Occupation',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      dynamic parsed;
      try {
        parsed = jsonDecode(response.body);
      } catch (_) {
        return null;
      }
      final profileMap = _extractProfile(parsed);
      if (profileMap == null) return null;
      return WikiTreeProfile.fromJson(profileMap);
    } catch (_) {
      return null;
    }
  }

  /// Searches WikiTree for profiles matching [name] (optionally filtered by
  /// [birthYear]).  Returns up to [limit] results.
  Future<List<WikiTreeProfile>> searchPerson(
    String name, {
    int? birthYear,
    int limit = 15,
  }) async {
    if (name.trim().isEmpty) return [];
    try {
      final body = <String, String>{
        'action': 'searchPerson',
        'q': name.trim(),
        'limit': '$limit',
        if (birthYear != null) 'birth_date': '$birthYear',
      };
      final response = await http.post(
        Uri.parse(_base),
        headers: _authHeaders(),
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];
      dynamic parsed;
      try {
        parsed = jsonDecode(response.body);
      } catch (_) {
        return [];
      }

      // WikiTree may wrap response in {"response": {...}} or return it flat.
      Map<String, dynamic> data;
      if (parsed is Map) {
        data = (parsed['response'] as Map<String, dynamic>?) ??
            parsed.cast<String, dynamic>();
      } else {
        return [];
      }

      final matches = data['matches'];
      if (matches is! List) return [];

      final profiles = <WikiTreeProfile>[];
      for (final m in matches) {
        if (m is Map) {
          final personMap = m['person'];
          if (personMap is Map) {
            try {
              profiles.add(
                  WikiTreeProfile.fromJson(personMap.cast<String, dynamic>()));
            } catch (_) {}
          }
        }
      }
      return profiles;
    } catch (_) {
      return [];
    }
  }

  /// Returns an ancestors tree up to [depth] generations for [wikiTreeId].
  Future<List<WikiTreeProfile>> getAncestors(
    String wikiTreeId, {
    int depth = 4,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_base),
        headers: _authHeaders(),
        body: {
          'action': 'getAncestors',
          'key': wikiTreeId,
          'depth': '$depth',
          'fields':
              'Id,Name,FirstName,LastName,BirthDate,BirthLocation,'
              'DeathDate,DeathLocation,Gender,Father,Mother',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];
      dynamic parsed;
      try {
        parsed = jsonDecode(response.body);
      } catch (_) {
        return [];
      }

      final ancestors = <WikiTreeProfile>[];
      void traverse(dynamic node) {
        if (node is Map) {
          // If node has 'Name' it's a profile dict
          if (node.containsKey('Name')) {
            try {
              ancestors.add(
                  WikiTreeProfile.fromJson(node.cast<String, dynamic>()));
            } catch (_) {}
          }
          for (final v in node.values) {
            traverse(v);
          }
        } else if (node is List) {
          for (final item in node) {
            traverse(item);
          }
        }
      }

      traverse(parsed);
      return ancestors;
    } catch (_) {
      return [];
    }
  }

  /// Downloads the GEDCOM export for [wikiTreeId] (requires authentication).
  ///
  /// Returns the raw GEDCOM text on success, or `null` on failure.
  Future<String?> exportGedcom(String wikiTreeId) async {
    if (!isLoggedIn) return null;
    try {
      final response = await http.post(
        Uri.parse(_base),
        headers: _authHeaders(),
        body: {
          'action': 'exportGEDCOM',
          'key': wikiTreeId,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return null;
      final body = response.body;
      // GEDCOM starts with "0 HEAD"
      if (body.contains('0 HEAD')) return body;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Conversion helpers ────────────────────────────────────────────────────

  /// Converts a [WikiTreeProfile] into a local [Person] record.
  ///
  /// If [existing] is provided its ID and existing data are preserved; the
  /// WikiTree data is merged in, only overwriting fields that are currently
  /// blank.  Pass `forceOverwrite: true` to always take the WikiTree value.
  Person profileToPerson(
    WikiTreeProfile profile, {
    Person? existing,
    bool forceOverwrite = false,
  }) {
    final id = existing?.id ?? const Uuid().v4();
    bool take(bool hasExisting) => forceOverwrite || !hasExisting;

    final gender = (take(existing?.gender != null))
        ? _mapGender(profile.gender)
        : existing?.gender;

    return Person(
      id: id,
      name: take(existing?.name.isEmpty ?? true)
          ? profile.displayName
          : existing!.name,
      birthDate:
          take(existing?.birthDate == null) ? profile.birthDate : existing?.birthDate,
      birthPlace:
          take(existing?.birthPlace == null) ? profile.birthPlace : existing?.birthPlace,
      deathDate:
          take(existing?.deathDate == null) ? profile.deathDate : existing?.deathDate,
      deathPlace:
          take(existing?.deathPlace == null) ? profile.deathPlace : existing?.deathPlace,
      gender: gender,
      occupation: take(existing?.occupation == null)
          ? profile.occupation
          : existing?.occupation,
      notes: take(existing?.notes == null)
          ? _stripWikiMarkup(profile.bio)
          : existing?.notes,
      wikitreeId: profile.wikiTreeId,
      // Preserve all other fields from the existing record.
      parentIds: existing?.parentIds ?? [],
      childIds: existing?.childIds ?? [],
      parentRelTypes: existing?.parentRelTypes ?? {},
      photoPaths: existing?.photoPaths ?? [],
      sourceIds: existing?.sourceIds ?? [],
      treeId: existing?.treeId,
      nationality: existing?.nationality,
      maidenName: existing?.maidenName,
      burialDate: existing?.burialDate,
      burialPlace: existing?.burialPlace,
      isPrivate: existing?.isPrivate ?? false,
      syncMedical: existing?.syncMedical ?? false,
      preferredSourceIds: existing?.preferredSourceIds ?? {},
      causeOfDeath: existing?.causeOfDeath,
      bloodType: existing?.bloodType,
      eyeColour: existing?.eyeColour,
      hairColour: existing?.hairColour,
      height: existing?.height,
      religion: existing?.religion,
      education: existing?.education,
      aliases: existing?.aliases ?? [],
      findAGraveId: existing?.findAGraveId,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Creates a [Source] record pointing at the WikiTree profile for [personId].
  Source profileToSource(WikiTreeProfile profile, String personId) {
    return Source(
      id: const Uuid().v4(),
      personId: personId,
      title: 'WikiTree profile: ${profile.displayName}',
      type: 'Online Database',
      url: 'https://www.wikitree.com/wiki/${profile.wikiTreeId}',
      author: 'WikiTree community',
      repository: 'WikiTree (wikitree.com)',
      retrievalDate: _todayStr(),
      confidence: 'B',
      extractedInfo:
          'WikiTree ID: ${profile.wikiTreeId}\n'
          '${profile.birthDate != null ? "Born: ${profile.birthDate!.year}" : ""}'
          '${profile.birthPlace != null ? " in ${profile.birthPlace}" : ""}'
          '${profile.deathDate != null ? "\nDied: ${profile.deathDate!.year}" : ""}'
          '${profile.deathPlace != null ? " in ${profile.deathPlace}" : ""}',
      citedFacts: [
        if (profile.birthDate != null) 'Birth Date',
        if (profile.birthPlace != null) 'Birth Place',
        if (profile.deathDate != null) 'Death Date',
        if (profile.deathPlace != null) 'Death Place',
      ],
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  String? _mapGender(String? wikiGender) {
    if (wikiGender == null) return null;
    final g = wikiGender.toLowerCase();
    if (g == 'male') return 'Male';
    if (g == 'female') return 'Female';
    return null;
  }

  /// Strips the most common WikiTree wiki markup to get plain-text bio.
  String? _stripWikiMarkup(String? bio) {
    if (bio == null || bio.trim().isEmpty) return null;
    var text = bio
        .replaceAll(RegExp(r'\[\[([^\]|]+\|)?([^\]]+)\]\]'), r'$2')
        .replaceAll(RegExp(r"'''(.+?)'''"), r'$1')
        .replaceAll(RegExp(r"''(.+?)''"), r'$1')
        .replaceAll(RegExp(r'={2,}[^=]+=+'), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\{\{[^}]+\}\}'), '')
        .trim();
    // Truncate very long bios
    if (text.length > 2000) text = '${text.substring(0, 2000)}…';
    return text.isEmpty ? null : text;
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.day} ${_monthNames[now.month - 1]} ${now.year}';
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
