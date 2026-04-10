import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/source.dart';

void main() {
  group('Source', () {
    group('constructor defaults', () {
      test('citedFacts defaults to empty list', () {
        final s = Source(
          id: '1',
          personId: 'p1',
          title: 'Title',
          type: 'document',
          url: 'http://example.com',
        );
        expect(s.citedFacts, isEmpty);
      });

      test('optional fields default to null', () {
        final s = Source(
          id: '1',
          personId: 'p1',
          title: 'Title',
          type: 'document',
          url: 'http://example.com',
        );
        expect(s.imagePath, isNull);
        expect(s.extractedInfo, isNull);
      });
    });

    group('toMap / fromMap', () {
      test('full roundtrip preserves all fields', () {
        final original = Source(
          id: 's1',
          personId: 'p1',
          title: 'Birth Certificate',
          type: 'document',
          url: 'http://example.com/cert',
          imagePath: '/path/image.jpg',
          extractedInfo: 'Born 15 May 1990',
          citedFacts: ['birthDate', 'birthPlace'],
        );
        final restored = Source.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.personId, original.personId);
        expect(restored.title, original.title);
        expect(restored.type, original.type);
        expect(restored.url, original.url);
        expect(restored.imagePath, original.imagePath);
        expect(restored.extractedInfo, original.extractedInfo);
        expect(restored.citedFacts, original.citedFacts);
      });

      test('empty citedFacts serialises to empty string', () {
        final s = Source(
          id: 's1',
          personId: 'p1',
          title: 'T',
          type: 'doc',
          url: 'http://x',
        );
        expect(s.toMap()['citedFacts'], '');
      });

      test('fromMap with empty citedFacts string returns empty list', () {
        final map = <String, dynamic>{
          'id': 's1',
          'personId': 'p1',
          'title': 'T',
          'type': 'doc',
          'url': 'http://x',
          'citedFacts': '',
        };
        expect(Source.fromMap(map).citedFacts, isEmpty);
      });

      test('fromMap with null citedFacts returns empty list', () {
        final map = <String, dynamic>{
          'id': 's1',
          'personId': 'p1',
          'title': 'T',
          'type': 'doc',
          'url': 'http://x',
        };
        expect(Source.fromMap(map).citedFacts, isEmpty);
      });

      test('multiple citedFacts survive roundtrip', () {
        final original = Source(
          id: 's1',
          personId: 'p1',
          title: 'T',
          type: 'doc',
          url: 'http://x',
          citedFacts: ['birthDate', 'birthPlace', 'name'],
        );
        final restored = Source.fromMap(original.toMap());
        expect(restored.citedFacts, ['birthDate', 'birthPlace', 'name']);
      });

      test('null imagePath and extractedInfo survive roundtrip', () {
        final original = Source(
          id: 's1',
          personId: 'p1',
          title: 'T',
          type: 'doc',
          url: 'http://x',
        );
        final restored = Source.fromMap(original.toMap());
        expect(restored.imagePath, isNull);
        expect(restored.extractedInfo, isNull);
      });
    });
  });
}
