import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/memory.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';

/// Memories screen for a person (Phase 4).
///
/// Displays a list of long-form stories and memories associated with the person.
class MemoriesScreen extends StatelessWidget {
  final Person person;
  const MemoriesScreen({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final memories = provider.memories
        .where((m) => m.personId == person.id)
        .toList()
      ..sort((a, b) => (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${person.name} — Memories'),
      ),
      body: memories.isEmpty
          ? _EmptyState(person: person, onAdd: () => _addMemory(context))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
              itemCount: memories.length,
              itemBuilder: (context, index) {
                final memory = memories[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memory.title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (memory.date != null || memory.place != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            [memory.date, memory.place]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' · '),
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          memory.text,
                          style: const TextStyle(fontSize: 15, height: 1.5),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                              onPressed: () => _editMemory(context, memory),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('Delete'),
                              style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.error),
                              onPressed: () =>
                                  _deleteMemory(context, provider, memory),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addMemory(context),
        icon: const Icon(Icons.edit_document),
        label: const Text('Write Memory'),
      ),
    );
  }

  Future<void> _addMemory(BuildContext context) async {
    final result = await showDialog<Memory>(
      context: context,
      builder: (_) => _MemoryDialog(personId: person.id),
    );
    if (result != null && context.mounted) {
      await context.read<TreeProvider>().addMemory(result);
    }
  }

  Future<void> _editMemory(BuildContext context, Memory memory) async {
    final result = await showDialog<Memory>(
      context: context,
      builder: (_) => _MemoryDialog(personId: person.id, existing: memory),
    );
    if (result != null && context.mounted) {
      await context.read<TreeProvider>().updateMemory(result);
    }
  }

  Future<void> _deleteMemory(
      BuildContext context, TreeProvider provider, Memory memory) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog.adaptive(
        title: const Text('Delete Memory'),
        content: Text('Delete "${memory.title}"? This cannot be undone.'),
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
    if (confirm == true) {
      await provider.deleteMemory(memory.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final Person person;
  final VoidCallback onAdd;

  const _EmptyState({required this.person, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories,
              size: 80, color: colorScheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No memories written yet.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Write a story or add a diary entry\nabout ${person.name}.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.edit_document),
            label: const Text('Write Memory'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _MemoryDialog extends StatefulWidget {
  final String personId;
  final Memory? existing;

  const _MemoryDialog({required this.personId, this.existing});

  @override
  State<_MemoryDialog> createState() => _MemoryDialogState();
}

class _MemoryDialogState extends State<_MemoryDialog> {
  late TextEditingController _titleController;
  late TextEditingController _textController;
  late TextEditingController _dateController;
  late TextEditingController _placeController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _textController = TextEditingController(text: widget.existing?.text ?? '');
    _dateController = TextEditingController(text: widget.existing?.date ?? '');
    _placeController = TextEditingController(text: widget.existing?.place ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _dateController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing != null ? 'Edit Memory' : 'Write Memory'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                if (_titleController.text.trim().isEmpty ||
                    _textController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Title and story text are required.')),
                  );
                  return;
                }
                final memory = Memory(
                  id: widget.existing?.id ?? const Uuid().v4(),
                  personId: widget.personId,
                  title: _titleController.text.trim(),
                  text: _textController.text.trim(),
                  date: _dateController.text.trim().isNotEmpty
                      ? _dateController.text.trim()
                      : null,
                  place: _placeController.text.trim().isNotEmpty
                      ? _placeController.text.trim()
                      : null,
                  treeId: widget.existing?.treeId,
                  updatedAt: DateTime.now().millisecondsSinceEpoch,
                );
                Navigator.pop(context, memory);
              },
              child: const Text('Save'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Summer at the lakehouse',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date (optional)',
                      hintText: 'e.g. July 1985',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _placeController,
                    decoration: const InputDecoration(
                      labelText: 'Location (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Story',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: null,
              minLines: 15,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}
