import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/person.dart';

void main() {
  group('Person', () {
    group('constructor defaults', () {
      test('optional lists default to empty', () {
        final p = Person(id: 'id1', name: 'Alice');
        expect(p.parentIds, isEmpty);
        expect(p.childIds, isEmpty);
        expect(p.parentRelTypes, isEmpty);
        expect(p.photoPaths, isEmpty);
        expect(p.sourceIds, isEmpty);
      });

      test('optional nullable fields default to null', () {
        final p = Person(id: 'id1', name: 'Alice');
        expect(p.birthDate, isNull);
        expect(p.birthPlace, isNull);
        expect(p.deathDate, isNull);
        expect(p.deathPlace, isNull);
        expect(p.gender, isNull);
        expect(p.notes, isNull);
        expect(p.treeId, isNull);
      });
    });

    group('parentRelType', () {
      test('returns biological when no entry exists', () {
        final p = Person(id: 'id1', name: 'Alice');
        expect(p.parentRelType('unknownParent'), 'biological');
      });

      test('returns the stored type for a known parent', () {
        final p = Person(
          id: 'id1',
          name: 'Alice',
          parentRelTypes: {'p1': 'adoptive', 'p2': 'step'},
        );
        expect(p.parentRelType('p1'), 'adoptive');
        expect(p.parentRelType('p2'), 'step');
      });
    });

    group('relTypeLabel', () {
      test('all known types', () {
        expect(Person.relTypeLabel('biological'), 'Biological');
        expect(Person.relTypeLabel('adoptive'), 'Adoptive');
        expect(Person.relTypeLabel('step'), 'Step');
        expect(Person.relTypeLabel('foster'), 'Foster');
        expect(Person.relTypeLabel('unknown'), 'Unknown');
      });

      test('unknown type falls through to Unknown', () {
        expect(Person.relTypeLabel('anything_else'), 'Unknown');
        expect(Person.relTypeLabel(''), 'Unknown');
      });
    });

    group('allParentRelTypes', () {
      test('contains all five supported types', () {
        expect(
          Person.allParentRelTypes,
          containsAll(['biological', 'adoptive', 'step', 'foster', 'unknown']),
        );
      });
    });

    group('toMap / fromMap', () {
      test('full roundtrip preserves all fields', () {
        final original = Person(
          id: 'abc-123',
          name: 'John Doe',
          birthDate: DateTime(1990, 5, 15),
          birthPlace: 'London',
          deathDate: DateTime(2060, 1, 1),
          deathPlace: 'Paris',
          gender: 'M',
          parentIds: ['p1', 'p2'],
          childIds: ['c1', 'c2'],
          parentRelTypes: {'p1': 'biological', 'p2': 'adoptive'},
          photoPaths: ['photo1.jpg', 'photo2.jpg'],
          sourceIds: ['s1', 's2'],
          notes: 'Some notes here',
          treeId: 'tree1',
        );
        final restored = Person.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.birthDate, original.birthDate);
        expect(restored.birthPlace, original.birthPlace);
        expect(restored.deathDate, original.deathDate);
        expect(restored.deathPlace, original.deathPlace);
        expect(restored.gender, original.gender);
        expect(restored.parentIds, original.parentIds);
        expect(restored.childIds, original.childIds);
        expect(restored.parentRelTypes, original.parentRelTypes);
        expect(restored.photoPaths, original.photoPaths);
        expect(restored.sourceIds, original.sourceIds);
        expect(restored.notes, original.notes);
        expect(restored.treeId, original.treeId);
      });

      test('empty lists serialise to empty strings and deserialise correctly', () {
        final p = Person(id: 'x', name: 'X');
        final map = p.toMap();
        expect(map['parentIds'], '');
        expect(map['childIds'], '');
        expect(map['photoPaths'], '');
        expect(map['sourceIds'], '');
        expect(map['parentRelTypes'], '');

        final restored = Person.fromMap(map);
        expect(restored.parentIds, isEmpty);
        expect(restored.childIds, isEmpty);
        expect(restored.photoPaths, isEmpty);
        expect(restored.sourceIds, isEmpty);
        expect(restored.parentRelTypes, isEmpty);
      });

      test('fromMap with null list fields returns empty lists', () {
        final map = <String, dynamic>{'id': 'x', 'name': 'Test'};
        final p = Person.fromMap(map);
        expect(p.parentIds, isEmpty);
        expect(p.childIds, isEmpty);
        expect(p.photoPaths, isEmpty);
        expect(p.sourceIds, isEmpty);
        expect(p.parentRelTypes, isEmpty);
      });

      test('fromMap with null dates returns null', () {
        final map = <String, dynamic>{
          'id': 'x',
          'name': 'Test',
          'birthDate': null,
          'deathDate': null,
        };
        final p = Person.fromMap(map);
        expect(p.birthDate, isNull);
        expect(p.deathDate, isNull);
      });

      test('parentRelTypes encoding includes key=value pairs', () {
        final p = Person(
          id: 'id1',
          name: 'Alice',
          parentRelTypes: {'p1': 'biological', 'p2': 'foster'},
        );
        final encoded = p.toMap()['parentRelTypes'] as String;
        expect(encoded, contains('p1=biological'));
        expect(encoded, contains('p2=foster'));
      });

      test('multiple photoPaths serialise with semicolon separator', () {
        final p = Person(
          id: 'id1',
          name: 'Alice',
          photoPaths: ['a.jpg', 'b.jpg', 'c.jpg'],
        );
        final map = p.toMap();
        expect(map['photoPaths'], 'a.jpg;b.jpg;c.jpg');
        final restored = Person.fromMap(map);
        expect(restored.photoPaths, ['a.jpg', 'b.jpg', 'c.jpg']);
      });

      test('multiple sourceIds / parentIds serialise with comma separator', () {
        final p = Person(
          id: 'id1',
          name: 'Alice',
          parentIds: ['par1', 'par2'],
          sourceIds: ['src1', 'src2'],
        );
        final map = p.toMap();
        expect(map['parentIds'], 'par1,par2');
        expect(map['sourceIds'], 'src1,src2');
      });
    });
  });
}
