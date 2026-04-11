import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/partnership.dart';

void main() {
  group('Partnership', () {
    group('constructor defaults', () {
      test('default status is married', () {
        final p = Partnership(id: '1', person1Id: 'a', person2Id: 'b');
        expect(p.status, 'married');
      });

      test('default dates and places are null', () {
        final p = Partnership(id: '1', person1Id: 'a', person2Id: 'b');
        expect(p.startDate, isNull);
        expect(p.startPlace, isNull);
        expect(p.endDate, isNull);
        expect(p.endPlace, isNull);
        expect(p.treeId, isNull);
      });
    });

    group('isEnded', () {
      test('married with no end date is not ended', () {
        final p = Partnership(id: '1', person1Id: 'a', person2Id: 'b');
        expect(p.isEnded, false);
      });

      test('partnered with no end date is not ended', () {
        final p = Partnership(
          id: '1',
          person1Id: 'a',
          person2Id: 'b',
          status: 'partnered',
        );
        expect(p.isEnded, false);
      });

      test('endDate set → isEnded true (regardless of status)', () {
        final p = Partnership(
          id: '1',
          person1Id: 'a',
          person2Id: 'b',
          endDate: DateTime(2020),
        );
        expect(p.isEnded, true);
      });

      test('status divorced → isEnded true', () {
        final p = Partnership(
          id: '1',
          person1Id: 'a',
          person2Id: 'b',
          status: 'divorced',
        );
        expect(p.isEnded, true);
      });

      test('status separated → isEnded true', () {
        final p = Partnership(
          id: '1',
          person1Id: 'a',
          person2Id: 'b',
          status: 'separated',
        );
        expect(p.isEnded, true);
      });

      test('status annulled → isEnded true', () {
        final p = Partnership(
          id: '1',
          person1Id: 'a',
          person2Id: 'b',
          status: 'annulled',
        );
        expect(p.isEnded, true);
      });
    });

    group('statusLabel', () {
      test('married → Married', () {
        expect(
          Partnership(id: '1', person1Id: 'a', person2Id: 'b').statusLabel,
          'Married',
        );
      });

      test('partnered → Partnered', () {
        expect(
          Partnership(
            id: '1',
            person1Id: 'a',
            person2Id: 'b',
            status: 'partnered',
          ).statusLabel,
          'Partnered',
        );
      });

      test('divorced → Divorced', () {
        expect(
          Partnership(
            id: '1',
            person1Id: 'a',
            person2Id: 'b',
            status: 'divorced',
          ).statusLabel,
          'Divorced',
        );
      });

      test('separated → Separated', () {
        expect(
          Partnership(
            id: '1',
            person1Id: 'a',
            person2Id: 'b',
            status: 'separated',
          ).statusLabel,
          'Separated',
        );
      });

      test('annulled → Annulled', () {
        expect(
          Partnership(
            id: '1',
            person1Id: 'a',
            person2Id: 'b',
            status: 'annulled',
          ).statusLabel,
          'Annulled',
        );
      });

      test('other → Other', () {
        expect(
          Partnership(
            id: '1',
            person1Id: 'a',
            person2Id: 'b',
            status: 'other',
          ).statusLabel,
          'Other',
        );
      });

      test('unknown status falls through to Other', () {
        expect(
          Partnership(
            id: '1',
            person1Id: 'a',
            person2Id: 'b',
            status: 'cohabiting',
          ).statusLabel,
          'Other',
        );
      });
    });

    group('allStatuses', () {
      test('contains all expected values', () {
        expect(
          Partnership.allStatuses,
          containsAll([
            'married',
            'partnered',
            'divorced',
            'separated',
            'annulled',
            'other',
          ]),
        );
      });
    });

    group('toMap / fromMap', () {
      test('full roundtrip preserves all fields', () {
        final original = Partnership(
          id: 'pt1',
          person1Id: 'p1',
          person2Id: 'p2',
          status: 'married',
          startDate: DateTime(2000, 6, 15),
          startPlace: 'New York',
          endDate: DateTime(2010, 3, 20),
          endPlace: 'London',
          treeId: 'tree1',
        );
        final restored = Partnership.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.person1Id, original.person1Id);
        expect(restored.person2Id, original.person2Id);
        expect(restored.status, original.status);
        expect(restored.startDate, original.startDate);
        expect(restored.startPlace, original.startPlace);
        expect(restored.endDate, original.endDate);
        expect(restored.endPlace, original.endPlace);
        expect(restored.treeId, original.treeId);
      });

      test('null status in map defaults to married', () {
        final map = <String, dynamic>{
          'id': '1',
          'person1Id': 'a',
          'person2Id': 'b',
          'status': null,
        };
        final p = Partnership.fromMap(map);
        expect(p.status, 'married');
      });

      test('null dates in map produce null fields', () {
        final map = <String, dynamic>{
          'id': '1',
          'person1Id': 'a',
          'person2Id': 'b',
          'status': 'married',
          'startDate': null,
          'endDate': null,
        };
        final p = Partnership.fromMap(map);
        expect(p.startDate, isNull);
        expect(p.endDate, isNull);
      });

      test('minimal map (only required fields) deserialises', () {
        final map = <String, dynamic>{
          'id': '42',
          'person1Id': 'x',
          'person2Id': 'y',
        };
        final p = Partnership.fromMap(map);
        expect(p.id, '42');
        expect(p.status, 'married');
      });

      test('notes and witnesses survive roundtrip', () {
        final original = Partnership(
          id: 'pt1',
          person1Id: 'a',
          person2Id: 'b',
          notes: 'Ceremony in Prague',
          witnesses: 'Jan Novák, Eva Nováková',
        );
        final r = Partnership.fromMap(original.toMap());
        expect(r.notes, 'Ceremony in Prague');
        expect(r.witnesses, 'Jan Novák, Eva Nováková');
      });

      test('null notes and witnesses survive roundtrip', () {
        final original = Partnership(id: 'pt1', person1Id: 'a', person2Id: 'b');
        final r = Partnership.fromMap(original.toMap());
        expect(r.notes, isNull);
        expect(r.witnesses, isNull);
      });

      test('ceremonyType survive roundtrip', () {
        for (final type in Partnership.allCeremonyTypes) {
          final p = Partnership(
            id: 'pt',
            person1Id: 'a',
            person2Id: 'b',
            ceremonyType: type,
          );
          expect(Partnership.fromMap(p.toMap()).ceremonyType, type);
        }
      });

      test('null ceremonyType survives roundtrip', () {
        final p = Partnership(id: 'pt', person1Id: 'a', person2Id: 'b');
        expect(Partnership.fromMap(p.toMap()).ceremonyType, isNull);
      });

      test('sourceIds serialise with comma separator and roundtrip correctly', () {
        final p = Partnership(
          id: 'pt',
          person1Id: 'a',
          person2Id: 'b',
          sourceIds: ['s1', 's2', 's3'],
        );
        final map = p.toMap();
        expect(map['sourceIds'], 's1,s2,s3');
        final r = Partnership.fromMap(map);
        expect(r.sourceIds, ['s1', 's2', 's3']);
      });

      test('empty sourceIds serialise to empty string and deserialise correctly',
          () {
        final p = Partnership(id: 'pt', person1Id: 'a', person2Id: 'b');
        final map = p.toMap();
        expect(map['sourceIds'], '');
        expect(Partnership.fromMap(map).sourceIds, isEmpty);
      });

      test('fromMap with null sourceIds returns empty list', () {
        final map = <String, dynamic>{
          'id': 'pt',
          'person1Id': 'a',
          'person2Id': 'b',
        };
        expect(Partnership.fromMap(map).sourceIds, isEmpty);
      });
    });

    group('allCeremonyTypes', () {
      test('contains all five expected types', () {
        expect(
          Partnership.allCeremonyTypes,
          containsAll(['civil', 'religious', 'traditional', 'common-law', 'other']),
        );
      });

      test('has exactly 5 entries', () {
        expect(Partnership.allCeremonyTypes.length, 5);
      });
    });
  });
}
