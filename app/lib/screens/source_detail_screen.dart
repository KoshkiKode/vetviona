import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tree_provider.dart';
import '../models/person.dart';
import '../models/source.dart';

class SourceDetailScreen extends StatefulWidget {
  final Person person;

  const SourceDetailScreen({super.key, required this.person});

  @override
  State<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends State<SourceDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  String? _type;

  static const _sourceTypes = ['Birth', 'Marriage', 'Death', 'Census', 'Other'];

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Source'),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.save, color: colorScheme.onPrimary),
            label: Text('Save',
                style: TextStyle(color: colorScheme.onPrimary)),
            onPressed: _saveSource,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Details section ──────────────────────────────────────────
            Card(
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
                        Text(
                          'Source Details',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. 1920 US Census',
                        prefixIcon: Icon(Icons.title),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Title is required'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _type,
                      decoration: const InputDecoration(
                        labelText: 'Source Type',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _sourceTypes
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _type = v),
                      validator: (v) =>
                          v == null ? 'Please select a type' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL (optional)',
                        hintText: 'https://…',
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Source'),
              onPressed: _saveSource,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSource() async {
    if (!_formKey.currentState!.validate()) return;
    final source = Source(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      personId: widget.person.id,
      title: _titleController.text.trim(),
      type: _type ?? 'Other',
      url: _urlController.text.trim(),
    );
    await context.read<TreeProvider>().addSource(source);
    if (mounted) Navigator.pop(context);
  }
}
