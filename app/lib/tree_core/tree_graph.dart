import '../models/person.dart';

/// A directed parent -> child edge in the family graph.
class TreeEdge {
  final String parentId;
  final String childId;
  const TreeEdge(this.parentId, this.childId);

  @override
  bool operator ==(Object other) =>
      other is TreeEdge && other.parentId == parentId && other.childId == childId;

  @override
  int get hashCode => Object.hash(parentId, childId);

  @override
  String toString() => '$parentId -> $childId';
}

/// The result of [TreeGraph.sanitize]: a cycle-free view of the graph plus the
/// edges that had to be dropped to get there.
class SanitizedTreeGraph {
  /// Children per person after removing [droppedEdges] (sorted, deterministic).
  final Map<String, List<String>> children;

  /// Parents per person after removing [droppedEdges] (sorted, deterministic).
  final Map<String, List<String>> parents;

  /// Back edges removed to break cycles (self-parent edges included).
  final List<TreeEdge> droppedEdges;

  const SanitizedTreeGraph({
    required this.children,
    required this.parents,
    required this.droppedEdges,
  });

  bool get hadCycles => droppedEdges.isNotEmpty;
}

/// Pure-Dart, **iterative** (never recursive) algorithms over the parent/child
/// graph of a tree.
///
/// Real-world data can contain cycles (bad GEDCOM files, a merge of two edited
/// copies, a mis-click). Every algorithm here terminates on such input, runs in
/// O(V + E) and is deterministic: the result never depends on the order in
/// which people were supplied.
///
/// An edge `parent -> child` exists when either side lists the other
/// (`child.parentIds` contains parent, or `parent.childIds` contains child) and
/// both people are part of the graph. References to people outside the graph
/// are ignored.
class TreeGraph {
  TreeGraph._(this._ids, this._parents, this._children);

  factory TreeGraph.fromPersons(Iterable<Person> persons) {
    final ids = <String>{for (final p in persons) p.id};
    final parents = <String, Set<String>>{for (final id in ids) id: <String>{}};
    final children = <String, Set<String>>{for (final id in ids) id: <String>{}};

    void link(String parentId, String childId) {
      parents[childId]!.add(parentId);
      children[parentId]!.add(childId);
    }

    for (final p in persons) {
      for (final parentId in p.parentIds) {
        if (ids.contains(parentId)) link(parentId, p.id);
      }
      for (final childId in p.childIds) {
        if (ids.contains(childId)) link(p.id, childId);
      }
    }

    List<String> sorted(Set<String> s) => (s.toList()..sort());
    return TreeGraph._(
      ids,
      {for (final e in parents.entries) e.key: sorted(e.value)},
      {for (final e in children.entries) e.key: sorted(e.value)},
    );
  }

  final Set<String> _ids;
  final Map<String, List<String>> _parents;
  final Map<String, List<String>> _children;

  /// All person IDs in the graph.
  Set<String> get ids => _ids;

  List<String> parentsOf(String id) => _parents[id] ?? const [];
  List<String> childrenOf(String id) => _children[id] ?? const [];

  /// Total number of parent -> child edges (self edges included).
  int get edgeCount =>
      _children.values.fold<int>(0, (sum, list) => sum + list.length);

  /// True if adding the edge `parentId -> childId` would create a cycle, i.e.
  /// the child is the parent itself or already an ancestor of the parent.
  bool wouldCreateCycle({required String parentId, required String childId}) {
    if (parentId == childId) return true;
    if (!_ids.contains(parentId) || !_ids.contains(childId)) return false;
    final visited = <String>{childId};
    final queue = <String>[childId];
    for (var i = 0; i < queue.length; i++) {
      for (final next in childrenOf(queue[i])) {
        if (next == parentId) return true;
        if (visited.add(next)) queue.add(next);
      }
    }
    return false;
  }

  /// True if the graph contains at least one cycle.
  bool get hasCycle => sanitize().hadCycles;

  /// Breaks every cycle by dropping back edges found by a depth-first walk that
  /// visits people (and their children) in sorted-ID order, so the same data
  /// always yields the same result.
  SanitizedTreeGraph sanitize() {
    const gray = 1;
    const black = 2;
    final color = <String, int>{};
    final dropped = <TreeEdge>[];

    final order = _ids.toList()..sort();
    for (final start in order) {
      if (color.containsKey(start)) continue;
      color[start] = gray;
      final stack = <_Frame>[_Frame(start)];
      while (stack.isNotEmpty) {
        final frame = stack.last;
        final kids = childrenOf(frame.id);
        if (frame.next < kids.length) {
          final child = kids[frame.next++];
          final c = color[child];
          if (c == null) {
            color[child] = gray;
            stack.add(_Frame(child));
          } else if (c == gray) {
            // Edge back to a person still on the DFS stack: it closes a cycle.
            dropped.add(TreeEdge(frame.id, child));
          }
        } else {
          color[frame.id] = black;
          stack.removeLast();
        }
      }
    }

    final droppedSet = dropped.toSet();
    final children = <String, List<String>>{};
    final parents = <String, List<String>>{for (final id in _ids) id: <String>[]};
    for (final id in _ids) {
      final kept = [
        for (final child in childrenOf(id))
          if (!droppedSet.contains(TreeEdge(id, child))) child,
      ];
      children[id] = kept;
      for (final child in kept) {
        parents[child]!.add(id);
      }
    }
    for (final list in parents.values) {
      list.sort();
    }
    return SanitizedTreeGraph(
      children: children,
      parents: parents,
      droppedEdges: dropped,
    );
  }

  /// Longest-path generation depth per person on the cycle-free view: people
  /// without parents are generation 0 and every child is one generation below
  /// its deepest parent. Always terminates, O(V + E).
  Map<String, int> generations() {
    final graph = sanitize();
    final remaining = <String, int>{
      for (final e in graph.parents.entries) e.key: e.value.length,
    };
    final generation = <String, int>{};
    final queue = <String>[
      for (final id in (_ids.toList()..sort()))
        if (remaining[id] == 0) id,
    ];
    for (final id in queue) {
      generation[id] = 0;
    }
    for (var i = 0; i < queue.length; i++) {
      final id = queue[i];
      final next = generation[id]! + 1;
      for (final child in graph.children[id]!) {
        if ((generation[child] ?? 0) < next) generation[child] = next;
        remaining[child] = remaining[child]! - 1;
        if (remaining[child] == 0) queue.add(child);
      }
    }
    return generation;
  }

  /// Ancestors of [id] mapped to their distance (1 = parent, 2 = grandparent).
  /// Stops after [maxDepth] generations when given. Cycle-safe.
  Map<String, int> ancestors(String id, {int? maxDepth}) =>
      _walk(id, parentsOf, maxDepth);

  /// Descendants of [id] mapped to their distance (1 = child, 2 = grandchild).
  /// Stops after [maxDepth] generations when given. Cycle-safe.
  Map<String, int> descendants(String id, {int? maxDepth}) =>
      _walk(id, childrenOf, maxDepth);

  Map<String, int> _walk(
    String start,
    List<String> Function(String) next,
    int? maxDepth,
  ) {
    final distance = <String, int>{};
    if (!_ids.contains(start)) return distance;
    final queue = <String>[start];
    final seen = <String>{start};
    for (var i = 0; i < queue.length; i++) {
      final id = queue[i];
      final depth = (distance[id] ?? 0) + 1;
      if (maxDepth != null && depth > maxDepth) continue;
      for (final n in next(id)) {
        if (seen.add(n)) {
          distance[n] = depth;
          queue.add(n);
        }
      }
    }
    distance.remove(start);
    return distance;
  }

  /// Groups everyone into connected components (ignoring edge direction), each
  /// sorted, with components ordered by their smallest ID.
  List<List<String>> connectedComponents() {
    final seen = <String>{};
    final components = <List<String>>[];
    for (final start in (_ids.toList()..sort())) {
      if (!seen.add(start)) continue;
      final component = <String>[start];
      for (var i = 0; i < component.length; i++) {
        final id = component[i];
        for (final n in [...parentsOf(id), ...childrenOf(id)]) {
          if (seen.add(n)) component.add(n);
        }
      }
      components.add(component..sort());
    }
    return components;
  }
}

class _Frame {
  _Frame(this.id);
  final String id;
  int next = 0;
}
