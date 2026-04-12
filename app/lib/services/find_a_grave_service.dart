import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/source.dart';

// ── Data model ────────────────────────────────────────────────────────────────

/// Structured data extracted from a Find A Grave memorial page.
class FindAGraveMemorial {
  final String memorialId;
  final String? fullName;
  final String? birthYear;
  final String? deathYear;
  final String? birthPlace;
  final String? deathPlace;
  final String? burialPlace;
  final String? cemeteryName;
  final String memorialUrl;

  const FindAGraveMemorial({
    required this.memorialId,
    required this.memorialUrl,
    this.fullName,
    this.birthYear,
    this.deathYear,
    this.birthPlace,
    this.deathPlace,
    this.burialPlace,
    this.cemeteryName,
  });
}

// ── FindAGraveService ─────────────────────────────────────────────────────────

/// Provides Find A Grave integration.
///
/// Find A Grave has **no public API**.  This service uses two strategies:
///
/// 1. **Schema.org JSON-LD** — memorial pages embed structured data in a
///    `<script type="application/ld+json">` block.  This is the most reliable
///    extraction method and is unlikely to break on markup changes.
///
/// 2. **HTML regex fallback** — extracts birth/death year from common
///    `<span>` and `<meta>` patterns when JSON-LD is absent.
///
/// All fetches are made on **explicit user demand only** — never in the
/// background or in bulk — to stay within reasonable usage limits.
class FindAGraveService {
  FindAGraveService._();
  static final FindAGraveService instance = FindAGraveService._();

  static const _ua =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  // ── URL helpers ───────────────────────────────────────────────────────────

  /// Canonical URL for a memorial ID.
  String memorialUrl(String memorialId) =>
      'https://www.findagrave.com/memorial/$memorialId';

  /// Extracts the numeric memorial ID from a Find A Grave URL.
  ///
  /// Supports both:
  ///   `https://www.findagrave.com/memorial/1836/george-washington`
  ///   `https://www.findagrave.com/memorial/1836`
  String? extractIdFromUrl(String url) {
    final match = RegExp(r'findagrave\.com/memorial/(\d+)').firstMatch(url);
    return match?.group(1);
  }

  // ── Fetch memorial ────────────────────────────────────────────────────────

  /// Fetches and parses a memorial page.
  ///
  /// Returns `null` if the page cannot be reached (bot-detection block,
  /// network error, or invalid ID).  Callers should handle `null` gracefully
  /// and fall back to showing the deep-link button only.
  Future<FindAGraveMemorial?> fetchMemorial(String memorialId) async {
    final url = memorialUrl(memorialId);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _ua,
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final html = response.body;

      // ── Strategy 1: JSON-LD structured data ─────────────────────────────
      final memorial = _parseJsonLd(html, memorialId, url);
      if (memorial != null) return memorial;

      // ── Strategy 2: HTML regex fallback ─────────────────────────────────
      return _parseHtml(html, memorialId, url);
    } catch (_) {
      return null;
    }
  }

  // ── Parsers ───────────────────────────────────────────────────────────────

  FindAGraveMemorial? _parseJsonLd(
      String html, String memorialId, String url) {
    try {
      final scriptPattern =
          RegExp(r'<script[^>]+type="application/ld\+json"[^>]*>(.*?)</script>',
              dotAll: true, caseSensitive: false);
      for (final match in scriptPattern.allMatches(html)) {
        final jsonText = match.group(1);
        if (jsonText == null) continue;
        dynamic parsed;
        try {
          parsed = jsonDecode(jsonText);
        } catch (_) {
          continue;
        }

        // JSON-LD may be a single object or an array of objects.
        final objects = <Map<String, dynamic>>[];
        if (parsed is Map<String, dynamic>) {
          objects.add(parsed);
        } else if (parsed is List) {
          for (final item in parsed) {
            if (item is Map<String, dynamic>) objects.add(item);
          }
        }

        for (final obj in objects) {
          final type = obj['@type'];
          if (type == 'Person' || type == 'deceased') {
            return FindAGraveMemorial(
              memorialId: memorialId,
              memorialUrl: url,
              fullName: _str(obj['name']),
              birthYear: _yearFromSchemaDate(obj['birthDate']),
              deathYear: _yearFromSchemaDate(obj['deathDate']),
              birthPlace: _placeFromSchema(obj['birthPlace']),
              deathPlace: _placeFromSchema(obj['deathPlace']),
              burialPlace: _placeFromSchema(obj['burialLocation']),
              cemeteryName: _str(obj['memberOf']?['name']),
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  FindAGraveMemorial? _parseHtml(
      String html, String memorialId, String url) {
    try {
      // Extract name from <title> or OG meta
      final titleMatch = RegExp(
              r'<meta\s+property="og:title"\s+content="([^"]+)"',
              caseSensitive: false)
          .firstMatch(html);
      final name = titleMatch?.group(1)?.split(' - ').first;

      // Birth/death years from itemprop or data-* attributes
      final birthYearMatch =
          RegExp(r'itemprop="birthDate"[^>]*>([^<]*)<')
              .firstMatch(html) ??
          RegExp(r'"birthDate"\s*:\s*"(\d{4})"').firstMatch(html);
      final deathYearMatch =
          RegExp(r'itemprop="deathDate"[^>]*>([^<]*)<')
              .firstMatch(html) ??
          RegExp(r'"deathDate"\s*:\s*"(\d{4})"').firstMatch(html);

      final birthPlaceMatch =
          RegExp(r'itemprop="birthPlace"[^>]*>\s*([^<]{2,})<')
              .firstMatch(html);
      final deathPlaceMatch =
          RegExp(r'itemprop="deathPlace"[^>]*>\s*([^<]{2,})<')
              .firstMatch(html);
      final cemeteryMatch =
          RegExp(r'class="[^"]*cemetery[^"]*"[^>]*>\s*([^<]{2,})<',
                  caseSensitive: false)
              .firstMatch(html);

      return FindAGraveMemorial(
        memorialId: memorialId,
        memorialUrl: url,
        fullName: name?.trim(),
        birthYear: _firstDigits(birthYearMatch?.group(1)),
        deathYear: _firstDigits(deathYearMatch?.group(1)),
        birthPlace: birthPlaceMatch?.group(1)?.trim(),
        deathPlace: deathPlaceMatch?.group(1)?.trim(),
        cemeteryName: cemeteryMatch?.group(1)?.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Source builder ────────────────────────────────────────────────────────

  /// Creates a [Source] record for a Find A Grave memorial.
  Source memorialToSource(FindAGraveMemorial memorial, String personId) {
    final info = StringBuffer();
    if (memorial.fullName != null) info.writeln('Name: ${memorial.fullName}');
    if (memorial.birthYear != null) info.writeln('Birth year: ${memorial.birthYear}');
    if (memorial.deathYear != null) info.writeln('Death year: ${memorial.deathYear}');
    if (memorial.birthPlace != null) info.writeln('Birth place: ${memorial.birthPlace}');
    if (memorial.deathPlace != null) info.writeln('Death place: ${memorial.deathPlace}');
    if (memorial.cemeteryName != null) info.writeln('Cemetery: ${memorial.cemeteryName}');
    if (memorial.burialPlace != null) info.writeln('Burial: ${memorial.burialPlace}');

    return Source(
      id: const Uuid().v4(),
      personId: personId,
      title: 'Find A Grave memorial #${memorial.memorialId}',
      type: 'Online Database',
      url: memorial.memorialUrl,
      author: 'Find A Grave contributors',
      repository: 'Find A Grave (findagrave.com)',
      confidence: 'B',
      extractedInfo: info.toString().trim(),
      citedFacts: [
        if (memorial.birthYear != null) 'Birth Date',
        if (memorial.birthPlace != null) 'Birth Place',
        if (memorial.deathYear != null) 'Death Date',
        if (memorial.deathPlace != null) 'Death Place',
        if (memorial.burialPlace != null || memorial.cemeteryName != null)
          'Burial Place',
      ],
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  String? _str(dynamic val) {
    if (val == null) return null;
    final s = val.toString().trim();
    return s.isEmpty ? null : s;
  }

  String? _yearFromSchemaDate(dynamic val) {
    if (val == null) return null;
    final s = val.toString();
    final m = RegExp(r'(\d{4})').firstMatch(s);
    return m?.group(1);
  }

  String? _placeFromSchema(dynamic val) {
    if (val == null) return null;
    if (val is Map) {
      return _str(val['name']) ??
          _str(val['address']?['addressLocality']) ??
          _str(val['address']?['name']);
    }
    return _str(val);
  }

  String? _firstDigits(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'\d{4}').firstMatch(raw);
    return m?.group(0);
  }
}
