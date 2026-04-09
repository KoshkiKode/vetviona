import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/partnership.dart';
import '../models/person.dart';
import '../models/source.dart';
import '../providers/tree_provider.dart';

class TimelineScreen extends StatelessWidget {
  final Person person;
  const TimelineScreen({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final sources = provider.sources
        .where((s) => s.personId == person.id)
        .toList();
    final myPartnerships = provider.partnershipsFor(person.id);
    final events = _buildEvents(sources, myPartnerships, provider);

    return Scaffold(
      appBar: AppBar(title: Text('${person.name} \u2013 Timeline')),
      body: events.isEmpty
          ? const Center(child: Text('No events recorded for this person.'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: events.length,
              itemBuilder: (context, i) =>
                  _TimelineEvent(event: events[i], isLast: i == events.length - 1),
            ),
    );
  }

  List<_Event> _buildEvents(
    List<Source> personSources,
    List<Partnership> myPartnerships,
    TreeProvider provider,
  ) {
    final events = <_Event>[];

    if (person.birthDate != null || person.birthPlace != null) {
      events.add(_Event(
        title: 'Birth',
        date: person.birthDate,
        place: person.birthPlace,
        icon: Icons.cake,
        kind: _EventKind.birth,
        sources: personSources
            .where((s) =>
                s.citedFacts.contains('Birth Date') ||
                s.citedFacts.contains('Birth Place'))
            .toList(),
      ));
    }

    // One event per partnership (marriage / union start and optional end)
    for (final pt in myPartnerships) {
      final otherPersonName = provider.persons
              .where((p) =>
                  p.id ==
                  (pt.person1Id == person.id ? pt.person2Id : pt.person1Id))
              .firstOrNull
              ?.name ??
          'Unknown';

      if (pt.startDate != null || pt.startPlace != null) {
        events.add(_Event(
          title: '${pt.statusLabel} with $otherPersonName',
          date: pt.startDate,
          place: pt.startPlace,
          icon: Icons.favorite,
          kind: pt.isEnded ? _EventKind.endedUnion : _EventKind.union,
          sources: personSources
              .where((s) =>
                  s.citedFacts.contains('Marriage Date') ||
                  s.citedFacts.contains('Marriage Place'))
              .toList(),
        ));
      }

      if (pt.isEnded && (pt.endDate != null || pt.endPlace != null)) {
        events.add(_Event(
          title: _endedEventTitle(pt.status, otherPersonName),
          date: pt.endDate,
          place: pt.endPlace,
          icon: Icons.heart_broken,
          kind: _EventKind.endedUnion,
          sources: const [],
        ));
      }
    }

    if (person.deathDate != null || person.deathPlace != null) {
      events.add(_Event(
        title: 'Death',
        date: person.deathDate,
        place: person.deathPlace,
        icon: Icons.star,
        kind: _EventKind.death,
        sources: personSources
            .where((s) =>
                s.citedFacts.contains('Death Date') ||
                s.citedFacts.contains('Death Place'))
            .toList(),
      ));
    }

    // Add other sources as generic events
    final citedEventFacts = {
      'Birth Date', 'Birth Place', 'Death Date', 'Death Place',
      'Marriage Date', 'Marriage Place',
    };
    for (final source in personSources) {
      if (!source.citedFacts.any((f) => citedEventFacts.contains(f))) {
        events.add(_Event(
          title: source.title,
          date: null,
          place: null,
          icon: Icons.description,
          kind: _EventKind.source,
          sources: [source],
        ));
      }
    }

    events.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });

    return events;
  }

  static String _endedEventTitle(String status, String partnerName) {
    switch (status) {
      case 'divorced':
        return 'Divorced from $partnerName';
      case 'annulled':
        return 'Annulled with $partnerName';
      default:
        return 'Separated from $partnerName';
    }
  }
}

enum _EventKind { birth, union, endedUnion, death, source }

extension _EventKindStyle on _EventKind {
  Color colorOf(ColorScheme cs) => switch (this) {
        _EventKind.birth => cs.tertiary,
        _EventKind.union => cs.outlineVariant,
        _EventKind.endedUnion => cs.outline,
        _EventKind.death => cs.error,
        _EventKind.source => cs.primary,
      };
}

class _Event {
  final String title;
  final DateTime? date;
  final String? place;
  final IconData icon;
  final _EventKind kind;
  final List<Source> sources;

  _Event({
    required this.title,
    required this.date,
    required this.place,
    required this.icon,
    required this.kind,
    required this.sources,
  });
}

class _TimelineEvent extends StatelessWidget {
  final _Event event;
  final bool isLast;
  const _TimelineEvent({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = event.kind.colorOf(colorScheme);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(event.icon, color: color, size: 20),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant.withOpacity(0.4),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 8, right: 16, bottom: 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (event.date != null)
                        Text(
                          DateFormat('d MMMM yyyy').format(event.date!),
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant),
                        ),
                      if (event.place != null && event.place!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 14,
                                color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.place!,
                                style: TextStyle(
                                    color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      if (event.sources.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          children: event.sources
                              .map((s) => Chip(
                                    label: Text(s.title,
                                        style: const TextStyle(fontSize: 11)),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ))
                              .toList(),
                        ),
                      ],
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
