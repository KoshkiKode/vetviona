import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphview/GraphView.dart';

import '../providers/tree_provider.dart';
import '../models/person.dart';
import 'person_detail_screen.dart';

class TreeDiagramScreen extends StatefulWidget {
  const TreeDiagramScreen({super.key});

  @override
  State<TreeDiagramScreen> createState() => _TreeDiagramScreenState();
}

class _TreeDiagramScreenState extends State<TreeDiagramScreen> {
  final TransformationController _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changeScale(double factor) {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.2, 5.0);
    final scaleFactor = newScale / currentScale;
    final newMatrix = _controller.value.clone()..scale(scaleFactor);
    _controller.value = newMatrix;
  }

  void _resetView() {
    _controller.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final persons = context.watch<TreeProvider>().persons;
    final colorScheme = Theme.of(context).colorScheme;

    if (persons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Tree Diagram')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_tree_outlined, size: 80, color: colorScheme.primary.withOpacity(0.4)),
              const SizedBox(height: 16),
              Text(
                'No people in the tree yet.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final graph = Graph();
    final nodeMap = <String, Node>{};

    for (final person in persons) {
      final node = Node.Id(person.id);
      nodeMap[person.id] = node;
      graph.addNode(node);
    }

    for (final person in persons) {
      for (final parentId in person.parentIds) {
        if (nodeMap.containsKey(parentId) && nodeMap.containsKey(person.id)) {
          graph.addEdge(nodeMap[parentId]!, nodeMap[person.id]!);
        }
      }
    }

    final configuration = BuchheimWalkerConfiguration()
      ..siblingSeparation = 60
      ..levelSeparation = 80
      ..subtreeSeparation = 60
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;

    final algorithm = BuchheimWalkerAlgorithm(
      configuration,
      TreeEdgeRenderer(configuration),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Tree Diagram'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Reset view',
            onPressed: _resetView,
          ),
        ],
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            transformationController: _controller,
            constrained: false,
            minScale: 0.1,
            maxScale: 5.0,
            boundaryMargin: const EdgeInsets.all(200),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GraphView(
                graph: graph,
                algorithm: algorithm,
                paint: Paint()
                  ..color = colorScheme.primary.withOpacity(0.5)
                  ..strokeWidth = 1.5
                  ..style = PaintingStyle.stroke,
                builder: (Node node) {
                  final personId = node.key?.value as String;
                  final person = persons.firstWhere(
                    (p) => p.id == personId,
                    orElse: () => Person(id: personId, name: '?'),
                  );
                  return _PersonNode(person: person, colorScheme: colorScheme);
                },
              ),
            ),
          ),
          // Zoom controls
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ZoomButton(
                  heroTag: 'zoom_in',
                  icon: Icons.add,
                  tooltip: 'Zoom in',
                  onPressed: () => _changeScale(1.3),
                ),
                const SizedBox(height: 8),
                _ZoomButton(
                  heroTag: 'zoom_out',
                  icon: Icons.remove,
                  tooltip: 'Zoom out',
                  onPressed: () => _changeScale(1 / 1.3),
                ),
                const SizedBox(height: 8),
                _ZoomButton(
                  heroTag: 'zoom_reset',
                  icon: Icons.fit_screen,
                  tooltip: 'Reset',
                  onPressed: _resetView,
                ),
              ],
            ),
          ),
          // Zoom level indicator
          Positioned(
            bottom: 24,
            left: 16,
            child: _ZoomIndicator(controller: _controller),
          ),
        ],
      ),
    );
  }
}

class _PersonNode extends StatelessWidget {
  final Person person;
  final ColorScheme colorScheme;

  const _PersonNode({required this.person, required this.colorScheme});

  Color _nodeColor() {
    if (person.gender?.toLowerCase() == 'male') {
      return colorScheme.primary;
    } else if (person.gender?.toLowerCase() == 'female') {
      return colorScheme.error;
    }
    return colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final color = _nodeColor();
    // Choose text that's legible on top of the node background color
    final textColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PersonDetailScreen(
            person: person,
          ),
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.onPrimary.withOpacity(0.2),
              child: Text(
                person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              person.name,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (person.birthDate != null) ...[
              const SizedBox(height: 2),
              Text(
                'b. ${person.birthDate!.year}',
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ZoomButton({
    required this.heroTag,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      onPressed: onPressed,
      tooltip: tooltip,
      elevation: 2,
      child: Icon(icon, size: 20),
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
  void initState() {
    super.initState();
    widget.controller.addListener(_onTransform);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTransform);
    super.dispose();
  }

  void _onTransform() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scale = widget.controller.value.getMaxScaleOnAxis();
    final percent = (scale * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Text(
        '$percent%',
        style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}
