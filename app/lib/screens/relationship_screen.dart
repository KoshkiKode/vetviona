import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tree_provider.dart';
import '../models/person.dart';

class RelationshipScreen extends StatefulWidget {
  final Person person;

  const RelationshipScreen({super.key, required this.person});

  @override
  State<RelationshipScreen> createState() => _RelationshipScreenState();
}

class _RelationshipScreenState extends State<RelationshipScreen> {
  String? _fatherId;
  String? _motherId;
  String? _spouseId;
  DateTime? _marriageDate;
  late TextEditingController _marriagePlaceController;
  String? _marriagePlace;

  @override
  void initState() {
    super.initState();
    // Pre-select if already linked
    final provider = context.read<TreeProvider>();
    if (widget.person.parentIds.length >= 1) {
      _fatherId = widget.person.parentIds[0];
    }
    if (widget.person.parentIds.length >= 2) {
      _motherId = widget.person.parentIds[1];
    }
    _spouseId = widget.person.spouseId;
    _marriageDate = widget.person.marriageDate;
    _marriagePlaceController = TextEditingController(text: widget.person.marriagePlace ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final persons = context.watch<TreeProvider>().persons.where((p) => p.id != widget.person.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Relationships'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _fatherId,
              decoration: const InputDecoration(labelText: 'Father'),
              items: persons.map((p) {
                return DropdownMenuItem<String>(
                  value: p.id,
                  child: Text(p.name),
                );
              }).toList(),
              onChanged: (value) => setState(() => _fatherId = value),
            ),
            DropdownButtonFormField<String>(
              value: _motherId,
              decoration: const InputDecoration(labelText: 'Mother'),
              items: persons.map((p) {
                return DropdownMenuItem<String>(
                  value: p.id,
                  child: Text(p.name),
                );
              }).toList(),
              onChanged: (value) => setState(() => _motherId = value),
            ),
            DropdownButtonFormField<String>(
              value: _spouseId,
              decoration: const InputDecoration(labelText: 'Spouse'),
              items: persons.map((p) {
                return DropdownMenuItem<String>(
                  value: p.id,
                  child: Text(p.name),
                );
              }).toList(),
              onChanged: (value) => setState(() => _spouseId = value),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveRelationships,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRelationships() async {
    final provider = context.read<TreeProvider>();
    final updatedPerson = Person(
      id: widget.person.id,
      name: widget.person.name,
      birthDate: widget.person.birthDate,
      birthPlace: widget.person.birthPlace,
      deathDate: widget.person.deathDate,
      deathPlace: widget.person.deathPlace,
      gender: widget.person.gender,
      parentIds: [_fatherId, _motherId].where((id) => id != null).cast<String>().toList(),
      childIds: widget.person.childIds,
      spouseId: _spouseId,
      photoPaths: widget.person.photoPaths,
      sourceIds: widget.person.sourceIds,
    );
    await provider.updatePerson(updatedPerson);
    // Update spouse
    if (_spouseId != null) {
      final spouse = provider.persons.firstWhere((p) => p.id == _spouseId);
      if (spouse.spouseId != widget.person.id) {
        final updatedSpouse = Person(
          id: spouse.id,
          name: spouse.name,
          birthDate: spouse.birthDate,
          birthPlace: spouse.birthPlace,
          deathDate: spouse.deathDate,
          deathPlace: spouse.deathPlace,
          gender: spouse.gender,
          parentIds: spouse.parentIds,
          childIds: spouse.childIds,
          spouseId: widget.person.id,
          photoPaths: spouse.photoPaths,
          sourceIds: spouse.sourceIds,
        );
        await provider.updatePerson(updatedSpouse);
      }
    }
    // Update parents' childIds
    if (_fatherId != null) {
      final father = provider.persons.firstWhere((p) => p.id == _fatherId);
      if (!father.childIds.contains(widget.person.id)) {
        father.childIds.add(widget.person.id);
        await provider.updatePerson(father);
      }
    }
    if (_motherId != null) {
      final mother = provider.persons.firstWhere((p) => p.id == _motherId);
      if (!mother.childIds.contains(widget.person.id)) {
        mother.childIds.add(widget.person.id);
        await provider.updatePerson(mother);
      }
    }
    Navigator.pop(context);
  }
}
