import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetviona_app/services/find_a_grave_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

FindAGraveMemorial _memorial({
  String id = '12345',
  String? fullName,
  String? birthYear,
  String? deathYear,
  String? birthPlace,
  String? deathPlace,
  String? burialPlace,
  String? cemeteryName,
}) {
  return FindAGraveMemorial(
    memorialId: id,
    memorialUrl: 'https://www.findagrave.com/memorial/$id',
    fullName: fullName,
    birthYear: birthYear,
    deathYear: deathYear,
    birthPlace: birthPlace,
    deathPlace: deathPlace,
    burialPlace: burialPlace,
    cemeteryName: cemeteryName,
  );
}

FindAGraveService _serviceWithHtml(String html, {int statusCode = 200}) {
  final mockClient = MockClient((_) async => http.Response(html, statusCode));
  return FindAGraveService.withClient(mockClient);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── memorialUrl ─────────────────────────────────────────────────────────────
  group('FindAGraveService.memorialUrl', () {
    final svc = FindAGraveService.instance;

    test('returns the canonical Find A Grave URL', () {
      expect(
        svc.memorialUrl('1836'),
        'https://www.findagrave.com/memorial/1836',
      );
    });

    test('works with alphanumeric id', () {
      expect(
        svc.memorialUrl('99999999'),
        'https://www.findagrave.com/memorial/99999999',
      );
    });
  });

  // ── extractIdFromUrl ─────────────────────────────────────────────────────────
  group('FindAGraveService.extractIdFromUrl', () {
    final svc = FindAGraveService.instance;

    test('extracts id from URL with slug', () {
      const url =
          'https://www.findagrave.com/memorial/1836/george-washington';
      expect(svc.extractIdFromUrl(url), '1836');
    });

    test('extracts id from URL without slug', () {
      expect(
        svc.extractIdFromUrl('https://www.findagrave.com/memorial/1836'),
        '1836',
      );
    });

    test('returns null for non-findagrave URL', () {
      expect(svc.extractIdFromUrl('https://example.com/memorial/1836'), isNull);
    });

    test('returns null for empty string', () {
      expect(svc.extractIdFromUrl(''), isNull);
    });

    test('handles URL with query string', () {
      const url =
          'https://www.findagrave.com/memorial/42?ref=acom';
      expect(svc.extractIdFromUrl(url), '42');
    });
  });

  // ── memorialToSource ─────────────────────────────────────────────────────────
  group('FindAGraveService.memorialToSource', () {
    final svc = FindAGraveService.instance;

    test('source has correct title', () {
      final source = svc.memorialToSource(_memorial(id: '9999'), 'p1');
      expect(source.title, 'Find A Grave memorial #9999');
    });

    test('source type is Online Database', () {
      final source = svc.memorialToSource(_memorial(), 'p1');
      expect(source.type, 'Online Database');
    });

    test('source url matches memorialUrl', () {
      final source = svc.memorialToSource(_memorial(id: '5555'), 'p1');
      expect(source.url, 'https://www.findagrave.com/memorial/5555');
    });

    test('source author is Find A Grave contributors', () {
      final source = svc.memorialToSource(_memorial(), 'p1');
      expect(source.author, 'Find A Grave contributors');
    });

    test('source repository contains findagrave.com', () {
      final source = svc.memorialToSource(_memorial(), 'p1');
      expect(source.repository, contains('findagrave.com'));
    });

    test('confidence is B (Secondary)', () {
      final source = svc.memorialToSource(_memorial(), 'p1');
      expect(source.confidence, 'B');
    });

    test('personId is set correctly', () {
      final source = svc.memorialToSource(_memorial(), 'person-abc');
      expect(source.personId, 'person-abc');
    });

    test('id is a non-empty UUID-like string', () {
      final source = svc.memorialToSource(_memorial(), 'p1');
      expect(source.id, isNotEmpty);
    });

    test('extractedInfo is empty when no optional fields set', () {
      final source = svc.memorialToSource(_memorial(), 'p1');
      expect(source.extractedInfo, isEmpty);
    });

    test('citedFacts is empty when no optional fields set', () {
      final source = svc.memorialToSource(_memorial(), 'p1');
      expect(source.citedFacts, isEmpty);
    });

    test('all fields populated → extractedInfo contains all labels', () {
      final mem = _memorial(
        fullName: 'George Washington',
        birthYear: '1732',
        deathYear: '1799',
        birthPlace: 'Virginia',
        deathPlace: 'Mount Vernon',
        burialPlace: 'Mount Vernon Estate',
        cemeteryName: 'Washington Family Vault',
      );
      final source = svc.memorialToSource(mem, 'p1');
      expect(source.extractedInfo, contains('George Washington'));
      expect(source.extractedInfo, contains('1732'));
      expect(source.extractedInfo, contains('1799'));
      expect(source.extractedInfo, contains('Virginia'));
      expect(source.extractedInfo, contains('Mount Vernon'));
      expect(source.extractedInfo, contains('Washington Family Vault'));
    });

    test('citedFacts includes Birth Date when birthYear is set', () {
      final source = svc.memorialToSource(
        _memorial(birthYear: '1850'),
        'p1',
      );
      expect(source.citedFacts, contains('Birth Date'));
    });

    test('citedFacts includes Death Date when deathYear is set', () {
      final source = svc.memorialToSource(
        _memorial(deathYear: '1920'),
        'p1',
      );
      expect(source.citedFacts, contains('Death Date'));
    });

    test('citedFacts includes Birth Place when birthPlace is set', () {
      final source = svc.memorialToSource(
        _memorial(birthPlace: 'London, England'),
        'p1',
      );
      expect(source.citedFacts, contains('Birth Place'));
    });

    test('citedFacts includes Death Place when deathPlace is set', () {
      final source = svc.memorialToSource(
        _memorial(deathPlace: 'Paris, France'),
        'p1',
      );
      expect(source.citedFacts, contains('Death Place'));
    });

    test('citedFacts includes Burial Place when burialPlace is set', () {
      final source = svc.memorialToSource(
        _memorial(burialPlace: 'Highgate Cemetery'),
        'p1',
      );
      expect(source.citedFacts, contains('Burial Place'));
    });

    test('citedFacts includes Burial Place when cemeteryName is set', () {
      final source = svc.memorialToSource(
        _memorial(cemeteryName: 'Père Lachaise'),
        'p1',
      );
      expect(source.citedFacts, contains('Burial Place'));
    });

    test('Burial Place appears only once when both burialPlace and cemetery set',
        () {
      final source = svc.memorialToSource(
        _memorial(burialPlace: 'Somewhere', cemeteryName: 'Some Cemetery'),
        'p1',
      );
      expect(
        source.citedFacts.where((f) => f == 'Burial Place').length,
        1,
      );
    });

    test('all four citedFacts populated together', () {
      final source = svc.memorialToSource(
        _memorial(
          birthYear: '1800',
          birthPlace: 'Dublin',
          deathYear: '1870',
          deathPlace: 'London',
        ),
        'p1',
      );
      expect(source.citedFacts, containsAll([
        'Birth Date',
        'Birth Place',
        'Death Date',
        'Death Place',
      ]));
    });
  });

  // ── fetchMemorial — HTTP 4xx/5xx → returns null ──────────────────────────────
  group('FindAGraveService.fetchMemorial (HTTP errors)', () {
    test('returns null on HTTP 403', () async {
      final svc = _serviceWithHtml('Forbidden', statusCode: 403);
      expect(await svc.fetchMemorial('999'), isNull);
    });

    test('returns null on HTTP 500', () async {
      final svc = _serviceWithHtml('<html></html>', statusCode: 500);
      expect(await svc.fetchMemorial('999'), isNull);
    });
  });

  // ── fetchMemorial — JSON-LD parsing ──────────────────────────────────────────
  group('FindAGraveService.fetchMemorial (JSON-LD strategy)', () {
    test('parses Person JSON-LD with full fields', () async {
      final jsonLd = jsonEncode({
        '@type': 'Person',
        'name': 'Jane Doe',
        'birthDate': '1850-06-15',
        'deathDate': '1922',
        'birthPlace': {'name': 'Dublin'},
        'deathPlace': 'London, England',
        'burialLocation': {'name': 'Highgate Cemetery'},
        'memberOf': {'name': 'East Chapel'},
      });
      final html = '''
<html>
<head>
<script type="application/ld+json">$jsonLd</script>
</head>
<body></body>
</html>
''';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('42');

      expect(m, isNotNull);
      expect(m!.fullName, 'Jane Doe');
      expect(m.birthYear, '1850');
      expect(m.deathYear, '1922');
      expect(m.birthPlace, 'Dublin');
      expect(m.deathPlace, 'London, England');
      expect(m.burialPlace, 'Highgate Cemetery');
      expect(m.cemeteryName, 'East Chapel');
      expect(m.memorialId, '42');
    });

    test('handles JSON-LD array wrapping', () async {
      final jsonLd = jsonEncode([
        {'@type': 'WebSite', 'name': 'Find A Grave'},
        {
          '@type': 'Person',
          'name': 'John Smith',
          'birthDate': '1900',
          'deathDate': '1970-01-01',
        },
      ]);
      final html =
          '<script type="application/ld+json">$jsonLd</script>';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('7');

      expect(m, isNotNull);
      expect(m!.fullName, 'John Smith');
      expect(m.birthYear, '1900');
      expect(m.deathYear, '1970');
    });

    test('returns null fields when JSON-LD fields absent', () async {
      final jsonLd = jsonEncode({'@type': 'Person'});
      final html =
          '<script type="application/ld+json">$jsonLd</script>';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('1');

      expect(m, isNotNull);
      expect(m!.fullName, isNull);
      expect(m.birthYear, isNull);
      expect(m.deathYear, isNull);
    });

    test('skips non-Person JSON-LD blocks and falls back to HTML regex', () async {
      final jsonLd = jsonEncode({'@type': 'WebSite', 'name': 'FAG'});
      final html = '''
<script type="application/ld+json">$jsonLd</script>
<meta property="og:title" content="Alice Brown - Memorial #8" />
<span itemprop="birthDate">1880</span>
''';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('8');

      expect(m, isNotNull);
      expect(m!.fullName, 'Alice Brown');
      expect(m.birthYear, '1880');
    });
  });

  // ── fetchMemorial — HTML regex fallback ──────────────────────────────────────
  group('FindAGraveService.fetchMemorial (HTML fallback strategy)', () {
    test('extracts name from og:title meta tag', () async {
      final html = '''
<html>
<meta property="og:title" content="George Washington - Memorial #1836" />
</html>
''';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('1836');

      expect(m, isNotNull);
      expect(m!.fullName, 'George Washington');
    });

    test('extracts birth year from itemprop="birthDate"', () async {
      final html =
          '<span itemprop="birthDate">February 22, 1732</span>';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('1');

      expect(m, isNotNull);
      expect(m!.birthYear, '1732');
    });

    test('extracts death year from itemprop="deathDate"', () async {
      final html =
          '<span itemprop="deathDate">December 14, 1799</span>';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('1');

      expect(m, isNotNull);
      expect(m!.deathYear, '1799');
    });

    test('extracts birth place from itemprop="birthPlace"', () async {
      final html = '<span itemprop="birthPlace">Westmoreland County, Virginia</span>';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('1');

      expect(m, isNotNull);
      expect(m!.birthPlace, 'Westmoreland County, Virginia');
    });

    test('returns null fields when HTML has no matching patterns', () async {
      final html = '<html><body><p>No data</p></body></html>';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('1');

      expect(m, isNotNull);
      expect(m!.fullName, isNull);
      expect(m.birthYear, isNull);
      expect(m.deathYear, isNull);
    });
  });

  // ── fetchMemorial — _placeFromSchema variants ─────────────────────────────
  group('FindAGraveService.fetchMemorial _placeFromSchema', () {
    test('handles birthPlace as plain string (not a Map)', () async {
      final jsonLd = jsonEncode({
        '@type': 'Person',
        'name': 'John Doe',
        'birthPlace': 'Dublin, Ireland',
      });
      final html =
          '<script type="application/ld+json">$jsonLd</script>';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('99');
      expect(m?.birthPlace, 'Dublin, Ireland');
    });

    test('handles birthPlace as Map with addressLocality', () async {
      final jsonLd = jsonEncode({
        '@type': 'Person',
        'birthPlace': {
          'address': {'addressLocality': 'Cork'},
        },
      });
      final html =
          '<script type="application/ld+json">$jsonLd</script>';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('100');
      expect(m?.birthPlace, 'Cork');
    });

    test('handles birthPlace as Map with address.name', () async {
      final jsonLd = jsonEncode({
        '@type': 'Person',
        'birthPlace': {
          'address': {'name': 'Galway'},
        },
      });
      final html =
          '<script type="application/ld+json">$jsonLd</script>';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('101');
      expect(m?.birthPlace, 'Galway');
    });

    test('handles null birthPlace returning null', () async {
      final jsonLd = jsonEncode({'@type': 'Person', 'birthPlace': null});
      final html =
          '<script type="application/ld+json">$jsonLd</script>';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('102');
      expect(m?.birthPlace, isNull);
    });
  });

  // ── fetchMemorial — HTML fallback additional cases ─────────────────────────
  group('FindAGraveService.fetchMemorial HTML fallback additional', () {
    test('extracts death place from itemprop="deathPlace"', () async {
      final html =
          '<span itemprop="deathPlace">Mount Vernon, Virginia</span>';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('2');
      expect(m?.deathPlace, 'Mount Vernon, Virginia');
    });

    test('extracts cemetery name from class="cemetery"', () async {
      final html =
          '<div class="cemetery-name">Arlington Cemetery</div>';
      final svc = _serviceWithHtml(html);
      final m = await svc.fetchMemorial('3');
      // The regex looks for class containing "cemetery"
      expect(m?.cemeteryName, 'Arlington Cemetery');
    });

    test('handles network exception returning null', () async {
      final client = MockClient((_) async => throw Exception('Network error'));
      final svc = FindAGraveService.withClient(client);
      expect(await svc.fetchMemorial('1'), isNull);
    });
  });
}
