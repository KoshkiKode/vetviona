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
                  labelText: 'From Person', border: OutlineInputBorder()),
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
                  labelText: 'To Person', border: OutlineInputBorder()),
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

    if (_path == null || _path!.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.link_off, color: Colors.grey),
              SizedBox(width: 8),
              Text('No relationship path found between these two people.'),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Path (${_path!.length - 1} step${_path!.length == 2 ? '' : 's'})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _path!.length,
                  separatorBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Icon(Icons.arrow_downward, color: Colors.grey),
                  ),
                  itemBuilder: (context, i) {
                    final id = _path![i];
                    final person = personMap[id];
                    return ListTile(
                      leading: CircleAvatar(
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
