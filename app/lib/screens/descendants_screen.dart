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

// ── Layout constants (fallback when no preset is provided) ────────────────────
const double _kCardW = 160.0;
const double _kCardH = 82.0;
const double _kColGap = 24.0;
const double _kRowGap = 80.0;

// ── Internal data structures ─────────────────────────────────────────────────

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

// ── Layout engine ─────────────────────────────────────────────────────────────

/// Computes positions for all visible persons and their couple-knots so that
/// each generation occupies its own horizontal row and couples are shown
/// side-by-side — layout is parameterized via [cardW], [cardH], [colGap], [rowGap].
class _DescLayout {
  final List<Person> persons;
  final List<Partnership> partnerships;

  /// IDs of the actual descendants (partners-in-law are not descendants).
  final Set<String> descendantIds;

  final double cardW;
  final double cardH;
  final double colGap;
  final double rowGap;

  _DescLayout(
    this.persons,
    this.partnerships,
    this.descendantIds, {
    this.cardW = _kCardW,
    this.cardH = _kCardH,
    this.colGap = _kColGap,
    this.rowGap = _kRowGap,
  });

  final Map<String, _NodeInfo> nodes = {};
  final List<_EdgeInfo> edges = [];
  Size canvasSize = Size.zero;

  void compute() {
    if (persons.isEmpty) return;
    final personMap = {for (final p in persons) p.id: p};

    // ── Assign generation depths via BFS through the descendant set ──────────
    final generation = <String, int>{};
    final queue = Queue<String>();

    // Seed: descendants whose parents are NOT in the visible set are gen-0.
    for (final p in persons) {
      if (!descendantIds.contains(p.id)) continue;
      if (!p.parentIds.any((pid) => descendantIds.contains(pid))) {
        generation[p.id] = 0;
        queue.add(p.id);
      }
    }
    while (queue.isNotEmpty) {
      final id = queue.removeFirst();
      final person = personMap[id];
      if (person == null) continue;
      final g = generation[id]!;
      for (final childId in person.childIds) {
        if (!descendantIds.contains(childId)) continue;
        if (!generation.containsKey(childId) || generation[childId]! < g + 1) {
          generation[childId] = g + 1;
          queue.add(childId);
        }
      }
    }

    // Partners-in-law share the same generation as the descendant they partner.
    // Guard with containsKey to avoid overwriting an already-assigned generation
    // for persons who appear in multiple partnerships.
    for (final part in partnerships) {
      if (descendantIds.contains(part.person1Id) &&
          !descendantIds.contains(part.person2Id) &&
          !generation.containsKey(part.person2Id)) {
        generation[part.person2Id] = generation[part.person1Id] ?? 0;
      }
      if (descendantIds.contains(part.person2Id) &&
          !descendantIds.contains(part.person1Id) &&
          !generation.containsKey(part.person1Id)) {
        generation[part.person1Id] = generation[part.person2Id] ?? 0;
      }
    }

    // ── Build person nodes ───────────────────────────────────────────────────
    for (final p in persons) {
      nodes[p.id] = _NodeInfo(id: p.id, generation: generation[p.id] ?? 0);
    }

    // ── Build couple-knot nodes and couple edges ─────────────────────────────
    final knotMap = <String, String>{}; // partnershipId → knotId
    for (final part in partnerships) {
      if (!personMap.containsKey(part.person1Id) ||
          !personMap.containsKey(part.person2Id))
        continue;
      final knotId = 'knot_${part.id}';
      final knotGen = math.min(
        generation[part.person1Id] ?? 0,
        generation[part.person2Id] ?? 0,
      );
      nodes[knotId] = _NodeInfo(
        id: knotId,
        isCoupleKnot: true,
        knotPartner1: part.person1Id,
        knotPartner2: part.person2Id,
        generation: knotGen,
      );
      knotMap[part.id] = knotId;
      edges.add(_EdgeInfo(part.person1Id, knotId, isCouple: true));
      edges.add(_EdgeInfo(part.person2Id, knotId, isCouple: true));
    }

    // ── Build parent-child edges (routed through knots when possible) ────────
    for (final p in persons) {
      if (!descendantIds.contains(p.id)) continue;
      for (final childId in p.childIds) {
        if (!personMap.containsKey(childId)) continue;
        final childPerson = personMap[childId]!;
        Partnership? matchingPart;
        for (final part in partnerships) {
          if ((part.person1Id == p.id || part.person2Id == p.id) &&
              childPerson.parentIds.contains(part.person1Id) &&
              childPerson.parentIds.contains(part.person2Id)) {
            matchingPart = part;
            break;
          }
        }
        if (matchingPart != null && knotMap.containsKey(matchingPart.id)) {
          final knotId = knotMap[matchingPart.id]!;
          if (!edges.any((e) => e.from == knotId && e.to == childId)) {
            edges.add(_EdgeInfo(knotId, childId));
          }
        } else {
          if (!edges.any((e) => e.from == p.id && e.to == childId)) {
            edges.add(_EdgeInfo(p.id, childId));
          }
        }
      }
    }

    // ── Assign x / y coordinates per generation ──────────────────────────────
    final byGen = <int, List<String>>{};
    for (final n in nodes.values) {
      byGen.putIfAbsent(n.generation, () => []).add(n.id);
    }

    for (final entry in byGen.entries) {
      final nodeIds = entry.value;

      // Build an ordered list: person nodes first, then insert each couple-knot
      // between its two partners so they appear side-by-side.
      final ordered = <String>[];
      final added = <String>{};

      for (final nid in nodeIds) {
        if (added.contains(nid) || nodes[nid]!.isCoupleKnot) continue;
        ordered.add(nid);
        added.add(nid);
      }
      for (final nid in nodeIds) {
        final node = nodes[nid]!;
        if (!node.isCoupleKnot) continue;
        final p1 = node.knotPartner1!;
        final p2 = node.knotPartner2!;
        final i1 = ordered.indexOf(p1);
        final i2 = ordered.indexOf(p2);
        if (i1 >= 0 && i2 >= 0) {
          if ((i2 - i1).abs() > 1) {
            ordered.remove(p2);
            ordered.insert(ordered.indexOf(p1) + 1, p2);
          }
          final minIdx = math.min(ordered.indexOf(p1), ordered.indexOf(p2));
          ordered.insert(minIdx + 1, nid);
          added.add(nid);
        } else {
          ordered.add(nid);
          added.add(nid);
        }
      }

      final step = cardW + colGap;
      for (int i = 0; i < ordered.length; i++) {
        final node = nodes[ordered[i]]!;
        node.x = i * step;
        node.y = entry.key * (cardH + rowGap);
      }
    }

    // ── Refine layout ────────────────────────────────────────────────────────
    _refineLayout(byGen);

    // ── Canvas bounds ────────────────────────────────────────────────────────
    double maxX = 0, maxY = 0;
    for (final n in nodes.values) {
      maxX = math.max(maxX, n.x + cardW);
      maxY = math.max(maxY, n.y + cardH);
    }
    canvasSize = Size(maxX + 40, maxY + 40);
  }

  /// Three-pass iterative layout refinement:
  ///   A. Bottom-up: centre each non-knot parent over its children.
  ///   B. Push apart overlapping nodes within each generation row.
  ///   C. Re-centre couple knots between their two partners.
  /// Finishes with a left-normalisation pass.
  void _refineLayout(Map<int, List<String>> byGen) {
    final childrenOf = <String, List<String>>{};
    for (final e in edges) {
      if (!e.isCouple) childrenOf.putIfAbsent(e.from, () => []).add(e.to);
    }

    final sortedGens = byGen.keys.toList()..sort();
    final step = cardW + colGap;

    for (int iter = 0; iter < 3; iter++) {
      // Pass A: bottom-up parent centering.
      for (final gen in sortedGens.reversed) {
        for (final id in (byGen[gen] ?? [])) {
          if (nodes[id]!.isCoupleKnot) continue;
          final kids = (childrenOf[id] ?? [])
              .where((k) => nodes.containsKey(k))
              .toList();
          if (kids.isEmpty) continue;
          final childCx =
              kids.map((k) => nodes[k]!.x + cardW / 2).reduce((a, b) => a + b) /
              kids.length;
          nodes[id]!.x = childCx - cardW / 2;
        }

        // Pass B: push apart overlapping nodes in this row.
        final rowNodes = (byGen[gen] ?? []).map((id) => nodes[id]!).toList()
          ..sort((a, b) => a.x.compareTo(b.x));
        for (int i = 1; i < rowNodes.length; i++) {
          final minX = rowNodes[i - 1].x + step;
          if (rowNodes[i].x < minX) rowNodes[i].x = minX;
        }
      }

      // Pass C: re-centre couple knots between their partners.
      for (final node in nodes.values) {
        if (!node.isCoupleKnot) continue;
        final p1 = nodes[node.knotPartner1];
        final p2 = nodes[node.knotPartner2];
        if (p1 != null && p2 != null) {
          node.x = (p1.x + p2.x + cardW) / 2.0 - cardW / 2.0;
        }
      }
    }

    // Normalise: shift everything so the leftmost node starts at x = 0.
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

// ── Edge painter ──────────────────────────────────────────────────────────────

class _DescEdgePainter extends CustomPainter {
  final Map<String, _NodeInfo> nodes;
  final List<_EdgeInfo> edges;
  final Color edgeColor;
  final Color coupleColor;
  final TreeEdgeStyle edgeStyle;
  final double cardW;
  final double cardH;

  const _DescEdgePainter({
    required this.nodes,
    required this.edges,
    required this.edgeColor,
    required this.coupleColor,
    this.edgeStyle = TreeEdgeStyle.orthogonal,
    this.cardW = _kCardW,
    this.cardH = _kCardH,
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
        // Straight line connecting person ↔ couple-knot (all styles).
        canvas.drawLine(
          Offset(fromNode.x + cardW / 2, fromNode.y + cardH / 2),
          Offset(toNode.x + cardW / 2, toNode.y + cardH / 2),
          couplePaint,
        );
      } else {
        final fromCx = fromNode.x + cardW / 2;
        final fromBot = fromNode.isCoupleKnot
            ? fromNode.y + cardH / 2
            : fromNode.y + cardH;
        final toCx = toNode.x + cardW / 2;
        final toTop = toNode.y;

        switch (edgeStyle) {
          case TreeEdgeStyle.bezier:
            final dy = (toTop - fromBot).abs();
            final tension = (dy * 0.45).clamp(0.0, 80.0);
            final path = Path()
              ..moveTo(fromCx, fromBot)
              ..cubicTo(
                fromCx,
                fromBot + tension,
                toCx,
                toTop - tension,
                toCx,
                toTop,
              );
            canvas.drawPath(path, parentPaint);

          case TreeEdgeStyle.orthogonal:
            // Right-angle elbow: down → horizontal → down.
            final midY = fromBot + (toTop - fromBot) * 0.4;
            final path = Path()
              ..moveTo(fromCx, fromBot)
              ..lineTo(fromCx, midY)
              ..lineTo(toCx, midY)
              ..lineTo(toCx, toTop);
            canvas.drawPath(path, parentPaint);

          case TreeEdgeStyle.straight:
            // Never draw oblique diagonals; use elbow routing instead.
            final midY = fromBot + (toTop - fromBot) * 0.4;
            final path = Path()
              ..moveTo(fromCx, fromBot)
              ..lineTo(fromCx, midY)
              ..lineTo(toCx, midY)
              ..lineTo(toCx, toTop);
            canvas.drawPath(path, parentPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DescEdgePainter old) =>
      old.nodes.length != nodes.length ||
      old.edges.length != edges.length ||
      old.edgeColor != edgeColor ||
      old.coupleColor != coupleColor ||
      old.edgeStyle != edgeStyle;
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Shows all descendants of a chosen ancestor using a layout driven by the
/// active [TreePreset].  Couples appear side-by-side with a union knot,
/// children in rows below, and connectors between generations styled per preset.
class DescendantsScreen extends StatefulWidget {
  final Person? initialPerson;

  /// Visual preset supplied by [FamilyTreeScreen].  Falls back to the
  /// default dimensions when null (standalone usage).
  final TreePreset? preset;

  /// Maximum number of descendant generations to show.  [null] means unlimited
  /// (standalone usage).  Supplied by [FamilyTreeScreen] from shared settings.
  final int? descendantGens;

  const DescendantsScreen({
    super.key,
    this.initialPerson,
    this.preset,
    this.descendantGens,
  });

  @override
  State<DescendantsScreen> createState() => _DescendantsScreenState();
}

class _DescendantsScreenState extends State<DescendantsScreen> {
  final TransformationController _transformCtrl = TransformationController();
  Person? _rootPerson;
  Size _lastCanvasSize = Size.zero;
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    // Fit to view once the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  /// Scales and centres the view so the full descendant canvas fits in the
  /// viewport, clamped to a maximum of 1:1.
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
      ..translateByDouble(tx, ty, 0.0, 1.0)
      ..scaleByDouble(scale, scale, scale, 1.0);
  }

  void _changeScale(double factor) {
    final s = _transformCtrl.value.getMaxScaleOnAxis();
    final ns = (s * factor).clamp(0.1, 5.0);
    _transformCtrl.value = _transformCtrl.value.clone()..scaleByDouble(ns / s, ns / s, ns / s, 1.0);
  }

  void _resetView() {
    _transformCtrl.value = Matrix4.identity();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  /// BFS downward through childIds to collect this person and their
  /// descendants up to [maxGens] generations.  When [maxGens] is null the
  /// traversal is unlimited.
  Set<String> _collectDescendants(
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
        for (final childId in pm[id]?.childIds ?? []) {
          if (!visited.contains(childId)) {
            visited.add(childId);
            next.add(childId);
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
        appBar: AppBar(title: const Text('Descendants Chart')),
        body: const Center(child: Text('No people in the tree yet.')),
      );
    }

    _rootPerson ??= widget.initialPerson ?? persons.first;
    final pm = {for (final p in persons) p.id: p};

    // Ensure root still exists after tree changes.
    if (!pm.containsKey(_rootPerson!.id)) _rootPerson = persons.first;

    final descIds = _collectDescendants(
      _rootPerson!,
      pm,
      maxGens: widget.descendantGens,
    );

    if (descIds.length <= 1) {
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
          child: Text('This person has no recorded descendants.'),
        ),
      );
    }

    // Include partners of descendants who are not themselves descendants so
    // that couple-knots can be rendered properly.
    final partnerIds = <String>{};
    for (final part in partnerships) {
      if (descIds.contains(part.person1Id) &&
          pm.containsKey(part.person2Id) &&
          !descIds.contains(part.person2Id)) {
        partnerIds.add(part.person2Id);
      }
      if (descIds.contains(part.person2Id) &&
          pm.containsKey(part.person1Id) &&
          !descIds.contains(part.person1Id)) {
        partnerIds.add(part.person1Id);
      }
    }

    final visibleIds = {...descIds, ...partnerIds};
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

    // Resolve effective preset dimensions.
    final p = widget.preset;
    final effectiveCardW = p?.nodeWidth ?? _kCardW;
    final effectiveCardH = p?.nodeHeight ?? _kCardH;
    final effectiveColGap = p?.colGap ?? _kColGap;
    final effectiveRowGap = p?.rowGap ?? _kRowGap;
    final effectiveEdgeStyle = p?.edgeStyle ?? TreeEdgeStyle.orthogonal;

    final layout = _DescLayout(
      visiblePersons,
      visiblePartnerships,
      descIds,
      cardW: effectiveCardW,
      cardH: effectiveCardH,
      colGap: effectiveColGap,
      rowGap: effectiveRowGap,
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
                          painter: _DescEdgePainter(
                            nodes: layout.nodes,
                            edges: layout.edges,
                            edgeColor: colorScheme.outline.withValues(alpha: 0.5),
                            coupleColor: colorScheme.tertiary.withValues(alpha: 0.7),
                            edgeStyle: effectiveEdgeStyle,
                            cardW: effectiveCardW,
                            cardH: effectiveCardH,
                          ),
                        ),
                      ),
                      for (final node in layout.nodes.values)
                        Positioned(
                          left: node.x,
                          top: node.y,
                          width: effectiveCardW,
                          height: effectiveCardH,
                          child: node.isCoupleKnot
                              ? _CoupleKnot(
                                  node: node,
                                  partnerships: visiblePartnerships,
                                  colorScheme: colorScheme,
                                )
                              : _DescCard(
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
                      heroTag: 'desc_zoom_in',
                      onPressed: () => _changeScale(1.3),
                      tooltip: 'Zoom in',
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'desc_zoom_out',
                      onPressed: () => _changeScale(0.77),
                      tooltip: 'Zoom out',
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'desc_reset',
                      onPressed: _fitView,
                      tooltip: 'Fit to view',
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

// ── Root-person picker ────────────────────────────────────────────────────────

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
    return DropdownButton<String>(
      value: rootId,
      dropdownColor: colorScheme.surface,
      underline: const SizedBox.shrink(),
      style: TextStyle(
        color: colorScheme.onPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      icon: Icon(Icons.arrow_drop_down, color: colorScheme.onPrimary),
      selectedItemBuilder: (_) => persons
          .map(
            (p) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                p.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(color: colorScheme.onPrimary, fontSize: 13),
              ),
            ),
          )
          .toList(),
      items: persons
          .map(
            (p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (id) {
        if (id != null && pm.containsKey(id)) onChanged(pm[id]!);
      },
    );
  }
}

// ── Couple-knot widget ────────────────────────────────────────────────────────

class _CoupleKnot extends StatelessWidget {
  final _NodeInfo node;
  final List<Partnership> partnerships;
  final ColorScheme colorScheme;

  const _CoupleKnot({
    required this.node,
    required this.partnerships,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final partId = node.id.startsWith('knot_') ? node.id.substring(5) : '';
    final part = partnerships.where((p) => p.id == partId).firstOrNull;
    final year = part?.startDate?.year;
    return Center(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer,
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.tertiary, width: 1.5),
        ),
        child: Center(
          child: year != null
              ? Text(
                  '${year % 100}',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onTertiaryContainer,
                  ),
                )
              : Icon(Icons.favorite, size: 10, color: colorScheme.tertiary),
        ),
      ),
    );
  }
}

// ── Person card ───────────────────────────────────────────────────────────────

/// Standard person card: white surface, coloured left-strip + avatar, name and
/// birth/death years on the right.  Matches the visual language of
/// tree_diagram_screen.dart's _PersonNodeWidget.
class _DescCard extends StatelessWidget {
  final Person person;
  final bool isRoot;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _DescCard({
    required this.person,
    required this.isRoot,
    required this.colorScheme,
    required this.onTap,
  });

  Color _accentColor() {
    if (isRoot) return colorScheme.tertiary;
    if (person.gender?.toLowerCase() == 'male') return colorScheme.primary;
    if (person.gender?.toLowerCase() == 'female') return colorScheme.error;
    return colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    final isDead = person.deathDate != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent, width: isRoot ? 2.0 : 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isRoot ? 0.25 : 0.12),
              blurRadius: isRoot ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Coloured left strip
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Avatar circle
            CircleAvatar(
              radius: 14,
              backgroundColor: accent.withValues(alpha: 0.15),
              child: Text(
                person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Name + dates + location
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            person.name,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDead)
                          Icon(
                            Icons.star,
                            size: 10,
                            color: colorScheme.onSurfaceVariant.withOpacity(
                              0.6,
                            ),
                          ),
                      ],
                    ),
                    if (person.birthDate != null ||
                        person.deathDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (person.birthDate != null)
                            '${person.birthDate!.year}',
                          if (person.deathDate != null)
                            '${person.deathDate!.year}',
                        ].join(' – '),
                        style: TextStyle(
                          fontSize: 9,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (person.birthPlace != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        person.birthPlace!,
                        style: TextStyle(
                          fontSize: 9,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
