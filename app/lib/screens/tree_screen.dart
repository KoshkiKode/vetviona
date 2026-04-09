import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../providers/tree_provider.dart';
import 'person_detail_screen.dart';
import 'relationship_screen.dart';
import 'sources_page.dart';
import 'timeline_screen.dart';

class TreeScreen extends StatelessWidget {
  const TreeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final persons = provider.persons;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Tree'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Person',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PersonDetailScreen()),
            ),
          ),
        ],
      ),
      body: persons.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No people in this tree yet.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add First Person'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PersonDetailScreen()),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: persons.length,
              itemBuilder: (context, i) =>
                  _PersonCard(person: persons[i]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PersonDetailScreen()),
        ),
        tooltip: 'Add Person',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final Person person;
  const _PersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                child: Text(
                  person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                ),
              ),
              title: Text(
                person.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: _buildSubtitle(),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                _ActionButton(
                  icon: Icons.source,
                  label: 'Sources',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SourcesPage(person: person)),
                  ),
                ),
                _ActionButton(
                  icon: Icons.timeline,
                  label: 'Timeline',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TimelineScreen(person: person)),
                  ),
                ),
                _ActionButton(
                  icon: Icons.link,
                  label: 'Relationships',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RelationshipScreen(person: person)),
                  ),
                ),
                _ActionButton(
                  icon: Icons.edit,
                  label: 'Edit',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PersonDetailScreen(person: person)),
                  ),
                ),
                _ActionButton(
                  icon: Icons.delete,
                  label: 'Delete',
                  color: Colors.red,
                  onPressed: () => _confirmDelete(context, person),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildSubtitle() {
    final parts = <String>[];
    if (person.birthDate != null) parts.add('b. ${person.birthDate!.year}');
    if (person.birthPlace != null && person.birthPlace!.isNotEmpty) {
      parts.add(person.birthPlace!);
    }
    if (person.deathDate != null) parts.add('d. ${person.deathDate!.year}');
    if (parts.isEmpty) return null;
    return Text(parts.join(' \u00b7 '), maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Future<void> _confirmDelete(BuildContext context, Person person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Person'),
        content: Text('Delete ${person.name}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TreeProvider>().deletePerson(person.id);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
    );
  }
}
