import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/tree_core/tree_graph.dart';

Person _p(String id, {List<String> parents = const [], List<String> children = const []}) =>
    Person(
      id: id,
      name: id,
      parentIds: [...parents],
      childIds: [...children],
    );

/// Independent topological check (Kahn) used to prove a graph is acyclic.
bool _isAcyclic(Map<String, List<String>> children, Map<String, List<String>> parents) {
  final remaining = {for (final e in parents.entries) e.key: e.value.length};
  final queue = [for (final e in remaining.entries) if (e.value == 0) e.key];
  var seen = 0;
  for (var i = 0; i < queue.length; i++) {
    seen++;
    for (final c in children[queue[i]]!) {
      remaining[c] = remaining[c]! - 1;
      if (remaining[c] == 0) queue.add(c);
    }
  }
  return seen == children.length;
}

void main() {
  group('TreeGraph construction', () {
    test('links edges from either side and de-duplicates them', () {
      final g = TreeGraph.fromPersons([
        _p('dad', children: ['kid']),
        _p('mum'),
        _p('kid', parents: ['dad', 'mum']),
      ]);
      expect(g.childrenOf('dad'), ['kid']);
      expect(g.childrenOf('mum'), ['kid']);
      expect(g.parentsOf('kid'), ['dad', 'mum']);
      expect(g.edgeCount, 2);
    });

    test('ignores references to people outside the graph', () {
      final g = TreeGraph.fromPersons([
        _p('a', parents: ['ghost'], children: ['phantom']),
      ]);
      expect(g.parentsOf('a'), isEmpty);
      expect(g.childrenOf('a'), isEmpty);
      expect(g.edgeCount, 0);
    });

    test('unknown ids yield empty adjacency instead of throwing', () {
      final g = TreeGraph.fromPersons([_p('a')]);
      expect(g.parentsOf('nope'), isEmpty);
      expect(g.childrenOf('nope'), isEmpty);
      expect(g.ancestors('nope'), isEmpty);
      expect(g.descendants('nope'), isEmpty);
    });
  });

  group('wouldCreateCycle', () {
    final g = TreeGraph.fromPersons([
      _p('gp', children: ['p']),
      _p('p', parents: ['gp'], children: ['c']),
      _p('c', parents: ['p']),
      _p('stranger'),
    ]);

    test('a person cannot be their own parent', () {
      expect(g.wouldCreateCycle(parentId: 'p', childId: 'p'), isTrue);
    });
    test('child as parent of its own parent is a cycle', () {
      expect(g.wouldCreateCycle(parentId: 'c', childId: 'p'), isTrue);
    });
    test('descendant as parent of a distant ancestor is a cycle', () {
      expect(g.wouldCreateCycle(parentId: 'c', childId: 'gp'), isTrue);
    });
    test('forward edges and unrelated people are fine', () {
      expect(g.wouldCreateCycle(parentId: 'gp', childId: 'c'), isFalse);
      expect(g.wouldCreateCycle(parentId: 'stranger', childId: 'c'), isFalse);
      expect(g.wouldCreateCycle(parentId: 'c', childId: 'stranger'), isFalse);
    });
    test('people outside the graph never report a cycle', () {
      expect(g.wouldCreateCycle(parentId: 'x', childId: 'y'), isFalse);
    });
  });

  group('sanitize', () {
    test('leaves an acyclic graph untouched', () {
      final g = TreeGraph.fromPersons([
        _p('a', children: ['b', 'c']),
        _p('b', parents: ['a'], children: ['d']),
        _p('c', parents: ['a'], children: ['d']), // pedigree collapse / diamond
        _p('d', parents: ['b', 'c']),
      ]);
      final s = g.sanitize();
      expect(s.hadCycles, isFalse);
      expect(s.droppedEdges, isEmpty);
      expect(s.children['a'], ['b', 'c']);
      expect(g.hasCycle, isFalse);
    });

    test('drops a self-parent edge', () {
      final g = TreeGraph.fromPersons([_p('a', parents: ['a'])]);
      final s = g.sanitize();
      expect(s.droppedEdges, [const TreeEdge('a', 'a')]);
      expect(s.children['a'], isEmpty);
      expect(s.parents['a'], isEmpty);
    });

    test('breaks a two-person cycle (A -> B -> A) deterministically', () {
      final g = TreeGraph.fromPersons([
        _p('a', parents: ['b'], children: ['b']),
        _p('b', parents: ['a'], children: ['a']),
      ]);
      final s = g.sanitize();
      expect(s.droppedEdges.length, 1);
      expect(_isAcyclic(s.children, s.parents), isTrue);
    });

    test('breaks a very long cycle without recursing (no stack overflow)', () {
      const n = 50000;
      final people = [
        for (var i = 0; i < n; i++)
          _p('p${i.toString().padLeft(6, '0')}',
              children: ['p${((i + 1) % n).toString().padLeft(6, '0')}']),
      ];
      final s = TreeGraph.fromPersons(people).sanitize();
      expect(s.droppedEdges.length, 1);
      expect(_isAcyclic(s.children, s.parents), isTrue);
    });

    test('handles several independent cycles plus healthy branches', () {
      final g = TreeGraph.fromPersons([
        _p('a', children: ['b']),
        _p('b', children: ['c']),
        _p('c', children: ['a']), // cycle 1
        _p('x', children: ['y']),
        _p('y', children: ['x']), // cycle 2
        _p('r', children: ['s']),
        _p('s'), // healthy
      ]);
      final s = g.sanitize();
      expect(s.droppedEdges.length, 2);
      expect(s.children['r'], ['s']);
      expect(_isAcyclic(s.children, s.parents), isTrue);
    });

    test('result does not depend on input order', () {
      final base = [
        _p('a', children: ['b']),
        _p('b', children: ['c']),
        _p('c', children: ['a', 'd']),
        _p('d', children: ['b']),
      ];
      final rnd = Random(7);
      final expected = TreeGraph.fromPersons(base).sanitize().droppedEdges;
      for (var i = 0; i < 20; i++) {
        final shuffled = [...base]..shuffle(rnd);
        expect(TreeGraph.fromPersons(shuffled).sanitize().droppedEdges, expected);
      }
    });
  });

  group('generations', () {
    test('uses the longest path (pedigree collapse goes to the deepest slot)', () {
      final g = TreeGraph.fromPersons([
        _p('root', children: ['a', 'd']),
        _p('a', parents: ['root'], children: ['b']),
        _p('b', parents: ['a'], children: ['d']),
        _p('d', parents: ['root', 'b']),
      ]);
      final gen = g.generations();
      expect(gen, {'root': 0, 'a': 1, 'b': 2, 'd': 3});
    });

    test('disconnected people all start at generation 0', () {
      final gen = TreeGraph.fromPersons([_p('a'), _p('b'), _p('c')]).generations();
      expect(gen, {'a': 0, 'b': 0, 'c': 0});
    });

    test('terminates and covers everyone on cyclic data', () {
      final people = [
        _p('a', children: ['b']),
        _p('b', children: ['a', 'c']),
        _p('c'),
      ];
      final gen = TreeGraph.fromPersons(people).generations();
      expect(gen.keys.toSet(), {'a', 'b', 'c'});
      for (final v in gen.values) {
        expect(v, lessThan(10));
      }
    });
  });

  group('ancestors / descendants', () {
    final g = TreeGraph.fromPersons([
      _p('gp', children: ['p']),
      _p('p', parents: ['gp'], children: ['c1', 'c2']),
      _p('c1', parents: ['p'], children: ['gc']),
      _p('c2', parents: ['p']),
      _p('gc', parents: ['c1']),
    ]);

    test('report distance in generations', () {
      expect(g.ancestors('gc'), {'c1': 1, 'p': 2, 'gp': 3});
      expect(g.descendants('gp'), {'p': 1, 'c1': 2, 'c2': 2, 'gc': 3});
    });

    test('respect maxDepth', () {
      expect(g.ancestors('gc', maxDepth: 2), {'c1': 1, 'p': 2});
      expect(g.descendants('gp', maxDepth: 1), {'p': 1});
    });

    test('are cycle-safe and never include the start person', () {
      final cyclic = TreeGraph.fromPersons([
        _p('a', children: ['b']),
        _p('b', children: ['a']),
      ]);
      expect(cyclic.descendants('a'), {'b': 1});
      expect(cyclic.ancestors('a'), {'b': 1});
    });
  });

  group('connectedComponents', () {
    test('groups people ignoring direction and orders deterministically', () {
      final g = TreeGraph.fromPersons([
        _p('b', children: ['c']),
        _p('c', parents: ['b']),
        _p('a'),
        _p('x', children: ['y']),
        _p('y'),
      ]);
      expect(g.connectedComponents(), [
        ['a'],
        ['b', 'c'],
        ['x', 'y'],
      ]);
    });
  });

  group('property checks on random graphs', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      test('seed $seed: sanitize always yields a DAG that only removes real edges', () {
        final rnd = Random(seed);
        const n = 300;
        final ids = [for (var i = 0; i < n; i++) 'p${i.toString().padLeft(4, '0')}'];
        final people = {for (final id in ids) id: _p(id)};

        // Random DAG: edges only from lower to higher rank...
        for (var i = 0; i < n; i++) {
          for (var k = 0; k < 2; k++) {
            if (rnd.nextDouble() < 0.5 && i + 1 < n) {
              final j = i + 1 + rnd.nextInt(min(10, n - i - 1));
              people[ids[j]]!.parentIds.add(ids[i]);
            }
          }
        }
        final dag = TreeGraph.fromPersons(people.values);
        expect(dag.sanitize().droppedEdges, isEmpty, reason: 'a DAG needs no repairs');

        // ...then inject some back edges to create cycles.
        for (var k = 0; k < 15; k++) {
          final hi = 10 + rnd.nextInt(n - 10);
          final lo = rnd.nextInt(hi);
          people[ids[lo]]!.parentIds.add(ids[hi]);
        }
        final graph = TreeGraph.fromPersons(people.values);
        final s = graph.sanitize();

        expect(_isAcyclic(s.children, s.parents), isTrue);
        for (final e in s.droppedEdges) {
          expect(graph.childrenOf(e.parentId), contains(e.childId));
        }
        final gen = graph.generations();
        for (final entry in s.children.entries) {
          for (final c in entry.value) {
            expect(gen[c]!, greaterThan(gen[entry.key]!));
          }
        }
      });
    }

    test('scales: 100k-person chain sanitizes and layers quickly', () {
      const n = 100000;
      final people = [
        for (var i = 0; i < n; i++)
          _p('p$i', parents: i == 0 ? const [] : ['p${i - 1}']),
      ];
      final sw = Stopwatch()..start();
      final g = TreeGraph.fromPersons(people);
      expect(g.sanitize().hadCycles, isFalse);
      expect(g.generations()['p${n - 1}'], n - 1);
      expect(sw.elapsed, lessThan(const Duration(seconds: 15)));
    });
  });
}
