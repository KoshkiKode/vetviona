import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/heritage.dart';

void main() {
  group('Heritage Model', () {
    test('toMap and fromMap serialize and deserialize correctly with all fields', () {
      final heritage = Heritage(
        id: '1',
        personId: 'p1',
        region: 'Scandinavian',
        percentage: 45.5,
        notes: 'From 23andMe',
        dnaService: '23andMe',
        dnaResultsUrl: 'https://example.com/results',
        treeId: 't1',
        updatedAt: 1620000000000,
      );

      final map = heritage.toMap();
      expect(map['id'], '1');
      expect(map['personId'], 'p1');
      expect(map['region'], 'Scandinavian');
      expect(map['percentage'], 45.5);
      expect(map['notes'], 'From 23andMe');
      expect(map['dnaService'], '23andMe');
      expect(map['dnaResultsUrl'], 'https://example.com/results');
      expect(map['treeId'], 't1');
      expect(map['updatedAt'], 1620000000000);

      final decoded = Heritage.fromMap(map);
      expect(decoded.id, '1');
      expect(decoded.personId, 'p1');
      expect(decoded.region, 'Scandinavian');
      expect(decoded.percentage, 45.5);
      expect(decoded.notes, 'From 23andMe');
      expect(decoded.dnaService, '23andMe');
      expect(decoded.dnaResultsUrl, 'https://example.com/results');
      expect(decoded.treeId, 't1');
      expect(decoded.updatedAt, 1620000000000);
    });

    test('toMap and fromMap serialize and deserialize correctly with null optional fields', () {
      final heritage = Heritage(
        id: '2',
        personId: 'p2',
        region: 'Irish',
      );

      final map = heritage.toMap();
      expect(map['id'], '2');
      expect(map['personId'], 'p2');
      expect(map['region'], 'Irish');
      expect(map['percentage'], isNull);
      expect(map['notes'], isNull);
      expect(map['dnaService'], isNull);
      expect(map['dnaResultsUrl'], isNull);
      expect(map['treeId'], isNull);
      expect(map['updatedAt'], isNull);

      final decoded = Heritage.fromMap(map);
      expect(decoded.id, '2');
      expect(decoded.personId, 'p2');
      expect(decoded.region, 'Irish');
      expect(decoded.percentage, isNull);
      expect(decoded.notes, isNull);
      expect(decoded.dnaService, isNull);
      expect(decoded.dnaResultsUrl, isNull);
      expect(decoded.treeId, isNull);
      expect(decoded.updatedAt, isNull);
    });

    test('fromMap handles num gracefully for percentage', () {
      final map = {
        'id': '3',
        'personId': 'p3',
        'region': 'Malian',
        'percentage': 50, // int instead of double
      };

      final decoded = Heritage.fromMap(map);
      expect(decoded.percentage, 50.0);
    });
    
    test('commonRegions and dnaServices are populated', () {
      expect(Heritage.commonRegions, isNotEmpty);
      expect(Heritage.dnaServices, isNotEmpty);
      expect(Heritage.commonRegions.contains('West African'), isTrue);
      expect(Heritage.dnaServices.contains('AncestryDNA'), isTrue);
    });
  });
}
