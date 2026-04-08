import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/tree_provider.dart';
import '../models/person.dart';

class PersonDetailScreen extends StatefulWidget {
  final Person? person;

  const PersonDetailScreen({super.key, this.person});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _birthPlaceController;
  late TextEditingController _deathPlaceController;
  late TextEditingController _genderController;
  DateTime? _birthDate;
  DateTime? _deathDate;
  bool _isLiving = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.person?.name ?? '');
    _birthPlaceController = TextEditingController(text: widget.person?.birthPlace ?? '');
    _deathPlaceController = TextEditingController(text: widget.person?.deathPlace ?? '');
    _genderController = TextEditingController(text: widget.person?.gender ?? '');
    _birthDate = widget.person?.birthDate;
    _deathDate = widget.person?.deathDate;
    _isLiving = widget.person == null || widget.person!.deathDate == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person == null ? 'Add Person' : 'Edit Person'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
              ),
              Row(
                children: [
                  const Text('Living: '),
                  Radio<bool>(
                    value: true,
                    groupValue: _isLiving,
                    onChanged: (value) => setState(() => _isLiving = value!),
                  ),
                  const Text('Yes'),
                  Radio<bool>(
                    value: false,
                    groupValue: _isLiving,
                    onChanged: (value) => setState(() => _isLiving = value!),
                  ),
                  const Text('No'),
                ],
              ),
              TextFormField(
                controller: _genderController,
                decoration: const InputDecoration(labelText: 'Gender (Male, Female, or custom)'),
              ),
              ListTile(
                title: Text('Birth Date: ${_birthDate != null ? DateFormat.yMd().format(_birthDate!) : 'Not set'}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, true),
              ),
              TextFormField(
                controller: _birthPlaceController,
                decoration: const InputDecoration(labelText: 'Birth Place'),
              ),
              if (!_isLiving) ...[
                ListTile(
                  title: Text('Death Date: ${_deathDate != null ? DateFormat.yMd().format(_deathDate!) : 'Not set'}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context, false),
                ),
                TextFormField(
                  controller: _deathPlaceController,
                  decoration: const InputDecoration(labelText: 'Death Place'),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _savePerson,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isBirth) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1800),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isBirth) {
          _birthDate = picked;
        } else {
          _deathDate = picked;
        }
      });
    }
  }

  Future<void> _savePerson() async {
    if (_formKey.currentState!.validate()) {
      final person = Person(
        id: widget.person?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        birthDate: _birthDate,
        birthPlace: _birthPlaceController.text.isEmpty ? null : _birthPlaceController.text,
        deathDate: _isLiving ? null : _deathDate,
        deathPlace: _isLiving ? null : (_deathPlaceController.text.isEmpty ? null : _deathPlaceController.text),
        gender: _genderController.text.isEmpty ? null : _genderController.text,
        photoPaths: widget.person?.photoPaths ?? [],
        sourceIds: widget.person?.sourceIds ?? [],
      );
      if (widget.person == null) {
        await context.read<TreeProvider>().addPerson(person);
      } else {
        await context.read<TreeProvider>().updatePerson(person);
      }
      Navigator.pop(context);
    }
  }
}
