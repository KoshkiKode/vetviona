// app/test/tree_core/tree_visibility_engine_test.dart
//
// Unit tests for TreeVisibilityEngine.
// Pure Dart tests — no Flutter widget tree required.

import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/tree_core/tree_visibility_engine.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Person _p(
  String id, {
  List<String> parentIds = const [],
  List<String> childIds = const [],
}) =>
    Person(
      id: id,
      name: 'Person $id',
      parentIds: List<String>.from(parentIds),
      childIds: List<String>.from(childIds),
    );

Partnership _couple(String id, String p1, String p2) =>
    Partnership(id: id, person1Id: p1, person2Id: p2);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── resetToHome ─────────────────────────────────────────────────────────────
  group('resetToHome — empty tree', () {
    test('produces empty visible set when persons list is empty', () {
      final engine = TreeVisibilityEngine(
        persons: [],
        partnerships: [],
        homePersonId: 'X',
      );
      engine.resetToHome();
      expect(engine.visibleIds, isEmpty);
    });
  });

  group('resetToHome — single person', () {
    test('home person is visible', () {
      final engine = TreeVisibilityEngine(
        persons: [_p('A')],
        partnerships: [],
        homePersonId: 'A',
      );
      engine.resetToHome();
      expect(engine.visibleIds, contains('A'));
    });
  });

  group('resetToHome — 1 ancestor generation', () {
    // Tree: GP → P → Home
    late TreeVisibilityEngine engine;
    setUp(() {
      final home = _p('Home', parentIds: ['P']);
      final parent = _p('P', parentIds: ['GP'], childIds: ['Home']);
      final gp = _p('GP', childIds: ['P']);
      engine = TreeVisibilityEngine(
        persons: [home, parent, gp],
        partnerships: [],
        homePersonId: 'Home',
      );
    });

    test('home and direct parent are visible with ancestorGens=1', () {
      engine.resetToHome(ancestorGens: 1);
      expect(engine.visibleIds, containsAll(['Home', 'P']));
    });

    test('grandparent is not visible with ancestorGens=1', () {
      engine.resetToHome(ancestorGens: 1);
      expect(engine.visibleIds, isNot(contains('GP')));
    });

    test('grandparent IS visible with ancestorGens=2', () {
      engine.resetToHome(ancestorGens: 2);
      expect(engine.visibleIds, containsAll(['Home', 'P', 'GP']));
    });
  });

  group('resetToHome — 1 descendant generation', () {
    // Tree: Home → Child → GC
    late TreeVisibilityEngine engine;
    setUp(() {
      final home = _p('Home', childIds: ['Child']);
      final child = _p('Child', parentIds: ['Home'], childIds: ['GC']);
      final gc = _p('GC', parentIds: ['Child']);
      engine = TreeVisibilityEngine(
        persons: [home, child, gc],
        partnerships: [],
        homePersonId: 'Home',
      );
    });

    test('home and child are visible with descendantGens=1', () {
      engine.resetToHome(descendantGens: 1);
      expect(engine.visibleIds, containsAll(['Home', 'Child']));
    });

    test('grandchild is not visible with descendantGens=1', () {
      engine.resetToHome(descendantGens: 1);
      expect(engine.visibleIds, isNot(contains('GC')));
    });

    test('grandchild IS visible with descendantGens=2', () {
      engine.resetToHome(descendantGens: 2);
      expect(engine.visibleIds, containsAll(['Home', 'Child', 'GC']));
    });
  });

  group('resetToHome — partners included', () {
    test("home person's partner is visible after reset", () {
      final home = _p('Home');
      final partner = _p('Spouse');
      final engine = TreeVisibilityEngine(
        persons: [home, partner],
        partnerships: [_couple('p1', 'Home', 'Spouse')],
        homePersonId: 'Home',
      );
      engine.resetToHome();
      expect(engine.visibleIds, containsAll(['Home', 'Spouse']));
    });

    test("partner is visible when home person is person2 in partnership", () {
      final home = _p('Home');
      final partner = _p('Spouse');
      final engine = TreeVisibilityEngine(
        persons: [home, partner],
        partnerships: [_couple('p1', 'Spouse', 'Home')],  // reversed order
        homePersonId: 'Home',
      );
      engine.resetToHome();
      expect(engine.visibleIds, containsAll(['Home', 'Spouse']));
    });

    test("partner's parents are visible when they exist", () {
      // Tree: SpouseDad + SpouseMom → Spouse, and Home is partnered to Spouse.
      // Both spouses' parents should be visible after reset; Home has none.
      final home = _p('Home');
      final spouse = _p('Spouse', parentIds: ['SpouseDad', 'SpouseMom']);
      final spouseDad = _p('SpouseDad', childIds: ['Spouse']);
      final spouseMom = _p('SpouseMom', childIds: ['Spouse']);
      final engine = TreeVisibilityEngine(
        persons: [home, spouse, spouseDad, spouseMom],
        partnerships: [
          _couple('p1', 'Home', 'Spouse'),
          _couple('p2', 'SpouseDad', 'SpouseMom'),
        ],
        homePersonId: 'Home',
      );
      engine.resetToHome();
      expect(
        engine.visibleIds,
        containsAll(['Home', 'Spouse', 'SpouseDad', 'SpouseMom']),
      );
    });

    test("descendant's spouse parents are visible", () {
      // Home → Child, Child partnered to ChildSpouse whose parents exist.
      // Both Child and ChildSpouse parents should appear in the same row.
      final home = _p('Home', childIds: ['Child']);
      final child = _p('Child', parentIds: ['Home']);
      final childSpouse =
          _p('ChildSpouse', parentIds: ['CSDad', 'CSMom']);
      final csDad = _p('CSDad', childIds: ['ChildSpouse']);
      final csMom = _p('CSMom', childIds: ['ChildSpouse']);
      final engine = TreeVisibilityEngine(
        persons: [home, child, childSpouse, csDad, csMom],
        partnerships: [
          _couple('p1', 'Child', 'ChildSpouse'),
          _couple('p2', 'CSDad', 'CSMom'),
        ],
        homePersonId: 'Home',
      );
      engine.resetToHome(descendantGens: 1);
      expect(
        engine.visibleIds,
        containsAll(['Home', 'Child', 'ChildSpouse', 'CSDad', 'CSMom']),
      );
    });
  });

  // ── expandParents ────────────────────────────────────────────────────────────
  group('expandParents', () {
    test("adds parent and parent's partner to visible set", () {
      final home = _p('Home', parentIds: ['Dad']);
      final dad = _p('Dad', childIds: ['Home']);
      final mom = _p('Mom');
      final engine = TreeVisibilityEngine(
        persons: [home, dad, mom],
        partnerships: [_couple('p1', 'Dad', 'Mom')],
        homePersonId: 'Home',
      );
      engine.resetToHome(ancestorGens: 0); // only home visible
      expect(engine.visibleIds, equals({'Home'}));

      engine.expandParents('Home');
      expect(engine.visibleIds, containsAll(['Home', 'Dad', 'Mom']));
    });
  });

  // ── expandChildren ───────────────────────────────────────────────────────────
  group('expandChildren', () {
    test("adds child and child's partner", () {
      final home = _p('Home', childIds: ['Child']);
      final child = _p('Child', parentIds: ['Home']);
      final childSpouse = _p('ChildSpouse');
      final engine = TreeVisibilityEngine(
        persons: [home, child, childSpouse],
        partnerships: [_couple('p1', 'Child', 'ChildSpouse')],
        homePersonId: 'Home',
      );
      engine.resetToHome(descendantGens: 0); // only home
      engine.expandChildren('Home');
      expect(engine.visibleIds, containsAll(['Home', 'Child', 'ChildSpouse']));
    });
  });

  // ── expandSiblings ───────────────────────────────────────────────────────────
  group('expandSiblings', () {
    test('adds sibling (shares same parent)', () {
      final parent = _p('Parent', childIds: ['Home', 'Sibling']);
      final home = _p('Home', parentIds: ['Parent']);
      final sibling = _p('Sibling', parentIds: ['Parent']);
      final engine = TreeVisibilityEngine(
        persons: [home, sibling, parent],
        partnerships: [],
        homePersonId: 'Home',
      );
      engine.resetToHome(ancestorGens: 0);
      expect(engine.visibleIds, isNot(contains('Sibling')));

      engine.expandSiblings('Home');
      expect(engine.visibleIds, contains('Sibling'));
    });
  });

  // ── expandAllAncestors ────────────────────────────────────────────────────────
  group('expandAllAncestors', () {
    test('BFS adds all ancestors', () {
      final home = _p('Home', parentIds: ['P']);
      final parent = _p('P', parentIds: ['GP'], childIds: ['Home']);
      final gp = _p('GP', parentIds: ['GGP'], childIds: ['P']);
      final ggp = _p('GGP', childIds: ['GP']);
      final engine = TreeVisibilityEngine(
        persons: [home, parent, gp, ggp],
        partnerships: [],
        homePersonId: 'Home',
      );
      engine.resetToHome(ancestorGens: 0);
      engine.expandAllAncestors('Home');
      expect(engine.visibleIds, containsAll(['P', 'GP', 'GGP']));
    });
  });

  // ── expandAllDescendants ──────────────────────────────────────────────────────
  group('expandAllDescendants', () {
    test('BFS adds all descendants', () {
      final home = _p('Home', childIds: ['C']);
      final child = _p('C', parentIds: ['Home'], childIds: ['GC']);
      final gc = _p('GC', parentIds: ['C'], childIds: ['GGC']);
      final ggc = _p('GGC', parentIds: ['GC']);
      final engine = TreeVisibilityEngine(
        persons: [home, child, gc, ggc],
        partnerships: [],
        homePersonId: 'Home',
      );
      engine.resetToHome(descendantGens: 0);
      engine.expandAllDescendants('Home');
      expect(engine.visibleIds, containsAll(['C', 'GC', 'GGC']));
    });
  });

  // ── showAll ───────────────────────────────────────────────────────────────────
  group('showAll', () {
    test('makes every person visible', () {
      final persons = [_p('A'), _p('B'), _p('C'), _p('D')];
      final engine = TreeVisibilityEngine(
          persons: persons, partnerships: [], homePersonId: 'A');
      engine.resetToHome();
      engine.showAll();
      expect(engine.visibleIds, containsAll(['A', 'B', 'C', 'D']));
    });
  });

  // ── focusOn ───────────────────────────────────────────────────────────────────
  group('focusOn', () {
    test('clears and rebuilds visibility around the given person', () {
      final persons = [
        _p('A', childIds: ['B']),
        _p('B', parentIds: ['A'], childIds: ['C']),
        _p('C', parentIds: ['B']),
      ];
      final engine = TreeVisibilityEngine(
          persons: persons, partnerships: [], homePersonId: 'A');
      engine.showAll(); // see everything
      engine.focusOn('B', ancestorGens: 1, descendantGens: 0);
      // B + parent A should be visible; grandchild C should not
      expect(engine.visibleIds, containsAll(['A', 'B']));
      expect(engine.visibleIds, isNot(contains('C')));
    });
  });

  // ── hasHiddenAncestors / Descendants / Siblings ───────────────────────────────
  group('query helpers', () {
    late TreeVisibilityEngine engine;
    setUp(() {
      final persons = [
        _p('GP', childIds: ['P']),
        _p('P', parentIds: ['GP'], childIds: ['Home', 'Sib']),
        _p('Home', parentIds: ['P'], childIds: ['Child']),
        _p('Sib', parentIds: ['P']),
        _p('Child', parentIds: ['Home']),
      ];
      engine = TreeVisibilityEngine(
          persons: persons, partnerships: [], homePersonId: 'Home');
      engine.resetToHome(ancestorGens: 1, descendantGens: 0);
      // Visible: Home, P. Not visible: GP, Sib, Child.
    });

    test('hasHiddenAncestors is true for P (its parent GP is hidden)', () {
      expect(engine.hasHiddenAncestors('P'), isTrue);
    });

    test('hasHiddenAncestors is false for GP (no parents in tree)', () {
      expect(engine.hasHiddenAncestors('GP'), isFalse);
    });

    test('hasHiddenDescendants is true for Home (Child is hidden)', () {
      expect(engine.hasHiddenDescendants('Home'), isTrue);
    });

    test('hasHiddenDescendants is false for Child (no children)', () {
      expect(engine.hasHiddenDescendants('Child'), isFalse);
    });

    test('hasHiddenSiblings is true for Home (Sib is hidden)', () {
      expect(engine.hasHiddenSiblings('Home'), isTrue);
    });

    test('hasHiddenSiblings is false for GP (no siblings)', () {
      expect(engine.hasHiddenSiblings('GP'), isFalse);
    });
  });

  // ── withUpdatedData ───────────────────────────────────────────────────────────
  group('withUpdatedData', () {
    test('preserves visible IDs across data refresh', () {
      final persons1 = [_p('A'), _p('B')];
      final engine = TreeVisibilityEngine(
          persons: persons1, partnerships: [], homePersonId: 'A');
      engine.showAll();

      // Add a new person
      final persons2 = [_p('A'), _p('B'), _p('C')];
      final engine2 = engine.withUpdatedData(
          persons: persons2, partnerships: []);
      // Old IDs still visible
      expect(engine2.visibleIds, containsAll(['A', 'B']));
      // New person C not automatically visible (it wasn't before)
      expect(engine2.visibleIds, isNot(contains('C')));
    });
  });

  // ── addVisibleId ──────────────────────────────────────────────────────────────
  group('addVisibleId', () {
    test('directly adds an ID to the visible set', () {
      final engine = TreeVisibilityEngine(
          persons: [_p('A'), _p('B')],
          partnerships: [],
          homePersonId: 'A');
      engine.resetToHome();
      expect(engine.visibleIds, isNot(contains('B')));
      engine.addVisibleId('B');
      expect(engine.visibleIds, contains('B'));
    });
  });
}
