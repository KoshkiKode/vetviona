import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../providers/tree_provider.dart';
import 'person_detail_screen.dart';
import 'relationship_screen.dart';
import 'sources_page.dart';
import 'timeline_screen.dart';
import 'tree_diagram_screen.dart';

class TreeScreen extends StatefulWidget {
  const TreeScreen({super.key});

  @override
  State<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends State<TreeScreen> {
  bool _tableView = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final persons = provider.persons;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Tree'),
        actions: [
          if (persons.isNotEmpty)
            IconButton(
              icon: Icon(_tableView ? Icons.list : Icons.table_rows_outlined),
              tooltip: _tableView ? 'List view' : 'Table view',
              onPressed: () => setState(() => _tableView = !_tableView),
            ),
          IconButton(
            icon: const Icon(Icons.account_tree),
            tooltip: 'View Diagram',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TreeDiagramScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Person',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PersonDetailScreen()),
            ),
          ),
        ],
      ),
      body: persons.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.people_outline,
                        size: 52,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No people in this tree yet',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first family member to get started.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
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
              ),
            )
          : Column(
              children: [
                // Diagram shortcut banner
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TreeDiagramScreen()),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: colorScheme.primaryContainer.withOpacity(0.5),
                    child: Row(
                      children: [
                        Icon(Icons.account_tree,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'View interactive tree diagram',
                          style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios,
                            size: 14, color: colorScheme.primary),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _tableView
                      ? _FamilyTableView(persons: persons, provider: provider)
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: persons.length,
                          itemBuilder: (context, i) =>
                              _PersonCard(person: persons[i]),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PersonDetailScreen()),
        ),
        tooltip: 'Add Person',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class _FamilyTableView extends StatelessWidget {
  final List<Person> persons;
  final TreeProvider provider;

  const _FamilyTableView({required this.persons, required this.provider});

  String _personName(String? id) {
    if (id == null || id.isEmpty) return '—';
    try {
      return persons.firstWhere((p) => p.id == id).name;
    } catch (_) {
      return '—';
    }
  }

  String _parentNames(Person p) {
    if (p.parentIds.isEmpty) return '—';
    return p.parentIds.map(_personName).join(', ');
  }

  String _childNames(Person p) {
    if (p.childIds.isEmpty) return '—';
    return p.childIds.map(_personName).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
              colorScheme.primaryContainer.withOpacity(0.5)),
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Born')),
            DataColumn(label: Text('Died')),
            DataColumn(label: Text('Parents')),
            DataColumn(label: Text('Spouse')),
            DataColumn(label: Text('Children')),
          ],
          rows: persons.map((p) {
            return DataRow(
              cells: [
                DataCell(
                  Text(p.name,
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PersonDetailScreen(person: p)),
                  ),
                ),
                DataCell(Text(p.birthDate != null
                    ? '${p.birthDate!.year}'
                    : '—')),
                DataCell(Text(p.deathDate != null
                    ? '${p.deathDate!.year}'
                    : '—')),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(_parentNames(p),
                        overflow: TextOverflow.ellipsis, maxLines: 2),
                  ),
                ),
                DataCell(Text(_personName(p.spouseId))),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(_childNames(p),
                        overflow: TextOverflow.ellipsis, maxLines: 2),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final Person person;
  const _PersonCard({required this.person});

  Color _avatarColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (person.gender?.toLowerCase() == 'male') {
      return const Color(0xFF1565C0);
    } else if (person.gender?.toLowerCase() == 'female') {
      return const Color(0xFFAD1457);
    }
    return colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _avatarColor(context);

    return Card(
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.fromLTRB(16, 8, 16, 4),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: avatarColor,
              child: Text(
                person.name.isNotEmpty
                    ? person.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            title: Text(
              person.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: _buildSubtitle(),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _ActionChip(
                  icon: Icons.source_outlined,
                  label: 'Sources',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            SourcesPage(person: person)),
                  ),
                ),
                _ActionChip(
                  icon: Icons.timeline,
                  label: 'Timeline',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            TimelineScreen(person: person)),
                  ),
                ),
                _ActionChip(
                  icon: Icons.link,
                  label: 'Relationships',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            RelationshipScreen(person: person)),
                  ),
                ),
                _ActionChip(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            PersonDetailScreen(person: person)),
                  ),
                ),
                _ActionChip(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: Colors.red,
                  onPressed: () =>
                      _confirmDelete(context, person),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildSubtitle() {
    final parts = <String>[];
    if (person.birthDate != null) {
      parts.add('b. ${person.birthDate!.year}');
    }
    if (person.birthPlace != null &&
        person.birthPlace!.isNotEmpty) {
      parts.add(person.birthPlace!);
    }
    if (person.deathDate != null) {
      parts.add('d. ${person.deathDate!.year}');
    }
    if (parts.isEmpty) return null;
    return Text(parts.join(' \u00b7 '),
        maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Future<void> _confirmDelete(
      BuildContext context, Person person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Person'),
        content:
            Text('Delete ${person.name}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
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

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chipColor = color ?? colorScheme.primary;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: chipColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: chipColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: chipColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

