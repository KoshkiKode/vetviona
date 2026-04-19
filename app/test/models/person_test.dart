import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/geo_coord.dart';
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

      test(
        'empty lists serialise to empty strings and deserialise correctly',
        () {
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
        },
      );

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

    group('new optional fields — defaults', () {
      test('occupation, nationality, maidenName default to null', () {
        final p = Person(id: 'x', name: 'X');
        expect(p.occupation, isNull);
        expect(p.nationality, isNull);
        expect(p.maidenName, isNull);
      });

      test('burialDate, burialPlace default to null', () {
        final p = Person(id: 'x', name: 'X');
        expect(p.burialDate, isNull);
        expect(p.burialPlace, isNull);
      });

      test('coord fields default to null', () {
        final p = Person(id: 'x', name: 'X');
        expect(p.birthCoord, isNull);
        expect(p.deathCoord, isNull);
        expect(p.burialCoord, isNull);
      });

      test('postal code fields default to null', () {
        final p = Person(id: 'x', name: 'X');
        expect(p.birthPostalCode, isNull);
        expect(p.deathPostalCode, isNull);
        expect(p.burialPostalCode, isNull);
      });

      test('isPrivate defaults to false', () {
        final p = Person(id: 'x', name: 'X');
        expect(p.isPrivate, false);
      });

      test('v7 extended fields default to null', () {
        final p = Person(id: 'x', name: 'X');
        expect(p.causeOfDeath, isNull);
        expect(p.bloodType, isNull);
        expect(p.eyeColour, isNull);
        expect(p.hairColour, isNull);
        expect(p.height, isNull);
        expect(p.religion, isNull);
        expect(p.education, isNull);
      });

      test('aliases defaults to empty list', () {
        final p = Person(id: 'x', name: 'X');
        expect(p.aliases, isEmpty);
      });

      test('preferredSourceIds defaults to empty map', () {
        final p = Person(id: 'x', name: 'X');
        expect(p.preferredSourceIds, isEmpty);
      });

      test('syncMedical defaults to false', () {
        final p = Person(id: 'x', name: 'X');
        expect(p.syncMedical, false);
      });

      test('wikitreeId defaults to null', () {
        final p = Person(id: 'x', name: 'X');
        expect(p.wikitreeId, isNull);
      });

      test('findAGraveId defaults to null', () {
        final p = Person(id: 'x', name: 'X');
        expect(p.findAGraveId, isNull);
      });

      test('familySearchId defaults to null', () {
        final p = Person(id: 'x', name: 'X');
        expect(p.familySearchId, isNull);
      });
    });

    group('allBloodTypes', () {
      test('contains all expected ABO/Rh types', () {
        expect(
          Person.allBloodTypes,
          containsAll([
            'A+',
            'A-',
            'B+',
            'B-',
            'O+',
            'O-',
            'AB+',
            'AB-',
            'Unknown',
          ]),
        );
      });

      test('has exactly 9 entries', () {
        expect(Person.allBloodTypes.length, 9);
      });
    });

    group('toMap / fromMap — extended fields', () {
      test('occupation, nationality, maidenName survive roundtrip', () {
        final p = Person(
          id: 'x',
          name: 'Alice',
          occupation: 'Nurse',
          nationality: 'British',
          maidenName: 'Jones',
        );
        final r = Person.fromMap(p.toMap());
        expect(r.occupation, 'Nurse');
        expect(r.nationality, 'British');
        expect(r.maidenName, 'Jones');
      });

      test('burialDate and burialPlace survive roundtrip', () {
        final p = Person(
          id: 'x',
          name: 'Bob',
          burialDate: DateTime(1980, 4, 12),
          burialPlace: 'Highgate Cemetery',
        );
        final r = Person.fromMap(p.toMap());
        expect(r.burialDate, DateTime(1980, 4, 12));
        expect(r.burialPlace, 'Highgate Cemetery');
      });

      test('isPrivate serialises as 1 and deserialises as true', () {
        final p = Person(id: 'x', name: 'Private', isPrivate: true);
        final map = p.toMap();
        expect(map['isPrivate'], 1);
        expect(Person.fromMap(map).isPrivate, true);
      });

      test('isPrivate false serialises as 0 and deserialises as false', () {
        final p = Person(id: 'x', name: 'Public');
        final map = p.toMap();
        expect(map['isPrivate'], 0);
        expect(Person.fromMap(map).isPrivate, false);
      });

      test('fromMap with null isPrivate defaults to false', () {
        final map = <String, dynamic>{
          'id': 'x',
          'name': 'T',
          'isPrivate': null,
        };
        expect(Person.fromMap(map).isPrivate, false);
      });

      test('v7 extended fields survive roundtrip', () {
        final p = Person(
          id: 'x',
          name: 'Alice',
          causeOfDeath: 'cardiac arrest',
          bloodType: 'A+',
          eyeColour: 'brown',
          hairColour: 'auburn',
          height: '172 cm',
          religion: 'Catholic',
          education: "Bachelor's degree",
        );
        final r = Person.fromMap(p.toMap());
        expect(r.causeOfDeath, 'cardiac arrest');
        expect(r.bloodType, 'A+');
        expect(r.eyeColour, 'brown');
        expect(r.hairColour, 'auburn');
        expect(r.height, '172 cm');
        expect(r.religion, 'Catholic');
        expect(r.education, "Bachelor's degree");
      });

      test('aliases serialise with semicolon separator', () {
        final p = Person(id: 'x', name: 'Alice', aliases: ['Ally', 'Ali']);
        final map = p.toMap();
        expect(map['aliases'], 'Ally;Ali');
        final r = Person.fromMap(map);
        expect(r.aliases, ['Ally', 'Ali']);
      });

      test(
        'empty aliases serialises to empty string and deserialises correctly',
        () {
          final p = Person(id: 'x', name: 'X');
          final map = p.toMap();
          expect(map['aliases'], '');
          expect(Person.fromMap(map).aliases, isEmpty);
        },
      );

      test('fromMap with null aliases returns empty list', () {
        final map = <String, dynamic>{'id': 'x', 'name': 'T'};
        expect(Person.fromMap(map).aliases, isEmpty);
      });

      test('preferredSourceIds survive roundtrip', () {
        final p = Person(
          id: 'x',
          name: 'Alice',
          preferredSourceIds: {'Birth Date': 'src1', 'Death Place': 'src2'},
        );
        final r = Person.fromMap(p.toMap());
        expect(r.preferredSourceIds['Birth Date'], 'src1');
        expect(r.preferredSourceIds['Death Place'], 'src2');
      });

      test('preferredSourceIds empty map roundtrip', () {
        final p = Person(id: 'x', name: 'X');
        final r = Person.fromMap(p.toMap());
        expect(r.preferredSourceIds, isEmpty);
      });

      test('syncMedical survives roundtrip (true)', () {
        final p = Person(id: 'x', name: 'Alice', syncMedical: true);
        final r = Person.fromMap(p.toMap());
        expect(r.syncMedical, isTrue);
      });

      test('syncMedical survives roundtrip (false)', () {
        final p = Person(id: 'x', name: 'Alice');
        final r = Person.fromMap(p.toMap());
        expect(r.syncMedical, isFalse);
      });

      test('fromMap with null syncMedical defaults to false', () {
        final map = <String, dynamic>{'id': 'x', 'name': 'T'};
        expect(Person.fromMap(map).syncMedical, isFalse);
      });

      test('wikitreeId survives roundtrip', () {
        final p = Person(id: 'x', name: 'Winston', wikitreeId: 'Churchill-4');
        final r = Person.fromMap(p.toMap());
        expect(r.wikitreeId, 'Churchill-4');
      });

      test('null wikitreeId roundtrips to null', () {
        final p = Person(id: 'x', name: 'X');
        final r = Person.fromMap(p.toMap());
        expect(r.wikitreeId, isNull);
      });

      test('findAGraveId survives roundtrip', () {
        final p = Person(id: 'x', name: 'Jane', findAGraveId: '1836');
        final r = Person.fromMap(p.toMap());
        expect(r.findAGraveId, '1836');
      });

      test('null findAGraveId roundtrips to null', () {
        final p = Person(id: 'x', name: 'X');
        final r = Person.fromMap(p.toMap());
        expect(r.findAGraveId, isNull);
      });

      test('familySearchId survives roundtrip', () {
        final p = Person(id: 'x', name: 'Jane', familySearchId: 'KW7S-BBQ');
        final r = Person.fromMap(p.toMap());
        expect(r.familySearchId, 'KW7S-BBQ');
      });

      test('null familySearchId roundtrips to null', () {
        final p = Person(id: 'x', name: 'X');
        final r = Person.fromMap(p.toMap());
        expect(r.familySearchId, isNull);
      });

      test('postal code fields survive roundtrip', () {
        final p = Person(
          id: 'x',
          name: 'Alice',
          birthPostalCode: 'EC1A 1BB',
          deathPostalCode: '75001',
          burialPostalCode: 'N6 6PJ',
        );
        final r = Person.fromMap(p.toMap());
        expect(r.birthPostalCode, 'EC1A 1BB');
        expect(r.deathPostalCode, '75001');
        expect(r.burialPostalCode, 'N6 6PJ');
      });

      test('coord fields survive roundtrip via GeoCoord.toDbString', () {
        const coord = GeoCoord(lat: 51.5074, lng: -0.1278, city: 'London');
        final p = Person(id: 'x', name: 'Alice', birthCoord: coord);
        final r = Person.fromMap(p.toMap());
        expect(r.birthCoord, isNotNull);
        expect(r.birthCoord!.lat, closeTo(51.5074, 0.0001));
        expect(r.birthCoord!.lng, closeTo(-0.1278, 0.0001));
        expect(r.birthCoord!.city, 'London');
      });

      test('null coord fields roundtrip to null', () {
        final p = Person(id: 'x', name: 'X');
        final r = Person.fromMap(p.toMap());
        expect(r.birthCoord, isNull);
        expect(r.deathCoord, isNull);
        expect(r.burialCoord, isNull);
      });

      test('full extended-field roundtrip preserves every field', () {
        const coord = GeoCoord(lat: 48.8566, lng: 2.3522, city: 'Paris');
        final original = Person(
          id: 'full-001',
          name: 'Marie Dupont',
          birthDate: DateTime(1945, 6, 1),
          birthPlace: 'Paris',
          deathDate: DateTime(2010, 11, 15),
          deathPlace: 'Lyon',
          gender: 'F',
          parentIds: ['p1'],
          childIds: ['c1'],
          parentRelTypes: {'p1': 'biological'},
          photoPaths: ['photo.jpg'],
          sourceIds: ['s1'],
          notes: 'Lived in Paris',
          treeId: 'tree1',
          occupation: 'Teacher',
          nationality: 'French',
          maidenName: 'Martin',
          burialDate: DateTime(2010, 11, 18),
          burialPlace: 'Père Lachaise',
          birthCoord: coord,
          birthPostalCode: '75001',
          isPrivate: false,
          causeOfDeath: 'natural causes',
          bloodType: 'B+',
          eyeColour: 'green',
          hairColour: 'black',
          height: '165 cm',
          religion: 'Catholic',
          education: "Master's degree",
          aliases: ['Marie Martin', 'Mme Dupont'],
          preferredSourceIds: {'Birth Date': 's1'},
          syncMedical: true,
          updatedAt: 1700000000000,
          wikitreeId: 'Dupont-42',
          findAGraveId: '9876',
          familySearchId: 'KW7S-BBQ',
        );
        final r = Person.fromMap(original.toMap());
        expect(r.occupation, original.occupation);
        expect(r.nationality, original.nationality);
        expect(r.maidenName, original.maidenName);
        expect(r.burialDate, original.burialDate);
        expect(r.burialPlace, original.burialPlace);
        expect(r.birthPostalCode, original.birthPostalCode);
        expect(r.isPrivate, original.isPrivate);
        expect(r.causeOfDeath, original.causeOfDeath);
        expect(r.bloodType, original.bloodType);
        expect(r.eyeColour, original.eyeColour);
        expect(r.hairColour, original.hairColour);
        expect(r.height, original.height);
        expect(r.religion, original.religion);
        expect(r.education, original.education);
        expect(r.aliases, original.aliases);
        expect(r.preferredSourceIds, original.preferredSourceIds);
        expect(r.syncMedical, original.syncMedical);
        expect(r.updatedAt, original.updatedAt);
        expect(r.wikitreeId, original.wikitreeId);
        expect(r.findAGraveId, original.findAGraveId);
        expect(r.familySearchId, original.familySearchId);
      });
    });
  });
}
