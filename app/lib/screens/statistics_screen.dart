import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/partnership.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import 'person_detail_screen.dart';
import '../utils/page_routes.dart';

/// Lifespans outside this range are treated as data-entry errors and excluded
/// from lifespan statistics.
const int _kMaxReasonableLifespan = 130;

/// A full-screen statistics & insights view for the family tree.
///
/// Displays:
///   • Key counts (people, living / deceased, partnerships, generations)
///   • Birth-decade bar chart
///   • Gender distribution bar chart
///   • Top-10 surnames frequency chart
///   • Average lifespan (with min/max)
///   • Lifespan distribution histogram
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final persons = provider.persons;
    final partnerships = provider.partnerships;

    if (persons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statistics & Insights')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart,
                  size: 80,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text('Add people to see statistics.'),
            ],
          ),
        ),
      );
    }

    final stats = _TreeStats.compute(persons, partnerships);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics & Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Key numbers ─────────────────────────────────────────────────────
          _SectionHeader(icon: Icons.people, label: 'Overview'),
          const SizedBox(height: 8),
          _KeyNumbersGrid(stats: stats, partnerships: partnerships),
          const SizedBox(height: 20),

          // ── Birth-decade distribution ────────────────────────────────────────
          if (stats.decadeCounts.isNotEmpty) ...[
            _SectionHeader(icon: Icons.date_range, label: 'Birth Decades'),
            const SizedBox(height: 8),
            _BarChartCard(
              data: stats.decadeCounts.entries
                  .map((e) => _Bar('${e.key}s', e.value))
                  .toList(),
              color: colorScheme.primary,
              axisLabel: 'People born',
            ),
            const SizedBox(height: 20),
          ],

          // ── Gender distribution ──────────────────────────────────────────────
          if (stats.genderCounts.isNotEmpty) ...[
            _SectionHeader(icon: Icons.wc, label: 'Gender Distribution'),
            const SizedBox(height: 8),
            _BarChartCard(
              data: stats.genderCounts.entries
                  .map((e) => _Bar(e.key, e.value))
                  .toList(),
              color: colorScheme.tertiary,
              axisLabel: 'People',
            ),
            const SizedBox(height: 20),
          ],

          // ── Top surnames ─────────────────────────────────────────────────────
          if (stats.topSurnames.isNotEmpty) ...[
            _SectionHeader(
                icon: Icons.family_restroom, label: 'Top Surnames'),
            const SizedBox(height: 8),
            _BarChartCard(
              data: stats.topSurnames
                  .take(10)
                  .map((e) => _Bar(e.key, e.value))
                  .toList(),
              color: colorScheme.secondary,
              axisLabel: 'People',
            ),
            const SizedBox(height: 20),
          ],

          // ── Lifespan ─────────────────────────────────────────────────────────
          if (stats.lifespans.isNotEmpty) ...[
            _SectionHeader(
                icon: Icons.hourglass_bottom, label: 'Lifespan'),
            const SizedBox(height: 8),
            _LifespanCard(stats: stats, colorScheme: colorScheme),
            const SizedBox(height: 20),
          ],

          // ── Oldest & youngest ────────────────────────────────────────────────
          if (stats.oldestPerson != null || stats.youngestPerson != null) ...[
            _SectionHeader(
                icon: Icons.cake, label: 'Oldest & Youngest Births'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  if (stats.oldestPerson != null)
                    _PersonRow(
                      person: stats.oldestPerson!,
                      label: 'Oldest born',
                      subtitle: stats.oldestPerson!.birthDate != null
                          ? 'b. ${stats.oldestPerson!.birthDate!.year}'
                          : '',
                      colorScheme: colorScheme,
                    ),
                  if (stats.oldestPerson != null &&
                      stats.youngestPerson != null)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  if (stats.youngestPerson != null)
                    _PersonRow(
                      person: stats.youngestPerson!,
                      label: 'Youngest born',
                      subtitle: stats.youngestPerson!.birthDate != null
                          ? 'b. ${stats.youngestPerson!.birthDate!.year}'
                          : '',
                      colorScheme: colorScheme,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Partnership stats ────────────────────────────────────────────────
          if (partnerships.isNotEmpty) ...[
            _SectionHeader(
                icon: Icons.favorite, label: 'Partnerships'),
            const SizedBox(height: 8),
            _PartnershipCard(
                stats: stats,
                partnerships: partnerships,
                colorScheme: colorScheme),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _TreeStats {
  final int totalPeople;
  final int livingCount;
  final int deceasedCount;
  final int generationCount;
  final Map<int, int> decadeCounts;
  final Map<String, int> genderCounts;
  final List<MapEntry<String, int>> topSurnames;
  final List<int> lifespans;
  final double? avgLifespan;
  final int? minLifespan;
  final int? maxLifespan;
  final Person? oldestPerson;
  final Person? youngestPerson;

  const _TreeStats({
    required this.totalPeople,
    required this.livingCount,
    required this.deceasedCount,
    required this.generationCount,
    required this.decadeCounts,
    required this.genderCounts,
    required this.topSurnames,
    required this.lifespans,
    required this.avgLifespan,
    required this.minLifespan,
    required this.maxLifespan,
    required this.oldestPerson,
    required this.youngestPerson,
  });

  factory _TreeStats.compute(
      List<Person> persons, List<Partnership> partnerships) {
    final living = persons.where((p) => p.deathDate == null).length;

    // Birth decade distribution
    final decadeCounts = <int, int>{};
    for (final p in persons) {
      if (p.birthDate == null) continue;
      final decade = (p.birthDate!.year ~/ 10) * 10;
      decadeCounts[decade] = (decadeCounts[decade] ?? 0) + 1;
    }
    final sortedDecades = Map.fromEntries(
        decadeCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));

    // Gender distribution (normalise to title-case bucket)
    final genderCounts = <String, int>{};
    for (final p in persons) {
      final g = p.gender?.trim();
      if (g == null || g.isEmpty) {
        genderCounts['Unknown'] = (genderCounts['Unknown'] ?? 0) + 1;
      } else {
        final bucket = g[0].toUpperCase() + g.substring(1).toLowerCase();
        genderCounts[bucket] = (genderCounts[bucket] ?? 0) + 1;
      }
    }

    // Surname frequency (last word of full name)
    final surnameCounts = <String, int>{};
    for (final p in persons) {
      final parts = p.name.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        final surname = parts.last;
        if (surname.isNotEmpty) {
          surnameCounts[surname] = (surnameCounts[surname] ?? 0) + 1;
        }
      }
    }
    final topSurnames = surnameCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Lifespans
    final lifespans = persons
        .where((p) => p.birthDate != null && p.deathDate != null)
        .map((p) => p.deathDate!.year - p.birthDate!.year)
        .where((y) => y >= 0 && y <= _kMaxReasonableLifespan)
        .toList();
    double? avgLifespan;
    int? minLifespan;
    int? maxLifespan;
    if (lifespans.isNotEmpty) {
      avgLifespan = lifespans.reduce((a, b) => a + b) / lifespans.length;
      minLifespan = lifespans.reduce(math.min);
      maxLifespan = lifespans.reduce(math.max);
    }

    // Oldest & youngest by birth date
    final withBirth = persons
        .where((p) => p.birthDate != null)
        .toList()
      ..sort((a, b) => a.birthDate!.compareTo(b.birthDate!));
    final oldestPerson = withBirth.isNotEmpty ? withBirth.first : null;
    final youngestPerson = withBirth.isNotEmpty ? withBirth.last : null;

    // Generation count (BFS depth)
    int generationCount = 0;
    if (persons.isNotEmpty) {
      final personMap = {for (final p in persons) p.id: p};
      final roots = persons.where((p) =>
          p.parentIds.isEmpty ||
          !p.parentIds.any((id) => personMap.containsKey(id)));
      var current = <String>{for (final r in roots) r.id};
      final visited = <String>{};
      while (current.isNotEmpty) {
        generationCount++;
        final next = <String>{};
        for (final id in current) {
          if (visited.contains(id)) continue;
          visited.add(id);
          final p = personMap[id];
          if (p == null) continue;
          for (final childId in p.childIds) {
            if (!visited.contains(childId) && personMap.containsKey(childId)) {
              next.add(childId);
            }
          }
        }
        current = next;
      }
    }

    return _TreeStats(
      totalPeople: persons.length,
      livingCount: living,
      deceasedCount: persons.length - living,
      generationCount: generationCount,
      decadeCounts: sortedDecades,
      genderCounts: genderCounts,
      topSurnames: topSurnames,
      lifespans: lifespans,
      avgLifespan: avgLifespan,
      minLifespan: minLifespan,
      maxLifespan: maxLifespan,
      oldestPerson: oldestPerson,
      youngestPerson: youngestPerson,
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
        ),
      ],
    );
  }
}

class _KeyNumbersGrid extends StatelessWidget {
  final _TreeStats stats;
  final List<Partnership> partnerships;
  const _KeyNumbersGrid(
      {required this.stats, required this.partnerships});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _NumberTile(
          value: '${stats.totalPeople}',
          label: 'People',
          icon: Icons.people,
          color: Theme.of(context).colorScheme.primary,
        ),
        _NumberTile(
          value: '${stats.livingCount}',
          label: 'Living',
          icon: Icons.favorite,
          color: Theme.of(context).colorScheme.tertiary,
        ),
        _NumberTile(
          value: '${stats.deceasedCount}',
          label: 'Deceased',
          icon: Icons.star_border,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        _NumberTile(
          value: '${stats.generationCount}',
          label: 'Generations',
          icon: Icons.account_tree,
          color: Theme.of(context).colorScheme.secondary,
        ),
        _NumberTile(
          value: '${partnerships.length}',
          label: 'Partnerships',
          icon: Icons.link,
          color: Theme.of(context).colorScheme.error,
        ),
        if (stats.avgLifespan != null)
          _NumberTile(
            value: '${stats.avgLifespan!.toStringAsFixed(1)} yrs',
            label: 'Avg lifespan',
            icon: Icons.hourglass_bottom,
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }
}

class _NumberTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _NumberTile(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bar chart ──────────────────────────────────────────────────────────────────

class _Bar {
  final String label;
  final int count;
  const _Bar(this.label, this.count);
}

class _BarChartCard extends StatelessWidget {
  final List<_Bar> data;
  final Color color;
  final String axisLabel;

  const _BarChartCard(
      {required this.data, required this.color, required this.axisLabel});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxVal = data.map((b) => b.count).reduce(math.max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final bar in data) ...[
              _BarRow(
                  bar: bar, maxVal: maxVal, color: color),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 4),
            Text(axisLabel,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final _Bar bar;
  final int maxVal;
  final Color color;
  const _BarRow(
      {required this.bar, required this.maxVal, required this.color});

  @override
  Widget build(BuildContext context) {
    final frac = maxVal == 0 ? 0.0 : bar.count / maxVal;
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            bar.label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final barW = constraints.maxWidth * frac;
              return Stack(
                children: [
                  Container(
                    height: 20,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 20,
                    width: barW.clamp(0, constraints.maxWidth),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '${bar.count}',
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ── Lifespan card ──────────────────────────────────────────────────────────────

class _LifespanCard extends StatelessWidget {
  final _TreeStats stats;
  final ColorScheme colorScheme;
  const _LifespanCard(
      {required this.stats, required this.colorScheme});

  /// Buckets lifespans into 10-year intervals and returns a sorted map.
  Map<String, int> _buckets() {
    final m = <int, int>{};
    for (final ls in stats.lifespans) {
      final bucket = (ls ~/ 10) * 10;
      m[bucket] = (m[bucket] ?? 0) + 1;
    }
    final sorted = m.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return {for (final e in sorted) '${e.key}–${e.key + 9}': e.value};
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _buckets();
    final maxVal =
        buckets.values.isEmpty ? 1 : buckets.values.reduce(math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary row
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                if (stats.avgLifespan != null)
                  _StatPill(
                    label: 'Average',
                    value: '${stats.avgLifespan!.toStringAsFixed(1)} yrs',
                    color: colorScheme.primary,
                  ),
                if (stats.minLifespan != null)
                  _StatPill(
                    label: 'Minimum',
                    value: '${stats.minLifespan} yrs',
                    color: colorScheme.secondary,
                  ),
                if (stats.maxLifespan != null)
                  _StatPill(
                    label: 'Maximum',
                    value: '${stats.maxLifespan} yrs',
                    color: colorScheme.tertiary,
                  ),
                _StatPill(
                  label: 'Sample',
                  value: '${stats.lifespans.length} people',
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            if (buckets.isNotEmpty) ...[
              const SizedBox(height: 16),
              // Histogram
              for (final entry in buckets.entries) ...[
                _BarRow(
                  bar: _Bar(entry.key, entry.value),
                  maxVal: maxVal,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 6),
              ],
              Text('Age at death (years)',
                  style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ── Partnership card ───────────────────────────────────────────────────────────

class _PartnershipCard extends StatelessWidget {
  final _TreeStats stats;
  final List<Partnership> partnerships;
  final ColorScheme colorScheme;
  const _PartnershipCard(
      {required this.stats,
      required this.partnerships,
      required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final active = partnerships.where((p) => !p.isEnded).length;
    final ended = partnerships.length - active;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _StatPill(
              label: 'Total',
              value: '${partnerships.length}',
              color: colorScheme.primary,
            ),
            _StatPill(
              label: 'Active',
              value: '$active',
              color: colorScheme.tertiary,
            ),
            _StatPill(
              label: 'Ended',
              value: '$ended',
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Person row (oldest / youngest) ────────────────────────────────────────────

class _PersonRow extends StatelessWidget {
  final Person person;
  final String label;
  final String subtitle;
  final ColorScheme colorScheme;
  const _PersonRow(
      {required this.person,
      required this.label,
      required this.subtitle,
      required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    Color avatarBg;
    if (person.gender?.toLowerCase() == 'male') {
      avatarBg = colorScheme.primary;
    } else if (person.gender?.toLowerCase() == 'female') {
      avatarBg = colorScheme.error;
    } else {
      avatarBg = colorScheme.secondary;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: avatarBg,
        child: Text(
          person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
          style: TextStyle(
              color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(person.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$label  ·  $subtitle'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        fadeSlideRoute(builder: (_) => PersonDetailScreen(person: person)),
      ),
    );
  }
}
