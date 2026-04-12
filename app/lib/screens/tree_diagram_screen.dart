import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/partnership.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../services/sync_service.dart';
import '../utils/page_routes.dart';
import 'pedigree_screen.dart';
import 'person_detail_screen.dart';

// Layout constants
const double _kNodeW = 128.0;
const double _kNodeH = 88.0;
const double _kColGap = 44.0;
const double _kRowGap = 100.0;

// Internal node info
class _NodeInfo {
  final String id;
  bool isCoupleKnot;
  String? knotPartner1;
  String? knotPartner2;
  int generation;
  double x = 0;
  double y = 0;

  _NodeInfo({
    required this.id,
    this.isCoupleKnot = false,
    this.knotPartner1,
    this.knotPartner2,
    required this.generation,
  });
}

class _EdgeInfo {
  final String from;
  final String to;
  final bool isCouple;
  _EdgeInfo(this.from, this.to, {this.isCouple = false});
}

/// One entry per generation row used for the left-rail generation labels.
class _GenRow {
  final int generation;
  final double y;
  _GenRow(this.generation, this.y);
}

// Layout engine
class _TreeLayout {
  final List<Person> persons;
  final List<Partnership> partnerships;
  _TreeLayout(this.persons, this.partnerships);

  final Map<String, _NodeInfo> nodes = {};
  final List<_EdgeInfo> edges = [];
  final List<_GenRow> generationRows = [];
  Size canvasSize = Size.zero;

  void compute() {
    if (persons.isEmpty) return;
    final personMap = {for (final p in persons) p.id: p};
    final generation = <String, int>{};

    // BFS from roots
    final roots = persons.where((p) =>
        p.parentIds.isEmpty ||
        !p.parentIds.any((id) => personMap.containsKey(id))).toList();
    final queue = <String>[];
    for (final r in roots) { generation[r.id] = 0; queue.add(r.id); }
    for (final p in persons) {
      if (!generation.containsKey(p.id)) { generation[p.id] = 0; queue.add(p.id); }
    }
    int qi = 0;
    while (qi < queue.length) {
      final current = queue[qi++];
      final person = personMap[current];
      if (person == null) continue;
      final g = generation[current]!;
      for (final childId in person.childIds) {
        if (!personMap.containsKey(childId)) continue;
        if (!generation.containsKey(childId)) {
          generation[childId] = g + 1; queue.add(childId);
        } else if (generation[childId]! < g + 1) {
          generation[childId] = g + 1;
        }
      }
    }

    // Build person nodes
    for (final p in persons) {
      nodes[p.id] = _NodeInfo(id: p.id, generation: generation[p.id] ?? 0);
    }

    // Build couple knots
    final knotMap = <String, String>{};
    for (final p in partnerships) {
      if (!personMap.containsKey(p.person1Id) || !personMap.containsKey(p.person2Id)) continue;
      final knotId = 'knot_${p.id}';
      final knotGen = math.min(generation[p.person1Id] ?? 0, generation[p.person2Id] ?? 0);
      nodes[knotId] = _NodeInfo(
        id: knotId, isCoupleKnot: true,
        knotPartner1: p.person1Id, knotPartner2: p.person2Id, generation: knotGen,
      );
      knotMap[p.id] = knotId;
      edges.add(_EdgeInfo(p.person1Id, knotId, isCouple: true));
      edges.add(_EdgeInfo(p.person2Id, knotId, isCouple: true));
    }

    // Parent-child edges routed through knots
    for (final p in persons) {
      for (final childId in p.childIds) {
        if (!personMap.containsKey(childId)) continue;
        final childPerson = personMap[childId]!;
        Partnership? matchingPart;
        for (final part in partnerships) {
          if ((part.person1Id == p.id || part.person2Id == p.id) &&
              childPerson.parentIds.contains(part.person1Id) &&
              childPerson.parentIds.contains(part.person2Id)) {
            matchingPart = part; break;
          }
        }
        if (matchingPart != null && knotMap.containsKey(matchingPart.id)) {
          final knotId = knotMap[matchingPart.id]!;
          if (!edges.any((e) => e.from == knotId && e.to == childId)) {
            edges.add(_EdgeInfo(knotId, childId));
          }
        } else {
          edges.add(_EdgeInfo(p.id, childId));
        }
      }
    }

    // Assign x/y per generation
    final byGen = <int, List<String>>{};
    for (final n in nodes.values) {
      byGen.putIfAbsent(n.generation, () => []).add(n.id);
    }

    for (final entry in byGen.entries) {
      final gen = entry.key;
      final nodeIds = entry.value;
      nodeIds.sort((a, b) {
        final aK = nodes[a]!.isCoupleKnot ? 1 : 0;
        final bK = nodes[b]!.isCoupleKnot ? 1 : 0;
        return aK - bK;
      });
      final ordered = <String>[];
      final added = <String>{};
      for (final nid in nodeIds) {
        if (added.contains(nid) || nodes[nid]!.isCoupleKnot) continue;
        ordered.add(nid); added.add(nid);
      }
      for (final nid in nodeIds) {
        final node = nodes[nid]!;
        if (!node.isCoupleKnot) continue;
        final p1 = node.knotPartner1!; final p2 = node.knotPartner2!;
        final i1 = ordered.indexOf(p1); final i2 = ordered.indexOf(p2);
        if (i1 >= 0 && i2 >= 0) {
          if ((i2 - i1).abs() > 1) {
            ordered.remove(p2);
            final p1Idx = ordered.indexOf(p1);
            ordered.insert(p1Idx + 1, p2);
          }
          final p1Idx2 = ordered.indexOf(p1); final p2Idx2 = ordered.indexOf(p2);
          ordered.insert(math.min(p1Idx2, p2Idx2) + 1, nid); added.add(nid);
        } else {
          ordered.add(nid); added.add(nid);
        }
      }
      final step = _kNodeW + _kColGap;
      for (int i = 0; i < ordered.length; i++) {
        final node = nodes[ordered[i]]!;
        node.x = i * step;
        node.y = gen * (_kNodeH + _kRowGap);
      }
    }

    // Refine layout: iteratively centre parents over children and resolve overlaps.
    _refineLayout(byGen);

    // Canvas size
    double maxX = 0, maxY = 0;
    for (final n in nodes.values) {
      maxX = math.max(maxX, n.x + _kNodeW);
      maxY = math.max(maxY, n.y + _kNodeH);
    }
    canvasSize = Size(maxX + 40, maxY + 40);

    // Generation row labels (sorted ascending)
    generationRows.clear();
    final genNums = byGen.keys.toList()..sort();
    for (final gen in genNums) {
      generationRows.add(_GenRow(gen, gen * (_kNodeH + _kRowGap)));
    }
  }

  /// Iterative layout refinement:
  ///   1. Bottom-up: centre each non-knot parent node over its children.
  ///   2. Push apart overlapping nodes in each generation row.
  ///   3. Re-centre couple knots between their two partners.
  /// Three passes are enough for typical genealogy trees while remaining fast.
  void _refineLayout(Map<int, List<String>> byGen) {
    // Map: layoutParent -> [layoutChildren] using non-couple edges only.
    final childrenOf = <String, List<String>>{};
    for (final e in edges) {
      if (!e.isCouple) childrenOf.putIfAbsent(e.from, () => []).add(e.to);
    }

    final sortedGens = byGen.keys.toList()..sort(); // ascending (gen 0 = root)
    const step = _kNodeW + _kColGap;

    for (int iter = 0; iter < 3; iter++) {
      // --- Pass A: bottom-up centering of parents over their children ---
      for (final gen in sortedGens.reversed) {
        for (final id in (byGen[gen] ?? [])) {
          if (nodes[id]!.isCoupleKnot) continue; // handled in pass C
          final kids = (childrenOf[id] ?? [])
              .where((k) => nodes.containsKey(k))
              .toList();
          if (kids.isEmpty) continue;
          final childCx = kids
                  .map((k) => nodes[k]!.x + _kNodeW / 2)
                  .reduce((a, b) => a + b) /
              kids.length;
          nodes[id]!.x = childCx - _kNodeW / 2;
        }

        // --- Pass B: push apart overlapping nodes in this row ---
        final rowNodes = (byGen[gen] ?? [])
            .map((id) => nodes[id]!)
            .toList()
          ..sort((a, b) => a.x.compareTo(b.x));
        for (int i = 1; i < rowNodes.length; i++) {
          final minX = rowNodes[i - 1].x + step;
          if (rowNodes[i].x < minX) rowNodes[i].x = minX;
        }
      }

      // --- Pass C: centre couple knots between their two partners ---
      for (final node in nodes.values) {
        if (!node.isCoupleKnot) continue;
        final p1 = nodes[node.knotPartner1];
        final p2 = nodes[node.knotPartner2];
        if (p1 != null && p2 != null) {
          node.x = (p1.x + p2.x + _kNodeW) / 2.0 - _kNodeW / 2.0;
        }
      }
    }

    // Normalise: shift everything so the leftmost node is at x = 0.
    if (nodes.isNotEmpty) {
      final minX = nodes.values.map((n) => n.x).reduce(math.min);
      if (minX < 0) {
        for (final n in nodes.values) {
          n.x -= minX;
        }
      }
    }
  }
}

// Edge painter — uses smooth cubic-Bézier curves for parent→child edges
// and straight lines for partnership (couple) connections.
class _EdgePainter extends CustomPainter {
  final Map<String, _NodeInfo> nodes;
  final List<_EdgeInfo> edges;
  final Color edgeColor;
  final Color coupleColor;

  _EdgePainter({required this.nodes, required this.edges, required this.edgeColor, required this.coupleColor});

  @override
  void paint(Canvas canvas, Size size) {
    final parentPaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final couplePaint = Paint()
      ..color = coupleColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final edge in edges) {
      final fromNode = nodes[edge.from];
      final toNode = nodes[edge.to];
      if (fromNode == null || toNode == null) continue;

      if (edge.isCouple) {
        // Straight line between couple nodes / knot
        canvas.drawLine(
          Offset(fromNode.x + _kNodeW / 2, fromNode.y + _kNodeH / 2),
          Offset(toNode.x + _kNodeW / 2, toNode.y + _kNodeH / 2),
          couplePaint,
        );
      } else {
        // Smooth S-curve from the bottom-centre of the parent/knot to the
        // top-centre of the child node.
        final fromCx = fromNode.x + _kNodeW / 2;
        final fromBot = fromNode.isCoupleKnot
            ? fromNode.y + _kNodeH / 2  // knot centre
            : fromNode.y + _kNodeH;     // person bottom
        final toCx = toNode.x + _kNodeW / 2;
        final toTop = toNode.y;
        final dy = (toTop - fromBot).abs();
        final tension = math.min(dy * 0.5, _kRowGap * 0.6);

        final path = Path()
          ..moveTo(fromCx, fromBot)
          ..cubicTo(
            fromCx, fromBot + tension,
            toCx, toTop - tension,
            toCx, toTop,
          );
        canvas.drawPath(path, parentPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.nodes != nodes || old.edges != edges ||
      old.edgeColor != edgeColor || old.coupleColor != coupleColor;
}

// Main Screen
class TreeDiagramScreen extends StatefulWidget {
  const TreeDiagramScreen({super.key});
  @override
  State<TreeDiagramScreen> createState() => _TreeDiagramScreenState();
}

class _TreeDiagramScreenState extends State<TreeDiagramScreen> {
  final TransformationController _txCtrl = TransformationController();
  String _searchQuery = '';
  String? _selectedPersonId;
  bool _showLegend = false;

  /// When true, every person in the tree is visible (not just the focal family).
  bool _showingAll = false;

  /// IDs of persons currently rendered in the tree.
  Set<String> _visiblePersonIds = {};

  /// Tracks the last known home person ID so we can reset when it changes.
  String? _lastHomePersonId;

  /// Most recently computed layout — used by fit-to-view.
  _TreeLayout? _lastLayout;

  /// Last measured body viewport size — used by fit-to-view.
  Size _viewportSize = Size.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<TreeProvider>();
    final effectiveHomeId = provider.homePersonId ??
        (provider.persons.isNotEmpty ? provider.persons.first.id : null);

    if (effectiveHomeId != _lastHomePersonId || _visiblePersonIds.isEmpty) {
      _lastHomePersonId = effectiveHomeId;
      if (effectiveHomeId != null) {
        _visiblePersonIds = _buildInitialFamily(
          effectiveHomeId,
          provider.persons,
          provider.partnerships,
        );
      }
    }
  }

  /// Returns the IDs of the immediate family unit centred on [homeId]:
  /// the home person, their parents (+ each parent's partner), their own
  /// partners, and their children.
  static Set<String> _buildInitialFamily(
    String homeId,
    List<Person> persons,
    List<Partnership> partnerships,
  ) {
    final personMap = {for (final p in persons) p.id: p};
    final visible = <String>{homeId};
    final home = personMap[homeId];
    if (home == null) return visible;

    // Partners of the home person
    for (final part in partnerships) {
      if (part.person1Id == homeId && personMap.containsKey(part.person2Id)) {
        visible.add(part.person2Id);
      } else if (part.person2Id == homeId &&
          personMap.containsKey(part.person1Id)) {
        visible.add(part.person1Id);
      }
    }

    // Parents of the home person (and their partners)
    for (final parentId in home.parentIds) {
      if (!personMap.containsKey(parentId)) continue;
      visible.add(parentId);
      for (final part in partnerships) {
        if (part.person1Id == parentId &&
            personMap.containsKey(part.person2Id)) {
          visible.add(part.person2Id);
        } else if (part.person2Id == parentId &&
            personMap.containsKey(part.person1Id)) {
          visible.add(part.person1Id);
        }
      }
    }

    // Children of the home person
    for (final childId in home.childIds) {
      if (personMap.containsKey(childId)) visible.add(childId);
    }

    return visible;
  }

  void _resetToHome(List<Person> persons, List<Partnership> partnerships) {
    final effectiveHomeId = context.read<TreeProvider>().homePersonId ??
        (persons.isNotEmpty ? persons.first.id : null);
    if (effectiveHomeId == null) return;
    setState(() {
      _showingAll = false;
      _visiblePersonIds =
          _buildInitialFamily(effectiveHomeId, persons, partnerships);
    });
    _resetView();
  }

  /// Makes all persons in the tree visible at once.
  void _showAll(List<Person> persons) {
    setState(() {
      _showingAll = true;
      _visiblePersonIds = persons.map((p) => p.id).toSet();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  /// Adds [person]'s parents (and their partners) to the visible set.
  void _expandParents(
    Person person,
    Map<String, Person> personMap,
    List<Partnership> partnerships,
  ) {
    final newIds = <String>{};
    for (final parentId in person.parentIds) {
      if (!personMap.containsKey(parentId)) continue;
      newIds.add(parentId);
      for (final part in partnerships) {
        if (part.person1Id == parentId &&
            personMap.containsKey(part.person2Id)) {
          newIds.add(part.person2Id);
        } else if (part.person2Id == parentId &&
            personMap.containsKey(part.person1Id)) {
          newIds.add(part.person1Id);
        }
      }
    }
    if (newIds.isNotEmpty) {
      setState(() => _visiblePersonIds = {..._visiblePersonIds, ...newIds});
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    }
  }

  /// Adds [person]'s children to the visible set.
  void _expandChildren(Person person, Map<String, Person> personMap) {
    final newIds = person.childIds
        .where((id) => personMap.containsKey(id))
        .toSet();
    if (newIds.isNotEmpty) {
      setState(() => _visiblePersonIds = {..._visiblePersonIds, ...newIds});
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    }
  }

  /// Adds [person]'s siblings (children of the same parents) to the visible set.
  void _expandSiblings(Person person, Map<String, Person> personMap) {
    final newIds = <String>{};
    for (final parentId in person.parentIds) {
      final parent = personMap[parentId];
      if (parent == null) continue;
      for (final sibId in parent.childIds) {
        if (sibId != person.id && personMap.containsKey(sibId)) {
          newIds.add(sibId);
        }
      }
    }
    if (newIds.isNotEmpty) {
      setState(() => _visiblePersonIds = {..._visiblePersonIds, ...newIds});
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    }
  }

  /// BFS-expands ALL ancestors of [person] (and each ancestor's partners).
  void _expandAllAncestors(
    Person person,
    Map<String, Person> personMap,
    List<Partnership> partnerships,
  ) {
    final newIds = <String>{};
    final queue = <Person>[person];
    while (queue.isNotEmpty) {
      final p = queue.removeAt(0);
      for (final parentId in p.parentIds) {
        if (!personMap.containsKey(parentId)) continue;
        if (!_visiblePersonIds.contains(parentId) && !newIds.contains(parentId)) {
          newIds.add(parentId);
          queue.add(personMap[parentId]!);
        }
        // Include each parent's partners so couple knots render correctly.
        for (final part in partnerships) {
          String? partnerId;
          if (part.person1Id == parentId) partnerId = part.person2Id;
          if (part.person2Id == parentId) partnerId = part.person1Id;
          if (partnerId != null &&
              personMap.containsKey(partnerId) &&
              !_visiblePersonIds.contains(partnerId) &&
              !newIds.contains(partnerId)) {
            newIds.add(partnerId);
          }
        }
      }
    }
    if (newIds.isNotEmpty) {
      setState(() => _visiblePersonIds = {..._visiblePersonIds, ...newIds});
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    }
  }

  /// BFS-expands ALL descendants of [person].
  void _expandAllDescendants(Person person, Map<String, Person> personMap) {
    final newIds = <String>{};
    final queue = <Person>[person];
    while (queue.isNotEmpty) {
      final p = queue.removeAt(0);
      for (final childId in p.childIds) {
        if (!personMap.containsKey(childId)) continue;
        if (!_visiblePersonIds.contains(childId) && !newIds.contains(childId)) {
          newIds.add(childId);
          queue.add(personMap[childId]!);
        }
      }
    }
    if (newIds.isNotEmpty) {
      setState(() => _visiblePersonIds = {..._visiblePersonIds, ...newIds});
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    }
  }

  @override
  void dispose() { _txCtrl.dispose(); super.dispose(); }

  void _zoom(double factor) {
    final s = _txCtrl.value.getMaxScaleOnAxis();
    final ns = (s * factor).clamp(0.05, 5.0);
    _txCtrl.value = _txCtrl.value.clone()..scale(ns / s);
  }
  void _resetView() => _txCtrl.value = Matrix4.identity();

  /// Scales and centres the view so all visible nodes fit in the viewport.
  void _fitView() {
    final layout = _lastLayout;
    final vp = _viewportSize;
    if (layout == null || layout.canvasSize == Size.zero || vp == Size.zero) {
      _resetView();
      return;
    }
    const padding = 48.0;
    final sx = (vp.width  - padding * 2) / layout.canvasSize.width;
    final sy = (vp.height - padding * 2) / layout.canvasSize.height;
    final scale = (sx < sy ? sx : sy).clamp(0.05, 1.0);
    final scaledW = layout.canvasSize.width  * scale;
    final scaledH = layout.canvasSize.height * scale;
    final tx = (vp.width  - scaledW) / 2;
    final ty = (vp.height - scaledH) / 2;
    _txCtrl.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);
  }

  void _showPersonSheet(
    BuildContext context,
    Person person,
    Map<String, Person> personMap,
    List<Partnership> partnerships,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasHiddenParents = person.parentIds
        .any((id) => personMap.containsKey(id) && !_visiblePersonIds.contains(id));
    final hasHiddenChildren = person.childIds
        .any((id) => personMap.containsKey(id) && !_visiblePersonIds.contains(id));
    final hasHiddenSiblings = person.parentIds.any((parentId) {
      final parent = personMap[parentId];
      if (parent == null) return false;
      return parent.childIds.any(
          (id) => id != person.id && personMap.containsKey(id) && !_visiblePersonIds.contains(id));
    });

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Color avatarBg = colorScheme.secondary;
        if (person.gender?.toLowerCase() == 'male') avatarBg = colorScheme.primary;
        if (person.gender?.toLowerCase() == 'female') avatarBg = colorScheme.error;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                CircleAvatar(
                  radius: 28, backgroundColor: avatarBg,
                  child: Text(
                    person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.name,
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    if (person.birthDate != null || person.deathDate != null)
                      Text(
                        [if (person.birthDate != null) 'b. ${person.birthDate!.year}',
                         if (person.deathDate != null) 'd. ${person.deathDate!.year}'].join('  ·  '),
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant)),
                    if (person.birthPlace != null)
                      Text(person.birthPlace!,
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant)),
                  ])),
              ]),
              if (person.occupation != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.work_outline, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(person.occupation!, style: Theme.of(ctx).textTheme.bodyMedium),
                ]),
              ],
              const SizedBox(height: 20),
              // Primary actions
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline), label: const Text('Full Profile'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context,
                        fadeSlideRoute(builder: (_) => PersonDetailScreen(person: person)));
                  })),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(
                  icon: const Icon(Icons.center_focus_strong), label: const Text('Focus'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedPersonId = person.id;
                      _visiblePersonIds = _buildInitialFamily(
                          person.id,
                          personMap.values.toList(),
                          partnerships);
                    });
                    _resetView();
                  })),
              ]),
              // Expand actions — only shown when there is something to expand
              if (hasHiddenParents || hasHiddenChildren || hasHiddenSiblings) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasHiddenParents)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.keyboard_arrow_up, size: 16),
                        label: const Text('Show Parents'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandParents(person, personMap, partnerships);
                        }),
                    if (hasHiddenChildren)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        label: const Text('Show Children'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandChildren(person, personMap);
                        }),
                    if (hasHiddenSiblings)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.people_outline, size: 16),
                        label: const Text('Show Siblings'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandSiblings(person, personMap);
                        }),
                  ],
                ),
              ],
              // "Expand all" chain actions
              if (hasHiddenParents || hasHiddenChildren) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasHiddenParents)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.account_tree, size: 16),
                        label: const Text('All Ancestors'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandAllAncestors(person, personMap, partnerships);
                        }),
                    if (hasHiddenChildren)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.account_tree, size: 16),
                        label: const Text('All Descendants'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandAllDescendants(person, personMap);
                        }),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final syncService = context.watch<SyncService>();
    final colorScheme = Theme.of(context).colorScheme;
    final persons = provider.persons;
    final partnerships = provider.partnerships;

    if (persons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Tree')),
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree_outlined, size: 80,
                color: colorScheme.primary.withOpacity(0.35)),
            const SizedBox(height: 16),
            Text('No people in the tree yet.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Add people from the home screen.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
          ])),
      );
    }

    final personMap = {for (final p in persons) p.id: p};

    // Ensure visible set is initialised (e.g. first build after load).
    if (_visiblePersonIds.isEmpty) {
      final homeId = provider.homePersonId ??
          (persons.isNotEmpty ? persons.first.id : null);
      if (homeId != null) {
        _visiblePersonIds =
            _buildInitialFamily(homeId, persons, partnerships);
        _lastHomePersonId = homeId;
      }
    }

    // Build layout from visible persons only.
    final visiblePersons = persons
        .where((p) => _visiblePersonIds.contains(p.id))
        .toList();
    final visiblePartnerships = partnerships.where((part) =>
        _visiblePersonIds.contains(part.person1Id) &&
        _visiblePersonIds.contains(part.person2Id)).toList();

    final layout = _TreeLayout(visiblePersons, visiblePartnerships);
    layout.compute();
    _lastLayout = layout;
    final searchLower = _searchQuery.toLowerCase();

    // Live collaboration: show how many peers are currently synced/syncing.
    final peerCount = syncService.discoveredPeers.length;
    final isSyncing = syncService.status == SyncStatus.syncing;
    final isCollaborating = syncService.isServerRunning &&
        (peerCount > 0 || isSyncing);

    final shownCount = visiblePersons.length;
    final totalCount = persons.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Family Tree'),
            const SizedBox(width: 8),
            // Node count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                shownCount == totalCount
                    ? '$totalCount'
                    : '$shownCount / $totalCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            // Live collaboration indicator
            if (isCollaborating) ...[
              const SizedBox(width: 6),
              _LiveDot(isSyncing: isSyncing, peerCount: peerCount),
            ],
          ],
        ),
        actions: [
          // Show all / focus home toggle
          IconButton(
            icon: Icon(_showingAll ? Icons.center_focus_strong : Icons.account_tree),
            tooltip: _showingAll ? 'Focus on home person' : 'Show entire tree',
            onPressed: _showingAll
                ? () => _resetToHome(persons, partnerships)
                : () => _showAll(persons)),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Reset to home person',
            onPressed: () => _resetToHome(persons, partnerships)),
          IconButton(
            icon: const Icon(Icons.legend_toggle),
            tooltip: 'Legend',
            onPressed: () => setState(() => _showLegend = !_showLegend)),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Pedigree Chart',
            onPressed: () => Navigator.push(
                context, fadeSlideRoute(builder: (_) => const PedigreeScreen()))),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''))
                    : null,
                filled: true,
                fillColor: colorScheme.onPrimary.withOpacity(0.15),
                hintStyle: TextStyle(color: colorScheme.onPrimary.withOpacity(0.7)),
                prefixIconColor: colorScheme.onPrimary.withOpacity(0.8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              style: TextStyle(color: colorScheme.onPrimary),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          // Track viewport size for fit-to-view.
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(children: [
            InteractiveViewer(
              transformationController: _txCtrl,
              constrained: false,
              minScale: 0.05,
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(6000),
              child: SizedBox(
                width: layout.canvasSize.width,
                height: layout.canvasSize.height,
                child: Stack(children: [
                  // Bezier edge lines
                  Positioned.fill(child: CustomPaint(painter: _EdgePainter(
                    nodes: layout.nodes, edges: layout.edges,
                    edgeColor: colorScheme.outline.withOpacity(0.5),
                    coupleColor: colorScheme.tertiary.withOpacity(0.7)))),

                  // Generation row labels (left rail)
                  for (final row in layout.generationRows)
                    Positioned(
                      left: 0,
                      top: row.y + (_kNodeH - 18) / 2,
                      child: _GenLabel(
                        generation: row.generation,
                        colorScheme: colorScheme,
                      ),
                    ),

                  // Person / couple-knot nodes
                  for (final node in layout.nodes.values)
                    Positioned(
                      left: node.x, top: node.y, width: _kNodeW, height: _kNodeH,
                      child: node.isCoupleKnot
                          ? _CoupleKnot(
                              node: node,
                              partnerships: visiblePartnerships,
                              colorScheme: colorScheme)
                          : _PersonNodeWidget(
                              person: personMap[node.id] ?? Person(id: node.id, name: '?'),
                              colorScheme: colorScheme,
                              isHighlighted: searchLower.isNotEmpty &&
                                  (personMap[node.id]?.name.toLowerCase().contains(searchLower) ?? false),
                              isSelected: _selectedPersonId == node.id,
                              hasHiddenAncestors: (() {
                                final p = personMap[node.id];
                                if (p == null) return false;
                                return p.parentIds.any((id) =>
                                    personMap.containsKey(id) &&
                                    !_visiblePersonIds.contains(id));
                              })(),
                              hasHiddenDescendants: (() {
                                final p = personMap[node.id];
                                if (p == null) return false;
                                return p.childIds.any((id) =>
                                    personMap.containsKey(id) &&
                                    !_visiblePersonIds.contains(id));
                              })(),
                              onTap: () {
                                final p = personMap[node.id];
                                if (p == null) return;
                                setState(() => _selectedPersonId = node.id);
                                _showPersonSheet(context, p, personMap, partnerships);
                              }),
                    ),
                ]),
              ),
            ),

            // Legend overlay
            if (_showLegend)
              Positioned(
                top: 8, right: 8,
                child: _LegendCard(
                    colorScheme: colorScheme,
                    onClose: () => setState(() => _showLegend = false))),

            // Zoom controls (bottom-right)
            Positioned(
              bottom: 24, right: 16,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _ZoomFab(heroTag: 'ft_zi', icon: Icons.add, onPressed: () => _zoom(1.3)),
                const SizedBox(height: 8),
                _ZoomFab(heroTag: 'ft_zo', icon: Icons.remove, onPressed: () => _zoom(1 / 1.3)),
                const SizedBox(height: 8),
                _ZoomFab(heroTag: 'ft_zr', icon: Icons.fit_screen,
                    tooltip: 'Fit to view', onPressed: _fitView),
                const SizedBox(height: 8),
                _ZoomFab(heroTag: 'ft_zreset', icon: Icons.filter_center_focus,
                    tooltip: 'Reset zoom', onPressed: _resetView),
              ])),

            // Zoom % indicator (bottom-left)
            Positioned(bottom: 24, left: 16, child: _ZoomIndicator(controller: _txCtrl)),

            // Search match count (bottom-centre)
            if (searchLower.isNotEmpty)
              Positioned(
                bottom: 24, left: 0, right: 0,
                child: Center(child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: () {
                    final count = persons
                        .where((p) => p.name.toLowerCase().contains(searchLower))
                        .length;
                    return Container(
                      key: ValueKey(count),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.inverseSurface.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        count == 0
                            ? 'No matches'
                            : '$count match${count == 1 ? "" : "es"}',
                        style: TextStyle(
                            color: colorScheme.onInverseSurface, fontSize: 13)));
                  }(),
                ))),
          ]);
        },
      ),
    );
  }
}

// Person node widget
class _PersonNodeWidget extends StatelessWidget {
  final Person person;
  final ColorScheme colorScheme;
  final bool isHighlighted;
  final bool isSelected;
  final bool hasHiddenAncestors;
  final bool hasHiddenDescendants;
  final VoidCallback onTap;

  const _PersonNodeWidget({
    required this.person, required this.colorScheme,
    required this.isHighlighted, required this.isSelected,
    this.hasHiddenAncestors = false,
    this.hasHiddenDescendants = false,
    required this.onTap});

  Color _borderColor() {
    if (isHighlighted) return Colors.amber;
    if (isSelected) return colorScheme.primary;
    if (person.gender?.toLowerCase() == 'male') return colorScheme.primary;
    if (person.gender?.toLowerCase() == 'female') return colorScheme.error;
    return colorScheme.secondary;
  }

  Color _avatarBg() {
    if (person.gender?.toLowerCase() == 'male') return colorScheme.primary;
    if (person.gender?.toLowerCase() == 'female') return colorScheme.error;
    return colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor();
    final avatarBg = _avatarBg();
    final bool isDead = person.deathDate != null;
    final card = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isHighlighted || isSelected ? 2.5 : 1.5),
          boxShadow: [BoxShadow(color: borderColor.withOpacity(isSelected ? 0.3 : 0.12), blurRadius: isSelected ? 8 : 4, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(width: 6, decoration: BoxDecoration(
            color: avatarBg.withOpacity(0.85),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)))),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 14, backgroundColor: avatarBg,
                  child: Text(person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                    style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(width: 6),
                Expanded(child: Text(person.name,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: colorScheme.onSurface),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
                if (isDead) Icon(Icons.star, size: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
              ]),
              const SizedBox(height: 3),
              if (person.birthDate != null || person.deathDate != null)
                Text(
                  [if (person.birthDate != null) '${person.birthDate!.year}',
                   if (person.deathDate != null) '${person.deathDate!.year}'].join(' – '),
                  style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant)),
              if (person.birthPlace != null)
                Text(person.birthPlace!, style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant.withOpacity(0.8)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          )),
        ]),
      ),
    );

    // Wrap in a Stack to overlay expand indicator dots.
    if (!hasHiddenAncestors && !hasHiddenDescendants) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        if (hasHiddenAncestors)
          Positioned(
            top: -7,
            left: 0, right: 0,
            child: Center(child: _ExpandDot(
              icon: Icons.keyboard_arrow_up, colorScheme: colorScheme))),
        if (hasHiddenDescendants)
          Positioned(
            bottom: -7,
            left: 0, right: 0,
            child: Center(child: _ExpandDot(
              icon: Icons.keyboard_arrow_down, colorScheme: colorScheme))),
      ],
    );
  }
}

/// Small circular indicator showing that hidden relatives exist in a direction.
class _ExpandDot extends StatelessWidget {
  final IconData icon;
  final ColorScheme colorScheme;
  const _ExpandDot({required this.icon, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.4), blurRadius: 4)],
      ),
      child: Icon(icon, size: 12, color: colorScheme.onPrimary),
    );
  }
}

// Couple knot widget
class _CoupleKnot extends StatelessWidget {
  final _NodeInfo node;
  final List<Partnership> partnerships;
  final ColorScheme colorScheme;
  const _CoupleKnot({required this.node, required this.partnerships, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final partId = node.id.startsWith('knot_') ? node.id.substring(5) : '';
    final part = partnerships.where((p) => p.id == partId).firstOrNull;
    final year = part?.startDate?.year;
    return Center(child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: colorScheme.tertiaryContainer, shape: BoxShape.circle,
        border: Border.all(color: colorScheme.tertiary, width: 1.5)),
      child: Center(child: year != null
          ? Text('${year % 100}', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colorScheme.onTertiaryContainer))
          : Icon(Icons.favorite, size: 10, color: colorScheme.tertiary)),
    ));
  }
}

// Legend card
class _LegendCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final VoidCallback onClose;
  const _LegendCard({required this.colorScheme, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(elevation: 4, child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Legend', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          GestureDetector(onTap: onClose, child: Icon(Icons.close, size: 16, color: colorScheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 8),
        _LegendItem(color: colorScheme.primary, label: 'Male'),
        _LegendItem(color: colorScheme.error, label: 'Female'),
        _LegendItem(color: colorScheme.secondary, label: 'Other / Unknown'),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 24, height: 2, color: colorScheme.outline.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text('Parent – child', style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 24, height: 2, color: colorScheme.tertiary.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text('Partnership', style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 16, height: 16,
            decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.tertiaryContainer,
              border: Border.all(color: colorScheme.tertiary, width: 1.5)),
            child: Center(child: Icon(Icons.favorite, size: 8, color: colorScheme.tertiary))),
          const SizedBox(width: 8),
          Text('Union knot', style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.star, size: 12, color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
          const SizedBox(width: 8),
          Text('Deceased', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ]),
    ));
  }
}

class _LegendItem extends StatelessWidget {
  final Color color; final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 24, decoration: BoxDecoration(color: color.withOpacity(0.85), borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]));
  }
}

// Zoom helpers
class _ZoomFab extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const _ZoomFab({
    required this.heroTag,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: FloatingActionButton.small(
        heroTag: heroTag,
        onPressed: onPressed,
        elevation: 2,
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _ZoomIndicator extends StatefulWidget {
  final TransformationController controller;
  const _ZoomIndicator({required this.controller});
  @override
  State<_ZoomIndicator> createState() => _ZoomIndicatorState();
}

class _ZoomIndicatorState extends State<_ZoomIndicator> {
  @override
  void initState() { super.initState(); widget.controller.addListener(_rebuild); }
  @override
  void dispose() { widget.controller.removeListener(_rebuild); super.dispose(); }
  void _rebuild() => setState(() {});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pct = (widget.controller.value.getMaxScaleOnAxis() * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2))),
      child: Text('$pct%', style: TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w500)));
  }
}

// Generation row label rendered in the tree canvas.
class _GenLabel extends StatelessWidget {
  final int generation;
  final ColorScheme colorScheme;
  const _GenLabel({required this.generation, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final label = generation == 0 ? 'Home' : 'Gen ${generation + 1}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// Animated pulsing dot shown in the AppBar when live-sync is active.
class _LiveDot extends StatefulWidget {
  final bool isSyncing;
  final int peerCount;
  const _LiveDot({required this.isSyncing, required this.peerCount});
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.isSyncing ? cs.tertiary : Colors.green;
    return Tooltip(
      message: widget.isSyncing
          ? 'Syncing…'
          : 'Live sync active — ${widget.peerCount} '
              'device${widget.peerCount == 1 ? '' : 's'} connected',
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.4 + 0.6 * _ctrl.value),
          ),
        ),
      ),
    );
  }
}
