import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/life_event.dart';

void main() {
  group('LifeEvent', () {
    group('constructor defaults', () {
      test('optional fields default to null', () {
        final e = LifeEvent(id: 'e1', personId: 'p1', title: 'Baptism');
        expect(e.date, isNull);
        expect(e.place, isNull);
        expect(e.notes, isNull);
        expect(e.treeId, isNull);
      });

      test('required fields are stored correctly', () {
        final e = LifeEvent(id: 'e1', personId: 'p1', title: 'Graduation');
        expect(e.id, 'e1');
        expect(e.personId, 'p1');
        expect(e.title, 'Graduation');
      });
    });

    group('commonTypes', () {
      test('list is non-empty', () {
        expect(LifeEvent.commonTypes, isNotEmpty);
      });

      test('contains expected event types', () {
        expect(
          LifeEvent.commonTypes,
          containsAll([
            'Baptism',
            'Graduation',
            'Immigration',
            'Emigration',
            'Residence',
            'Other',
          ]),
        );
      });
    });

    group('toMap / fromMap', () {
      test('full roundtrip preserves all fields', () {
        final original = LifeEvent(
          id: 'ev-1',
          personId: 'p-42',
          title: 'Immigration',
          date: DateTime(1920, 3, 15),
          place: 'Ellis Island, New York',
          notes: 'Arrived from Poland',
          treeId: 'tree-1',
        );
        final restored = LifeEvent.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.personId, original.personId);
        expect(restored.title, original.title);
        expect(restored.date, original.date);
        expect(restored.place, original.place);
        expect(restored.notes, original.notes);
        expect(restored.treeId, original.treeId);
      });

      test('null optional fields survive roundtrip', () {
        final original = LifeEvent(
          id: 'ev-2',
          personId: 'p-1',
          title: 'Census',
        );
        final restored = LifeEvent.fromMap(original.toMap());

        expect(restored.date, isNull);
        expect(restored.place, isNull);
        expect(restored.notes, isNull);
        expect(restored.treeId, isNull);
      });

      test('toMap produces correct keys', () {
        final e = LifeEvent(
          id: 'ev-3',
          personId: 'p-2',
          title: 'Military Service',
          date: DateTime(1944, 6, 6),
          place: 'Normandy, France',
        );
        final map = e.toMap();

        expect(map['id'], 'ev-3');
        expect(map['personId'], 'p-2');
        expect(map['title'], 'Military Service');
        expect(map['date'], DateTime(1944, 6, 6).toIso8601String());
        expect(map['place'], 'Normandy, France');
      });

      test('fromMap with null date returns null date field', () {
        final map = <String, dynamic>{
          'id': 'ev-4',
          'personId': 'p-3',
          'title': 'Residence',
          'date': null,
        };
        final e = LifeEvent.fromMap(map);
        expect(e.date, isNull);
      });

      test('date stored as ISO-8601 string in map', () {
        final date = DateTime(1985, 12, 31);
        final e = LifeEvent(id: 'e', personId: 'p', title: 'T', date: date);
        final map = e.toMap();
        expect(map['date'], date.toIso8601String());
      });

      test('minimal map (only required fields) deserialises without error', () {
        final map = <String, dynamic>{
          'id': 'ev-5',
          'personId': 'p-5',
          'title': 'Other',
        };
        final e = LifeEvent.fromMap(map);
        expect(e.id, 'ev-5');
        expect(e.personId, 'p-5');
        expect(e.title, 'Other');
      });
    });
  });
}
