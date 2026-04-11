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

      test('citation fields survive roundtrip', () {
        final original = Source(
          id: 's1',
          personId: 'p1',
          title: 'Marriage Register',
          type: 'register',
          url: 'http://archives.example.com/reg',
          author: 'John Smith',
          publisher: 'State Archives',
          publicationDate: 'Jan 1920',
          repository: 'National Archives',
          volumePage: 'Vol. 3, p. 45',
          retrievalDate: '15 Mar 2024',
          confidence: 'A',
          treeId: 'tree1',
        );
        final r = Source.fromMap(original.toMap());
        expect(r.author, 'John Smith');
        expect(r.publisher, 'State Archives');
        expect(r.publicationDate, 'Jan 1920');
        expect(r.repository, 'National Archives');
        expect(r.volumePage, 'Vol. 3, p. 45');
        expect(r.retrievalDate, '15 Mar 2024');
        expect(r.confidence, 'A');
        expect(r.treeId, 'tree1');
      });

      test('null citation fields survive roundtrip', () {
        final original = Source(
          id: 's1',
          personId: 'p1',
          title: 'T',
          type: 'doc',
          url: 'http://x',
        );
        final r = Source.fromMap(original.toMap());
        expect(r.author, isNull);
        expect(r.publisher, isNull);
        expect(r.publicationDate, isNull);
        expect(r.repository, isNull);
        expect(r.volumePage, isNull);
        expect(r.retrievalDate, isNull);
        expect(r.confidence, isNull);
        expect(r.treeId, isNull);
      });

      test('all confidence ratings survive roundtrip', () {
        for (final rating in Source.confidenceRatings) {
          final s = Source(
            id: 's1',
            personId: 'p1',
            title: 'T',
            type: 'doc',
            url: 'http://x',
            confidence: rating,
          );
          expect(Source.fromMap(s.toMap()).confidence, rating);
        }
      });

      test('fromMap with minimal map leaves citation fields null', () {
        final map = <String, dynamic>{
          'id': 's1',
          'personId': 'p1',
          'title': 'T',
          'type': 'doc',
          'url': 'http://x',
        };
        final s = Source.fromMap(map);
        expect(s.author, isNull);
        expect(s.publisher, isNull);
        expect(s.confidence, isNull);
        expect(s.treeId, isNull);
      });
    });

    group('confidenceRatings', () {
      test('contains all five letter grades', () {
        expect(
          Source.confidenceRatings,
          containsAll(['A', 'B', 'C', 'D', 'F']),
        );
      });

      test('has exactly 5 entries', () {
        expect(Source.confidenceRatings.length, 5);
      });
    });

    group('confidenceLabels', () {
      test('every confidenceRating has a label', () {
        for (final rating in Source.confidenceRatings) {
          expect(
            Source.confidenceLabels.containsKey(rating),
            true,
            reason: '"$rating" has no label',
          );
        }
      });

      test('label values are non-empty strings', () {
        for (final label in Source.confidenceLabels.values) {
          expect(label, isNotEmpty);
        }
      });

      test('A maps to Reliable', () {
        expect(Source.confidenceLabels['A'], 'Reliable');
      });

      test('F maps to Conflicting', () {
        expect(Source.confidenceLabels['F'], 'Conflicting');
      });
    });

    group('constructor defaults — optional citation fields', () {
      test('all citation optional fields default to null', () {
        final s = Source(
          id: '1',
          personId: 'p1',
          title: 'T',
          type: 'doc',
          url: 'http://x',
        );
        expect(s.author, isNull);
        expect(s.publisher, isNull);
        expect(s.publicationDate, isNull);
        expect(s.repository, isNull);
        expect(s.volumePage, isNull);
        expect(s.retrievalDate, isNull);
        expect(s.confidence, isNull);
        expect(s.treeId, isNull);
      });
    });
  });
}
