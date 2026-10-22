import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/record_hint.dart';

void main() {
  group('RecordHint Model', () {
    test('toMap and fromMap serialize and deserialize correctly with all fields', () {
      final hint = RecordHint(
        id: '1',
        personId: 'p1',
        apiSource: 'familysearch',
        externalRecordId: 'fs123',
        title: '1940 US Census',
        summary: 'John Doe born 1910',
        recordUrl: 'https://familysearch.org/123',
        imageUrl: 'https://familysearch.org/image.png',
        confidence: 0.95,
        status: 'accepted',
        treeId: 't1',
        discoveredAt: 1600000000000,
        resolvedAt: 1610000000000,
        updatedAt: 1620000000000,
      );

      final map = hint.toMap();
      expect(map['id'], '1');
      expect(map['personId'], 'p1');
      expect(map['apiSource'], 'familysearch');
      expect(map['externalRecordId'], 'fs123');
      expect(map['title'], '1940 US Census');
      expect(map['summary'], 'John Doe born 1910');
      expect(map['recordUrl'], 'https://familysearch.org/123');
      expect(map['imageUrl'], 'https://familysearch.org/image.png');
      expect(map['confidence'], 0.95);
      expect(map['status'], 'accepted');
      expect(map['treeId'], 't1');
      expect(map['discoveredAt'], 1600000000000);
      expect(map['resolvedAt'], 1610000000000);
      expect(map['updatedAt'], 1620000000000);

      final decoded = RecordHint.fromMap(map);
      expect(decoded.id, '1');
      expect(decoded.personId, 'p1');
      expect(decoded.apiSource, 'familysearch');
      expect(decoded.externalRecordId, 'fs123');
      expect(decoded.title, '1940 US Census');
      expect(decoded.summary, 'John Doe born 1910');
      expect(decoded.recordUrl, 'https://familysearch.org/123');
      expect(decoded.imageUrl, 'https://familysearch.org/image.png');
      expect(decoded.confidence, 0.95);
      expect(decoded.status, 'accepted');
      expect(decoded.treeId, 't1');
      expect(decoded.discoveredAt, 1600000000000);
      expect(decoded.resolvedAt, 1610000000000);
      expect(decoded.updatedAt, 1620000000000);
    });

    test('toMap and fromMap apply defaults for missing fields', () {
      final hint = RecordHint(
        id: '2',
        personId: 'p2',
        apiSource: 'wikitree',
        externalRecordId: 'wt456',
        title: 'Death Certificate',
        recordUrl: 'https://wikitree.com/456',
      );

      final map = hint.toMap();
      final decoded = RecordHint.fromMap(map);
      
      expect(decoded.confidence, 0.5);
      expect(decoded.status, 'pending');
      expect(decoded.summary, isNull);
    });

    test('Helper getters return correct booleans', () {
      final pendingHint = RecordHint(
        id: '1', personId: 'p1', apiSource: 'test',
        externalRecordId: '1', title: 'test', recordUrl: 'test', status: 'pending'
      );
      expect(pendingHint.isPending, isTrue);
      expect(pendingHint.isAccepted, isFalse);
      expect(pendingHint.isDismissed, isFalse);

      final acceptedHint = RecordHint(
        id: '2', personId: 'p1', apiSource: 'test',
        externalRecordId: '1', title: 'test', recordUrl: 'test', status: 'accepted'
      );
      expect(acceptedHint.isPending, isFalse);
      expect(acceptedHint.isAccepted, isTrue);
      expect(acceptedHint.isDismissed, isFalse);

      final dismissedHint = RecordHint(
        id: '3', personId: 'p1', apiSource: 'test',
        externalRecordId: '1', title: 'test', recordUrl: 'test', status: 'dismissed'
      );
      expect(dismissedHint.isPending, isFalse);
      expect(dismissedHint.isAccepted, isFalse);
      expect(dismissedHint.isDismissed, isTrue);
    });

    test('confidenceLabel returns correct strings', () {
      final h = RecordHint(id: '1', personId: '1', apiSource: 'a', externalRecordId: '1', title: 't', recordUrl: 'u');
      
      h.confidence = 0.95;
      expect(h.confidenceLabel, 'Very High');
      
      h.confidence = 0.75;
      expect(h.confidenceLabel, 'High');
      
      h.confidence = 0.55;
      expect(h.confidenceLabel, 'Medium');
      
      h.confidence = 0.35;
      expect(h.confidenceLabel, 'Low');
      
      h.confidence = 0.1;
      expect(h.confidenceLabel, 'Very Low');
    });
  });
}
