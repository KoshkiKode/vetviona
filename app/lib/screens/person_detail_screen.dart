import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  late TextEditingController _notesController;
  String? _gender;
  DateTime? _birthDate;
  DateTime? _deathDate;
  bool _isLiving = true;
  late List<String> _photoPaths;

  static const _genderOptions = ['Male', 'Female', 'Non-binary', 'Other'];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.person?.name ?? '');
    _birthPlaceController =
        TextEditingController(text: widget.person?.birthPlace ?? '');
    _deathPlaceController =
        TextEditingController(text: widget.person?.deathPlace ?? '');
    _notesController =
        TextEditingController(text: widget.person?.notes ?? '');
    _gender = widget.person?.gender;
    _birthDate = widget.person?.birthDate;
    _deathDate = widget.person?.deathDate;
    _isLiving =
        widget.person == null || widget.person!.deathDate == null;
    _photoPaths = List<String>.from(widget.person?.photoPaths ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthPlaceController.dispose();
    _deathPlaceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Picks one or more photos from the gallery / file system.
  Future<void> _pickPhotos() async {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    List<String> newPaths = [];
    if (isDesktop) {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null) {
        newPaths = result.files.map((f) => f.path).whereType<String>().toList();
      }
    } else {
      final images = await ImagePicker().pickMultiImage();
      newPaths = images.map((x) => x.path).toList();
    }
    if (newPaths.isNotEmpty) {
      setState(() => _photoPaths.addAll(newPaths));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.person != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Person' : 'Add Person'),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.save, color: colorScheme.onPrimary),
            label: Text('Save',
                style: TextStyle(color: colorScheme.onPrimary)),
            onPressed: _savePerson,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection(
              context,
              icon: Icons.person,
              title: 'Basic Information',
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration:
                      const InputDecoration(labelText: 'Full Name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty
                          ? 'Name is required'
                          : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _genderOptions.contains(_gender) ? _gender : null,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Not specified')),
                    ..._genderOptions.map(
                      (g) => DropdownMenuItem(value: g, child: Text(g)),
                    ),
                    // Preserve legacy/custom values that aren't in the standard list
                    if (_gender != null && !_genderOptions.contains(_gender))
                      DropdownMenuItem(value: _gender, child: Text(_gender!)),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isLiving,
                  onChanged: (v) => setState(() => _isLiving = v),
                  title: const Text('Currently living'),
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              icon: Icons.cake,
              title: 'Birth',
              children: [
                _DatePickerTile(
                  label: 'Birth Date',
                  date: _birthDate,
                  onPick: () => _selectDate(context, true),
                  onClear: _birthDate != null
                      ? () => setState(() => _birthDate = null)
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birthPlaceController,
                  decoration:
                      const InputDecoration(labelText: 'Birth Place'),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
            if (!_isLiving) ...[
              const SizedBox(height: 16),
              _buildSection(
                context,
                icon: Icons.star_border,
                title: 'Death',
                children: [
                  _DatePickerTile(
                    label: 'Death Date',
                    date: _deathDate,
                    onPick: () => _selectDate(context, false),
                    onClear: _deathDate != null
                        ? () => setState(() => _deathDate = null)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _deathPlaceController,
                    decoration:
                        const InputDecoration(labelText: 'Death Place'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _buildSection(
              context,
              icon: Icons.notes,
              title: 'Notes',
              children: [
                TextFormField(
                  controller: _notesController,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                  minLines: 3,
                  maxLines: 6,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              icon: Icons.photo_library_outlined,
              title: 'Photos',
              children: [
                if (_photoPaths.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No photos added.',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                    ),
                  )
                else
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photoPaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final path = _photoPaths[i];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(path),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 100,
                                  height: 100,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _photoPaths.removeAt(i)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add Photo'),
                  onPressed: _pickPhotos,
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Person'),
              onPressed: _savePerson,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
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

  Future<void> _selectDate(BuildContext context, bool isBirth) async {
    final initial = (isBirth ? _birthDate : _deathDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1700),
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
    if (!_formKey.currentState!.validate()) return;
    final person = Person(
      id: widget.person?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      birthDate: _birthDate,
      birthPlace: _birthPlaceController.text.trim().isEmpty
          ? null
          : _birthPlaceController.text.trim(),
      deathDate: _isLiving ? null : _deathDate,
      deathPlace: _isLiving
          ? null
          : (_deathPlaceController.text.trim().isEmpty
              ? null
              : _deathPlaceController.text.trim()),
      gender: _gender,
      photoPaths: _photoPaths,
      sourceIds: widget.person?.sourceIds ?? [],
      parentIds: widget.person?.parentIds ?? [],
      childIds: widget.person?.childIds ?? [],
      parentRelTypes: widget.person?.parentRelTypes ?? {},
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    final provider = context.read<TreeProvider>();
    if (widget.person == null) {
      try {
        await provider.addPerson(person);
      } on StateError catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor:
                  Theme.of(context).colorScheme.outlineVariant,
            ),
          );
        }
        return;
      }
    } else {
      await provider.updatePerson(person);
    }
    if (mounted) Navigator.pop(context);
  }
}

enum _DateField { birth, death }

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
          border: Border.all(
              color: colorScheme.outline.withOpacity(0.3)),
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
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    date != null
                        ? DateFormat('d MMMM yyyy').format(date!)
                        : 'Tap to set date',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
