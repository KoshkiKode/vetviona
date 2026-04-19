import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

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
  final _authorController = TextEditingController();
  final _publisherController = TextEditingController();
  final _publicationDateController = TextEditingController();
  final _repositoryController = TextEditingController();
  final _volumePageController = TextEditingController();
  final _retrievalDateController = TextEditingController();
  String? _type;
  String? _confidence;

  static const _sourceTypes = [
    'Birth',
    'Baptism',
    'Marriage',
    'Death',
    'Burial',
    'Census',
    'Immigration',
    'Military',
    'Probate/Will',
    'Land Record',
    'Newspaper',
    'Book',
    'Digital Database',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _publicationDateController.dispose();
    _repositoryController.dispose();
    _volumePageController.dispose();
    _retrievalDateController.dispose();
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
                      initialValue: _type,
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _authorController,
                      decoration: const InputDecoration(
                        labelText: 'Author (optional)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _publisherController,
                      decoration: const InputDecoration(
                        labelText: 'Publisher (optional)',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _publicationDateController,
                      decoration: const InputDecoration(
                        labelText: 'Publication Date (optional)',
                        hintText: 'e.g. 1920 or Jan 1920',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _repositoryController,
                      decoration: const InputDecoration(
                        labelText: 'Repository / Archive (optional)',
                        hintText: 'e.g. National Archives, Kew',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _volumePageController,
                      decoration: const InputDecoration(
                        labelText: 'Volume / Page (optional)',
                        hintText: 'e.g. Vol. 3, p. 45',
                        prefixIcon: Icon(Icons.menu_book_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _retrievalDateController,
                      decoration: const InputDecoration(
                        labelText: 'URL Retrieval Date (optional)',
                        hintText: 'e.g. 10 Apr 2025',
                        prefixIcon: Icon(Icons.access_time_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      initialValue: _confidence,
                      decoration: const InputDecoration(
                        labelText: 'Confidence Rating (optional)',
                        prefixIcon: Icon(Icons.verified_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Not rated')),
                        ...Source.confidenceRatings.map((r) =>
                            DropdownMenuItem(
                              value: r,
                              child: Text(
                                  '$r — ${Source.confidenceLabels[r]}'),
                            )),
                      ],
                      onChanged: (v) => setState(() => _confidence = v),
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
      id: const Uuid().v4(),
      personId: widget.person.id,
      title: _titleController.text.trim(),
      type: _type ?? 'Other',
      url: _urlController.text.trim(),
      author: _authorController.text.trim().isEmpty
          ? null
          : _authorController.text.trim(),
      publisher: _publisherController.text.trim().isEmpty
          ? null
          : _publisherController.text.trim(),
      publicationDate: _publicationDateController.text.trim().isEmpty
          ? null
          : _publicationDateController.text.trim(),
      repository: _repositoryController.text.trim().isEmpty
          ? null
          : _repositoryController.text.trim(),
      volumePage: _volumePageController.text.trim().isEmpty
          ? null
          : _volumePageController.text.trim(),
      retrievalDate: _retrievalDateController.text.trim().isEmpty
          ? null
          : _retrievalDateController.text.trim(),
      confidence: _confidence,
    );
    await context.read<TreeProvider>().addSource(source);
    if (mounted) Navigator.pop(context);
  }
}

