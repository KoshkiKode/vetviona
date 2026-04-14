import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../models/source.dart';
import '../providers/tree_provider.dart';

/// Shows a list of persons whose sources disagree on key facts, and lets the
/// user pick a preferred source for each disputed fact.
class ConflictResolverScreen extends StatelessWidget {
  const ConflictResolverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final conflicts = _findAllConflicts(provider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evidence Conflict Resolver'),
      ),
      body: conflicts.isEmpty
          ? _EmptyState(colorScheme: colorScheme)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conflicts.length,
              itemBuilder: (context, i) => _PersonConflictCard(
                conflict: conflicts[i],
                provider: provider,
              ),
            ),
    );
  }

  /// Scans all persons and returns one [_PersonConflict] per person that has
  /// at least one disputed fact.
  List<_PersonConflict> _findAllConflicts(TreeProvider provider) {
    const tracked = [
      'Birth Date',
      'Birth Place',
      'Death Date',
      'Death Place',
    ];

    final conflicts = <_PersonConflict>[];

    for (final person in provider.persons) {
      final personSources = provider.sources
          .where((s) => s.personId == person.id)
          .toList();

      final factConflicts = <_FactConflict>[];
      for (final fact in tracked) {
        final citing = personSources
            .where((s) => s.citedFacts.contains(fact))
            .toList();
        if (citing.length >= 2) {
          factConflicts.add(_FactConflict(
            fact: fact,
            sources: citing,
            preferredSourceId: person.preferredSourceIds[fact],
          ));
        }
      }

      if (factConflicts.isNotEmpty) {
        conflicts.add(_PersonConflict(
          person: person,
          factConflicts: factConflicts,
        ));
      }
    }

    return conflicts;
  }
}

// ── Data classes ─────────────────────────────────────────────────────────────

class _PersonConflict {
  final Person person;
  final List<_FactConflict> factConflicts;
  _PersonConflict({required this.person, required this.factConflicts});
}

class _FactConflict {
  final String fact;
  final List<Source> sources;
  final String? preferredSourceId;
  _FactConflict(
      {required this.fact,
      required this.sources,
      required this.preferredSourceId});
}

// ── Per-person conflict card ──────────────────────────────────────────────────

class _PersonConflictCard extends StatelessWidget {
  final _PersonConflict conflict;
  final TreeProvider provider;

  const _PersonConflictCard(
      {required this.conflict, required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedCount =
        conflict.factConflicts.where((f) => f.preferredSourceId != null).length;
    final totalCount = conflict.factConflicts.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: resolvedCount == totalCount
              ? colorScheme.primaryContainer
              : colorScheme.errorContainer,
          foregroundColor: resolvedCount == totalCount
              ? colorScheme.onPrimaryContainer
              : colorScheme.onErrorContainer,
          child: Text(
            conflict.person.name.isNotEmpty
                ? conflict.person.name[0].toUpperCase()
                : '?',
          ),
        ),
        title: Text(conflict.person.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          resolvedCount == totalCount
              ? 'All $totalCount conflict${totalCount == 1 ? '' : 's'} resolved'
              : '$resolvedCount / $totalCount conflict${totalCount == 1 ? '' : 's'} resolved',
          style: TextStyle(
            color: resolvedCount == totalCount
                ? colorScheme.primary
                : colorScheme.error,
          ),
        ),
        trailing: resolvedCount == totalCount
            ? Icon(Icons.check_circle, color: colorScheme.primary)
            : Icon(Icons.warning_amber_rounded, color: colorScheme.error),
        children: conflict.factConflicts
            .map((fc) => _FactConflictTile(
                  factConflict: fc,
                  person: conflict.person,
                  provider: provider,
                ))
            .toList(),
      ),
    );
  }
}

// ── Per-fact conflict tile ────────────────────────────────────────────────────

class _FactConflictTile extends StatelessWidget {
  final _FactConflict factConflict;
  final Person person;
  final TreeProvider provider;

  const _FactConflictTile({
    required this.factConflict,
    required this.person,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isResolved = factConflict.preferredSourceId != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: isResolved
              ? colorScheme.primaryContainer.withOpacity(0.3)
              : colorScheme.errorContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isResolved
                ? colorScheme.primary.withOpacity(0.3)
                : colorScheme.error.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Icon(
                    _factIcon(factConflict.fact),
                    size: 16,
                    color: isResolved ? colorScheme.primary : colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    factConflict.fact,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isResolved
                          ? colorScheme.primary
                          : colorScheme.error,
                    ),
                  ),
                  const Spacer(),
                  if (isResolved)
                    Chip(
                      label: const Text('Resolved'),
                      backgroundColor:
                          colorScheme.primary.withOpacity(0.12),
                      labelStyle: TextStyle(
                          color: colorScheme.primary, fontSize: 11),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    )
                  else
                    Chip(
                      label: const Text('Conflict'),
                      backgroundColor:
                          colorScheme.error.withOpacity(0.12),
                      labelStyle: TextStyle(
                          color: colorScheme.error, fontSize: 11),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...factConflict.sources.map((src) => _SourceOption(
                  source: src,
                  isPreferred:
                      src.id == factConflict.preferredSourceId,
                  onSelect: () =>
                      _setPreferred(context, src.id),
                  onClear: factConflict.preferredSourceId == src.id
                      ? () => _clearPreferred(context)
                      : null,
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _setPreferred(BuildContext context, String sourceId) async {
    person.preferredSourceIds = {
      ...person.preferredSourceIds,
      factConflict.fact: sourceId,
    };
    await provider.updatePerson(person);
  }

  Future<void> _clearPreferred(BuildContext context) async {
    person.preferredSourceIds =
        Map<String, String>.from(person.preferredSourceIds)
          ..remove(factConflict.fact);
    await provider.updatePerson(person);
  }

  IconData _factIcon(String fact) => switch (fact) {
        'Birth Date' || 'Birth Place' => Icons.cake_outlined,
        'Death Date' || 'Death Place' => Icons.star_border,
        _ => Icons.info_outline,
      };
}

// ── Source option row ─────────────────────────────────────────────────────────

class _SourceOption extends StatelessWidget {
  final Source source;
  final bool isPreferred;
  final VoidCallback onSelect;
  final VoidCallback? onClear;

  const _SourceOption({
    required this.source,
    required this.isPreferred,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPreferred
            ? colorScheme.primary.withOpacity(0.08)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPreferred
              ? colorScheme.primary.withOpacity(0.4)
              : colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isPreferred ? Icons.check_circle : Icons.circle_outlined,
          color: isPreferred ? colorScheme.primary : colorScheme.outlineVariant,
        ),
        title: Text(
          source.title,
          style: TextStyle(
            fontWeight:
                isPreferred ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${source.type}',
                style: TextStyle(
                    fontSize: 11, color: colorScheme.onSurfaceVariant)),
            if (source.extractedInfo != null &&
                source.extractedInfo!.isNotEmpty)
              Text(
                source.extractedInfo!,
                style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: isPreferred
            ? (onClear != null
                ? TextButton(
                    onPressed: onClear,
                    child: const Text('Clear'),
                  )
                : const SizedBox.shrink())
            : FilledButton.tonal(
                onPressed: onSelect,
                child: const Text('Prefer'),
              ),
        isThreeLine:
            source.extractedInfo != null && source.extractedInfo!.isNotEmpty,
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
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
              child: Icon(Icons.fact_check_outlined,
                  size: 40, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              'No conflicting evidence found',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Conflicts appear when two or more sources attached to the same person each cite the same key fact (birth date, birth place, etc.).',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
