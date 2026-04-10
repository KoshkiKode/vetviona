import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/partnership.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  static const _monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Returns the number of days from today until the next occurrence of the
  /// given month/day (ignoring the year).
  static int _daysUntilNextAnniversary(DateTime date) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final thisYear = DateTime(today.year, date.month, date.day);
    if (!thisYear.isBefore(todayNorm)) {
      return thisYear.difference(todayNorm).inDays;
    }
    final nextYear = DateTime(today.year + 1, date.month, date.day);
    return nextYear.difference(todayNorm).inDays;
  }

  List<_CalendarEvent> _buildUpcomingEvents(
    List<Person> persons,
    List<Partnership> partnerships,
    TreeProvider provider,
  ) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final events = <_CalendarEvent>[];

    // Birthdays for living people
    for (final person in persons) {
      if (person.birthDate == null) continue;
      if (person.deathDate != null) continue; // deceased
      final days = _daysUntilNextAnniversary(person.birthDate!);
      if (days <= 365) {
        final next = todayNorm.add(Duration(days: days));
        events.add(_CalendarEvent(
          label: person.name,
          type: _EventType.birthday,
          month: next.month,
          day: next.day,
          daysUntil: days,
        ));
      }
    }

    // Wedding anniversaries for active partnerships
    for (final partnership in partnerships) {
      if (partnership.startDate == null) continue;
      if (partnership.isEnded) continue;
      final days = _daysUntilNextAnniversary(partnership.startDate!);
      if (days <= 365) {
        final next = todayNorm.add(Duration(days: days));
        final p1 = provider.persons
            .where((p) => p.id == partnership.person1Id)
            .firstOrNull;
        final p2 = provider.persons
            .where((p) => p.id == partnership.person2Id)
            .firstOrNull;
        final names =
            '${p1?.name ?? 'Unknown'} & ${p2?.name ?? 'Unknown'}';
        events.add(_CalendarEvent(
          label: names,
          type: _EventType.anniversary,
          month: next.month,
          day: next.day,
          daysUntil: days,
        ));
      }
    }

    events.sort((a, b) {
      final cmp = a.daysUntil.compareTo(b.daysUntil);
      if (cmp != 0) return cmp;
      return a.day.compareTo(b.day);
    });
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final events = _buildUpcomingEvents(
      provider.persons,
      provider.partnerships,
      provider,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Birthdays & Anniversaries'),
      ),
      body: events.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No upcoming events',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add birth dates to living people or wedding dates to partnerships to see upcoming events here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : _EventListView(events: events, monthNames: _monthNames),
    );
  }
}

enum _EventType { birthday, anniversary }

class _CalendarEvent {
  final String label;
  final _EventType type;
  final int month;
  final int day;
  final int daysUntil;

  const _CalendarEvent({
    required this.label,
    required this.type,
    required this.month,
    required this.day,
    required this.daysUntil,
  });
}

class _EventListView extends StatelessWidget {
  final List<_CalendarEvent> events;
  final List<String> monthNames;

  const _EventListView({required this.events, required this.monthNames});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Group by month (preserving daysUntil order across months)
    final grouped = <int, List<_CalendarEvent>>{};
    for (final e in events) {
      grouped.putIfAbsent(e.month, () => []).add(e);
    }
    // Order months by the earliest event within each month
    final months = grouped.keys.toList()
      ..sort((a, b) {
        final aMin = grouped[a]!.map((e) => e.daysUntil).reduce((x, y) => x < y ? x : y);
        final bMin = grouped[b]!.map((e) => e.daysUntil).reduce((x, y) => x < y ? x : y);
        return aMin.compareTo(bMin);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: months.length,
      itemBuilder: (context, i) {
        final month = months[i];
        final monthEvents = grouped[month]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                monthNames[month],
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
              ),
            ),
            ...monthEvents.map((e) {
              final isBirthday = e.type == _EventType.birthday;
              final icon = isBirthday ? Icons.cake : Icons.favorite;
              final iconColor =
                  isBirthday ? colorScheme.tertiary : colorScheme.secondary;
              final daysLabel = e.daysUntil == 0
                  ? 'Today!'
                  : e.daysUntil == 1
                      ? 'Tomorrow'
                      : 'In ${e.daysUntil} days';
              final typeLabel =
                  isBirthday ? 'Birthday' : 'Anniversary';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: iconColor.withOpacity(0.15),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  title: Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$typeLabel · $daysLabel'),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${e.day}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}
