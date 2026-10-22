import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/screens/tree_layout.dart';

void main() {
  final List<Person> persons = [];
  final List<Partnership> partnerships = [];
  final random = math.Random(123);

  // Generate 1000 people
  for (int i = 0; i < 1000; i++) {
    persons.add(Person(
      id: 'p_$i',
      name: 'Person $i',
      gender: i % 2 == 0 ? 'M' : 'F',
      birthDate: DateTime(1900 + i % 100),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  // Create some families to link them up
  // Let's create a deep tree
  int nextPersonIdx = 0;
  
  // Start with a root couple
  if (persons.length >= 2) {
    partnerships.add(Partnership(
      id: 'pt_0',
      person1Id: persons[0].id,
      person2Id: persons[1].id,
      status: 'married',
    ));
    nextPersonIdx = 2;
    
    List<String> currentGenerationKnots = ['pt_0'];
    List<String> nextGenerationKnots = [];
    
    int partnershipId = 1;
    
    while (nextPersonIdx < 1000 && currentGenerationKnots.isNotEmpty) {
      for (final knotId in currentGenerationKnots) {
        // Assign 2-4 children to this knot
        int numChildren = 2 + random.nextInt(3);
        
        for (int c = 0; c < numChildren && nextPersonIdx < 1000; c++) {
          final child = persons[nextPersonIdx];
          
          // Set parent knot
          final updatedChild = child.copyWith(parentPartnershipId: knotId);
          persons[nextPersonIdx] = updatedChild;
          
          nextPersonIdx++;
          
          // Every child also gets a partner (if enough people left)
          if (nextPersonIdx < 1000) {
            final partner = persons[nextPersonIdx];
            final newKnotId = 'pt_$partnershipId';
            partnerships.add(Partnership(
              id: newKnotId,
              person1Id: updatedChild.id,
              person2Id: partner.id,
              status: 'married',
            ));
            nextGenerationKnots.add(newKnotId);
            partnershipId++;
            nextPersonIdx++;
          }
        }
      }
      
      currentGenerationKnots = nextGenerationKnots;
      nextGenerationKnots = [];
    }
  }

  print('Testing TreeLayout with ${persons.length} persons and ${partnerships.length} partnerships...');
  final stopwatch = Stopwatch()..start();
  
  try {
    final config = const TreeLayoutConfig();
    final layout = TreeLayout(persons, partnerships, config);
    stopwatch.stop();
    print('TreeLayout succeeded in ${stopwatch.elapsedMilliseconds}ms');
    print('Canvas size: ${layout.canvasSize.width} x ${layout.canvasSize.height}');
    print('Nodes: ${layout.nodes.length}, Edges: ${layout.edges.length}');
  } catch (e, stack) {
    print('TreeLayout failed with error: $e');
    print(stack);
  }
}
