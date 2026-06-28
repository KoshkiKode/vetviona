import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/partnership.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../utils/page_routes.dart';
import 'person_detail_screen.dart';

/// "On This Day" screen — shows births, deaths, and marriages that happened
/// on today's date across the user's family tree.
class OnThisDayScreen extends StatelessWidget {
  const OnThisDayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final now = DateTime.now();
    final events = _gatherEvents(
      provider.persons,
      provider.partnerships,
      now.month,
      now.day,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('On This Day — ${DateFormat('MMMM d').format(now)}'),
      ),
      body: events.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today,
                      size: 80,
                      color: colorScheme.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No family events on this day.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add more dates to your tree to see\nwhat happened on ${DateFormat('MMMM d').format(now)}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return _EventCard(
                  event: event,
                  onTap: () {
                    if (event.personId != null) {
                      final person = provider.persons
                          .where((p) => p.id == event.personId)
                          .firstOrNull;
                      if (person != null) {
                        Navigator.push(
                          context,
                          fadeSlideRoute(
                            builder: (_) =>
                                PersonDetailScreen(person: person),
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
    );
  }

  List<_OnThisDayEvent> _gatherEvents(
    List<Person> persons,
    List<Partnership> partnerships,
    int month,
    int day,
  ) {
    final events = <_OnThisDayEvent>[];

    for (final person in persons) {
      // Birth
      if (person.birthDate != null &&
          person.birthDate!.month == month &&
          person.birthDate!.day == day) {
        final yearsAgo = DateTime.now().year - person.birthDate!.year;
        events.add(_OnThisDayEvent(
          type: _EventType.birth,
          personId: person.id,
          personName: person.name,
          year: person.birthDate!.year,
          yearsAgo: yearsAgo,
          place: person.birthPlace,
          subtitle: person.deathDate != null
              ? 'Lived ${person.deathDate!.year - person.birthDate!.year} years'
              : (yearsAgo > 0 ? 'Would be $yearsAgo today' : null),
        ));
      }

      // Death
      if (person.deathDate != null &&
          person.deathDate!.month == month &&
          person.deathDate!.day == day) {
        final yearsAgo = DateTime.now().year - person.deathDate!.year;
        final age = person.birthDate != null
            ? person.deathDate!.year - person.birthDate!.year
            : null;
        events.add(_OnThisDayEvent(
          type: _EventType.death,
          personId: person.id,
          personName: person.name,
          year: person.deathDate!.year,
          yearsAgo: yearsAgo,
          place: person.deathPlace,
          subtitle: age != null ? 'Age $age' : null,
        ));
      }

      // Burial
      if (person.burialDate != null &&
          person.burialDate!.month == month &&
          person.burialDate!.day == day) {
        events.add(_OnThisDayEvent(
          type: _EventType.burial,
          personId: person.id,
          personName: person.name,
          year: person.burialDate!.year,
          yearsAgo: DateTime.now().year - person.burialDate!.year,
          place: person.burialPlace,
        ));
      }
    }

    // Marriages
    for (final partnership in partnerships) {
      if (partnership.startDate != null &&
          partnership.startDate!.month == month &&
          partnership.startDate!.day == day) {
        final p1 = persons.where((p) => p.id == partnership.person1Id).firstOrNull;
        final p2 = persons.where((p) => p.id == partnership.person2Id).firstOrNull;
        if (p1 != null && p2 != null) {
          final yearsAgo = DateTime.now().year - partnership.startDate!.year;
          events.add(_OnThisDayEvent(
            type: _EventType.marriage,
            personId: p1.id,
            personName: '${p1.name} & ${p2.name}',
            year: partnership.startDate!.year,
            yearsAgo: yearsAgo,
            place: partnership.startPlace,
            subtitle: yearsAgo > 0 ? '$yearsAgo years ago' : null,
          ));
        }
      }
    }

    // Sort by year (oldest first)
    events.sort((a, b) => a.year.compareTo(b.year));
    return events;
  }
}

enum _EventType { birth, death, burial, marriage }

class _OnThisDayEvent {
  final _EventType type;
  final String? personId;
  final String personName;
  final int year;
  final int yearsAgo;
  final String? place;
  final String? subtitle;

  const _OnThisDayEvent({
    required this.type,
    this.personId,
    required this.personName,
    required this.year,
    required this.yearsAgo,
    this.place,
    this.subtitle,
  });
}

class _EventCard extends StatelessWidget {
  final _OnThisDayEvent event;
  final VoidCallback? onTap;

  const _EventCard({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Event icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _eventColor(event.type).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _eventIcon(event.type),
                  color: _eventColor(event.type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.personName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_eventLabel(event.type)} · ${event.year}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _eventColor(event.type),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (event.place != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.place!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (event.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Years ago badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${event.yearsAgo}y ago',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _eventIcon(_EventType type) {
    switch (type) {
      case _EventType.birth:
        return Icons.cake;
      case _EventType.death:
        return Icons.favorite_border;
      case _EventType.burial:
        return Icons.location_on;
      case _EventType.marriage:
        return Icons.favorite;
    }
  }

  String _eventLabel(_EventType type) {
    switch (type) {
      case _EventType.birth:
        return 'Born';
      case _EventType.death:
        return 'Died';
      case _EventType.burial:
        return 'Buried';
      case _EventType.marriage:
        return 'Married';
    }
  }

  Color _eventColor(_EventType type) {
    switch (type) {
      case _EventType.birth:
        return Colors.green;
      case _EventType.death:
        return Colors.grey;
      case _EventType.burial:
        return Colors.brown;
      case _EventType.marriage:
        return Colors.pink;
    }
  }
}
