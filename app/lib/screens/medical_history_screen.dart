import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/medical_condition.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';

/// Shows all medical conditions recorded for every person in the current tree,
/// grouped by category, with the ability to drill into a per-person view.
class MedicalHistoryScreen extends StatefulWidget {
  /// When [person] is provided the screen opens in per-person mode and shows
  /// only that person's conditions.
  final Person? person;

  const MedicalHistoryScreen({super.key, this.person});

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.person == null ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final title = widget.person != null
        ? '${widget.person!.name} — Medical History'
        : 'Family Medical History';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: widget.person == null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'By Person'),
                  Tab(text: 'By Category'),
                ],
              )
            : null,
      ),
      body: widget.person != null
          ? _PersonConditionsList(
              provider: provider,
              personId: widget.person!.id,
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _AllPersonsList(provider: provider),
                _ByCategoryList(provider: provider),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Condition'),
        onPressed: () => _openConditionSheet(
          context,
          provider,
          widget.person?.id,
          null,
        ),
      ),
    );
  }

  static void _openConditionSheet(
    BuildContext context,
    TreeProvider provider,
    String? preselectedPersonId,
    MedicalCondition? existing,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ConditionSheet(
        provider: provider,
        preselectedPersonId: preselectedPersonId,
        existing: existing,
      ),
    );
  }
}

// ── By-person list ──────────────────────────────────────────────────────────

class _AllPersonsList extends StatelessWidget {
  final TreeProvider provider;
  const _AllPersonsList({required this.provider});

  @override
  Widget build(BuildContext context) {
    final persons = provider.persons
        .where((p) => provider.medicalConditionsFor(p.id).isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (persons.isEmpty) {
      return const _EmptyState(
          message:
              'No medical conditions recorded yet.\nTap + to add the first one.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: persons.length,
      itemBuilder: (context, i) {
        final person = persons[i];
        final conditions = provider.medicalConditionsFor(person.id);
        return _PersonTile(
          person: person,
          conditions: conditions,
          provider: provider,
        );
      },
    );
  }
}

// ── By-category list ────────────────────────────────────────────────────────

class _ByCategoryList extends StatelessWidget {
  final TreeProvider provider;
  const _ByCategoryList({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.medicalConditions.isEmpty) {
      return const _EmptyState(
          message:
              'No medical conditions recorded yet.\nTap + to add the first one.');
    }

    final byCategory = <String, List<MedicalCondition>>{};
    for (final mc in provider.medicalConditions) {
      (byCategory[mc.category] ??= []).add(mc);
    }
    final categories = byCategory.keys.toList()..sort();
    final personMap = {for (final p in provider.persons) p.id: p};
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final category = categories[i];
        final items = byCategory[category]!;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ExpansionTile(
            leading: Icon(
              _categoryIcon(category),
              color: colorScheme.primary,
            ),
            title: Text(
              category,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${items.length} condition${items.length == 1 ? '' : 's'}',
            ),
            children: items.map((mc) {
              final person = personMap[mc.personId];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 0),
                title: Text(mc.condition),
                subtitle: Text(person?.name ?? mc.personId),
                trailing: _conditionTrailing(context, mc, provider),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ── Per-person conditions list ───────────────────────────────────────────────

class _PersonConditionsList extends StatelessWidget {
  final TreeProvider provider;
  final String personId;
  const _PersonConditionsList(
      {required this.provider, required this.personId});

  @override
  Widget build(BuildContext context) {
    final conditions = provider.medicalConditionsFor(personId);
    if (conditions.isEmpty) {
      return const _EmptyState(
          message:
              'No medical conditions recorded for this person.\nTap + to add one.');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: conditions
          .map((mc) => _ConditionCard(condition: mc, provider: provider))
          .toList(),
    );
  }
}

// ── Person tile (expands to conditions) ─────────────────────────────────────

class _PersonTile extends StatelessWidget {
  final Person person;
  final List<MedicalCondition> conditions;
  final TreeProvider provider;

  const _PersonTile({
    required this.person,
    required this.conditions,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Text(
            person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
          ),
        ),
        title: Text(
          person.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${conditions.length} condition${conditions.length == 1 ? '' : 's'}',
        ),
        children: conditions
            .map((mc) => _ConditionCard(condition: mc, provider: provider))
            .toList(),
      ),
    );
  }
}

// ── Condition card ───────────────────────────────────────────────────────────

class _ConditionCard extends StatelessWidget {
  final MedicalCondition condition;
  final TreeProvider provider;

  const _ConditionCard(
      {required this.condition, required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: ListTile(
          leading: Icon(
            _categoryIcon(condition.category),
            color: colorScheme.primary,
          ),
          title: Text(condition.condition,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(condition.category,
                  style: TextStyle(
                      color: colorScheme.primary, fontSize: 12)),
              if (condition.ageOfOnset != null &&
                  condition.ageOfOnset!.isNotEmpty)
                Text('Age of onset: ${condition.ageOfOnset}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
              if (condition.notes != null && condition.notes!.isNotEmpty)
                Text(condition.notes!,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
          trailing: _conditionTrailing(context, condition, provider),
          isThreeLine: true,
        ),
      ),
    );
  }
}

Widget _conditionTrailing(
    BuildContext context, MedicalCondition mc, TreeProvider provider) {
  final colorScheme = Theme.of(context).colorScheme;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18),
        tooltip: 'Edit',
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _ConditionSheet(
            provider: provider,
            preselectedPersonId: mc.personId,
            existing: mc,
          ),
        ),
      ),
      IconButton(
        icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
        tooltip: 'Delete',
        onPressed: () => provider.deleteMedicalCondition(mc.id),
      ),
    ],
  );
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_hospital_outlined,
                  size: 40, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit sheet ─────────────────────────────────────────────────────────

class _ConditionSheet extends StatefulWidget {
  final TreeProvider provider;
  final String? preselectedPersonId;
  final MedicalCondition? existing;

  const _ConditionSheet({
    required this.provider,
    required this.preselectedPersonId,
    required this.existing,
  });

  @override
  State<_ConditionSheet> createState() => _ConditionSheetState();
}

class _ConditionSheetState extends State<_ConditionSheet> {
  late TextEditingController _conditionController;
  late TextEditingController _ageController;
  late TextEditingController _notesController;
  String? _selectedPersonId;
  String _selectedCategory = MedicalCondition.categories.first;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _conditionController = TextEditingController(text: e?.condition ?? '');
    _ageController = TextEditingController(text: e?.ageOfOnset ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _selectedPersonId = e?.personId ?? widget.preselectedPersonId;
    _selectedCategory = e?.category ?? MedicalCondition.categories.first;
  }

  @override
  void dispose() {
    _conditionController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_conditionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a condition name.')),
      );
      return;
    }
    if (_selectedPersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a person.')),
      );
      return;
    }
    final mc = MedicalCondition(
      id: widget.existing?.id ?? const Uuid().v4(),
      personId: _selectedPersonId!,
      condition: _conditionController.text.trim(),
      category: _selectedCategory,
      ageOfOnset: _ageController.text.trim().isEmpty
          ? null
          : _ageController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    if (widget.existing == null) {
      await widget.provider.addMedicalCondition(mc);
    } else {
      await widget.provider.updateMedicalCondition(mc);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final persons = widget.provider.persons..sort((a, b) => a.name.compareTo(b.name));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.existing == null
                      ? 'Add Medical Condition'
                      : 'Edit Medical Condition',
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
            if (widget.preselectedPersonId == null)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Person',
                  border: OutlineInputBorder(),
                ),
                value: _selectedPersonId,
                items: persons
                    .map((p) =>
                        DropdownMenuItem(value: p.id, child: Text(p.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPersonId = v),
              )
            else
              Text(
                'Person: ${widget.provider.persons.firstWhere((p) => p.id == widget.preselectedPersonId, orElse: () => Person(id: '', name: 'Unknown')).name}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _conditionController,
              decoration: const InputDecoration(
                labelText: 'Condition',
                hintText: 'e.g. Type 2 Diabetes, Hypertension…',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              value: _selectedCategory,
              items: MedicalCondition.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedCategory = v ?? _selectedCategory),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Age of onset (optional)',
                hintText: 'e.g. 45, childhood, unknown',
                border: OutlineInputBorder(),
              ),
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
                label: const Text('Save'),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

IconData _categoryIcon(String category) => switch (category) {
      'Cardiovascular' => Icons.favorite_border,
      'Cancer' => Icons.coronavirus_outlined,
      'Mental Health' => Icons.psychology_outlined,
      'Neurological' => Icons.biotech_outlined,
      'Metabolic / Endocrine' => Icons.science_outlined,
      'Autoimmune' => Icons.shield_outlined,
      'Respiratory' => Icons.air_outlined,
      'Genetic' => Icons.account_tree_outlined,
      'Musculoskeletal' => Icons.accessibility_new_outlined,
      _ => Icons.local_hospital_outlined,
    };
