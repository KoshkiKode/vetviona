import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    final person = widget.person;
    _fatherId = person.parentIds.isNotEmpty ? person.parentIds[0] : null;
    _motherId = person.parentIds.length >= 2 ? person.parentIds[1] : null;
    _spouseId = person.spouseId;
    _marriageDate = person.marriageDate;
    _marriagePlaceController =
        TextEditingController(text: person.marriagePlace ?? '');
  }

  @override
  void dispose() {
    _marriagePlaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final others =
        provider.persons.where((p) => p.id != widget.person.id).toList();
    final colorScheme = Theme.of(context).colorScheme;

    DropdownMenuItem<String?> noneItem() =>
        const DropdownMenuItem<String?>(value: null, child: Text('— None —'));

    List<DropdownMenuItem<String?>> personItems() => [
          noneItem(),
          ...others.map((p) =>
              DropdownMenuItem<String?>(value: p.id, child: Text(p.name))),
        ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Relationships'),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.save, color: colorScheme.onPrimary),
            label: Text('Save',
                style: TextStyle(color: colorScheme.onPrimary)),
            onPressed: _saveRelationships,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            context,
            icon: Icons.family_restroom,
            title: 'Parents',
            children: [
              DropdownButtonFormField<String?>(
                value: _fatherId,
                decoration: const InputDecoration(labelText: 'Father'),
                items: personItems(),
                onChanged: (v) => setState(() => _fatherId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _motherId,
                decoration: const InputDecoration(labelText: 'Mother'),
                items: personItems(),
                onChanged: (v) => setState(() => _motherId = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard(
            context,
            icon: Icons.favorite,
            title: 'Spouse & Marriage',
            children: [
              DropdownButtonFormField<String?>(
                value: _spouseId,
                decoration: const InputDecoration(labelText: 'Spouse'),
                items: personItems(),
                onChanged: (v) => setState(() => _spouseId = v),
              ),
              const SizedBox(height: 12),
              _DatePickerTile(
                label: 'Marriage Date',
                date: _marriageDate,
                onPick: () => _selectMarriageDate(context),
                onClear: _marriageDate != null
                    ? () => setState(() => _marriageDate = null)
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _marriagePlaceController,
                decoration:
                    const InputDecoration(labelText: 'Marriage Place'),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save Relationships'),
            onPressed: _saveRelationships,
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _selectMarriageDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _marriageDate ?? DateTime.now(),
      firstDate: DateTime(1700),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _marriageDate = picked);
  }

  Future<void> _saveRelationships() async {
    final provider = context.read<TreeProvider>();
    final p = widget.person;

    // Build new parentIds list (preserve order: father first, mother second)
    final newParentIds = [_fatherId, _motherId]
        .where((id) => id != null)
        .cast<String>()
        .toList();

    // Remove this person from old parents' childIds that are no longer parents
    for (final oldParentId in p.parentIds) {
      if (!newParentIds.contains(oldParentId)) {
        final oldParent =
            provider.persons.where((x) => x.id == oldParentId).firstOrNull;
        if (oldParent != null) {
          oldParent.childIds.remove(p.id);
          await provider.updatePerson(oldParent);
        }
      }
    }

    // Unlink old spouse if changed
    final oldSpouseId = p.spouseId;
    if (oldSpouseId != null && oldSpouseId != _spouseId) {
      final oldSpouse =
          provider.persons.where((x) => x.id == oldSpouseId).firstOrNull;
      if (oldSpouse != null && oldSpouse.spouseId == p.id) {
        final updatedOldSpouse = Person(
          id: oldSpouse.id,
          name: oldSpouse.name,
          birthDate: oldSpouse.birthDate,
          birthPlace: oldSpouse.birthPlace,
          deathDate: oldSpouse.deathDate,
          deathPlace: oldSpouse.deathPlace,
          gender: oldSpouse.gender,
          parentIds: oldSpouse.parentIds,
          childIds: oldSpouse.childIds,
          spouseId: null,
          photoPaths: oldSpouse.photoPaths,
          sourceIds: oldSpouse.sourceIds,
          marriageDate: oldSpouse.marriageDate,
          marriagePlace: oldSpouse.marriagePlace,
          notes: oldSpouse.notes,
        );
        await provider.updatePerson(updatedOldSpouse);
      }
    }

    final marriagePlaceText = _marriagePlaceController.text.trim();

    // Save updated person
    final updatedPerson = Person(
      id: p.id,
      name: p.name,
      birthDate: p.birthDate,
      birthPlace: p.birthPlace,
      deathDate: p.deathDate,
      deathPlace: p.deathPlace,
      gender: p.gender,
      parentIds: newParentIds,
      childIds: p.childIds,
      spouseId: _spouseId,
      photoPaths: p.photoPaths,
      sourceIds: p.sourceIds,
      marriageDate: _marriageDate,
      marriagePlace:
          marriagePlaceText.isEmpty ? null : marriagePlaceText,
      notes: p.notes,
    );
    await provider.updatePerson(updatedPerson);

    // Link new spouse bidirectionally
    if (_spouseId != null) {
      final spouse =
          provider.persons.where((x) => x.id == _spouseId).firstOrNull;
      if (spouse != null && spouse.spouseId != p.id) {
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
          spouseId: p.id,
          photoPaths: spouse.photoPaths,
          sourceIds: spouse.sourceIds,
          marriageDate: _marriageDate,
          marriagePlace: marriagePlaceText.isEmpty ? null : marriagePlaceText,
          notes: spouse.notes,
        );
        await provider.updatePerson(updatedSpouse);
      }
    }

    // Add this person to new parents' childIds
    if (_fatherId != null) {
      final father =
          provider.persons.where((x) => x.id == _fatherId).firstOrNull;
      if (father != null && !father.childIds.contains(p.id)) {
        father.childIds.add(p.id);
        await provider.updatePerson(father);
      }
    }
    if (_motherId != null) {
      final mother =
          provider.persons.where((x) => x.id == _motherId).firstOrNull;
      if (mother != null && !mother.childIds.contains(p.id)) {
        mother.childIds.add(p.id);
        await provider.updatePerson(mother);
      }
    }

    if (mounted) Navigator.pop(context);
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  const _DatePickerTile({
    required this.label,
    required this.date,
    required this.onPick,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: colorScheme.outline.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 18, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                  ),
                  Text(
                    date != null
                        ? DateFormat('d MMMM yyyy').format(date!)
                        : 'Tap to set date',
                    style:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: date != null
                                  ? null
                                  : colorScheme.onSurfaceVariant,
                            ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}
