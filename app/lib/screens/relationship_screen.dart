import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/partnership.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../utils/platform_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class RelationshipScreen extends StatefulWidget {
  final Person person;
  const RelationshipScreen({super.key, required this.person});

  @override
  State<RelationshipScreen> createState() => _RelationshipScreenState();
}

class _RelationshipScreenState extends State<RelationshipScreen> {
  /// Local copies of parent entries — edited in place; saved via the Save btn.
  late List<_ParentEntry> _parents;

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    _parents = p.parentIds
        .map((id) => _ParentEntry(
              parentId: id,
              relType: p.parentRelType(id),
            ))
        .toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final myPartnerships = provider.partnershipsFor(widget.person.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relationships'),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.save, color: colorScheme.onPrimary),
            label: Text('Save',
                style: TextStyle(color: colorScheme.onPrimary)),
            onPressed: _saveParents,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Parents ──────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.family_restroom,
            title: 'Parents',
            trailing: IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: 'Add parent',
              onPressed: _addParent,
            ),
            children: [
              if (_parents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No parents recorded.',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ),
              ..._parents.map((entry) => _ParentRow(
                    key: ObjectKey(entry),
                    entry: entry,
                    allPersons: provider.persons,
                    currentPersonId: widget.person.id,
                    onChanged: () => setState(() {}),
                    onRemove: () => setState(() => _parents.remove(entry)),
                  )),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Parent'),
                onPressed: _addParent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Partners & Unions ─────────────────────────────────────────────
          _SectionCard(
            icon: Icons.favorite,
            title: 'Partners & Unions',
            children: [
              if (myPartnerships.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No partnerships recorded.',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ),
              ...myPartnerships.map((pt) => _PartnershipTile(
                    key: ValueKey(pt.id),
                    partnership: pt,
                    currentPersonId: widget.person.id,
                    provider: provider,
                    onEdit: () => _editPartnership(context, pt, provider),
                    onDelete: () =>
                        _confirmDeletePartnership(context, pt, provider),
                  )),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Partner'),
                onPressed: () => _addPartnership(context, provider),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save Parent Links'),
            onPressed: _saveParents,
          ),
          const SizedBox(height: 8),
          Text(
            'Partnership changes are saved immediately.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Parent helpers ────────────────────────────────────────────────────────

  void _addParent() {
    setState(() => _parents.add(_ParentEntry(relType: 'biological')));
  }

  Future<void> _saveParents() async {
    final provider = context.read<TreeProvider>();
    final p = widget.person;

    final validParents =
        _parents.where((e) => e.parentId != null).toList();
    final newParentIds = validParents.map((e) => e.parentId!).toList();
    final newRelTypes = {
      for (final e in validParents) e.parentId!: e.relType
    };

    // Remove this person from old parents no longer in the list
    for (final oldId in p.parentIds) {
      if (!newParentIds.contains(oldId)) {
        final old =
            provider.persons.where((x) => x.id == oldId).firstOrNull;
        if (old != null) {
          old.childIds.remove(p.id);
          await provider.updatePerson(old);
        }
      }
    }

    // Add this person to newly-selected parents' childIds
    for (final newId in newParentIds) {
      if (!p.parentIds.contains(newId)) {
        final newParent =
            provider.persons.where((x) => x.id == newId).firstOrNull;
        if (newParent != null && !newParent.childIds.contains(p.id)) {
          newParent.childIds.add(p.id);
          await provider.updatePerson(newParent);
        }
      }
    }

    // Mutate the person in place — avoids dropping new fields that weren't
    // present in the original Person constructor call here.
    p.parentIds = newParentIds;
    p.parentRelTypes = newRelTypes;
    await provider.updatePerson(p);

    if (mounted) Navigator.pop(context);
  }

  // ── Partnership helpers ───────────────────────────────────────────────────

  Future<void> _addPartnership(
      BuildContext context, TreeProvider provider) async {
    final result = await showModalBottomSheet<Partnership>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PartnershipSheet(
        currentPersonId: widget.person.id,
        provider: provider,
      ),
    );
    if (result != null) {
      await provider.addPartnership(result);
    }
  }

  Future<void> _editPartnership(
      BuildContext context, Partnership pt, TreeProvider provider) async {
    final result = await showModalBottomSheet<Partnership>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PartnershipSheet(
        currentPersonId: widget.person.id,
        provider: provider,
        existing: pt,
      ),
    );
    if (result != null) {
      await provider.updatePartnership(result);
    }
  }

  Future<void> _confirmDeletePartnership(
      BuildContext context, Partnership pt, TreeProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Partnership'),
        content: const Text(
            'Remove this union record? Parent–child links are not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deletePartnership(pt.id);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ParentEntry — mutable local model for a single parent row
// ─────────────────────────────────────────────────────────────────────────────

class _ParentEntry {
  String? parentId;
  String relType;
  _ParentEntry({this.parentId, required this.relType});
}

// ─────────────────────────────────────────────────────────────────────────────
// _ParentRow widget
// ─────────────────────────────────────────────────────────────────────────────

class _ParentRow extends StatelessWidget {
  final _ParentEntry entry;
  final List<Person> allPersons;
  final String currentPersonId;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ParentRow({
    super.key,
    required this.entry,
    required this.allPersons,
    required this.currentPersonId,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final others = allPersons
        .where((p) => p.id != currentPersonId)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Person picker
          Expanded(
            flex: 5,
            child: DropdownButtonFormField<String?>(
              value: entry.parentId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Parent',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('— Select —')),
                ...others.map((p) => DropdownMenuItem<String?>(
                    value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) {
                entry.parentId = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Relationship type picker
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<String>(
              value: entry.relType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Type',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: Person.allParentRelTypes
                  .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(Person.relTypeLabel(t))))
                  .toList(),
              onChanged: (v) {
                if (v != null) entry.relType = v;
                onChanged();
              },
            ),
          ),
          // Remove button
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove parent',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PartnershipTile — shows a single partnership in the list
// ─────────────────────────────────────────────────────────────────────────────

class _PartnershipTile extends StatelessWidget {
  final Partnership partnership;
  final String currentPersonId;
  final TreeProvider provider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PartnershipTile({
    super.key,
    required this.partnership,
    required this.currentPersonId,
    required this.provider,
    required this.onEdit,
    required this.onDelete,
  });

  String _partnersName() {
    final otherId = partnership.person1Id == currentPersonId
        ? partnership.person2Id
        : partnership.person1Id;
    return provider.persons
            .where((p) => p.id == otherId)
            .firstOrNull
            ?.name ??
        'Unknown';
  }

  static String _childrenLabel(int count) =>
      '$count ${count == 1 ? 'child' : 'children'} together';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final df = DateFormat('d MMM yyyy');
    final children = provider.childrenOfPartnership(partnership);

    Color statusColor;
    switch (partnership.status) {
      case 'divorced':
      case 'separated':
      case 'annulled':
        statusColor = colorScheme.outline;
        break;
      default:
        statusColor = colorScheme.primary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Text(
                    _partnersName().isNotEmpty
                        ? _partnersName()[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_partnersName(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          _StatusChip(
                              label: partnership.statusLabel,
                              color: statusColor),
                          if (partnership.startDate != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              df.format(partnership.startDate!),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                          if (partnership.endDate != null) ...[
                            Text(' – ',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant)),
                            Text(
                              df.format(partnership.endDate!),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(Icons.link_off,
                      size: 18, color: colorScheme.error),
                  tooltip: 'Remove',
                  onPressed: onDelete,
                ),
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Text(
                  '${_childrenLabel(children.length)}: '
                  '${children.map((c) => c.name).join(', ')}',
                  style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PartnershipSheet — bottom sheet to add or edit a partnership
// ─────────────────────────────────────────────────────────────────────────────

class _PartnershipSheet extends StatefulWidget {
  final String currentPersonId;
  final TreeProvider provider;
  final Partnership? existing;

  const _PartnershipSheet({
    required this.currentPersonId,
    required this.provider,
    this.existing,
  });

  @override
  State<_PartnershipSheet> createState() => _PartnershipSheetState();
}

class _PartnershipSheetState extends State<_PartnershipSheet> {
  String? _partnerId;
  String _status = 'married';
  DateTime? _startDate;
  DateTime? _endDate;
  late TextEditingController _startPlaceCtrl;
  late TextEditingController _endPlaceCtrl;
  String? _ceremonyType;
  late TextEditingController _witnessesCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final pt = widget.existing;
    if (pt != null) {
      final otherId = pt.person1Id == widget.currentPersonId
          ? pt.person2Id
          : pt.person1Id;
      _partnerId = otherId;
      _status = pt.status;
      _startDate = pt.startDate;
      _endDate = pt.endDate;
      _startPlaceCtrl =
          TextEditingController(text: pt.startPlace ?? '');
      _endPlaceCtrl =
          TextEditingController(text: pt.endPlace ?? '');
      _ceremonyType = pt.ceremonyType;
      _witnessesCtrl = TextEditingController(text: pt.witnesses ?? '');
      _notesCtrl = TextEditingController(text: pt.notes ?? '');
    } else {
      _startPlaceCtrl = TextEditingController();
      _endPlaceCtrl = TextEditingController();
      _witnessesCtrl = TextEditingController();
      _notesCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _startPlaceCtrl.dispose();
    _endPlaceCtrl.dispose();
    _witnessesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existing != null;
  bool get _showEndFields =>
      _status == 'divorced' ||
      _status == 'separated' ||
      _status == 'annulled' ||
      _endDate != null;

  @override
  Widget build(BuildContext context) {
    final others = widget.provider.persons
        .where((p) => p.id != widget.currentPersonId)
        .toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Text(
                  _isEditing ? 'Edit Partnership' : 'Add Partnership',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 4),

            // Partner picker (disabled when editing)
            DropdownButtonFormField<String?>(
              value: _partnerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Partner'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('— Select partner —')),
                ...others.map((p) =>
                    DropdownMenuItem<String?>(value: p.id, child: Text(p.name))),
              ],
              onChanged: _isEditing
                  ? null
                  : (v) => setState(() => _partnerId = v),
            ),
            const SizedBox(height: 12),

            // Status
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: Partnership.allStatuses
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(_statusLabel(s))))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? 'married'),
            ),
            const SizedBox(height: 12),

            // Start date & place
            _DatePickerTile(
              label: 'Start Date (marriage / union)',
              date: _startDate,
              onPick: () => _pickDate(context, isStart: true),
              onClear:
                  _startDate != null ? () => setState(() => _startDate = null) : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _startPlaceCtrl,
              decoration:
                  const InputDecoration(labelText: 'Start Place (optional)'),
              textCapitalization: TextCapitalization.words,
            ),

            // End date & place — shown for ended statuses or if endDate set
            if (_showEndFields) ...[
              const SizedBox(height: 12),
              _DatePickerTile(
                label: 'End Date (divorce / separation)',
                date: _endDate,
                onPick: () => _pickDate(context, isStart: false),
                onClear:
                    _endDate != null ? () => setState(() => _endDate = null) : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _endPlaceCtrl,
                decoration: const InputDecoration(
                    labelText: 'End Place (optional)'),
                textCapitalization: TextCapitalization.words,
              ),
            ],

            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _ceremonyType,
              decoration:
                  const InputDecoration(labelText: 'Ceremony Type (optional)'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Not specified')),
                ...Partnership.allCeremonyTypes.map((t) =>
                    DropdownMenuItem<String?>(
                        value: t, child: Text(_ceremonyTypeLabel(t)))),
              ],
              onChanged: (v) => setState(() => _ceremonyType = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _witnessesCtrl,
              decoration: const InputDecoration(
                  labelText: 'Witnesses / Officiant (optional)'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              minLines: 2,
              maxLines: 4,
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: Text(_isEditing ? 'Save Changes' : 'Add Partnership'),
                onPressed: _partnerId == null ? null : _submit,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'married':
        return 'Married';
      case 'partnered':
        return 'Partnered';
      case 'divorced':
        return 'Divorced';
      case 'separated':
        return 'Separated';
      case 'annulled':
        return 'Annulled';
      default:
        return 'Other';
    }
  }

  Future<void> _pickDate(BuildContext context,
      {required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final picked = await pickDateAdaptive(
      context,
      initialDate: current ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _submit() {
    if (_partnerId == null) return;
    final sp = _startPlaceCtrl.text.trim();
    final ep = _endPlaceCtrl.text.trim();
    final witnesses = _witnessesCtrl.text.trim();
    final notes = _notesCtrl.text.trim();
    final result = Partnership(
      id: widget.existing?.id ?? '',
      person1Id: widget.currentPersonId,
      person2Id: _partnerId!,
      status: _status,
      startDate: _startDate,
      startPlace: sp.isEmpty ? null : sp,
      endDate: _showEndFields ? _endDate : null,
      endPlace: (_showEndFields && ep.isNotEmpty) ? ep : null,
      ceremonyType: _ceremonyType,
      witnesses: witnesses.isEmpty ? null : witnesses,
      notes: notes.isEmpty ? null : notes,
      sourceIds: widget.existing?.sourceIds ?? [],
    );
    Navigator.pop(context, result);
  }

  String _ceremonyTypeLabel(String t) {
    switch (t) {
      case 'civil':
        return 'Civil';
      case 'religious':
        return 'Religious';
      case 'traditional':
        return 'Traditional';
      case 'common-law':
        return 'Common-law';
      default:
        return 'Other';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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
          border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
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

