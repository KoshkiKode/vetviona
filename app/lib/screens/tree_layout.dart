// Tree diagram layout engine — extracted so that pure layout logic can be
// unit-tested without spinning up a Flutter widget tree.
//
// All classes and constants in this file are package-accessible (no leading
// underscore).  The screen widgets in tree_diagram_screen.dart import and
// use them directly.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/partnership.dart';
import '../models/person.dart';

// ── Layout constants ──────────────────────────────────────────────────────────

/// Width of a person card node in the tree diagram.
const double kTreeNodeW = 128.0;

/// Height of a person card node in the tree diagram.
const double kTreeNodeH = 88.0;

/// Horizontal gap between adjacent nodes in the same generation row.
const double kTreeColGap = 44.0;

/// Vertical gap between successive generation rows.
const double kTreeRowGap = 100.0;

// ── Data structures ───────────────────────────────────────────────────────────

/// Holds computed position and metadata for a single node in the tree diagram.
/// A node is either a person card or an invisible couple-knot placed between
/// two partners.
class TreeNodeInfo {
  final String id;
  bool isCoupleKnot;
  String? knotPartner1;
  String? knotPartner2;
  int generation;
  double x = 0;
  double y = 0;

  TreeNodeInfo({
    required this.id,
    this.isCoupleKnot = false,
    this.knotPartner1,
    this.knotPartner2,
    required this.generation,
  });
}

/// A directed edge in the diagram — either a partnership (couple) edge or a
/// parent → child edge.
class TreeEdgeInfo {
  final String from;
  final String to;
  final bool isCouple;
  TreeEdgeInfo(this.from, this.to, {this.isCouple = false});
}

/// One entry per generation row, carrying the row's generation index and its
/// vertical offset on the canvas.  Used to render the left-rail labels.
class TreeGenRow {
  final int generation;
  final double y;
  TreeGenRow(this.generation, this.y);
}

// ── Layout engine ─────────────────────────────────────────────────────────────

/// Computes positions for all visible persons and their couple-knots so that:
///
///  * each generation occupies its own horizontal row,
///  * couples appear side-by-side with a union knot between them,
///  * parent → child edges are routed through the knot when possible, and
///  * an iterative refinement pass centres parents over their children and
///    resolves any horizontal overlaps.
class TreeLayout {
  final List<Person> persons;
  final List<Partnership> partnerships;

  TreeLayout(this.persons, this.partnerships);

  final Map<String, TreeNodeInfo> nodes = {};
  final List<TreeEdgeInfo> edges = [];
  final List<TreeGenRow> generationRows = [];
  Size canvasSize = Size.zero;

  void compute() {
    if (persons.isEmpty) return;
    final personMap = {for (final p in persons) p.id: p};
    final generation = <String, int>{};

    // ── BFS from roots to assign generation depths ───────────────────────────
    final roots = persons
        .where((p) =>
            p.parentIds.isEmpty ||
            !p.parentIds.any((id) => personMap.containsKey(id)))
        .toList();
    final queue = <String>[];
    for (final r in roots) {
      generation[r.id] = 0;
      queue.add(r.id);
    }
    // Any disconnected person not reachable from a root starts at gen 0.
    for (final p in persons) {
      if (!generation.containsKey(p.id)) {
        generation[p.id] = 0;
        queue.add(p.id);
      }
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
          generation[childId] = g + 1;
          queue.add(childId);
        } else if (generation[childId]! < g + 1) {
          generation[childId] = g + 1;
        }
      }
    }

    // ── Build person nodes ───────────────────────────────────────────────────
    for (final p in persons) {
      nodes[p.id] = TreeNodeInfo(id: p.id, generation: generation[p.id] ?? 0);
    }

    // ── Build couple-knot nodes and couple edges ─────────────────────────────
    final knotMap = <String, String>{}; // partnershipId → knotId
    for (final p in partnerships) {
      if (!personMap.containsKey(p.person1Id) ||
          !personMap.containsKey(p.person2Id)) continue;
      final knotId = 'knot_${p.id}';
      final knotGen = math.min(
        generation[p.person1Id] ?? 0,
        generation[p.person2Id] ?? 0,
      );
      nodes[knotId] = TreeNodeInfo(
        id: knotId,
        isCoupleKnot: true,
        knotPartner1: p.person1Id,
        knotPartner2: p.person2Id,
        generation: knotGen,
      );
      knotMap[p.id] = knotId;
      edges.add(TreeEdgeInfo(p.person1Id, knotId, isCouple: true));
      edges.add(TreeEdgeInfo(p.person2Id, knotId, isCouple: true));
    }

    // ── Build parent-child edges (routed through knots when possible) ────────
    for (final p in persons) {
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
            edges.add(TreeEdgeInfo(knotId, childId));
          }
        } else {
          edges.add(TreeEdgeInfo(p.id, childId));
        }
      }
    }

    // ── Assign x / y coordinates per generation ──────────────────────────────
    final byGen = <int, List<String>>{};
    for (final n in nodes.values) {
      byGen.putIfAbsent(n.generation, () => []).add(n.id);
    }

    for (final entry in byGen.entries) {
      final gen = entry.key;
      final nodeIds = entry.value;
      // Sort so that person nodes come first, knot nodes last (they get
      // inserted between their partners in the next step).
      nodeIds.sort((a, b) {
        final aK = nodes[a]!.isCoupleKnot ? 1 : 0;
        final bK = nodes[b]!.isCoupleKnot ? 1 : 0;
        return aK - bK;
      });
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
            final p1Idx = ordered.indexOf(p1);
            ordered.insert(p1Idx + 1, p2);
          }
          final p1Idx2 = ordered.indexOf(p1);
          final p2Idx2 = ordered.indexOf(p2);
          ordered.insert(math.min(p1Idx2, p2Idx2) + 1, nid);
          added.add(nid);
        } else {
          ordered.add(nid);
          added.add(nid);
        }
      }
      const step = kTreeNodeW + kTreeColGap;
      for (int i = 0; i < ordered.length; i++) {
        final node = nodes[ordered[i]]!;
        node.x = i * step;
        node.y = gen * (kTreeNodeH + kTreeRowGap);
      }
    }

    // ── Refine layout ────────────────────────────────────────────────────────
    _refineLayout(byGen);

    // ── Canvas bounds ────────────────────────────────────────────────────────
    double maxX = 0, maxY = 0;
    for (final n in nodes.values) {
      maxX = math.max(maxX, n.x + kTreeNodeW);
      maxY = math.max(maxY, n.y + kTreeNodeH);
    }
    canvasSize = Size(maxX + 40, maxY + 40);

    // ── Generation row labels (sorted ascending) ─────────────────────────────
    generationRows.clear();
    final genNums = byGen.keys.toList()..sort();
    for (final g in genNums) {
      generationRows.add(TreeGenRow(g, g * (kTreeNodeH + kTreeRowGap)));
    }
  }

  /// Iterative layout refinement:
  ///   1. Bottom-up: centre each non-knot parent node over its children.
  ///   2. Push apart overlapping nodes in each generation row.
  ///   3. Re-centre couple knots between their two partners.
  /// Three passes are enough for typical genealogy trees while remaining fast.
  void _refineLayout(Map<int, List<String>> byGen) {
    // Map: layoutParent → [layoutChildren] using non-couple edges only.
    final childrenOf = <String, List<String>>{};
    for (final e in edges) {
      if (!e.isCouple) childrenOf.putIfAbsent(e.from, () => []).add(e.to);
    }

    final sortedGens = byGen.keys.toList()..sort();
    const step = kTreeNodeW + kTreeColGap;

    for (int iter = 0; iter < 3; iter++) {
      // Pass A: bottom-up centering of parents over their children.
      for (final gen in sortedGens.reversed) {
        for (final id in (byGen[gen] ?? [])) {
          if (nodes[id]!.isCoupleKnot) continue;
          final kids = (childrenOf[id] ?? [])
              .where((k) => nodes.containsKey(k))
              .toList();
          if (kids.isEmpty) continue;
          final childCx = kids
                  .map((k) => nodes[k]!.x + kTreeNodeW / 2)
                  .reduce((a, b) => a + b) /
              kids.length;
          nodes[id]!.x = childCx - kTreeNodeW / 2;
        }

        // Pass B: push apart overlapping nodes in this row.
        final rowNodes = (byGen[gen] ?? [])
            .map((id) => nodes[id]!)
            .toList()
          ..sort((a, b) => a.x.compareTo(b.x));
        for (int i = 1; i < rowNodes.length; i++) {
          final minX = rowNodes[i - 1].x + step;
          if (rowNodes[i].x < minX) rowNodes[i].x = minX;
        }
      }

      // Pass C: centre couple knots between their two partners.
      for (final node in nodes.values) {
        if (!node.isCoupleKnot) continue;
        final p1 = nodes[node.knotPartner1];
        final p2 = nodes[node.knotPartner2];
        if (p1 != null && p2 != null) {
          node.x = (p1.x + p2.x + kTreeNodeW) / 2.0 - kTreeNodeW / 2.0;
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
