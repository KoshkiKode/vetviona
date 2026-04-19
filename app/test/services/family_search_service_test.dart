import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/services/family_search_service.dart';

void main() {
  group('FamilySearchService', () {
    final svc = FamilySearchService.instance;

    test('personUrl builds canonical details URL', () {
      expect(
        svc.personUrl('KW7S-BBQ'),
        'https://www.familysearch.org/tree/person/details/KW7S-BBQ',
      );
    });

    test('extractPersonId extracts id from FamilySearch URL', () {
      expect(
        svc.extractPersonId(
          'https://www.familysearch.org/tree/person/details/KW7S-BBQ',
        ),
        'KW7S-BBQ',
      );
    });

    test('extractPersonId accepts direct person id', () {
      expect(svc.extractPersonId('LZ2F-123'), 'LZ2F-123');
    });

    test('extractPersonId returns null for invalid input', () {
      expect(svc.extractPersonId('https://example.com/person/123'), isNull);
      expect(svc.extractPersonId(''), isNull);
    });

    test('personToSource creates Online Database source', () {
      final source = svc.personToSource('KW7S-BBQ', 'person-1');
      expect(source.title, 'FamilySearch person KW7S-BBQ');
      expect(source.type, 'Online Database');
      expect(
        source.url,
        'https://www.familysearch.org/tree/person/details/KW7S-BBQ',
      );
      expect(source.personId, 'person-1');
      expect(source.repository, contains('familysearch.org'));
    });
  });
}
