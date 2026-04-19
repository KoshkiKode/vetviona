import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../providers/tree_provider.dart';

class RelationshipFinderScreen extends StatefulWidget {
  const RelationshipFinderScreen({super.key});

  @override
  State<RelationshipFinderScreen> createState() =>
      _RelationshipFinderScreenState();
}

class _RelationshipFinderScreenState
    extends State<RelationshipFinderScreen> {
  String? _fromId;
  String? _toId;
  List<String>? _path;
  bool _searched = false;

  void _findPath(TreeProvider provider) {
    if (_fromId == null || _toId == null) return;
    final path = provider.findRelationshipPath(_fromId!, _toId!);
    setState(() {
      _path = path;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final persons = provider.persons;

    return Scaffold(
      appBar: AppBar(title: const Text('Relationship Finder')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'From Person'),
              value: _fromId,
              items: persons
                  .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => setState(() {
                _fromId = v;
                _searched = false;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'To Person'),
              value: _toId,
              items: persons
                  .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => setState(() {
                _toId = v;
                _searched = false;
              }),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Find Relationship'),
              onPressed: (_fromId != null && _toId != null)
                  ? () => _findPath(provider)
                  : null,
            ),
            const SizedBox(height: 24),
            if (_searched) _buildResult(provider, persons),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(TreeProvider provider, List<Person> persons) {
    final personMap = {for (final p in persons) p.id: p};
    final colorScheme = Theme.of(context).colorScheme;

    if (_path == null || _path!.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.link_off, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              const Text('No relationship path found between these two people.'),
            ],
          ),
        ),
      );
    }

    final fromPerson = personMap[_path!.first];
    final toPerson = personMap[_path!.last];
    final label = (fromPerson != null && toPerson != null)
        ? describeRelationship(fromPerson, toPerson, persons, _path!)
        : 'Relative';

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Relationship label — shown prominently
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people,
                        size: 20, color: colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Path (${_path!.length - 1} step${_path!.length == 2 ? '' : 's'})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _path!.length,
                  separatorBuilder: (_, _) => Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Icon(Icons.arrow_downward,
                        color: colorScheme.onSurfaceVariant),
                  ),
                  itemBuilder: (context, i) {
                    final id = _path![i];
                    final person = personMap[id];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        child: Text(
                          person?.name.isNotEmpty == true
                              ? person!.name[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(person?.name ?? id),
                      subtitle: person?.birthDate != null
                          ? Text('b. ${person!.birthDate!.year}')
                          : null,
                      trailing: i == 0
                          ? const Chip(label: Text('Start'))
                          : i == _path!.length - 1
                              ? const Chip(label: Text('End'))
                              : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Computes a human-readable relationship label between [from] and [to]
/// by scanning consecutive pairs in [path]:
///   - If B is in A's parentIds  → "up" step
///   - If B is in A's childIds   → "down" step
///   - Otherwise                 → lateral/partner step (ignored for counting)
String describeRelationship(
    Person from, Person to, List<Person> allPersons, List<String> path) {
  if (path.length < 2) return 'Same Person';

  final personMap = {for (final p in allPersons) p.id: p};
  int ups = 0;
  int downs = 0;

  for (int i = 0; i < path.length - 1; i++) {
    final a = personMap[path[i]];
    final b = personMap[path[i + 1]];
    if (a == null || b == null) continue;
    if (a.parentIds.contains(b.id)) {
      ups++;
    } else if (a.childIds.contains(b.id)) {
      downs++;
    }
    // Lateral partner step — does not count as up or down
  }

  // Direct partner link
  if (ups == 0 && downs == 0 && path.length == 2) return 'Partner/Spouse';

  // Direct ancestor
  if (ups > 0 && downs == 0) {
    if (ups == 1) return 'Parent';
    if (ups == 2) return 'Grandparent';
    if (ups == 3) return 'Great-Grandparent';
    return '${ups - 2}x Great-Grandparent';
  }

  // Direct descendant
  if (ups == 0 && downs > 0) {
    if (downs == 1) return 'Child';
    if (downs == 2) return 'Grandchild';
    if (downs == 3) return 'Great-Grandchild';
    return '${downs - 2}x Great-Grandchild';
  }

  if (ups == 1 && downs == 1) return 'Sibling';
  if (ups == 2 && downs == 1) return 'Aunt/Uncle';
  if (ups == 1 && downs == 2) return 'Niece/Nephew';

  // Cousin relationships
  if (ups >= 2 && downs >= 2) {
    final minDeg = ups < downs ? ups : downs;
    final diff = (ups - downs).abs();
    final cousinDegree = minDeg - 1;
    // Correct ordinal suffix: 11th/12th/13th are exceptions
    final String ordinal;
    if (cousinDegree >= 11 && cousinDegree <= 13) {
      ordinal = '${cousinDegree}th';
    } else {
      ordinal = switch (cousinDegree % 10) {
        1 => '${cousinDegree}st',
        2 => '${cousinDegree}nd',
        3 => '${cousinDegree}rd',
        _ => '${cousinDegree}th',
      };
    }
    if (diff == 0) return '$ordinal Cousin';
    final removedLabel = diff == 1 ? 'once removed' : '$diff times removed';
    return '$ordinal Cousin $removedLabel';
  }

  return 'Relative';
}
