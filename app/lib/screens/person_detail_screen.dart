import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../services/sound_service.dart';
import '../models/life_event.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../utils/platform_utils.dart';
import 'medical_history_screen.dart';
import 'photo_gallery_screen.dart';
import 'relationship_screen.dart';
import 'research_tasks_screen.dart';
import 'descendants_screen.dart';
import 'wikitree_screen.dart';
import '../services/find_a_grave_service.dart';
import '../services/wikitree_service.dart';
import 'map_picker_screen.dart';

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
  late TextEditingController _occupationController;
  late TextEditingController _nationalityController;
  late TextEditingController _maidenNameController;
  late TextEditingController _burialPlaceController;
  late TextEditingController _birthPostalCodeController;
  late TextEditingController _deathPostalCodeController;
  late TextEditingController _burialPostalCodeController;
  String? _gender;
  DateTime? _birthDate;
  DateTime? _deathDate;
  DateTime? _burialDate;
  GeoCoord? _birthCoord;
  GeoCoord? _deathCoord;
  GeoCoord? _burialCoord;
  bool _isLiving = true;
  bool _isPrivate = false;
  late List<String> _photoPaths;

  // New fields — physical traits and extra details
  late TextEditingController _causeOfDeathController;
  late TextEditingController _eyeColourController;
  late TextEditingController _hairColourController;
  late TextEditingController _heightController;
  late TextEditingController _religionController;
  late TextEditingController _educationController;
  String? _bloodType;
  late List<String> _aliases;

  // External IDs
  String? _wikitreeId;
  String? _findAGraveId;

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
    _occupationController =
        TextEditingController(text: widget.person?.occupation ?? '');
    _nationalityController =
        TextEditingController(text: widget.person?.nationality ?? '');
    _maidenNameController =
        TextEditingController(text: widget.person?.maidenName ?? '');
    _burialPlaceController =
        TextEditingController(text: widget.person?.burialPlace ?? '');
    _birthPostalCodeController =
        TextEditingController(text: widget.person?.birthPostalCode ?? '');
    _deathPostalCodeController =
        TextEditingController(text: widget.person?.deathPostalCode ?? '');
    _burialPostalCodeController =
        TextEditingController(text: widget.person?.burialPostalCode ?? '');
    _gender = widget.person?.gender;
    _birthDate = widget.person?.birthDate;
    _deathDate = widget.person?.deathDate;
    _burialDate = widget.person?.burialDate;
    _birthCoord = widget.person?.birthCoord;
    _deathCoord = widget.person?.deathCoord;
    _burialCoord = widget.person?.burialCoord;
    _isLiving =
        widget.person == null || widget.person!.deathDate == null;
    _isPrivate = widget.person?.isPrivate ?? false;
    _photoPaths = List<String>.from(widget.person?.photoPaths ?? []);
    _causeOfDeathController =
        TextEditingController(text: widget.person?.causeOfDeath ?? '');
    _eyeColourController =
        TextEditingController(text: widget.person?.eyeColour ?? '');
    _hairColourController =
        TextEditingController(text: widget.person?.hairColour ?? '');
    _heightController =
        TextEditingController(text: widget.person?.height ?? '');
    _religionController =
        TextEditingController(text: widget.person?.religion ?? '');
    _educationController =
        TextEditingController(text: widget.person?.education ?? '');
    _bloodType = widget.person?.bloodType;
    _aliases = List<String>.from(widget.person?.aliases ?? []);
    _wikitreeId = widget.person?.wikitreeId;
    _findAGraveId = widget.person?.findAGraveId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthPlaceController.dispose();
    _deathPlaceController.dispose();
    _notesController.dispose();
    _occupationController.dispose();
    _nationalityController.dispose();
    _maidenNameController.dispose();
    _burialPlaceController.dispose();
    _birthPostalCodeController.dispose();
    _deathPostalCodeController.dispose();
    _burialPostalCodeController.dispose();
    _causeOfDeathController.dispose();
    _eyeColourController.dispose();
    _hairColourController.dispose();
    _heightController.dispose();
    _religionController.dispose();
    _educationController.dispose();
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
    final provider = context.watch<TreeProvider>();
    final isHomePerson =
        isEditing && provider.homePersonId == widget.person!.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Person' : 'Add Person'),
        actions: [
          if (isEditing)
            Tooltip(
              message: isHomePerson
                  ? 'Home person (tap to clear)'
                  : 'Set as home person',
              child: IconButton(
                icon: Icon(
                  isHomePerson ? Icons.home : Icons.home_outlined,
                  color: colorScheme.onPrimary,
                ),
                onPressed: () async {
                  final newId =
                      isHomePerson ? null : widget.person!.id;
                  await context
                      .read<TreeProvider>()
                      .setHomePersonId(newId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(
                      content: Text(newId != null
                          ? '${widget.person!.name} set as home person'
                          : 'Home person cleared'),
                    ));
                  }
                },
              ),
            ),
          TextButton.icon(
            icon: Icon(Icons.save, color: colorScheme.onPrimary),
            label: Text('Save',
                style: TextStyle(color: colorScheme.onPrimary)),
            onPressed: _savePerson,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final form = Form(
            key: _formKey,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 680 : double.infinity,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
            if (widget.person != null) _buildPersonHeader(context),
            _buildSection(
              context,
              icon: Icons.person,
              title: 'Basic Information',
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    helperText: 'Legal name or commonly known name',
                    helperMaxLines: 2,
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
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
                  subtitle: const Text('Turn off to enter death information'),
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                SwitchListTile(
                  value: _isPrivate,
                  onChanged: (v) => setState(() => _isPrivate = v),
                  title: const Text('Private (living person)'),
                  subtitle: const Text(
                    'Excluded from all exports & sync',
                    style: TextStyle(fontSize: 11),
                  ),
                  secondary: const Icon(Icons.lock_outline),
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
                _PlaceField(
                  controller: _birthPlaceController,
                  postalCodeController: _birthPostalCodeController,
                  label: 'Birth Place',
                  coord: _birthCoord,
                  eventDate: _birthDate,
                  onCoordChanged: (c) {
                    setState(() {
                      _birthCoord = c;
                      if (c != null) {
                        if (_birthPlaceController.text.trim().isEmpty) {
                          _birthPlaceController.text = c.shortLabel;
                        }
                        if (_birthPostalCodeController.text.trim().isEmpty &&
                            c.postalCode != null) {
                          _birthPostalCodeController.text = c.postalCode!;
                        }
                      }
                    });
                  },
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
                  _PlaceField(
                    controller: _deathPlaceController,
                    postalCodeController: _deathPostalCodeController,
                    label: 'Death Place',
                    coord: _deathCoord,
                    eventDate: _deathDate,
                    onCoordChanged: (c) {
                      setState(() {
                        _deathCoord = c;
                        if (c != null) {
                          if (_deathPlaceController.text.trim().isEmpty) {
                            _deathPlaceController.text = c.shortLabel;
                          }
                          if (_deathPostalCodeController.text.trim().isEmpty &&
                              c.postalCode != null) {
                            _deathPostalCodeController.text = c.postalCode!;
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _causeOfDeathController,
                    decoration:
                        const InputDecoration(labelText: 'Cause of Death'),
                    textCapitalization: TextCapitalization.sentences,
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
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    helperText: 'Any extra biographical details, stories, or observations',
                    helperMaxLines: 2,
                  ),
                  minLines: 3,
                  maxLines: 6,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Advanced Details (collapsed by default) ───────────────────
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.tune),
                title: const Text(
                  'Advanced Details',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Physical traits, aliases & more (optional)',
                  style: TextStyle(fontSize: 12),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Physical Traits subsection
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.accessibility_new,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Physical Traits',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                  DropdownButtonFormField<String?>(
                    value: _bloodType,
                    decoration: const InputDecoration(
                      labelText: 'Blood Type',
                      helperText: 'Useful for medical history tracking',
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Not specified')),
                      ...Person.allBloodTypes.map(
                          (t) => DropdownMenuItem(value: t, child: Text(t))),
                    ],
                    onChanged: (v) => setState(() => _bloodType = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _eyeColourController,
                    decoration: const InputDecoration(
                      labelText: 'Eye Colour',
                      hintText: 'e.g. Brown, Blue, Green',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _hairColourController,
                    decoration: const InputDecoration(
                      labelText: 'Hair Colour',
                      hintText: 'e.g. Black, Blonde, Auburn',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _heightController,
                    decoration: const InputDecoration(
                      labelText: 'Height',
                      hintText: "e.g. 178 cm or 5'10\"",
                    ),
                  ),
                  const Divider(height: 28),
                  // Aliases subsection
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.badge_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Aliases / Also Known As',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Add birth names, nicknames, or other names this person was known by.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ..._aliases.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(entry.value,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Remove alias',
                              onPressed: () =>
                                  setState(() => _aliases.removeAt(entry.key)),
                            ),
                          ],
                        ),
                      )),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Alias'),
                    onPressed: () => _addAlias(context),
                  ),
                  const Divider(height: 28),
                  // Additional Details subsection
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Additional Details',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                  TextFormField(
                    controller: _occupationController,
                    decoration: const InputDecoration(
                      labelText: 'Occupation',
                      hintText: 'e.g. Farmer, Teacher, Engineer',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nationalityController,
                    decoration: const InputDecoration(
                      labelText: 'Nationality',
                      hintText: 'e.g. Czech, Polish, Ukrainian',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _maidenNameController,
                    decoration: const InputDecoration(
                      labelText: 'Maiden Name',
                      helperText: 'Birth surname before marriage',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _religionController,
                    decoration: const InputDecoration(
                      labelText: 'Religion / Faith',
                      hintText: 'e.g. Catholic, Orthodox, None',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _educationController,
                    decoration: const InputDecoration(
                      labelText: 'Education Level',
                      hintText: 'e.g. Primary, Secondary, University',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ),
            if (!_isLiving) ...[
              const SizedBox(height: 16),
              _buildSection(
                context,
                icon: Icons.place_outlined,
                title: 'Burial',
                children: [
                  _DatePickerTile(
                    label: 'Burial Date',
                    date: _burialDate,
                    onPick: () => _selectBurialDate(context),
                    onClear: _burialDate != null
                        ? () => setState(() => _burialDate = null)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _PlaceField(
                    controller: _burialPlaceController,
                    postalCodeController: _burialPostalCodeController,
                    label: 'Burial Place',
                    coord: _burialCoord,
                    eventDate: _burialDate,
                    onCoordChanged: (c) {
                      setState(() {
                        _burialCoord = c;
                        if (c != null) {
                          if (_burialPlaceController.text.trim().isEmpty) {
                            _burialPlaceController.text = c.shortLabel;
                          }
                          if (_burialPostalCodeController.text.trim().isEmpty &&
                              c.postalCode != null) {
                            _burialPostalCodeController.text = c.postalCode!;
                          }
                        }
                      });
                    },
                  ),
                ],
              ),
            ],
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
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PhotoGalleryScreen(
                                    photoPaths: _photoPaths,
                                    initialIndex: i,
                                  ),
                                ),
                              ),
                              child: ClipRRect(
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
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _photoPaths.removeAt(i)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .scrim
                                        .withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
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
            const SizedBox(height: 16),
            if (isEditing) ...[
              _RelationshipsSection(person: widget.person!),
              const SizedBox(height: 8),
              _LifeEventsSection(personId: widget.person!.id),
              const SizedBox(height: 8),
              _QuickLinkCard(
                icon: Icons.account_tree,
                title: 'Descendants Chart',
                subtitle: 'View all descendants of this person',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DescendantsScreen(initialPerson: widget.person),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _QuickLinkCard(
                icon: Icons.local_hospital_outlined,
                title: 'Medical History',
                subtitle: 'Track inherited conditions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MedicalHistoryScreen(person: widget.person),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _QuickLinkCard(
                icon: Icons.assignment_outlined,
                title: 'Research Tasks',
                subtitle: 'To-do items for this person',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ResearchTasksScreen(person: widget.person),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            // ── External IDs ──────────────────────────────────────────────
            _buildSection(
              context,
              icon: Icons.link,
              title: 'External IDs',
              children: [
                _ExternalIdSection(
                  wikitreeId: _wikitreeId,
                  findAGraveId: _findAGraveId,
                  personName: _nameController.text,
                  birthYear: _birthDate?.year,
                  onWikiTreeIdChanged: (id) =>
                      setState(() => _wikitreeId = id),
                  onFindAGraveIdChanged: (id) =>
                      setState(() => _findAGraveId = id),
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
            ),
          );
          // On desktop, wrap in SelectionArea so all text is
          // selectable with the mouse and ⌘C / Ctrl+C.
          return isDesktop ? SelectionArea(child: form) : form;
        },
      ),
    );
  }

  Widget _buildPersonHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final person = widget.person!;
    Color avatarBg;
    if (_gender?.toLowerCase() == 'male') {
      avatarBg = colorScheme.primary;
    } else if (_gender?.toLowerCase() == 'female') {
      avatarBg = colorScheme.error;
    } else {
      avatarBg = colorScheme.secondary;
    }
    final avatarFg = ThemeData.estimateBrightnessForColor(avatarBg) ==
            Brightness.dark
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: Column(
          children: [
            Hero(
              tag: 'person_avatar_${person.id}',
              child: _photoPaths.isNotEmpty
                  ? CircleAvatar(
                      radius: 40,
                      backgroundImage:
                          FileImage(File(_photoPaths.first)),
                      backgroundColor: avatarBg,
                      onBackgroundImageError: (_, __) {},
                    )
                  : CircleAvatar(
                      radius: 40,
                      backgroundColor: avatarBg,
                      child: Text(
                        person.name.isNotEmpty
                            ? person.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: avatarFg,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              _nameController.text.isNotEmpty ? _nameController.text : person.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
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

  Future<void> _addAlias(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Add Alias'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              hintText: 'e.g. Birth name, nickname…'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && !_aliases.contains(result)) {
      setState(() => _aliases.add(result));
    }
  }

  Future<void> _selectDate(BuildContext context, bool isBirth) async {
    final initial = (isBirth ? _birthDate : _deathDate) ?? DateTime.now();
    final picked = await pickDateAdaptive(
      context,
      initialDate: initial,
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

  Future<void> _selectBurialDate(BuildContext context) async {
    final initial = _burialDate ?? DateTime.now();
    final picked = await pickDateAdaptive(
      context,
      initialDate: initial,
    );
    if (picked != null) {
      setState(() => _burialDate = picked);
    }
  }

  Future<void> _savePerson() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    final person = Person(
      id: widget.person?.id ?? const Uuid().v4(),
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
      occupation: _occupationController.text.trim().isEmpty
          ? null
          : _occupationController.text.trim(),
      nationality: _nationalityController.text.trim().isEmpty
          ? null
          : _nationalityController.text.trim(),
      maidenName: _maidenNameController.text.trim().isEmpty
          ? null
          : _maidenNameController.text.trim(),
      burialDate: _isLiving ? null : _burialDate,
      burialPlace: _isLiving
          ? null
          : (_burialPlaceController.text.trim().isEmpty
              ? null
              : _burialPlaceController.text.trim()),
      birthCoord: _birthCoord,
      deathCoord: _isLiving ? null : _deathCoord,
      burialCoord: _isLiving ? null : _burialCoord,
      birthPostalCode: _birthPostalCodeController.text.trim().isEmpty
          ? null
          : _birthPostalCodeController.text.trim(),
      deathPostalCode: _isLiving
          ? null
          : (_deathPostalCodeController.text.trim().isEmpty
              ? null
              : _deathPostalCodeController.text.trim()),
      burialPostalCode: _isLiving
          ? null
          : (_burialPostalCodeController.text.trim().isEmpty
              ? null
              : _burialPostalCodeController.text.trim()),
      isPrivate: _isPrivate,
      preferredSourceIds: widget.person?.preferredSourceIds ?? {},
      causeOfDeath: _isLiving
          ? null
          : (_causeOfDeathController.text.trim().isEmpty
              ? null
              : _causeOfDeathController.text.trim()),
      bloodType: _bloodType,
      eyeColour: _eyeColourController.text.trim().isEmpty
          ? null
          : _eyeColourController.text.trim(),
      hairColour: _hairColourController.text.trim().isEmpty
          ? null
          : _hairColourController.text.trim(),
      height: _heightController.text.trim().isEmpty
          ? null
          : _heightController.text.trim(),
      religion: _religionController.text.trim().isEmpty
          ? null
          : _religionController.text.trim(),
      education: _educationController.text.trim().isEmpty
          ? null
          : _educationController.text.trim(),
      aliases: _aliases,
      wikitreeId: _wikitreeId,
      findAGraveId: _findAGraveId,
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
      // Offer to set up family relationships right after creating a new person.
      if (mounted) {
        final displayName = person.name.length > 40
            ? '${person.name.substring(0, 40)}…'
            : person.name;
        final addRelationships = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog.adaptive(
            icon: const Icon(Icons.family_restroom),
            title: Text('Add relationships for $displayName?'),
            content: const Text(
              'Would you like to add parents, partners, or other family links now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add Now'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (addRelationships == true) {
          // Replace this screen with the relationships screen so Back goes to
          // wherever the user came from.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => RelationshipScreen(person: person),
            ),
          );
          return;
        }
      }
    } else {
      await provider.updatePerson(person);
    }
    if (mounted) Navigator.pop(context);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PlaceField — place name + postal code + map picker button + coord chip
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceField extends StatelessWidget {
  final TextEditingController controller;
  final TextEditingController postalCodeController;
  final String label;
  final GeoCoord? coord;
  final DateTime? eventDate;
  final ValueChanged<GeoCoord?> onCoordChanged;

  const _PlaceField({
    required this.controller,
    required this.postalCodeController,
    required this.label,
    required this.coord,
    required this.eventDate,
    required this.onCoordChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Place name text field ──────────────────────────────────────────
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: IconButton(
              icon: Icon(Icons.map_outlined, color: colorScheme.primary),
              tooltip: 'Pick on map',
              onPressed: () async {
                final result = await Navigator.push<GeoCoord?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MapPickerScreen(initialCoord: coord),
                  ),
                );
                // result == null means the user pressed back without confirming;
                // we only update if the screen returned something (even an
                // explicit clear returns null via the Clear button path handled
                // inside the screen — here result is simply absent so no-op).
                if (result != null) {
                  onCoordChanged(result);
                }
              },
            ),
          ),
          textCapitalization: TextCapitalization.words,
        ),

        // ── Postal / ZIP code field ────────────────────────────────────────
        const SizedBox(height: 8),
        TextFormField(
          controller: postalCodeController,
          decoration: InputDecoration(
            labelText: 'Postal / ZIP code',
            prefixIcon:
                Icon(Icons.local_post_office_outlined, size: 18,
                    color: colorScheme.onSurfaceVariant),
          ),
          keyboardType: TextInputType.text,
        ),

        // ── Coord info chip ────────────────────────────────────────────────
        if (coord != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              // Coordinate badge
              _InfoChip(
                icon: Icons.my_location,
                label: coord!.coordinateLabel,
                colorScheme: colorScheme,
              ),
              // Political boundaries badge
              if (coord!.politicalBoundaries.isNotEmpty)
                _InfoChip(
                  icon: Icons.account_balance_outlined,
                  label: coord!.politicalBoundaries,
                  colorScheme: colorScheme,
                ),
              // Clear coord button
              ActionChip(
                avatar: Icon(Icons.close, size: 14,
                    color: colorScheme.error),
                label: Text('Clear pin',
                    style: TextStyle(
                        fontSize: 11, color: colorScheme.error)),
                onPressed: () => onCoordChanged(null),
                side: BorderSide(color: colorScheme.error.withOpacity(0.3)),
                backgroundColor:
                    colorScheme.error.withOpacity(0.08),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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

// ── Relationships section (inline summary + quick manage) ─────────────────────

class _RelationshipsSection extends StatelessWidget {
  final Person person;
  const _RelationshipsSection({required this.person});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    final parents = person.parentIds
        .map((id) => provider.persons.where((p) => p.id == id).firstOrNull)
        .whereType<Person>()
        .toList();

    final partnerships = provider.partnershipsFor(person.id);
    final partners = partnerships
        .map((pt) {
          final otherId = pt.person1Id == person.id ? pt.person2Id : pt.person1Id;
          return provider.persons.where((p) => p.id == otherId).firstOrNull;
        })
        .whereType<Person>()
        .toList();

    final children = provider.persons
        .where((p) => p.parentIds.contains(person.id))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(Icons.family_restroom,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Family Relationships',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Manage'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RelationshipScreen(person: person),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Parents ──────────────────────────────────────────────────
            _RelRow(
              icon: Icons.arrow_upward,
              label: 'Parents',
              count: parents.length,
              names: parents.map((p) => p.name).toList(),
              emptyHint: 'No parents recorded',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 8),
            // ── Partners ─────────────────────────────────────────────────
            _RelRow(
              icon: Icons.favorite_outline,
              label: 'Partners',
              count: partners.length,
              names: partners.map((p) => p.name).toList(),
              emptyHint: 'No partners recorded',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 8),
            // ── Children ─────────────────────────────────────────────────
            _RelRow(
              icon: Icons.arrow_downward,
              label: 'Children',
              count: children.length,
              names: children.map((p) => p.name).toList(),
              emptyHint: 'No children recorded',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Manage Relationships'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RelationshipScreen(person: person),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final List<String> names;
  final String emptyHint;
  final ColorScheme colorScheme;

  const _RelRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.names,
    required this.emptyHint,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface),
                ),
                TextSpan(
                  text: count == 0
                      ? emptyHint
                      : names.join(', '),
                  style: TextStyle(
                    color: count == 0
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                    fontStyle:
                        count == 0 ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Quick link card ────────────────────────────────────────────────────────────

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(
                color: colorScheme.onSurfaceVariant, fontSize: 12)),
        trailing: Icon(Icons.chevron_right,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
        onTap: onTap,
      ),
    );
  }
}

// ── Life Events ────────────────────────────────────────────────────────────────

class _LifeEventsSection extends StatelessWidget {
  final String personId;
  const _LifeEventsSection({required this.personId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final events = provider.lifeEventsFor(personId);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Life Events',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Event'),
                  onPressed: () =>
                      _openEventSheet(context, provider, personId, null),
                ),
              ],
            ),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No life events recorded.',
                  style:
                      TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              ...events.map((event) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor:
                          colorScheme.tertiaryContainer,
                      child: Icon(Icons.event,
                          size: 18,
                          color: colorScheme.onTertiaryContainer),
                    ),
                    title: Text(event.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (event.date != null)
                          Text(DateFormat('d MMMM yyyy')
                              .format(event.date!)),
                        if (event.place != null &&
                            event.place!.isNotEmpty)
                          Text(event.place!,
                              style: TextStyle(
                                  color:
                                      colorScheme.onSurfaceVariant)),
                        if (event.notes != null &&
                            event.notes!.isNotEmpty)
                          Text(event.notes!,
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit',
                          onPressed: () => _openEventSheet(
                              context, provider, personId, event),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18,
                              color: colorScheme.error),
                          tooltip: 'Delete',
                          onPressed: () =>
                              provider.deleteLifeEvent(event.id),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  static void _openEventSheet(
    BuildContext context,
    TreeProvider provider,
    String personId,
    LifeEvent? existing,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _LifeEventSheet(
        personId: personId,
        existing: existing,
        provider: provider,
      ),
    );
  }
}

class _LifeEventSheet extends StatefulWidget {
  final String personId;
  final LifeEvent? existing;
  final TreeProvider provider;

  const _LifeEventSheet({
    required this.personId,
    required this.existing,
    required this.provider,
  });

  @override
  State<_LifeEventSheet> createState() => _LifeEventSheetState();
}

class _LifeEventSheetState extends State<_LifeEventSheet> {
  late TextEditingController _titleController;
  late TextEditingController _placeController;
  late TextEditingController _notesController;
  DateTime? _date;
  String? _selectedType;
  bool _useCustomTitle = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final isCommon = e != null && LifeEvent.commonTypes.contains(e.title);
    _selectedType = isCommon ? e.title : null;
    _useCustomTitle = e != null && !isCommon;
    _titleController = TextEditingController(
        text: _useCustomTitle ? (e?.title ?? '') : '');
    _placeController = TextEditingController(text: e?.place ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _date = e?.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _placeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _effectiveTitle =>
      _useCustomTitle ? _titleController.text.trim() : (_selectedType ?? '');

  Future<void> _save() async {
    if (_effectiveTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event title.')),
      );
      return;
    }
    final event = LifeEvent(
      id: widget.existing?.id ?? const Uuid().v4(),
      personId: widget.personId,
      title: _effectiveTitle,
      date: _date,
      place: _placeController.text.trim().isEmpty
          ? null
          : _placeController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    if (widget.existing == null) {
      await widget.provider.addLifeEvent(event);
    } else {
      await widget.provider.updateLifeEvent(event);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.existing == null ? 'Add Life Event' : 'Edit Life Event',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          if (!_useCustomTitle) ...[
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Event Type',
                border: OutlineInputBorder(),
              ),
              items: [
                ...LifeEvent.commonTypes.map((t) =>
                    DropdownMenuItem(value: t, child: Text(t))),
                const DropdownMenuItem(
                    value: '__custom__', child: Text('Custom…')),
              ],
              onChanged: (v) {
                if (v == '__custom__') {
                  setState(() => _useCustomTitle = true);
                } else {
                  setState(() => _selectedType = v);
                }
              },
            ),
          ] else ...[
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Custom Title',
                border: const OutlineInputBorder(),
                suffixIcon: TextButton(
                  child: const Text('Use list'),
                  onPressed: () => setState(() {
                    _useCustomTitle = false;
                    _titleController.clear();
                  }),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await pickDateAdaptive(
                context,
                initialDate: _date ?? DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border:
                    Border.all(color: colorScheme.outline.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 18, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _date != null
                          ? DateFormat('d MMMM yyyy').format(_date!)
                          : 'Tap to set date (optional)',
                      style: TextStyle(
                        color: _date != null
                            ? null
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_date != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _date = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _placeController,
            decoration: const InputDecoration(
              labelText: 'Place (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.save),
              label: Text(widget.existing == null ? 'Save Event' : 'Update Event'),
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExternalIdSection — WikiTree + Find A Grave IDs with search/link actions
// ─────────────────────────────────────────────────────────────────────────────

class _ExternalIdSection extends StatefulWidget {
  final String? wikitreeId;
  final String? findAGraveId;
  final String personName;
  final int? birthYear;
  final ValueChanged<String?> onWikiTreeIdChanged;
  final ValueChanged<String?> onFindAGraveIdChanged;

  const _ExternalIdSection({
    required this.wikitreeId,
    required this.findAGraveId,
    required this.personName,
    required this.birthYear,
    required this.onWikiTreeIdChanged,
    required this.onFindAGraveIdChanged,
  });

  @override
  State<_ExternalIdSection> createState() => _ExternalIdSectionState();
}

class _ExternalIdSectionState extends State<_ExternalIdSection> {
  late TextEditingController _wtCtrl;
  late TextEditingController _fagCtrl;
  bool _searching = false;
  List<WikiTreeProfile> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _wtCtrl = TextEditingController(text: widget.wikitreeId ?? '');
    _fagCtrl = TextEditingController(text: widget.findAGraveId ?? '');
  }

  @override
  void dispose() {
    _wtCtrl.dispose();
    _fagCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchWikiTree() async {
    if (widget.personName.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _searchResults = [];
    });
    final results = await WikiTreeService.instance.searchPerson(
      widget.personName,
      birthYear: widget.birthYear,
      limit: 5,
    );
    if (mounted) setState(() { _searching = false; _searchResults = results; });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── WikiTree ─────────────────────────────────────────────────────
        Row(children: [
          Icon(Icons.account_tree_outlined, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text('WikiTree', style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _wtCtrl,
              decoration: const InputDecoration(
                labelText: 'WikiTree ID (e.g. Churchill-4)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => widget.onWikiTreeIdChanged(v.trim().isEmpty ? null : v.trim()),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.wikitreeId != null && widget.wikitreeId!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 20),
              tooltip: 'Open WikiTree profile',
              onPressed: () => launchUrl(
                Uri.parse('https://www.wikitree.com/wiki/${widget.wikitreeId}'),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          if (_searching)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
          else
            TextButton.icon(
              onPressed: _searchWikiTree,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Search WikiTree for this person'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WikiTreeScreen())),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Open WikiTree Hub →'),
          ),
        ]),
        ..._searchResults.map((p) => _WikiTreeResultChip(
          profile: p,
          onSelect: (id) {
            widget.onWikiTreeIdChanged(id);
            setState(() { _wtCtrl.text = id; _searchResults = []; });
          },
        )),
        const SizedBox(height: 12),
        // ── Find A Grave ─────────────────────────────────────────────────
        Row(children: [
          Icon(Icons.location_on_outlined, size: 16, color: colorScheme.secondary),
          const SizedBox(width: 6),
          Text('Find A Grave', style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _fagCtrl,
              decoration: const InputDecoration(
                labelText: 'Memorial ID (e.g. 1836)',
                hintText: 'Paste URL or memorial ID',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.url,
              onChanged: (v) {
                final extracted = FindAGraveService.instance.extractIdFromUrl(v) ??
                    (RegExp(r'^\d+$').hasMatch(v.trim()) ? v.trim() : null);
                widget.onFindAGraveIdChanged(extracted);
                if (extracted != null && extracted != v.trim()) {
                  _fagCtrl.text = extracted;
                  _fagCtrl.selection = TextSelection.fromPosition(TextPosition(offset: extracted.length));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          if (widget.findAGraveId != null && widget.findAGraveId!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 20),
              tooltip: 'Open Find A Grave memorial',
              onPressed: () => launchUrl(
                Uri.parse(FindAGraveService.instance.memorialUrl(widget.findAGraveId!)),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ]),
      ],
    );
  }
}

class _WikiTreeResultChip extends StatelessWidget {
  final WikiTreeProfile profile;
  final void Function(String wikiTreeId) onSelect;
  const _WikiTreeResultChip({required this.profile, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sub = [
      if (profile.birthDate != null) 'b. ${profile.birthDate!.year}',
      if (profile.birthPlace != null) profile.birthPlace!,
      profile.wikiTreeId,
    ].join(' · ');
    return InkWell(
      onTap: () => onSelect(profile.wikiTreeId),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.primaryContainer, width: 1),
        ),
        child: Row(children: [
          Icon(Icons.account_tree_outlined, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profile.displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(sub, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
          ])),
          Icon(Icons.check_circle_outline, size: 16, color: colorScheme.primary),
        ]),
      ),
    );
  }
}
