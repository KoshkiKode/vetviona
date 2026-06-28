import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../utils/page_routes.dart';
import 'memories_screen.dart';
import 'heritage_screen.dart';
import 'record_hints_screen.dart';
import 'record_search_screen.dart';
import 'sources_page.dart';

class PersonDetailScreen extends StatelessWidget {
  final Person person;
  const PersonDetailScreen({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // Get live updated person (so changes reflect immediately)
    final livePerson =
        provider.persons.where((p) => p.id == person.id).firstOrNull ??
            person;

    final hintCount = provider.recordHints
        .where((h) => h.personId == livePerson.id && h.isPending)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Person Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit coming soon')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header info
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: livePerson.photoPaths.isNotEmpty
                    ? FileImage(File(livePerson.photoPaths.first))
                    : null,
                child: livePerson.photoPaths.isEmpty
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(livePerson.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    if (livePerson.birthDate != null || livePerson.deathDate != null)
                      Text(
                        '${_formatDate(livePerson.birthDate)} - ${_formatDate(livePerson.deathDate)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Hints button
          if (hintCount > 0)
            Card(
              color: colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text('$hintCount record hints available'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  fadeSlideRoute(builder: (_) => RecordHintsScreen(person: livePerson)),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Action grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: [
              _ActionTile(
                icon: Icons.search,
                label: 'Search Records',
                onTap: () => Navigator.push(
                  context,
                  fadeSlideRoute(
                    builder: (_) => RecordSearchScreen(person: livePerson),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.description,
                label: 'Sources',
                onTap: () => Navigator.push(
                  context,
                  fadeSlideRoute(
                    builder: (_) => SourcesPage(person: livePerson),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.auto_stories,
                label: 'Memories',
                onTap: () => Navigator.push(
                  context,
                  fadeSlideRoute(
                    builder: (_) => MemoriesScreen(person: livePerson),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.biotech,
                label: 'Heritage & DNA',
                onTap: () => Navigator.push(
                  context,
                  fadeSlideRoute(
                    builder: (_) => HeritageScreen(person: livePerson),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return DateFormat('yyyy').format(date);
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
