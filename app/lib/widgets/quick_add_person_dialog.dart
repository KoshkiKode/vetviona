import 'package:flutter/material.dart';

import '../models/person.dart';

class QuickAddPersonInput {
  final String name;
  final String? gender;

  /// When non-null the user picked an already-existing person from the tree
  /// rather than creating a new one.  The [name] field still holds the
  /// display name of that person for convenience.
  final String? existingPersonId;

  const QuickAddPersonInput({
    required this.name,
    this.gender,
    this.existingPersonId,
  });

  /// Whether the user picked an existing person rather than entering a new one.
  bool get isExisting => existingPersonId != null;
}

/// Shows a quick-add dialog that lets the user either **create** a new person
/// (by typing a name and optional gender) or **pick** an already-existing
/// person from [existingPersons] via an inline search list.
///
/// Returns `null` if the user cancels.
Future<QuickAddPersonInput?> showQuickAddPersonDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  String confirmLabel = 'Add',
  String? initialGender,
  List<Person>? existingPersons,
}) {
  return showDialog<QuickAddPersonInput>(
    context: context,
    builder: (_) => _QuickAddPersonDialog(
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
      initialGender: initialGender,
      existingPersons: existingPersons,
    ),
  );
}

class _QuickAddPersonDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String confirmLabel;
  final String? initialGender;
  final List<Person>? existingPersons;

  const _QuickAddPersonDialog({
    required this.title,
    this.subtitle,
    required this.confirmLabel,
    this.initialGender,
    this.existingPersons,
  });

  @override
  State<_QuickAddPersonDialog> createState() => _QuickAddPersonDialogState();
}

class _QuickAddPersonDialogState extends State<_QuickAddPersonDialog> {
  late final TextEditingController _nameCtrl;
  String? _gender;
  List<Person> _matches = [];

  static const _maxSearchResults = 6;

  static const _genderOptions = ['Male', 'Female', 'Non-binary', 'Other'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _gender = _genderOptions.contains(widget.initialGender)
        ? widget.initialGender
        : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    if (widget.existingPersons == null || widget.existingPersons!.isEmpty) {
      return;
    }
    final query = value.trim().toLowerCase();
    setState(() {
      _matches = query.isEmpty
          ? []
          : widget.existingPersons!
              .where((p) => p.name.toLowerCase().contains(query))
              .take(_maxSearchResults)
              .toList();
    });
  }

  void _pickExisting(Person person) {
    Navigator.pop(
      context,
      QuickAddPersonInput(
        name: person.name,
        gender: person.gender,
        existingPersonId: person.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.subtitle != null) ...[
              Text(widget.subtitle!),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: widget.existingPersons != null
                    ? 'Type to search or create'
                    : 'Enter person name',
              ),
              onChanged: _onNameChanged,
              onSubmitted: (_) => _submit(),
            ),
            // ── Existing-person search results ────────────────────────────
            if (_matches.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        'Pick from tree',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ..._matches.map(
                      (p) => InkWell(
                        onTap: () => _pickExisting(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: _genderColor(
                                  p.gender,
                                  colorScheme,
                                ),
                                child: Text(
                                  p.name.isNotEmpty
                                      ? p.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _genderOnColor(
                                      p.gender,
                                      colorScheme,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (p.birthDate != null || p.gender != null)
                                      Text(
                                        [
                                          if (p.gender != null) p.gender,
                                          if (p.birthDate != null)
                                            'b. ${p.birthDate!.year}',
                                        ].join(' · '),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.link,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        'Or create new person below',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Gender (optional)'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Not specified'),
                ),
                ..._genderOptions.map(
                  (gender) => DropdownMenuItem<String?>(
                    value: gender,
                    child: Text(gender),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _gender = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }

  Color _genderColor(String? gender, ColorScheme cs) {
    if (gender?.toLowerCase() == 'male') return cs.primary;
    if (gender?.toLowerCase() == 'female') return cs.error;
    return cs.secondary;
  }

  Color _genderOnColor(String? gender, ColorScheme cs) {
    if (gender?.toLowerCase() == 'male') return cs.onPrimary;
    if (gender?.toLowerCase() == 'female') return cs.onError;
    return cs.onSecondary;
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      QuickAddPersonInput(name: name, gender: _gender),
    );
  }
}
