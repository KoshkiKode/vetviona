// Unit tests for the TreeLayout engine (app/lib/screens/tree_layout.dart).
//
// These tests exercise the pure layout logic without any Flutter widget tree,
// which makes them fast and deterministic.

import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/screens/tree_layout.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Person _person(String id, {List<String>? parentIds, List<String>? childIds}) =>
    Person(
      id: id,
      name: 'Person $id',
      parentIds: parentIds ?? [],
      childIds: childIds ?? [],
    );

Partnership _couple(String id, String p1, String p2) =>
    Partnership(id: id, person1Id: p1, person2Id: p2);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Empty input ─────────────────────────────────────────────────────────────
  group('TreeLayout — empty input', () {
    test(
      'compute() on empty persons list produces no nodes, edges, or rows',
      () {
        final layout = TreeLayout([], []);
        layout.compute();

        expect(layout.nodes, isEmpty);
        expect(layout.edges, isEmpty);
        expect(layout.generationRows, isEmpty);
        expect(layout.canvasSize, Size.zero);
      },
    );
  });

  // ── Single person ────────────────────────────────────────────────────────────
  group('TreeLayout — single person', () {
    late TreeLayout layout;

    setUp(() {
      layout = TreeLayout([_person('A')], []);
      layout.compute();
    });

    test('creates exactly one node', () {
      expect(layout.nodes.length, 1);
      expect(layout.nodes.containsKey('A'), isTrue);
    });

    test('node is at generation 0', () {
      expect(layout.nodes['A']!.generation, 0);
    });

    test('node is positioned at (0, 0)', () {
      expect(layout.nodes['A']!.x, 0);
      expect(layout.nodes['A']!.y, 0);
    });

    test('no edges', () => expect(layout.edges, isEmpty));

    test('canvas size is non-zero', () {
      expect(layout.canvasSize.width, greaterThan(0));
      expect(layout.canvasSize.height, greaterThan(0));
    });

    test('one generation row at y = 0', () {
      expect(layout.generationRows.length, 1);
      expect(layout.generationRows.first.generation, 0);
      expect(layout.generationRows.first.y, 0);
    });
  });

  // ── Parent → child chain ─────────────────────────────────────────────────────
  group('TreeLayout — parent → child', () {
    late TreeLayout layout;

    setUp(() {
      layout = TreeLayout([
        _person('P', childIds: ['C']),
        _person('C', parentIds: ['P']),
      ], []);
      layout.compute();
    });

    test('two person nodes, no knot', () {
      expect(layout.nodes.length, 2);
      expect(layout.nodes.containsKey('P'), isTrue);
      expect(layout.nodes.containsKey('C'), isTrue);
    });

    test('parent is generation 0, child is generation 1', () {
      expect(layout.nodes['P']!.generation, 0);
      expect(layout.nodes['C']!.generation, 1);
    });

    test('one parent-child edge exists', () {
      final parentEdges = layout.edges.where((e) => !e.isCouple).toList();
      expect(parentEdges.length, 1);
      expect(parentEdges.first.from, 'P');
      expect(parentEdges.first.to, 'C');
    });

    test('child y is greater than parent y', () {
      expect(layout.nodes['C']!.y, greaterThan(layout.nodes['P']!.y));
    });

    test('two generation rows', () {
      expect(layout.generationRows.length, 2);
    });
  });

  // ── Multi-generation chain ───────────────────────────────────────────────────
  group('TreeLayout — three-generation chain (GP → P → C)', () {
    late TreeLayout layout;

    setUp(() {
      layout = TreeLayout([
        _person('GP', childIds: ['P']),
        _person('P', parentIds: ['GP'], childIds: ['C']),
        _person('C', parentIds: ['P']),
      ], []);
      layout.compute();
    });

    test('GP is generation 0, P is generation 1, C is generation 2', () {
      expect(layout.nodes['GP']!.generation, 0);
      expect(layout.nodes['P']!.generation, 1);
      expect(layout.nodes['C']!.generation, 2);
    });

    test('three generation rows', () {
      expect(layout.generationRows.length, 3);
    });

    test('generation rows are in ascending order', () {
      final ys = layout.generationRows.map((r) => r.y).toList();
      for (int i = 1; i < ys.length; i++) {
        expect(ys[i], greaterThan(ys[i - 1]));
      }
    });
  });

  // ── Partnership (couple knot) ────────────────────────────────────────────────
  group('TreeLayout — couple without children', () {
    late TreeLayout layout;

    setUp(() {
      layout = TreeLayout(
        [_person('A'), _person('B')],
        [_couple('p1', 'A', 'B')],
      );
      layout.compute();
    });

    test('creates two person nodes and one couple-knot node', () {
      expect(layout.nodes.length, 3);
      final knots = layout.nodes.values.where((n) => n.isCoupleKnot).toList();
      expect(knots.length, 1);
      expect(knots.first.id, 'knot_p1');
    });

    test('couple-knot references the correct partners', () {
      final knot = layout.nodes['knot_p1']!;
      expect({knot.knotPartner1, knot.knotPartner2}, {'A', 'B'});
    });

    test('two couple edges (A→knot and B→knot)', () {
      final coupleEdges = layout.edges.where((e) => e.isCouple).toList();
      expect(coupleEdges.length, 2);
      expect(coupleEdges.map((e) => e.from).toSet(), {'A', 'B'});
      expect(coupleEdges.map((e) => e.to).toSet(), {'knot_p1'});
    });

    test('knot is between the two partners horizontally', () {
      final a = layout.nodes['A']!;
      final b = layout.nodes['B']!;
      final k = layout.nodes['knot_p1']!;
      final lo = a.x < b.x ? a.x : b.x;
      final hi = a.x < b.x ? b.x : a.x;
      expect(k.x, greaterThanOrEqualTo(lo));
      expect(k.x, lessThanOrEqualTo(hi));
    });

    test('all three nodes are in generation 0', () {
      for (final node in layout.nodes.values) {
        expect(node.generation, 0);
      }
    });
  });

  // ── Couple with children ─────────────────────────────────────────────────────
  group('TreeLayout — couple with one child', () {
    late TreeLayout layout;

    setUp(() {
      layout = TreeLayout(
        [
          _person('Dad', childIds: ['Kid']),
          _person('Mum', childIds: ['Kid']),
          _person('Kid', parentIds: ['Dad', 'Mum']),
        ],
        [_couple('p1', 'Dad', 'Mum')],
      );
      layout.compute();
    });

    test('has 4 nodes: Dad, Mum, knot, Kid', () {
      expect(layout.nodes.length, 4);
    });

    test('parents in generation 0, child in generation 1', () {
      expect(layout.nodes['Dad']!.generation, 0);
      expect(layout.nodes['Mum']!.generation, 0);
      expect(layout.nodes['Kid']!.generation, 1);
    });

    test('child edge comes from the knot (not directly from Dad or Mum)', () {
      final childEdges = layout.edges
          .where((e) => !e.isCouple && e.to == 'Kid')
          .toList();
      expect(childEdges.length, 1);
      expect(childEdges.first.from, 'knot_p1');
    });

    test('only one parent-child edge for Kid', () {
      final childEdges = layout.edges
          .where((e) => !e.isCouple && e.to == 'Kid')
          .toList();
      expect(childEdges.length, 1);
    });
  });

  // ── Couple with multiple children ────────────────────────────────────────────
  group('TreeLayout — couple with three children', () {
    late TreeLayout layout;

    setUp(() {
      layout = TreeLayout(
        [
          _person('Dad', childIds: ['C1', 'C2', 'C3']),
          _person('Mum', childIds: ['C1', 'C2', 'C3']),
          _person('C1', parentIds: ['Dad', 'Mum']),
          _person('C2', parentIds: ['Dad', 'Mum']),
          _person('C3', parentIds: ['Dad', 'Mum']),
        ],
        [_couple('p1', 'Dad', 'Mum')],
      );
      layout.compute();
    });

    test('exactly 3 parent-child edges, all from the knot', () {
      final childEdges = layout.edges.where((e) => !e.isCouple).toList();
      expect(childEdges.length, 3);
      for (final e in childEdges) {
        expect(e.from, 'knot_p1');
      }
    });

    test('all three children are in generation 1', () {
      for (final id in ['C1', 'C2', 'C3']) {
        expect(layout.nodes[id]!.generation, 1);
      }
    });

    test('no two nodes in the same row overlap', () {
      // For each generation, check that consecutive nodes (sorted by x) have
      // enough horizontal distance between them.
      final byGen = <int, List<TreeNodeInfo>>{};
      for (final n in layout.nodes.values) {
        byGen.putIfAbsent(n.generation, () => []).add(n);
      }
      for (final row in byGen.values) {
        row.sort((a, b) => a.x.compareTo(b.x));
        for (int i = 1; i < row.length; i++) {
          expect(
            row[i].x - row[i - 1].x,
            greaterThanOrEqualTo(kTreeNodeW + kTreeColGap - 0.01),
            reason: 'Nodes ${row[i - 1].id} and ${row[i].id} overlap',
          );
        }
      }
    });
  });

  // ── Two unconnected roots ────────────────────────────────────────────────────
  group('TreeLayout — two disconnected roots', () {
    late TreeLayout layout;

    setUp(() {
      layout = TreeLayout([_person('A'), _person('B')], []);
      layout.compute();
    });

    test('both persons are generation 0', () {
      expect(layout.nodes['A']!.generation, 0);
      expect(layout.nodes['B']!.generation, 0);
    });

    test('nodes are placed side-by-side (different x)', () {
      expect(layout.nodes['A']!.x, isNot(layout.nodes['B']!.x));
    });

    test('no edges', () => expect(layout.edges, isEmpty));
  });

  // ── Normalisation ────────────────────────────────────────────────────────────
  group('TreeLayout — normalisation', () {
    test('leftmost node x is >= 0 after compute()', () {
      final layout = TreeLayout([
        _person('P', childIds: ['C1', 'C2', 'C3']),
        _person('C1', parentIds: ['P']),
        _person('C2', parentIds: ['P']),
        _person('C3', parentIds: ['P']),
      ], []);
      layout.compute();

      final minX = layout.nodes.values
          .map((n) => n.x)
          .reduce((a, b) => a < b ? a : b);
      expect(minX, greaterThanOrEqualTo(0));
    });
  });

  // ── Canvas size ──────────────────────────────────────────────────────────────
  group('TreeLayout — canvas size', () {
    test('canvas width covers all nodes', () {
      final layout = TreeLayout([_person('A'), _person('B'), _person('C')], []);
      layout.compute();

      final maxNodeRight = layout.nodes.values
          .map((n) => n.x + kTreeNodeW)
          .reduce((a, b) => a > b ? a : b);
      expect(layout.canvasSize.width, greaterThanOrEqualTo(maxNodeRight));
    });

    test('canvas height covers all nodes', () {
      final layout = TreeLayout([
        _person('GP', childIds: ['P']),
        _person('P', parentIds: ['GP'], childIds: ['C']),
        _person('C', parentIds: ['P']),
      ], []);
      layout.compute();

      final maxNodeBottom = layout.nodes.values
          .map((n) => n.y + kTreeNodeH)
          .reduce((a, b) => a > b ? a : b);
      expect(layout.canvasSize.height, greaterThanOrEqualTo(maxNodeBottom));
    });
  });

  // ── Generation rows ──────────────────────────────────────────────────────────
  group('TreeLayout — generation rows', () {
    test('row y values are evenly spaced (compact rank formula)', () {
      // For consecutive generations the rank equals the generation index so
      // the formula is identical to the old gen*(nodeH+rowGap) formula.
      final layout = TreeLayout([
        _person('GP', childIds: ['P']),
        _person('P', parentIds: ['GP'], childIds: ['C']),
        _person('C', parentIds: ['P']),
      ], []);
      layout.compute();

      for (int i = 0; i < layout.generationRows.length; i++) {
        final expectedY = i * (kTreeNodeH + kTreeRowGap);
        expect(layout.generationRows[i].y, closeTo(expectedY, 0.01));
      }
    });

    test('rows are sorted in ascending generation order', () {
      final layout = TreeLayout([
        _person('GP', childIds: ['P']),
        _person('P', parentIds: ['GP'], childIds: ['C']),
        _person('C', parentIds: ['P']),
      ], []);
      layout.compute();

      final gens = layout.generationRows.map((r) => r.generation).toList();
      for (int i = 1; i < gens.length; i++) {
        expect(gens[i], greaterThan(gens[i - 1]));
      }
    });
  });

  // ── Non-consecutive generation normalisation ─────────────────────────────────
  group('TreeLayout — non-consecutive generation normalisation', () {
    // Scenario: A and B are spouses.  B has no parents in the visible set
    // (gen 0 initially).  A is at gen 2 due to known ancestry.  After
    // spouse-alignment B gets bumped to gen 2, creating a gap at gen 1.
    // The layout engine must map gen 0 → row 0 and gen 2 → row 1 so the
    // two rows are adjacent on screen with no empty vertical gap.
    test('nodes with non-consecutive generation indices have consecutive y positions', () {
      // Root (gen 0) → Parent (gen 1) → A (gen 2)
      // B has no parents → initially gen 0, bumped to gen 2 by spouse
      // alignment with A.
      // So the visible nodes are at generations 0 (Root, Parent) … wait –
      // let's build a minimal tree where a gap is guaranteed:
      //
      //  Root ──── Parent ──── A (gen 2)
      //                         ↕ married
      //                        B (gen 0 → bumped to gen 2)
      //
      // B's parent BG has no other connections, so BG stays at gen 0.
      // After alignment A==B==gen 2.  BG stays at gen 0.
      // There is no person at gen 1 in B's branch → gap at gen 1 for that
      // family line, but the row map should still produce exactly 3 rows.
      final layout = TreeLayout(
        [
          _person('Root', childIds: ['Parent']),
          _person('Parent', parentIds: ['Root'], childIds: ['A']),
          _person('A', parentIds: ['Parent']),
          _person('B'),
          _person('BG', childIds: ['B']),
          // Note: B's parentIds are intentionally left blank so that the
          // BG→B relationship is one-sided (BG has B in childIds, but B
          // does not have BG in parentIds).  This means B is a root from
          // the BFS perspective and stays at gen 0 until spouse-aligned.
        ],
        [_couple('pAB', 'A', 'B')],
      );
      layout.compute();

      // Gather the unique y positions and sort them.
      final ys = layout.nodes.values
          .map((n) => n.y)
          .toSet()
          .toList()
        ..sort();

      // Every y step should equal exactly one row pitch (nodeH + rowGap).
      final pitch = kTreeNodeH + kTreeRowGap;
      for (int i = 1; i < ys.length; i++) {
        expect(
          ys[i] - ys[i - 1],
          closeTo(pitch, 0.01),
          reason: 'Gap between row $i and row ${i - 1} should equal one pitch',
        );
      }
    });

    test('generation row labels are placed at compact consecutive y values', () {
      final layout = TreeLayout(
        [
          _person('R', childIds: ['P']),
          _person('P', parentIds: ['R'], childIds: ['A']),
          _person('A', parentIds: ['P']),
          _person('B'),
        ],
        [_couple('pAB', 'A', 'B')],
      );
      layout.compute();

      final pitch = kTreeNodeH + kTreeRowGap;
      for (int i = 0; i < layout.generationRows.length; i++) {
        expect(
          layout.generationRows[i].y,
          closeTo(i * pitch, 0.01),
          reason: 'Generation row $i y should be i * pitch',
        );
      }
    });

    test('no two nodes in different rows share the same y coordinate after normalisation', () {
      final layout = TreeLayout(
        [
          _person('R', childIds: ['P']),
          _person('P', parentIds: ['R'], childIds: ['A']),
          _person('A', parentIds: ['P']),
          _person('B'),
        ],
        [_couple('pAB', 'A', 'B')],
      );
      layout.compute();

      // Collect (generation → y) mapping and assert all nodes in the same
      // generation share the same y, and different generations have different y.
      final genToY = <int, double>{};
      for (final node in layout.nodes.values) {
        if (genToY.containsKey(node.generation)) {
          expect(node.y, closeTo(genToY[node.generation]!, 0.01),
              reason: 'All nodes in the same generation must share the same y');
        } else {
          genToY[node.generation] = node.y;
        }
      }
      final uniqueYs = genToY.values.toSet();
      expect(uniqueYs.length, genToY.length,
          reason: 'Different generations must have different y values');
    });
  });

  // ── Parent centred over children ─────────────────────────────────────────────
  group('TreeLayout — parent centred over children', () {
    test('single parent with two children is horizontally centred', () {
      // Layout: P is the parent of C1 and C2.
      // After refinement P should sit above the midpoint of C1 and C2.
      final layout = TreeLayout([
        _person('P', childIds: ['C1', 'C2']),
        _person('C1', parentIds: ['P']),
        _person('C2', parentIds: ['P']),
      ], []);
      layout.compute();

      final pCx = layout.nodes['P']!.x + kTreeNodeW / 2;
      final c1Cx = layout.nodes['C1']!.x + kTreeNodeW / 2;
      final c2Cx = layout.nodes['C2']!.x + kTreeNodeW / 2;
      final midChildren = (c1Cx + c2Cx) / 2;
      expect(pCx, closeTo(midChildren, 1.0));
    });
  });

  // ── Diamond / shared child ───────────────────────────────────────────────────
  group('TreeLayout — child with two separate parents (no partnership)', () {
    test('child is assigned the higher generation of the two parents + 1', () {
      // GP → P1 → Child, and P2 → Child (P2 is also in gen 1)
      final layout = TreeLayout([
        _person('GP', childIds: ['P1']),
        _person('P1', parentIds: ['GP'], childIds: ['Child']),
        _person('P2', childIds: ['Child']),
        _person('Child', parentIds: ['P1', 'P2']),
      ], []);
      layout.compute();

      expect(layout.nodes['GP']!.generation, 0);
      expect(layout.nodes['P1']!.generation, 1);
      // P2 has no parents in the tree → gen 0 initially; child should be
      // max(gen(P1), gen(P2)) + 1 = max(1, 0) + 1 = 2.
      expect(layout.nodes['Child']!.generation, 2);
    });
  });

  group('TreeLayout — deterministic ordering', () {
    test('same graph yields identical positions regardless of input order', () {
      final persons = [
        _person('Dad', childIds: ['Kid1', 'Kid2']),
        _person('Mum', childIds: ['Kid1', 'Kid2']),
        _person('Kid1', parentIds: ['Dad', 'Mum']),
        _person('Kid2', parentIds: ['Dad', 'Mum']),
      ];
      final partnerships = [_couple('p1', 'Mum', 'Dad')];

      final layoutA = TreeLayout(persons, partnerships)..compute();
      final layoutB = TreeLayout(
        persons.reversed.toList(),
        partnerships.reversed.toList(),
      )..compute();

      expect(layoutA.nodes.keys.toSet(), layoutB.nodes.keys.toSet());
      for (final id in layoutA.nodes.keys) {
        expect(layoutB.nodes.containsKey(id), isTrue);
        expect(layoutA.nodes[id]!.generation, layoutB.nodes[id]!.generation);
        expect(layoutA.nodes[id]!.x, closeTo(layoutB.nodes[id]!.x, 0.001));
        expect(layoutA.nodes[id]!.y, closeTo(layoutB.nodes[id]!.y, 0.001));
      }
    });
  });
}
