import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/life_event.dart';
import '../models/partnership.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../utils/page_routes.dart';
import 'person_detail_screen.dart';

/// A chronological timeline of every recorded event across the entire family
/// tree: births, deaths, partnerships, and custom life events.
///
/// Events without a known date are listed in a separate "Undated" section at
/// the bottom.
class FamilyTimelineScreen extends StatefulWidget {
  const FamilyTimelineScreen({super.key});

  @override
  State<FamilyTimelineScreen> createState() => _FamilyTimelineScreenState();
}

class _FamilyTimelineScreenState extends State<FamilyTimelineScreen> {
  String _search = '';
  _EventFilter _filter = _EventFilter.all;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final persons = provider.persons;
    final partnerships = provider.partnerships;
    final lifeEvents = provider.lifeEvents;

    if (persons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Timeline')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timeline,
                  size: 80,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text('Add people to see the family timeline.'),
            ],
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final personMap = {for (final p in persons) p.id: p};

    // Build the complete event list.
    final allEvents = _buildEvents(persons, partnerships, lifeEvents, personMap);

    // Apply filter.
    final filtered = allEvents.where((e) {
      if (_filter != _EventFilter.all && e.filter != _filter) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return e.title.toLowerCase().contains(q) ||
            e.personName.toLowerCase().contains(q) ||
            (e.place?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();

    // Split into dated / undated.
    final dated =
        filtered.where((e) => e.year != null).toList();
    final undated =
        filtered.where((e) => e.year == null).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Timeline'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search events…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setState(() => _search = ''))
                        : null,
                    filled: true,
                    fillColor: colorScheme.onPrimary.withValues(alpha: 0.15),
                    hintStyle: TextStyle(
                        color: colorScheme.onPrimary.withValues(alpha: 0.7)),
                    prefixIconColor:
                        colorScheme.onPrimary.withValues(alpha: 0.8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0),
                  ),
                  style: TextStyle(color: colorScheme.onPrimary),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  children: _EventFilter.values
                      .map((f) => Padding(
                            padding:
                                const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(f.label),
                              selected: _filter == f,
                              onSelected: (_) =>
                                  setState(() => _filter = f),
                              selectedColor: colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.8),
                              labelStyle: TextStyle(
                                  color: _filter == f
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface,
                                  fontSize: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: dated.isEmpty && undated.isEmpty
          ? Center(
              child: Text(
                'No events match.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: dated.length +
                  (undated.isNotEmpty ? undated.length + 1 : 0),
              itemBuilder: (ctx, i) {
                if (i < dated.length) {
                  final event = dated[i];
                  final prevYear =
                      i > 0 ? dated[i - 1].year : null;
                  return _TimelineTile(
                    event: event,
                    showYear: event.year != prevYear,
                    isFirst: i == 0,
                    isLast: i == dated.length - 1 && undated.isEmpty,
                    colorScheme: colorScheme,
                    personMap: personMap,
                  );
                }
                // Undated header
                final undatedIdx = i - dated.length;
                if (undatedIdx == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 4),
                    child: Text(
                      'Undated',
                      style: Theme.of(ctx)
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold),
                    ),
                  );
                }
                final event = undated[undatedIdx - 1];
                return _TimelineTile(
                  event: event,
                  showYear: false,
                  isFirst: false,
                  isLast: undatedIdx == undated.length,
                  colorScheme: colorScheme,
                  personMap: personMap,
                );
              },
            ),
    );
  }

  static List<_TimelineEvent> _buildEvents(
    List<Person> persons,
    List<Partnership> partnerships,
    List<LifeEvent> lifeEvents,
    Map<String, Person> personMap,
  ) {
    final events = <_TimelineEvent>[];

    for (final p in persons) {
      // Birth
      if (p.birthDate != null || p.birthPlace != null) {
        events.add(_TimelineEvent(
          personId: p.id,
          personName: p.name,
          title: 'Birth',
          year: p.birthDate?.year,
          date: p.birthDate,
          place: p.birthPlace,
          icon: Icons.cake,
          filter: _EventFilter.births,
          gender: p.gender,
        ));
      }
      // Death
      if (p.deathDate != null || p.deathPlace != null) {
        events.add(_TimelineEvent(
          personId: p.id,
          personName: p.name,
          title: 'Death',
          year: p.deathDate?.year,
          date: p.deathDate,
          place: p.deathPlace,
          icon: Icons.star,
          filter: _EventFilter.deaths,
          gender: p.gender,
        ));
      }
    }

    // Partnerships
    for (final pt in partnerships) {
      final p1 = personMap[pt.person1Id];
      final p2 = personMap[pt.person2Id];
      final names = [p1?.name ?? '?', p2?.name ?? '?'].join(' & ');
      if (pt.startDate != null || pt.startPlace != null) {
        events.add(_TimelineEvent(
          personId: pt.person1Id,
          personName: names,
          title: pt.statusLabel,
          year: pt.startDate?.year,
          date: pt.startDate,
          place: pt.startPlace,
          icon: Icons.favorite,
          filter: _EventFilter.partnerships,
          gender: null,
        ));
      }
      if (pt.endDate != null || pt.endPlace != null) {
        events.add(_TimelineEvent(
          personId: pt.person1Id,
          personName: names,
          title: 'Partnership ended',
          year: pt.endDate?.year,
          date: pt.endDate,
          place: pt.endPlace,
          icon: Icons.heart_broken,
          filter: _EventFilter.partnerships,
          gender: null,
        ));
      }
    }

    // Life events
    for (final le in lifeEvents) {
      final person = personMap[le.personId];
      if (person == null) continue;
      events.add(_TimelineEvent(
        personId: le.personId,
        personName: person.name,
        title: le.title,
        year: le.date?.year,
        date: le.date,
        place: le.place,
        icon: _iconForLifeEvent(le.title),
        filter: _EventFilter.other,
        gender: person.gender,
      ));
    }

    // Sort dated events chronologically, undated at end.
    events.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });

    return events;
  }

  static IconData _iconForLifeEvent(String title) {
    final t = title.toLowerCase();
    if (t.contains('bapti') || t.contains('christen')) {
      return Icons.water_drop;
    }
    if (t.contains('graduat')) return Icons.school;
    if (t.contains('militar') || t.contains('service')) {
      return Icons.military_tech;
    }
    if (t.contains('immigrat') || t.contains('emigrat')) {
      return Icons.flight_takeoff;
    }
    if (t.contains('census')) return Icons.list_alt;
    if (t.contains('residence')) return Icons.home;
    if (t.contains('occupation') || t.contains('job')) return Icons.work;
    if (t.contains('illness') || t.contains('disease')) {
      return Icons.local_hospital;
    }
    return Icons.event;
  }
}

// ── Data model ─────────────────────────────────────────────────────────────────

enum _EventFilter {
  all('All'),
  births('Births'),
  deaths('Deaths'),
  partnerships('Partnerships'),
  other('Events');

  final String label;
  const _EventFilter(this.label);
}

class _TimelineEvent {
  final String personId;
  final String personName;
  final String title;
  final int? year;
  final DateTime? date;
  final String? place;
  final IconData icon;
  final _EventFilter filter;
  final String? gender;

  const _TimelineEvent({
    required this.personId,
    required this.personName,
    required this.title,
    required this.year,
    required this.date,
    required this.place,
    required this.icon,
    required this.filter,
    required this.gender,
  });
}

// ── Timeline tile ──────────────────────────────────────────────────────────────

class _TimelineTile extends StatelessWidget {
  final _TimelineEvent event;
  final bool showYear;
  final bool isFirst;
  final bool isLast;
  final ColorScheme colorScheme;
  final Map<String, Person> personMap;

  const _TimelineTile({
    required this.event,
    required this.showYear,
    required this.isFirst,
    required this.isLast,
    required this.colorScheme,
    required this.personMap,
  });

  Color _iconColor() {
    switch (event.filter) {
      case _EventFilter.births:
        return colorScheme.tertiary;
      case _EventFilter.deaths:
        return colorScheme.onSurfaceVariant;
      case _EventFilter.partnerships:
        return colorScheme.error;
      default:
        return colorScheme.secondary;
    }
  }

  String _formattedDate() {
    final d = event.date;
    if (d == null) return '';
    return '${d.day} ${_month(d.month)} ${d.year}';
  }

  static String _month(int m) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (m < 1 || m > 12) return '';
    return names[m];
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _iconColor();
    final person = personMap[event.personId];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Year label + vertical line
          SizedBox(
            width: 60,
            child: Column(
              children: [
                if (showYear && event.year != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '${event.year}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Dot connector
          Column(
            children: [
              const SizedBox(height: 14),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: iconColor.withValues(alpha: 0.5)),
                ),
                child: Icon(event.icon, size: 14, color: iconColor),
              ),
            ],
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: person != null
                    ? () => Navigator.push(
                          context,
                          fadeSlideRoute(
                            builder: (_) =>
                                PersonDetailScreen(person: person),
                          ),
                        )
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Text(
                        event.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.personName,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (event.date != null || event.place != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 10,
                            children: [
                              if (event.date != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 11,
                                        color:
                                            colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 3),
                                    Text(
                                      _formattedDate(),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme
                                              .onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              if (event.place != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.place_outlined,
                                        size: 11,
                                        color:
                                            colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        event.place!,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: colorScheme
                                                .onSurfaceVariant),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
