import 'dart:collection';

import 'package:flutter/material.dart';
import '../utils/page_routes.dart';
import 'package:graphview/GraphView.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../providers/tree_provider.dart';
import 'person_detail_screen.dart';

/// Shows all descendants of a chosen ancestor as a top-down directed graph.
class DescendantsScreen extends StatefulWidget {
  final Person? initialPerson;
  const DescendantsScreen({super.key, this.initialPerson});

  @override
  State<DescendantsScreen> createState() => _DescendantsScreenState();
}

class _DescendantsScreenState extends State<DescendantsScreen> {
  final TransformationController _transformCtrl = TransformationController();
  Person? _rootPerson;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _changeScale(double factor) {
    final s = _transformCtrl.value.getMaxScaleOnAxis();
    final ns = (s * factor).clamp(0.1, 5.0);
    _transformCtrl.value = _transformCtrl.value.clone()..scale(ns / s);
  }

  void _resetView() => _transformCtrl.value = Matrix4.identity();

  /// BFS to collect this person and all their descendants.
  Set<String> _collectDescendants(Person root, Map<String, Person> pm) {
    final visited = <String>{};
    final q = Queue<String>()..add(root.id);
    while (q.isNotEmpty) {
      final id = q.removeFirst();
      if (visited.contains(id)) continue;
      visited.add(id);
      for (final c in pm[id]?.childIds ?? []) {
        if (!visited.contains(c)) q.add(c);
      }
    }
    return visited;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final persons = provider.persons;
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

    final descIds = _collectDescendants(_rootPerson!, pm);
    final descs = descIds.map((id) => pm[id]).whereType<Person>().toList();

    final graph = Graph()..isTree = true;
    final nodeMap = <String, Node>{
      for (final p in descs) p.id: Node.Id(p.id)
    };
    // Add root first so graphview has a starting point.
    if (nodeMap.containsKey(_rootPerson!.id)) {
      graph.addNode(nodeMap[_rootPerson!.id]!);
    }
    for (final p in descs) {
      for (final cid in p.childIds) {
        if (nodeMap.containsKey(cid)) {
          graph.addEdge(nodeMap[p.id]!, nodeMap[cid]!);
        }
      }
    }

    final cfg = BuchheimWalkerConfiguration()
      ..siblingSeparation = 20
      ..levelSeparation = 50
      ..subtreeSeparation = 30
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Descendants Chart'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButton<String>(
              value: _rootPerson!.id,
              dropdownColor: colorScheme.surface,
              underline: const SizedBox.shrink(),
              style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
              icon:
                  Icon(Icons.arrow_drop_down, color: colorScheme.onPrimary),
              selectedItemBuilder: (_) => persons
                  .map((p) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(p.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                                color: colorScheme.onPrimary, fontSize: 13)),
                      ))
                  .toList(),
              items: persons
                  .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (id) {
                if (id != null) {
                  setState(() {
                    _rootPerson = pm[id];
                    _resetView();
                  });
                }
              },
            ),
          ),
        ],
      ),
      body: descs.isEmpty
          ? const Center(child: Text('This person has no recorded descendants.'))
          : Stack(
              children: [
                InteractiveViewer(
                  constrained: false,
                  transformationController: _transformCtrl,
                  boundaryMargin: const EdgeInsets.all(200),
                  minScale: 0.1,
                  maxScale: 5.0,
                  child: GraphView(
                    graph: graph,
                    algorithm:
                        BuchheimWalkerAlgorithm(cfg, TreeEdgeRenderer(cfg)),
                    paint: Paint()
                      ..color = colorScheme.outline
                      ..strokeWidth = 1.5
                      ..style = PaintingStyle.stroke,
                    builder: (Node node) {
                      final pid = node.key!.value as String;
                      final p = pm[pid];
                      if (p == null) return const SizedBox.shrink();
                      return _DescNode(
                        person: p,
                        isRoot: p.id == _rootPerson!.id,
                        onTap: () => Navigator.push(
                          context,
                          fadeSlideRoute(
                            builder: (_) => PersonDetailScreen(person: p),
                          ),
                        ),
                      );
                    },
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
                        onPressed: _resetView,
                        tooltip: 'Reset view',
                        child: const Icon(Icons.fit_screen),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DescNode extends StatelessWidget {
  final Person person;
  final bool isRoot;
  final VoidCallback onTap;

  const _DescNode({
    required this.person,
    required this.isRoot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color bg;
    if (isRoot) {
      bg = cs.tertiary;
    } else if (person.gender?.toLowerCase() == 'male') {
      bg = cs.primary;
    } else if (person.gender?.toLowerCase() == 'female') {
      bg = cs.error;
    } else {
      bg = cs.secondary;
    }
    final fg =
        ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
            ? cs.onPrimary
            : cs.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: bg.withOpacity(0.35),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              person.name,
              style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (person.birthDate != null) ...[
              const SizedBox(height: 2),
              Text(
                'b. ${person.birthDate!.year}',
                style:
                    TextStyle(color: fg.withOpacity(0.8), fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
