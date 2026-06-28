import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/source.dart';

// ── Data models ──────────────────────────────────────────────────────────────

/// A single newspaper page result from Chronicling America.
class ChroniclingAmericaResult {
  final String title;
  final String? newspaperTitle;
  final String date;        // "YYYY-MM-DD"
  final String? state;
  final String? city;
  final String pageUrl;     // permanent link to the page viewer
  final String? ocrText;    // snippet of OCR-extracted text
  final String? thumbnailUrl;
  final String? pdfUrl;

  const ChroniclingAmericaResult({
    required this.title,
    this.newspaperTitle,
    required this.date,
    this.state,
    this.city,
    required this.pageUrl,
    this.ocrText,
    this.thumbnailUrl,
    this.pdfUrl,
  });
}

// ── Service ──────────────────────────────────────────────────────────────────

/// Integration with the Library of Congress **Chronicling America** API.
///
/// Provides full-text search of digitised US newspapers from 1770–1963.
/// The API is **completely free** and requires **no API key**.
///
/// Reference: https://chroniclingamerica.loc.gov/about/api/
class ChroniclingAmericaService {
  ChroniclingAmericaService._({http.Client? client})
      : _client = client ?? http.Client();

  static final ChroniclingAmericaService instance =
      ChroniclingAmericaService._();

  factory ChroniclingAmericaService.withClient(http.Client client) =>
      ChroniclingAmericaService._(client: client);

  final http.Client _client;

  static const _baseUrl = 'https://chroniclingamerica.loc.gov';

  /// Searches Chronicling America for newspaper pages matching [query].
  ///
  /// Optional filters:
  /// - [state]: two-letter US state code (e.g. "New York", "Virginia")
  /// - [dateStart] / [dateEnd]: limit to a date range
  /// - [page]: 1-based result page (20 results per page)
  ///
  /// Returns up to 20 [ChroniclingAmericaResult]s per call, or an empty
  /// list on error.
  Future<List<ChroniclingAmericaResult>> searchPages({
    required String query,
    String? state,
    String? dateStart,    // "YYYY" or "YYYYMMDD"
    String? dateEnd,      // "YYYY" or "YYYYMMDD"
    int page = 1,
  }) async {
    try {
      final params = <String, String>{
        'andtext': query,
        'format': 'json',
        'page': '$page',
      };
      if (state != null && state.isNotEmpty) {
        params['state'] = state;
      }
      if (dateStart != null && dateStart.isNotEmpty) {
        // API expects date1=YYYYMMDD
        params['date1'] = _normaliseDate(dateStart);
      }
      if (dateEnd != null && dateEnd.isNotEmpty) {
        params['date2'] = _normaliseDate(dateEnd);
      }

      final uri = Uri.parse('$_baseUrl/search/pages/results/')
          .replace(queryParameters: params);

      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['items'] as List<dynamic>? ?? [];

      return items.map((item) {
        final m = item as Map<String, dynamic>;
        final id = m['id'] as String? ?? '';
        return ChroniclingAmericaResult(
          title: _buildTitle(m),
          newspaperTitle: m['title'] as String?,
          date: m['date'] as String? ?? '',
          state: (m['state'] as List?)?.cast<String>().join(', '),
          city: (m['city'] as List?)?.cast<String>().join(', '),
          pageUrl: id.startsWith('http')
              ? id
              : '$_baseUrl$id',
          ocrText: _truncateOcr(m['ocr_eng'] as String?),
          thumbnailUrl: m['thumbnail_url'] as String?,
          pdfUrl: _pdfUrl(id),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Searches for newspaper titles (publications) by [state] and/or [query].
  ///
  /// Useful for browsing available newspapers before searching pages.
  Future<List<Map<String, String>>> searchNewspaperTitles({
    String? state,
    String? query,
  }) async {
    try {
      final params = <String, String>{'format': 'json'};
      if (state != null) params['state'] = state;
      if (query != null) params['terms'] = query;

      final uri = Uri.parse('$_baseUrl/search/titles/results/')
          .replace(queryParameters: params);

      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['items'] as List<dynamic>? ?? [];

      return items.map((item) {
        final m = item as Map<String, dynamic>;
        return <String, String>{
          'title': m['title'] as String? ?? '',
          'place': (m['place_of_publication'] as String?) ?? '',
          'lccn': m['lccn'] as String? ?? '',
          'startYear': m['start_year'] as String? ?? '',
          'endYear': m['end_year'] as String? ?? '',
          'url': m['url'] as String? ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Source builder ────────────────────────────────────────────────────────

  /// Creates a [Source] record from a Chronicling America result.
  Source resultToSource(ChroniclingAmericaResult result, String personId) {
    final info = StringBuffer();
    if (result.newspaperTitle != null) {
      info.writeln('Newspaper: ${result.newspaperTitle}');
    }
    info.writeln('Date: ${result.date}');
    if (result.state != null) info.writeln('State: ${result.state}');
    if (result.city != null) info.writeln('City: ${result.city}');
    if (result.ocrText != null && result.ocrText!.isNotEmpty) {
      info.writeln('---');
      info.writeln(result.ocrText);
    }

    return Source(
      id: const Uuid().v4(),
      personId: personId,
      title: result.title,
      type: 'Newspaper',
      url: result.pageUrl,
      author: result.newspaperTitle ?? 'Unknown newspaper',
      publisher: 'Library of Congress — Chronicling America',
      repository: 'Chronicling America (chroniclingamerica.loc.gov)',
      confidence: 'B',
      extractedInfo: info.toString().trim(),
      citedFacts: const [],
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Builds a human-readable title from result fields.
  String _buildTitle(Map<String, dynamic> m) {
    final newspaper = m['title'] as String? ?? 'Newspaper';
    final date = m['date'] as String? ?? '';
    final page = m['sequence'] as int?;
    final pageStr = page != null ? ', p. $page' : '';
    return '$newspaper ($date$pageStr)';
  }

  /// Normalises a year or date string to the YYYYMMDD format the API expects.
  String _normaliseDate(String input) {
    final trimmed = input.trim().replaceAll('-', '');
    if (trimmed.length == 4) return '${trimmed}0101'; // year only
    if (trimmed.length == 6) return '${trimmed}01';   // YYYYMM
    return trimmed;                                     // already YYYYMMDD
  }

  /// Truncates OCR text to a reasonable snippet length.
  String? _truncateOcr(String? ocr) {
    if (ocr == null || ocr.isEmpty) return null;
    if (ocr.length <= 500) return ocr;
    return '${ocr.substring(0, 497)}…';
  }

  /// Builds the PDF download URL from a page ID path.
  String? _pdfUrl(String id) {
    if (id.isEmpty) return null;
    final base = id.startsWith('http') ? id : '$_baseUrl$id';
    // Chronicling America page URLs end with the sequence number.
    // Append .pdf to get the PDF rendition.
    return '${base.replaceAll(RegExp(r'/\$'), '')}.pdf';
  }
}
