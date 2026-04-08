import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphview/GraphView.dart';

import '../providers/tree_provider.dart';
import '../models/person.dart';

class TreeDiagramScreen extends StatelessWidget {
  const TreeDiagramScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final persons = context.watch<TreeProvider>().persons;
    final graph = Graph();
    final nodeMap = <String, Node>{};

    // Create nodes
    for (final person in persons) {
      final node = Node.Id(person.id);
      nodeMap[person.id] = node;
      graph.addNode(node);
    }

    // Create edges for parent-child
    for (final person in persons) {
      for (final parentId in person.parentIds) {
        if (nodeMap.containsKey(parentId) && nodeMap.containsKey(person.id)) {
          graph.addEdge(nodeMap[parentId]!, nodeMap[person.id]!);
        }
      }
    }

    // For spouses, perhaps add horizontal edges, but for simplicity, skip

    final builder = BuchheimWalkerAlgorithm(builder);
    final configuration = BuchheimWalkerConfiguration();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Tree Diagram'),
      ),
      body: InteractiveViewer(
        constrained: false,
        child: GraphView(
          graph: graph,
          algorithm: builder,
          paint: Paint()
            ..color = Colors.green
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
          builder: (Node node) {
            final personId = node.key?.value as String;
            final person = persons.firstWhere((p) => p.id == personId);
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                person.name,
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }
}
