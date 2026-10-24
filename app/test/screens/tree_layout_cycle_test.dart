import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/screens/tree_layout.dart';

Person _person(
  String id, {
  List<String> parents = const [],
  List<String> children = const [],
}) =>
    Person(
      id: id,
      name: id,
      parentIds: [...parents],
      childIds: [...children],
    );

void main() {
  group('TreeLayout on corrupt, cyclic data', () {
    test('a two-person parent cycle lays out and terminates', () {
      final layout = TreeLayout(
        [
          _person('a', parents: ['b'], children: ['b']),
          _person('b', parents: ['a'], children: ['a']),
        ],
        [],
      )..compute();

      expect(layout.nodes.keys, containsAll(['a', 'b']));
      for (final node in layout.nodes.values) {
        expect(node.generation, inInclusiveRange(0, 1));
      }
    });

    test('a self-parent and a long cycle both terminate', () {
      final layout = TreeLayout(
        [
          _person('self', parents: ['self'], children: ['self']),
          _person('a', parents: ['c'], children: ['b']),
          _person('b', parents: ['a'], children: ['c']),
          _person('c', parents: ['b'], children: ['a']),
        ],
        [],
      )..compute();

      expect(layout.nodes.keys, containsAll(['self', 'a', 'b', 'c']));
      expect(
        layout.nodes.values.every((n) => n.generation >= 0),
        isTrue,
      );
    });

    test('a partnership between a parent and their child cannot loop forever',
        () {
      final layout = TreeLayout(
        [
          _person('parent', children: ['child']),
          _person('child', parents: ['parent']),
        ],
        [
          Partnership(
            id: 'bad',
            person1Id: 'parent',
            person2Id: 'child',
            status: 'married',
          ),
        ],
      )..compute();

      expect(layout.nodes.keys, containsAll(['parent', 'child']));
    });
  });
}
