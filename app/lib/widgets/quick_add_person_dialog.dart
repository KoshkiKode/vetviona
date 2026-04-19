import 'package:flutter/material.dart';

class QuickAddPersonInput {
  final String name;
  final String? gender;

  const QuickAddPersonInput({
    required this.name,
    this.gender,
  });
}

Future<QuickAddPersonInput?> showQuickAddPersonDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  String confirmLabel = 'Add',
  String? initialGender,
}) {
  return showDialog<QuickAddPersonInput>(
    context: context,
    builder: (_) => _QuickAddPersonDialog(
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
      initialGender: initialGender,
    ),
  );
}

class _QuickAddPersonDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String confirmLabel;
  final String? initialGender;

  const _QuickAddPersonDialog({
    required this.title,
    this.subtitle,
    required this.confirmLabel,
    this.initialGender,
  });

  @override
  State<_QuickAddPersonDialog> createState() => _QuickAddPersonDialogState();
}

class _QuickAddPersonDialogState extends State<_QuickAddPersonDialog> {
  late final TextEditingController _nameCtrl;
  String? _gender;

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.subtitle != null) ...[
            Text(widget.subtitle!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Enter person name',
            ),
            onSubmitted: (_) => _submit(),
          ),
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

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      QuickAddPersonInput(name: name, gender: _gender),
    );
  }
}
