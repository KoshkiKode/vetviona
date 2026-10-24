import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/tree_core/tree_numbering.dart';

void main() {
  Map<String, List<String>> tree(Map<String, List<String>> parents) =>
      parents;

  group('sosaNumbering', () {
    test('father is 2n and mother is 2n+1', () {
      final parents = tree({
        'root': ['dad', 'mum'],
        'dad': ['granddad', 'grandmum'],
      });
      final entries = sosaNumbering('root', (id) => parents[id] ?? const []);
      expect({for (final e in entries) e.number: e.personId}, {
        1: 'root',
        2: 'dad',
        3: 'mum',
        4: 'granddad',
        5: 'grandmum',
      });
      expect(entries.firstWhere((e) => e.number == 4).generation, 2);
    });

    test('a missing parent leaves a gap in the numbering', () {
      final parents = tree({
        'root': ['dad'],
      });
      final entries = sosaNumbering('root', (id) => parents[id] ?? const []);
      expect(entries.map((e) => e.number), [1, 2]);
    });

    test('cyclic data terminates within the generation limit', () {
      final parents = tree({
        'a': ['b', 'c'],
        'b': ['a', 'c'],
        'c': ['a', 'b'],
      });
      final entries = sosaNumbering(
        'a',
        (id) => parents[id] ?? const [],
        maxGenerations: 5,
      );
      expect(entries.length, lessThanOrEqualTo(63));
      expect(entries.first.number, 1);
    });

    test('huge generation requests are capped rather than exhausting memory', () {
      final parents = tree({
        'a': ['b', 'c'],
        'b': ['a', 'c'],
        'c': ['a', 'b'],
      });
      final entries = sosaNumbering(
        'a',
        (id) => parents[id] ?? const [],
        maxGenerations: 1000,
      );
      expect(entries.length, lessThanOrEqualTo(65536));
    });
  });
}
