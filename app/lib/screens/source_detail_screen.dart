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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Source'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
              ),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: ['Birth', 'Marriage', 'Death', 'Census', 'Other'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _type = value),
              ),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'URL'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveSource,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSource() async {
    if (_formKey.currentState!.validate()) {
      final source = Source(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        personId: widget.person.id,
        title: _titleController.text,
        type: _type ?? 'Other',
        url: _urlController.text,
      );
      await context.read<TreeProvider>().addSource(source);
      Navigator.pop(context);
    }
  }
}
