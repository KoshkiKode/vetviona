import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tree_provider.dart';

class TreeScreen extends StatelessWidget {
  const TreeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final persons = context.watch<TreeProvider>().persons;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Tree'),
      ),
      body: ListView.builder(
        itemCount: persons.length,
        itemBuilder: (context, index) {
          final person = persons[index];
          return ListTile(
            title: Text(person.name),
            subtitle: Text(
              'Born: ${person.birthDate?.toString() ?? 'Unknown'} at ${person.birthPlace ?? 'Unknown'}',
            ),
          );
        },
      ),
    );
  }
}
