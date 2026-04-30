// app/lib/widgets/person_action_sheet.dart
//
// Shared bottom-sheet for person actions across all tree views.
//
// Shows the person's summary, navigation to full profile / relationships,
// and quick-add buttons for adding relatives — all with existing-person
// search so the user can link someone already in the tree instead of
// creating a duplicate.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/partnership.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../utils/page_routes.dart';
import '../screens/person_detail_screen.dart';
import '../screens/relationship_screen.dart';
import 'quick_add_person_dialog.dart';

/// Shows a modal bottom sheet with actions for [person].
///
/// Provides:
///  * Full Profile navigation
///  * Manage Relationships navigation
///  * Quick-add buttons (Mom, Dad, Sibling, Partner, Son, Daughter) that
///    search the existing tree before creating a new person.
///
/// Call from any tree view's person-tap handler.
Future<void> showPersonActionSheet(
  BuildContext context, {
  required Person person,
}) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _PersonActionSheet(person: person),
  );
}

class _PersonActionSheet extends StatelessWidget {
  final Person person;
  const _PersonActionSheet({required this.person});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.read<TreeProvider>();

    Color avatarBg = colorScheme.secondary;
    if (person.gender?.toLowerCase() == 'male') {
      avatarBg = colorScheme.primary;
    }
    if (person.gender?.toLowerCase() == 'female') {
      avatarBg = colorScheme.error;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Person header
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: avatarBg,
                child: Text(
                  person.name.isNotEmpty
                      ? person.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (person.birthDate != null || person.deathDate != null)
                      Text(
                        [
                          if (person.birthDate != null)
                            'b. ${person.birthDate!.year}',
                          if (person.deathDate != null)
                            'd. ${person.deathDate!.year}',
                        ].join('  ·  '),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (person.birthPlace != null)
                      Text(
                        person.birthPlace!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Primary actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Full Profile'),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      fadeSlideRoute(
                        builder: (_) => PersonDetailScreen(person: person),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.link),
                  label: const Text('Relationships'),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      fadeSlideRoute(
                        builder: (_) => RelationshipScreen(person: person),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          // Quick-add section
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Quick Add Relative',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickAddChip(
                icon: Icons.woman,
                label: 'Mom',
                onPressed: () => _quickAdd(
                  context,
                  provider: provider,
                  relation: _Relation.mom,
                ),
              ),
              _QuickAddChip(
                icon: Icons.man,
                label: 'Dad',
                onPressed: () => _quickAdd(
                  context,
                  provider: provider,
                  relation: _Relation.dad,
                ),
              ),
              _QuickAddChip(
                icon: Icons.people_alt_outlined,
                label: 'Sibling',
                onPressed: () => _quickAdd(
                  context,
                  provider: provider,
                  relation: _Relation.sibling,
                ),
              ),
              _QuickAddChip(
                icon: Icons.favorite_outline,
                label: 'Partner',
                onPressed: () => _quickAdd(
                  context,
                  provider: provider,
                  relation: _Relation.partner,
                ),
              ),
              _QuickAddChip(
                icon: Icons.male,
                label: 'Son',
                onPressed: () => _quickAdd(
                  context,
                  provider: provider,
                  relation: _Relation.son,
                ),
              ),
              _QuickAddChip(
                icon: Icons.female,
                label: 'Daughter',
                onPressed: () => _quickAdd(
                  context,
                  provider: provider,
                  relation: _Relation.daughter,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _quickAdd(
    BuildContext context, {
    required TreeProvider provider,
    required _Relation relation,
  }) async {
    final current =
        provider.persons.where((p) => p.id == person.id).firstOrNull;
    if (current == null) return;

    if (relation == _Relation.sibling && current.parentIds.isEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a parent first, then add siblings')),
      );
      return;
    }

    // Build candidate list excluding the current person and people already
    // in the target role.
    final excludeIds = <String>{current.id};
    switch (relation) {
      case _Relation.mom:
      case _Relation.dad:
        excludeIds.addAll(current.parentIds);
      case _Relation.partner:
        for (final p in provider.partnerships) {
          if (p.person1Id == current.id) excludeIds.add(p.person2Id);
          if (p.person2Id == current.id) excludeIds.add(p.person1Id);
        }
      case _Relation.sibling:
        for (final parentId in current.parentIds) {
          final parent =
              provider.persons.where((p) => p.id == parentId).firstOrNull;
          if (parent != null) excludeIds.addAll(parent.childIds);
        }
      case _Relation.son:
      case _Relation.daughter:
        excludeIds.addAll(current.childIds);
    }
    final existingCandidates =
        provider.persons.where((p) => !excludeIds.contains(p.id)).toList();

    final input = await showQuickAddPersonDialog(
      context,
      title: relation.dialogTitle,
      subtitle: '${relation.subtitle} ${current.name}.',
      confirmLabel: relation.dialogTitle,
      initialGender: relation.defaultGender,
      existingPersons: existingCandidates,
    );
    if (input == null) return;

    // Close the action sheet before mutating state.
    if (context.mounted) Navigator.pop(context);

    try {
      if (input.isExisting) {
        await _linkExisting(
          provider: provider,
          anchor: current,
          existingId: input.existingPersonId!,
          relation: relation,
        );
      } else {
        await _createAndLink(
          provider: provider,
          anchor: current,
          input: input,
          relation: relation,
        );
      }
    } on StateError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Returns the ID of the first partner of [personId], or null if none.
  static String? _findPartner(TreeProvider provider, String personId) {
    for (final pt in provider.partnerships) {
      if (pt.person1Id == personId) return pt.person2Id;
      if (pt.person2Id == personId) return pt.person1Id;
    }
    return null;
  }

  Future<void> _linkExisting({
    required TreeProvider provider,
    required Person anchor,
    required String existingId,
    required _Relation relation,
  }) async {
    final existing =
        provider.persons.where((p) => p.id == existingId).firstOrNull;
    if (existing == null) return;

    switch (relation) {
      case _Relation.mom:
      case _Relation.dad:
        if (!anchor.parentIds.contains(existingId)) {
          anchor.parentIds.add(existingId);
          anchor.parentRelTypes[existingId] = 'biological';
          await provider.updatePerson(anchor);
        }
        if (!existing.childIds.contains(anchor.id)) {
          existing.childIds.add(anchor.id);
          await provider.updatePerson(existing);
        }

      case _Relation.partner:
        final alreadyPartners = provider.partnerships.any(
          (p) =>
              (p.person1Id == anchor.id && p.person2Id == existingId) ||
              (p.person1Id == existingId && p.person2Id == anchor.id),
        );
        if (!alreadyPartners) {
          await provider.addPartnership(
            Partnership(
              id: '',
              person1Id: anchor.id,
              person2Id: existingId,
            ),
          );
        }

      case _Relation.sibling:
        for (final parentId in anchor.parentIds) {
          if (!existing.parentIds.contains(parentId)) {
            existing.parentIds.add(parentId);
            existing.parentRelTypes[parentId] =
                anchor.parentRelType(parentId);
          }
          final parent = provider.persons
              .where((p) => p.id == parentId)
              .firstOrNull;
          if (parent != null && !parent.childIds.contains(existingId)) {
            parent.childIds.add(existingId);
            await provider.updatePerson(parent);
          }
        }
        await provider.updatePerson(existing);

      case _Relation.son:
      case _Relation.daughter:
        if (!existing.parentIds.contains(anchor.id)) {
          existing.parentIds.add(anchor.id);
          existing.parentRelTypes[anchor.id] = 'biological';
        }
        // Also link to the anchor's partner so the child appears under the
        // couple knot in the tree diagram.
        final partnerIdLink = _findPartner(provider, anchor.id);
        if (partnerIdLink != null &&
            !existing.parentIds.contains(partnerIdLink)) {
          existing.parentIds.add(partnerIdLink);
          existing.parentRelTypes[partnerIdLink] = 'biological';
        }
        await provider.updatePerson(existing);
        if (!anchor.childIds.contains(existingId)) {
          anchor.childIds.add(existingId);
          await provider.updatePerson(anchor);
        }
        if (partnerIdLink != null) {
          final partner = provider.persons
              .where((p) => p.id == partnerIdLink)
              .firstOrNull;
          if (partner != null && !partner.childIds.contains(existingId)) {
            partner.childIds.add(existingId);
            await provider.updatePerson(partner);
          }
        }
    }
  }

  Future<void> _createAndLink({
    required TreeProvider provider,
    required Person anchor,
    required QuickAddPersonInput input,
    required _Relation relation,
  }) async {
    switch (relation) {
      case _Relation.mom:
      case _Relation.dad:
        final parent = Person(
          id: '',
          name: input.name,
          gender: input.gender ?? relation.defaultGender,
          childIds: [anchor.id],
        );
        await provider.addPerson(parent);
        if (!anchor.parentIds.contains(parent.id)) {
          anchor.parentIds.add(parent.id);
          anchor.parentRelTypes[parent.id] = 'biological';
          await provider.updatePerson(anchor);
        }

      case _Relation.partner:
        final partner = Person(
          id: '',
          name: input.name,
          gender: input.gender,
        );
        await provider.addPerson(partner);
        await provider.addPartnership(
          Partnership(
            id: '',
            person1Id: anchor.id,
            person2Id: partner.id,
          ),
        );

      case _Relation.sibling:
        final sibling = Person(
          id: '',
          name: input.name,
          gender: input.gender,
          parentIds: List<String>.from(anchor.parentIds),
          parentRelTypes: {
            for (final parentId in anchor.parentIds)
              parentId: anchor.parentRelType(parentId),
          },
        );
        await provider.addPerson(sibling);
        for (final parentId in anchor.parentIds) {
          final parent = provider.persons
              .where((p) => p.id == parentId)
              .firstOrNull;
          if (parent == null || parent.childIds.contains(sibling.id)) continue;
          parent.childIds.add(sibling.id);
          await provider.updatePerson(parent);
        }

      case _Relation.son:
      case _Relation.daughter:
        // Find the anchor's partner so the child is linked to both parents.
        final partnerIdCreate = _findPartner(provider, anchor.id);
        final childParentIds = [anchor.id, ?partnerIdCreate];
        final child = Person(
          id: '',
          name: input.name,
          gender: input.gender ?? relation.defaultGender,
          parentIds: childParentIds,
          parentRelTypes: {for (final pid in childParentIds) pid: 'biological'},
        );
        await provider.addPerson(child);
        if (!anchor.childIds.contains(child.id)) {
          anchor.childIds.add(child.id);
          await provider.updatePerson(anchor);
        }
        if (partnerIdCreate != null) {
          final partner = provider.persons
              .where((p) => p.id == partnerIdCreate)
              .firstOrNull;
          if (partner != null && !partner.childIds.contains(child.id)) {
            partner.childIds.add(child.id);
            await provider.updatePerson(partner);
          }
        }
    }
  }
}

class _QuickAddChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _QuickAddChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: colorScheme.surfaceContainerHighest,
    );
  }
}

enum _Relation {
  mom,
  dad,
  sibling,
  partner,
  son,
  daughter;

  String get dialogTitle {
    switch (this) {
      case _Relation.mom:
        return 'Add Mom';
      case _Relation.dad:
        return 'Add Dad';
      case _Relation.sibling:
        return 'Add Sibling';
      case _Relation.partner:
        return 'Add Partner';
      case _Relation.son:
        return 'Add Son';
      case _Relation.daughter:
        return 'Add Daughter';
    }
  }

  String get subtitle {
    switch (this) {
      case _Relation.mom:
      case _Relation.dad:
        return 'Create or pick an existing parent for';
      case _Relation.sibling:
        return 'Create or pick an existing sibling for';
      case _Relation.partner:
        return 'Create or pick an existing partner for';
      case _Relation.son:
      case _Relation.daughter:
        return 'Create or pick an existing child for';
    }
  }

  String? get defaultGender {
    switch (this) {
      case _Relation.mom:
      case _Relation.daughter:
        return 'Female';
      case _Relation.dad:
      case _Relation.son:
        return 'Male';
      case _Relation.sibling:
      case _Relation.partner:
        return null;
    }
  }
}
