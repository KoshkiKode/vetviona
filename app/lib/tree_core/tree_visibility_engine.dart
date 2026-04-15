// app/lib/tree_core/tree_visibility_engine.dart
//
// Central visibility-state manager for all family-tree views.
//
// Keeps the set of IDs that are currently rendered and provides
// consistent, home-person-anchored expansion helpers used by
// FamilyTreeScreen, DescendantsScreen, and PedigreeScreen.

import 'dart:collection';

import '../models/partnership.dart';
import '../models/person.dart';

/// Manages which persons are visible in the tree at any given time.
///
/// The engine is the single source of truth for the "visible persons" set.
/// It is anchored to a *home person* and supports incremental expansion by
/// direction (ancestors, descendants, siblings, partners) and BFS sweeps.
///
/// Usage pattern:
/// ```dart
/// final engine = TreeVisibilityEngine(
///   persons: provider.persons,
///   partnerships: provider.partnerships,
///   homePersonId: provider.homePersonId,
/// );
/// engine.resetToHome(ancestorGens: 2, descendantGens: 2);
/// // later…
/// engine.expandParents(personId);
/// final visible = engine.visibleIds; // use in build()
/// ```
///
/// When the provider data changes but the home person stays the same, call
/// [withUpdatedData] to get a new engine that preserves the current expansion
/// state while using fresh person/partnership lists.
class TreeVisibilityEngine {
  final List<Person> persons;
  final List<Partnership> partnerships;
  final String? homePersonId;

  late final Map<String, Person> _personMap;
  final Set<String> _visibleIds;

  TreeVisibilityEngine({
    required this.persons,
    required this.partnerships,
    this.homePersonId,
    Set<String>? initialVisibleIds,
  }) : _visibleIds = Set<String>.from(initialVisibleIds ?? const {}) {
    _personMap = {for (final p in persons) p.id: p};
  }

  // ── Factory / copy ──────────────────────────────────────────────────────────

  /// Returns a new engine with updated persons/partnerships but the *same*
  /// visibility state.  Call this when the provider data changes but you
  /// want to preserve what the user has already expanded.
  TreeVisibilityEngine withUpdatedData({
    required List<Person> persons,
    required List<Partnership> partnerships,
    String? homePersonId,
  }) => TreeVisibilityEngine(
    persons: persons,
    partnerships: partnerships,
    homePersonId: homePersonId ?? this.homePersonId,
    initialVisibleIds: Set<String>.from(_visibleIds),
  );

  // ── State accessors ─────────────────────────────────────────────────────────

  /// Read-only view of the currently visible person IDs.
  Set<String> get visibleIds => Set.unmodifiable(_visibleIds);

  /// Whether any person is visible.
  bool get hasVisible => _visibleIds.isNotEmpty;

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Clears the visible set and rebuilds it centered on the home person.
  ///
  /// Shows [ancestorGens] generations of ancestors (with each ancestor's
  /// partners) and [descendantGens] generations of descendants (with each
  /// descendant's partners).
  void resetToHome({int ancestorGens = 1, int descendantGens = 1}) {
    _visibleIds.clear();
    final homeId =
        homePersonId ?? (persons.isNotEmpty ? persons.first.id : null);
    if (homeId == null || !_personMap.containsKey(homeId)) return;
    _addFamily(homeId, ancestorGens, descendantGens);
  }

  void _addFamily(String rootId, int ancestorGens, int descendantGens) {
    _visibleIds.add(rootId);
    _addPartners(rootId, _visibleIds);
    _addAncestors(rootId, ancestorGens, _visibleIds);
    _addDescendants(rootId, descendantGens, _visibleIds);
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  void _addPartners(String personId, Set<String> out) {
    for (final part in partnerships) {
      if (part.person1Id == personId &&
          _personMap.containsKey(part.person2Id)) {
        out.add(part.person2Id);
      } else if (part.person2Id == personId &&
          _personMap.containsKey(part.person1Id)) {
        out.add(part.person1Id);
      }
    }
  }

  void _addAncestors(String personId, int gens, Set<String> out) {
    if (gens <= 0) return;
    final person = _personMap[personId];
    if (person == null) return;
    for (final parentId in person.parentIds) {
      if (!_personMap.containsKey(parentId)) continue;
      out.add(parentId);
      _addPartners(parentId, out);
      _addAncestors(parentId, gens - 1, out);
    }
  }

  void _addDescendants(String personId, int gens, Set<String> out) {
    if (gens <= 0) return;
    final person = _personMap[personId];
    if (person == null) return;
    for (final childId in person.childIds) {
      if (!_personMap.containsKey(childId)) continue;
      out.add(childId);
      _addPartners(childId, out);
      _addDescendants(childId, gens - 1, out);
    }
  }

  // ── Single-step expansion ───────────────────────────────────────────────────

  /// Adds direct parents of [personId] (+ each parent's partners).
  void expandParents(String personId) {
    final person = _personMap[personId];
    if (person == null) return;
    for (final parentId in person.parentIds) {
      if (!_personMap.containsKey(parentId)) continue;
      _visibleIds.add(parentId);
      _addPartners(parentId, _visibleIds);
    }
  }

  /// Adds direct children of [personId] (+ each child's partners).
  void expandChildren(String personId) {
    final person = _personMap[personId];
    if (person == null) return;
    for (final childId in person.childIds) {
      if (!_personMap.containsKey(childId)) continue;
      _visibleIds.add(childId);
      _addPartners(childId, _visibleIds);
    }
  }

  /// Adds siblings of [personId] — children of the same parents (+ their partners).
  void expandSiblings(String personId) {
    final person = _personMap[personId];
    if (person == null) return;
    for (final parentId in person.parentIds) {
      final parent = _personMap[parentId];
      if (parent == null) continue;
      for (final sibId in parent.childIds) {
        if (sibId == personId || !_personMap.containsKey(sibId)) continue;
        _visibleIds.add(sibId);
        _addPartners(sibId, _visibleIds);
      }
    }
  }

  // ── BFS expansion ───────────────────────────────────────────────────────────

  /// BFS-expands ALL ancestors of [personId] (+ each ancestor's partners).
  void expandAllAncestors(String personId) {
    final queue = Queue<String>()..add(personId);
    final visited = <String>{personId};
    while (queue.isNotEmpty) {
      final id = queue.removeFirst();
      final person = _personMap[id];
      if (person == null) continue;
      for (final parentId in person.parentIds) {
        if (!_personMap.containsKey(parentId)) continue;
        _visibleIds.add(parentId);
        _addPartners(parentId, _visibleIds);
        if (!visited.contains(parentId)) {
          visited.add(parentId);
          queue.add(parentId);
        }
      }
    }
  }

  /// BFS-expands ALL descendants of [personId] (+ each descendant's partners).
  void expandAllDescendants(String personId) {
    final queue = Queue<String>()..add(personId);
    final visited = <String>{personId};
    while (queue.isNotEmpty) {
      final id = queue.removeFirst();
      final person = _personMap[id];
      if (person == null) continue;
      for (final childId in person.childIds) {
        if (!_personMap.containsKey(childId)) continue;
        _visibleIds.add(childId);
        _addPartners(childId, _visibleIds);
        if (!visited.contains(childId)) {
          visited.add(childId);
          queue.add(childId);
        }
      }
    }
  }

  // ── Bulk operations ─────────────────────────────────────────────────────────

  /// Makes every person in the tree visible.
  void showAll() {
    for (final p in persons) {
      _visibleIds.add(p.id);
    }
  }

  /// Clears the visible set and rebuilds it centered on [personId].
  void focusOn(
    String personId, {
    int ancestorGens = 1,
    int descendantGens = 1,
  }) {
    _visibleIds.clear();
    _addFamily(personId, ancestorGens, descendantGens);
  }

  /// Directly adds an ID to the visible set (used after quick-add operations
  /// where we want the newly created person to appear immediately).
  void addVisibleId(String id) => _visibleIds.add(id);

  // ── Query helpers ───────────────────────────────────────────────────────────

  /// Returns `true` if [personId] has at least one parent in the tree that
  /// is not currently visible.
  bool hasHiddenAncestors(String personId) {
    final person = _personMap[personId];
    if (person == null) return false;
    return person.parentIds.any(
      (id) => _personMap.containsKey(id) && !_visibleIds.contains(id),
    );
  }

  /// Returns `true` if [personId] has at least one child in the tree that
  /// is not currently visible.
  bool hasHiddenDescendants(String personId) {
    final person = _personMap[personId];
    if (person == null) return false;
    return person.childIds.any(
      (id) => _personMap.containsKey(id) && !_visibleIds.contains(id),
    );
  }

  /// Returns `true` if [personId] has at least one sibling that is not
  /// currently visible.
  bool hasHiddenSiblings(String personId) {
    final person = _personMap[personId];
    if (person == null) return false;
    return person.parentIds.any((parentId) {
      final parent = _personMap[parentId];
      if (parent == null) return false;
      return parent.childIds.any(
        (id) =>
            id != personId &&
            _personMap.containsKey(id) &&
            !_visibleIds.contains(id),
      );
    });
  }
}
