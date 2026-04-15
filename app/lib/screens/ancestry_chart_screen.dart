// app/lib/screens/ancestry_chart_screen.dart
//
// Vertical ancestry tree.
//
// The home (root) person appears at the bottom-centre of the canvas.
// Their parents are one row above, grandparents two rows above, and so on.
// The layout algorithm mirrors DescendantsScreen but traverses *parents*
// instead of children.

import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/partnership.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../tree_core/tree_preset.dart';
import '../utils/page_routes.dart';
import 'person_detail_screen.dart';

// ── Layout constants (fallback when no preset provided) ───────────────────────
const double _kNodeW = 152.0;
const double _kNodeH = 86.0;
const double _kColGap = 44.0;
const double _kRowGap = 100.0;

// ── Node / edge models ────────────────────────────────────────────────────────

class _AncNode {
  final String id;
  final bool isCoupleKnot;
  final String? knotPartner1; // first partner id (isCoupleKnot==true only)
  final String? knotPartner2; // second partner id
  double x;
  double y;

  _AncNode({
    required this.id,
    required this.x,
    required this.y,
    this.isCoupleKnot = false,
    this.knotPartner1,
    this.knotPartner2,
  });
}

class _AncEdge {
  final String from;
  final String to;
  final bool isCouple;
  const _AncEdge(this.from, this.to, {this.isCouple = false});
}

// ── Ancestry layout ───────────────────────────────────────────────────────────

/// Computes node positions for the ancestry view.
///
/// Root is at generation 0 (placed at the bottom of the canvas).
/// Each subsequent generation (parents, grandparents…) occupies a row higher
/// up on the canvas.
class _AncestryLayout {
  final List<Person> persons;
  final List<Partnership> partnerships;

  // IDs that are actual ancestors (partners-in-law are not).
  final Set<String> ancestorIds;

  final double nodeW;
  final double nodeH;
  final double colGap;
  final double rowGap;

  final Map<String, _AncNode> nodes = {};
  final List<_AncEdge> edges = [];
  Size canvasSize = Size.zero;
  int maxGen = 0;

  _AncestryLayout(
    this.persons,
    this.partnerships,
    this.ancestorIds, {
    this.nodeW = _kNodeW,
    this.nodeH = _kNodeH,
    this.colGap = _kColGap,
    this.rowGap = _kRowGap,
  });

  void compute() {
    if (persons.isEmpty) return;

    final pm = {for (final p in persons) p.id: p};

    // ── Assign generation depths via BFS upward ───────────────────────────────
    // Generation 0 = root person (bottom of canvas).
    // Each generation of parents/grandparents is gen+1.
    final genMap = <String, int>{};
    final queue = Queue<String>();
    for (final id in ancestorIds) {
      genMap[id] = 0;
    }
    // Seed the BFS with the single root (gen 0 = only person with gen assigned as root).
    // We need the actual root; find the one with no overlap.
    // Since ancestorIds is built BFS-upward from the root with proper gens,
    // we trust the caller to supply genMap instead. We'll build our own:
    genMap.clear();
    // The root is the person who is a full ancestor of nobody else here.
    // Simpler: ancestorIds are the BFS nodes, ordered so that the root is
    // the person whose parentIds are NOT in ancestorIds — but that's complex.
    // Easier: we receive ancestorIds as BFS output; re-run BFS to assign gens.

    // For the ancestry layout, all persons in `persons` list are included.
    // Find the person who is the "root" (lowest gen = 0) = the one who is not
    // in any person's parentIds within this set.
    // ── Detect root person ────────────────────────────────────────────────────
    // The root is the focal person (lowest generation): the only member of
    // `ancestorIds` that does NOT appear as a parentId of any other member of
    // `ancestorIds`.  Using only `ancestorIds` (not all `persons`) avoids
    // incorrectly picking a partner-in-law who also has no children in the set.
    final ancestorParentIds = <String>{};
    for (final id in ancestorIds) {
      final p = pm[id];
      if (p == null) continue;
      for (final pid in p.parentIds) {
        if (ancestorIds.contains(pid)) ancestorParentIds.add(pid);
      }
    }
    final rootCandidates = ancestorIds
        .where((id) => !ancestorParentIds.contains(id))
        .toList();
    final rootPerson =
        (rootCandidates.isNotEmpty ? pm[rootCandidates.first] : null) ??
        persons.first;

    // BFS upward from the root.
    queue.add(rootPerson.id);
    genMap[rootPerson.id] = 0;

    while (queue.isNotEmpty) {
      final id = queue.removeFirst();
      final person = pm[id];
      if (person == null) continue;
      final gen = genMap[id]!;
      for (final parentId in person.parentIds) {
        if (pm.containsKey(parentId) && !genMap.containsKey(parentId)) {
          genMap[parentId] = gen + 1;
          queue.add(parentId);
        }
      }
    }

    // Assign gen 0 to any person not yet reached.
    for (final p in persons) {
      genMap.putIfAbsent(p.id, () => 0);
    }

    maxGen = genMap.values.fold(0, math.max);

    // ── Group by generation ───────────────────────────────────────────────────
    final byGen = <int, List<String>>{};
    for (final entry in genMap.entries) {
      byGen.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    // ── Insert couple knots ───────────────────────────────────────────────────
    // For each partnership where both members are in the layout, add a knot.
    final knotFor = <String, String>{}; // partnshipId → knotId
    for (final part in partnerships) {
      if (!genMap.containsKey(part.person1Id) ||
          !genMap.containsKey(part.person2Id))
        continue;
      if (genMap[part.person1Id] != genMap[part.person2Id]) continue;
      final knotId = '__knot__${part.id}';
      final gen = genMap[part.person1Id]!;
      knotFor[part.id] = knotId;
      byGen.putIfAbsent(gen, () => []).add(knotId);
      genMap[knotId] = gen;
      // Couple edges.
      edges.add(_AncEdge(part.person1Id, knotId, isCouple: true));
      edges.add(_AncEdge(knotId, part.person2Id, isCouple: true));
    }

    // ── Parent→child edges (upward direction in layout) ───────────────────────
    // In the layout, "parent" nodes appear in a higher generation (higher gen
    // number) and are drawn at a lower Y value (higher on screen).
    // We draw edges from child (gen N) to parent/knot (gen N+1).
    for (final p in persons) {
      final childGen = genMap[p.id] ?? 0;
      for (final part in partnerships) {
        // Find the knot that connects two parents of this child.
        final isChild1 =
            part.person1Id != p.id && p.parentIds.contains(part.person1Id);
        final isChild2 =
            part.person2Id != p.id && p.parentIds.contains(part.person2Id);
        if (isChild1 || isChild2) {
          final knotId = knotFor[part.id];
          if (knotId != null) {
            edges.add(_AncEdge(p.id, knotId));
            break;
          }
        }
      }
      // Also connect to any un-knotted parents.
      for (final parentId in p.parentIds) {
        if (!genMap.containsKey(parentId)) continue;
        // Skip if parent is part of a knot already connected above.
        final alreadyKnotted = partnerships.any(
          (part) =>
              knotFor.containsKey(part.id) &&
              ((part.person1Id == parentId &&
                      p.parentIds.contains(part.person2Id)) ||
                  (part.person2Id == parentId &&
                      p.parentIds.contains(part.person1Id))),
        );
        if (!alreadyKnotted) {
          edges.add(_AncEdge(p.id, parentId));
        }
      }
    }

    // ── Initial X positions ───────────────────────────────────────────────────
    final step = nodeW + colGap;
    for (final entry in byGen.entries) {
      final gen = entry.key;
      final ordered = List<String>.from(entry.value);
      // Interleave knots between their partners.
      final added = <String>{};
      for (final nid in List<String>.from(ordered)) {
        if (!nid.startsWith('__knot__') || added.contains(nid)) continue;
        // Find the knot node's partners by examining couple edges.
        String? p1, p2;
        for (final e in edges) {
          if (e.isCouple && e.to == nid) p1 = e.from;
          if (e.isCouple && e.from == nid) p2 = e.to;
        }
        final i1 = ordered.indexOf(p1 ?? '');
        final i2 = ordered.indexOf(p2 ?? '');
        if (i1 >= 0 && i2 >= 0) {
          if ((i2 - i1).abs() > 1) {
            ordered.remove(p2);
            ordered.insert(ordered.indexOf(p1!) + 1, p2!);
          }
          final minIdx = math.min(
            ordered.indexOf(p1 ?? ''),
            ordered.indexOf(p2 ?? ''),
          );
          ordered.insert(minIdx + 1, nid);
          added.add(nid);
        } else {
          ordered.add(nid);
          added.add(nid);
        }
      }

      // Y: gen 0 (root) at the bottom; higher gen → lower Y value.
      final y = (maxGen - gen) * (nodeH + rowGap);
      for (int i = 0; i < ordered.length; i++) {
        final id = ordered[i];
        final isKnot = id.startsWith('__knot__');
        nodes[id] = _AncNode(
          id: id,
          x: i * step,
          y: y,
          isCoupleKnot: isKnot,
          knotPartner1: isKnot
              ? edges
                    .where((e) => e.isCouple && e.to == id)
                    .map((e) => e.from)
                    .firstOrNull
              : null,
          knotPartner2: isKnot
              ? edges
                    .where((e) => e.isCouple && e.from == id)
                    .map((e) => e.to)
                    .firstOrNull
              : null,
        );
      }
    }

    // ── Refine layout ─────────────────────────────────────────────────────────
    _refineLayout(byGen);

    // ── Canvas bounds ─────────────────────────────────────────────────────────
    double maxX = 0, maxY = 0;
    for (final n in nodes.values) {
      maxX = math.max(maxX, n.x + nodeW);
      maxY = math.max(maxY, n.y + nodeH);
    }
    canvasSize = Size(maxX + 40, maxY + 40);
  }

  void _refineLayout(Map<int, List<String>> byGen) {
    // Map: child → [parents in layout]
    final parentsOf = <String, List<String>>{};
    for (final e in edges) {
      if (!e.isCouple) parentsOf.putIfAbsent(e.from, () => []).add(e.to);
    }

    final sortedGens = byGen.keys.toList()..sort();
    final step = nodeW + colGap;

    for (int iter = 0; iter < 3; iter++) {
      // Pass A: top-down — centre each parent over its children.
      for (final gen in sortedGens) {
        for (final id in (byGen[gen] ?? [])) {
          if (nodes[id]?.isCoupleKnot ?? false) continue;
          final children = (parentsOf.entries
              .where((e) => e.value.contains(id))
              .map((e) => e.key)
              .where((k) => nodes.containsKey(k))
              .toList());
          if (children.isEmpty) continue;
          final childCx =
              children
                  .map((k) => nodes[k]!.x + nodeW / 2)
                  .reduce((a, b) => a + b) /
              children.length;
          nodes[id]!.x = childCx - nodeW / 2;
        }

        // Pass B: push apart overlapping nodes in this row.
        final rowNodes = (byGen[gen] ?? []).map((id) => nodes[id]!).toList()
          ..sort((a, b) => a.x.compareTo(b.x));
        for (int i = 1; i < rowNodes.length; i++) {
          final minX = rowNodes[i - 1].x + step;
          if (rowNodes[i].x < minX) rowNodes[i].x = minX;
        }
      }

      // Pass C: re-centre couple knots.
      for (final node in nodes.values) {
        if (!node.isCoupleKnot) continue;
        final p1 = nodes[node.knotPartner1];
        final p2 = nodes[node.knotPartner2];
        if (p1 != null && p2 != null) {
          node.x = (p1.x + p2.x + nodeW) / 2.0 - nodeW / 2.0;
        }
      }
    }

    // Normalise to x ≥ 0.
    if (nodes.isNotEmpty) {
      final minX = nodes.values.map((n) => n.x).reduce(math.min);
      if (minX < 0) {
        for (final n in nodes.values) n.x -= minX;
      }
    }
  }
}

// ── Edge painter ──────────────────────────────────────────────────────────────

class _AncEdgePainter extends CustomPainter {
  final Map<String, _AncNode> nodes;
  final List<_AncEdge> edges;
  final Color edgeColor;
  final Color coupleColor;
  final double nodeW;
  final double nodeH;
  final TreeEdgeStyle edgeStyle;

  const _AncEdgePainter({
    required this.nodes,
    required this.edges,
    required this.edgeColor,
    required this.coupleColor,
    this.nodeW = _kNodeW,
    this.nodeH = _kNodeH,
    this.edgeStyle = TreeEdgeStyle.orthogonal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final parentPaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final couplePaint = Paint()
      ..color = coupleColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final fromNode = nodes[edge.from];
      final toNode = nodes[edge.to];
      if (fromNode == null || toNode == null) continue;

      if (edge.isCouple) {
        canvas.drawLine(
          Offset(fromNode.x + nodeW / 2, fromNode.y + nodeH / 2),
          Offset(toNode.x + nodeW / 2, toNode.y + nodeH / 2),
          couplePaint,
        );
      } else {
        // In the ancestry layout, edges go UPWARD: from child (lower on screen,
        // higher Y) to parent (higher on screen, lower Y).
        final fromCx = fromNode.x + nodeW / 2;
        final fromTop = fromNode.isCoupleKnot
            ? fromNode.y + nodeH / 2
            : fromNode.y; // top of child node
        final toCx = toNode.x + nodeW / 2;
        final toBot = toNode.isCoupleKnot
            ? toNode.y + nodeH / 2
            : toNode.y + nodeH; // bottom of parent node

        switch (edgeStyle) {
          case TreeEdgeStyle.bezier:
            final dy = (fromTop - toBot).abs();
            final tension = (dy * 0.45).clamp(0.0, 80.0);
            final path = Path()
              ..moveTo(fromCx, fromTop)
              ..cubicTo(
                fromCx,
                fromTop - tension,
                toCx,
                toBot + tension,
                toCx,
                toBot,
              );
            canvas.drawPath(path, parentPaint);
          case TreeEdgeStyle.orthogonal:
            final midY = toBot + (fromTop - toBot) * 0.5;
            final path = Path()
              ..moveTo(fromCx, fromTop)
              ..lineTo(fromCx, midY)
              ..lineTo(toCx, midY)
              ..lineTo(toCx, toBot);
            canvas.drawPath(path, parentPaint);
          case TreeEdgeStyle.straight:
            canvas.drawLine(
              Offset(fromCx, fromTop),
              Offset(toCx, toBot),
              parentPaint,
            );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_AncEdgePainter old) =>
      old.nodes.length != nodes.length ||
      old.edges.length != edges.length ||
      old.edgeColor != edgeColor ||
      old.edgeStyle != edgeStyle;
}

// ── Person card ───────────────────────────────────────────────────────────────

class _AncCard extends StatelessWidget {
  final Person person;
  final bool isRoot;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _AncCard({
    required this.person,
    required this.isRoot,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = person.gender?.toLowerCase() == 'male'
        ? colorScheme.primary
        : person.gender?.toLowerCase() == 'female'
        ? colorScheme.error
        : colorScheme.secondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isRoot ? colorScheme.primaryContainer : colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isRoot ? colorScheme.primary : accentColor.withOpacity(0.6),
            width: isRoot ? 2.0 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(isRoot ? 0.25 : 0.1),
              blurRadius: isRoot ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(9),
                  bottomLeft: Radius.circular(9),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: isRoot
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (person.birthDate != null || person.deathDate != null)
                      Text(
                        [
                          if (person.birthDate != null)
                            'b. ${person.birthDate!.year}',
                          if (person.deathDate != null)
                            'd. ${person.deathDate!.year}',
                        ].join('  '),
                        style: TextStyle(
                          fontSize: 9,
                          color: isRoot
                              ? colorScheme.onPrimaryContainer.withOpacity(0.75)
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (person.birthPlace != null)
                      Text(
                        person.birthPlace!,
                        style: TextStyle(
                          fontSize: 9,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Couple knot ───────────────────────────────────────────────────────────────

class _AncCoupleKnot extends StatelessWidget {
  final ColorScheme colorScheme;
  const _AncCoupleKnot({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: colorScheme.tertiary.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.onTertiary, width: 1.5),
        ),
      ),
    );
  }
}

// ── Root person picker ────────────────────────────────────────────────────────

class _RootPicker extends StatelessWidget {
  final List<Person> persons;
  final String rootId;
  final Map<String, Person> pm;
  final ColorScheme colorScheme;
  final ValueChanged<Person> onChanged;

  const _RootPicker({
    required this.persons,
    required this.rootId,
    required this.pm,
    required this.colorScheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showSearch<Person?>(
          context: context,
          delegate: _PersonSearchDelegate(persons),
        );
        if (result != null) onChanged(result);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ancestry'),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              pm[rootId]?.name ?? '?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, color: colorScheme.onSurface, size: 18),
        ],
      ),
    );
  }
}

class _PersonSearchDelegate extends SearchDelegate<Person?> {
  final List<Person> persons;
  _PersonSearchDelegate(this.persons);

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final lower = query.toLowerCase();
    final filtered = persons
        .where((p) => p.name.toLowerCase().contains(lower))
        .toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) => ListTile(
        title: Text(filtered[i].name),
        onTap: () => close(context, filtered[i]),
      ),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Vertical ancestor tree: root person at the bottom, ancestors growing
/// upward row by row.  Optionally accepts a visual [preset] from
/// [FamilyTreeScreen].
class AncestryChartScreen extends StatefulWidget {
  final Person? initialPerson;
  final TreePreset? preset;

  /// Maximum number of ancestor generations to show.  [null] means unlimited
  /// (standalone usage).  Supplied by [FamilyTreeScreen] from shared settings.
  final int? ancestorGens;

  const AncestryChartScreen({
    super.key,
    this.initialPerson,
    this.preset,
    this.ancestorGens,
  });

  @override
  State<AncestryChartScreen> createState() => _AncestryChartScreenState();
}

class _AncestryChartScreenState extends State<AncestryChartScreen> {
  final TransformationController _transformCtrl = TransformationController();
  Person? _rootPerson;
  Size _lastCanvasSize = Size.zero;
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _fitView() {
    final canvas = _lastCanvasSize;
    final vp = _viewportSize;
    if (canvas == Size.zero || vp == Size.zero) {
      _transformCtrl.value = Matrix4.identity();
      return;
    }
    const padding = 32.0;
    final sx = (vp.width - padding * 2) / canvas.width;
    final sy = (vp.height - padding * 2) / canvas.height;
    final scale = (sx < sy ? sx : sy).clamp(0.1, 1.0);
    final scaledW = canvas.width * scale;
    final scaledH = canvas.height * scale;
    final tx = (vp.width - scaledW) / 2;
    final ty = (vp.height - scaledH) / 2;
    _transformCtrl.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);
  }

  void _changeScale(double factor) {
    final s = _transformCtrl.value.getMaxScaleOnAxis();
    final ns = (s * factor).clamp(0.1, 5.0);
    _transformCtrl.value = _transformCtrl.value.clone()..scale(ns / s);
  }

  void _resetView() {
    _transformCtrl.value = Matrix4.identity();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  /// BFS upward through parentIds to collect ancestors up to [maxGens]
  /// generations.  When [maxGens] is null the traversal is unlimited.
  Set<String> _collectAncestors(
    Person root,
    Map<String, Person> pm, {
    int? maxGens,
  }) {
    final visited = <String>{root.id};
    var frontier = [root.id];
    int depth = 0;
    while (frontier.isNotEmpty && (maxGens == null || depth < maxGens)) {
      final next = <String>[];
      for (final id in frontier) {
        for (final parentId in pm[id]?.parentIds ?? []) {
          if (!visited.contains(parentId) && pm.containsKey(parentId)) {
            visited.add(parentId);
            next.add(parentId);
          }
        }
      }
      frontier = next;
      depth++;
    }
    return visited;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final persons = provider.persons;
    final partnerships = provider.partnerships;
    final colorScheme = Theme.of(context).colorScheme;

    if (persons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ancestry')),
        body: const Center(child: Text('No people in the tree yet.')),
      );
    }

    _rootPerson ??= widget.initialPerson ?? persons.first;
    final pm = {for (final p in persons) p.id: p};
    if (!pm.containsKey(_rootPerson!.id)) _rootPerson = persons.first;

    final ancestorIds = _collectAncestors(
      _rootPerson!,
      pm,
      maxGens: widget.ancestorGens,
    );

    if (ancestorIds.length <= 1) {
      return Scaffold(
        appBar: AppBar(
          title: _RootPicker(
            persons: persons,
            rootId: _rootPerson!.id,
            pm: pm,
            colorScheme: colorScheme,
            onChanged: (p) => setState(() {
              _rootPerson = p;
              _resetView();
            }),
          ),
        ),
        body: const Center(
          child: Text('This person has no recorded ancestors.'),
        ),
      );
    }

    // Include partners of ancestors for couple-knot rendering.
    final partnerIds = <String>{};
    for (final part in partnerships) {
      if (ancestorIds.contains(part.person1Id) &&
          pm.containsKey(part.person2Id) &&
          !ancestorIds.contains(part.person2Id)) {
        partnerIds.add(part.person2Id);
      }
      if (ancestorIds.contains(part.person2Id) &&
          pm.containsKey(part.person1Id) &&
          !ancestorIds.contains(part.person1Id)) {
        partnerIds.add(part.person1Id);
      }
    }

    final visibleIds = {...ancestorIds, ...partnerIds};
    final visiblePersons = visibleIds
        .map((id) => pm[id])
        .whereType<Person>()
        .toList();
    final visiblePartnerships = partnerships
        .where(
          (p) =>
              visibleIds.contains(p.person1Id) &&
              visibleIds.contains(p.person2Id),
        )
        .toList();

    // Resolve dimensions from preset.
    final p = widget.preset;
    final nodeW = p?.nodeWidth ?? _kNodeW;
    final nodeH = p?.nodeHeight ?? _kNodeH;
    final colGap = p?.colGap ?? _kColGap;
    final rowGap = p?.rowGap ?? _kRowGap;
    final edgeStyle = p?.edgeStyle ?? TreeEdgeStyle.orthogonal;

    final layout = _AncestryLayout(
      visiblePersons,
      visiblePartnerships,
      ancestorIds,
      nodeW: nodeW,
      nodeH: nodeH,
      colGap: colGap,
      rowGap: rowGap,
    );
    layout.compute();
    _lastCanvasSize = layout.canvasSize;

    return Scaffold(
      appBar: AppBar(
        title: _RootPicker(
          persons: persons,
          rootId: _rootPerson!.id,
          pm: pm,
          colorScheme: colorScheme,
          onChanged: (p) => setState(() {
            _rootPerson = p;
            _resetView();
          }),
        ),
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            children: [
              InteractiveViewer(
                constrained: false,
                transformationController: _transformCtrl,
                boundaryMargin: const EdgeInsets.all(200),
                minScale: 0.1,
                maxScale: 5.0,
                child: SizedBox(
                  width: layout.canvasSize.width,
                  height: layout.canvasSize.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _AncEdgePainter(
                            nodes: layout.nodes,
                            edges: layout.edges,
                            edgeColor: colorScheme.outline.withOpacity(0.5),
                            coupleColor: colorScheme.tertiary.withOpacity(0.7),
                            nodeW: nodeW,
                            nodeH: nodeH,
                            edgeStyle: edgeStyle,
                          ),
                        ),
                      ),
                      for (final node in layout.nodes.values)
                        Positioned(
                          left: node.x,
                          top: node.y,
                          width: nodeW,
                          height: nodeH,
                          child: node.isCoupleKnot
                              ? _AncCoupleKnot(colorScheme: colorScheme)
                              : _AncCard(
                                  person: pm[node.id]!,
                                  isRoot: node.id == _rootPerson!.id,
                                  colorScheme: colorScheme,
                                  onTap: () => Navigator.push(
                                    context,
                                    fadeSlideRoute(
                                      builder: (_) => PersonDetailScreen(
                                        person: pm[node.id]!,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
              // Zoom controls
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'ac_zi',
                      onPressed: () => _changeScale(1.3),
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'ac_zo',
                      onPressed: () => _changeScale(1 / 1.3),
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'ac_fit',
                      tooltip: 'Fit to view',
                      onPressed: _fitView,
                      child: const Icon(Icons.fit_screen),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
