import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tree_provider.dart';
import '../models/person.dart';
import '../models/source.dart';
import 'source_detail_screen.dart';

class SourcesPage extends StatelessWidget {
  final Person person;

  const SourcesPage({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final sources = context.watch<TreeProvider>().sources.where((s) => person.sourceIds.contains(s.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${person.name} - Sources'),
      ),
      body: sources.isEmpty
          ? const Center(child: Text('No sources added yet.'))
          : ListView.builder(
              itemCount: sources.length,
              itemBuilder: (context, index) {
                final source = sources[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text('Type: ${source.type}'),
                        if (source.url.isNotEmpty) Text('URL: ${source.url}'),
                        const SizedBox(height: 8),
                        Text('Cites: ${source.citedFacts.isEmpty ? 'None' : source.citedFacts.join(', ')}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => _editCitations(context, source),
                              child: const Text('Edit Citations'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _deleteSource(context, source),
                              child: const Text('Delete'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addSource(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _editCitations(BuildContext context, Source source) async {
    final facts = ['Name', 'Gender', 'Birth Date', 'Birth Place', 'Death Date', 'Death Place', 'Marriage Date', 'Marriage Place'];
    final selected = source.citedFacts.toSet();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Citations'),
          content: SingleChildScrollView(
            child: Column(
              children: facts.map((fact) => CheckboxListTile(
                title: Text(fact),
                value: selected.contains(fact),
                onChanged: (value) {
                  setState(() {
                    if (value!) {
                      selected.add(fact);
                    } else {
                      selected.remove(fact);
                    }
                  });
                },
              )).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                source.citedFacts = selected.toList();
                context.read<TreeProvider>().updateSource(source);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSource(BuildContext context, Source source) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Source'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<TreeProvider>().deleteSource(source);
    }
  }

  Future<void> _addSource(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SourceDetailScreen(person: person)),
    );
  }
}
