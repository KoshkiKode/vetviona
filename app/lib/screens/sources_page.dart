import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tree_provider.dart';
import '../models/person.dart';
import '../models/source.dart';
import 'source_detail_screen.dart';

/// Canonical fact tags used for citations; keep in sync with TimelineScreen.
const List<String> kCitableFacts = [
  'Birth Date',
  'Birth Place',
  'Death Date',
  'Death Place',
  'Marriage Date',
  'Marriage Place',
  'Name',
  'Gender',
];

class SourcesPage extends StatelessWidget {
  final Person person;

  const SourcesPage({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    // Show sources that belong to this person (by personId or in sourceIds)
    final sources = provider.sources
        .where((s) =>
            s.personId == person.id || person.sourceIds.contains(s.id))
        .toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${person.name} – Sources'),
      ),
      body: sources.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.source_outlined,
                      size: 64, color: colorScheme.primary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No sources added yet.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          )),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Source'),
                    onPressed: () => _addSource(context),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
              itemCount: sources.length,
              itemBuilder: (context, index) {
                final source = sources[index];
                return _SourceCard(
                  source: source,
                  onEditCitations: () => _editCitations(context, source),
                  onDelete: () => _deleteSource(context, source),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSource(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Source'),
      ),
    );
  }

  Future<void> _editCitations(BuildContext context, Source source) async {
    final selected = source.citedFacts.toSet();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Citations'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: kCitableFacts
                  .map((fact) => CheckboxListTile(
                        dense: true,
                        title: Text(fact),
                        value: selected.contains(fact),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selected.add(fact);
                            } else {
                              selected.remove(fact);
                            }
                          });
                        },
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
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
        content: Text('Delete "${source.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<TreeProvider>().deleteSource(source.id);
    }
  }

  void _addSource(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SourceDetailScreen(person: person)),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final Source source;
  final VoidCallback onEditCitations;
  final VoidCallback onDelete;

  const _SourceCard({
    required this.source,
    required this.onEditCitations,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    source.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _TypeBadge(type: source.type),
              ],
            ),
            if (source.url.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.link,
                      size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      source.url,
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (source.extractedInfo != null &&
                source.extractedInfo!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(source.extractedInfo!,
                  style: TextStyle(
                      fontSize: 13, color: colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),
            if (source.citedFacts.isNotEmpty) ...[
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: source.citedFacts
                    .map((f) => Chip(
                          label: Text(f,
                              style: const TextStyle(fontSize: 11)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.checklist, size: 16),
                  label: const Text('Citations'),
                  onPressed: onEditCitations,
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 11,
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
