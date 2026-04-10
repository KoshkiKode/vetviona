import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/device.dart';

void main() {
  group('Device', () {
    group('Device.create', () {
      test('generates non-empty id and sharedSecret', () {
        final d = Device.create();
        expect(d.id, isNotEmpty);
        expect(d.sharedSecret, isNotEmpty);
      });

      test('id and sharedSecret are different values', () {
        final d = Device.create();
        expect(d.id, isNot(equals(d.sharedSecret)));
      });

      test('two create() calls produce distinct IDs', () {
        final d1 = Device.create();
        final d2 = Device.create();
        expect(d1.id, isNot(equals(d2.id)));
        expect(d1.sharedSecret, isNot(equals(d2.sharedSecret)));
      });

      test('default tier is mobileFree', () {
        final d = Device.create();
        expect(d.tier, 'mobileFree');
      });

      test('tier parameter is respected', () {
        final d = Device.create(tier: 'desktopPro');
        expect(d.tier, 'desktopPro');
      });
    });

    group('constructor', () {
      test('default tier is mobileFree', () {
        final d = Device(id: '1', sharedSecret: 'secret');
        expect(d.tier, 'mobileFree');
      });

      test('explicit tier is stored', () {
        final d = Device(id: '1', sharedSecret: 'secret', tier: 'mobilePaid');
        expect(d.tier, 'mobilePaid');
      });
    });

    group('toMap / fromMap', () {
      test('full roundtrip preserves all fields', () {
        final original = Device(
          id: 'device-uuid',
          sharedSecret: 'secret-uuid',
          tier: 'desktopPro',
        );
        final restored = Device.fromMap(original.toMap());

        expect(restored.id, original.id);
        expect(restored.sharedSecret, original.sharedSecret);
        expect(restored.tier, original.tier);
      });

      test('null tier in map defaults to mobileFree', () {
        final map = <String, dynamic>{
          'id': '1',
          'sharedSecret': 'secret',
          'tier': null,
        };
        final d = Device.fromMap(map);
        expect(d.tier, 'mobileFree');
      });

      test('all three tier values survive roundtrip', () {
        for (final tier in ['mobileFree', 'mobilePaid', 'desktopPro']) {
          final d = Device(id: 'x', sharedSecret: 'y', tier: tier);
          expect(Device.fromMap(d.toMap()).tier, tier);
        }
      });
    });
  });
}
