import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/memory.dart';

void main() {
  group('Memory Model', () {
    test('toMap and fromMap serialize and deserialize correctly with all fields', () {
      final memory = Memory(
        id: '1',
        personId: 'p1',
        title: 'Childhood memory',
        text: 'Lived in a small house near the woods.',
        date: '1990-01-01',
        place: 'Hometown',
        mediaUri: 'file://images/photo.png',
        treeId: 't1',
        updatedAt: 1620000000000,
      );

      final map = memory.toMap();
      expect(map['id'], '1');
      expect(map['personId'], 'p1');
      expect(map['title'], 'Childhood memory');
      expect(map['text'], 'Lived in a small house near the woods.');
      expect(map['date'], '1990-01-01');
      expect(map['place'], 'Hometown');
      expect(map['mediaUri'], 'file://images/photo.png');
      expect(map['treeId'], 't1');
      expect(map['updatedAt'], 1620000000000);

      final decoded = Memory.fromMap(map);
      expect(decoded.id, '1');
      expect(decoded.personId, 'p1');
      expect(decoded.title, 'Childhood memory');
      expect(decoded.text, 'Lived in a small house near the woods.');
      expect(decoded.date, '1990-01-01');
      expect(decoded.place, 'Hometown');
      expect(decoded.mediaUri, 'file://images/photo.png');
      expect(decoded.treeId, 't1');
      expect(decoded.updatedAt, 1620000000000);
    });

    test('toMap and fromMap handle null fields gracefully', () {
      final memory = Memory(
        id: '2',
        personId: 'p2',
        title: 'Another memory',
        text: 'Some short text',
      );

      final map = memory.toMap();
      expect(map['date'], isNull);
      expect(map['place'], isNull);
      expect(map['mediaUri'], isNull);
      expect(map['treeId'], isNull);
      expect(map['updatedAt'], isNull);

      final decoded = Memory.fromMap(map);
      expect(decoded.date, isNull);
      expect(decoded.place, isNull);
      expect(decoded.mediaUri, isNull);
      expect(decoded.treeId, isNull);
      expect(decoded.updatedAt, isNull);
    });
  });
}
