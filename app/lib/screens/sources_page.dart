import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/person.dart';
import '../models/source.dart';
import '../providers/tree_provider.dart';
import '../utils/page_routes.dart';
import 'record_search_screen.dart';
import 'source_detail_screen.dart';

class SourcesPage extends StatelessWidget {
  final Person person;
  const SourcesPage({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    // Look up sources either by direct assignment to the person OR via the person's sourceIds list.
    final sources = provider.sources
        .where((s) => s.personId == person.id || person.sourceIds.contains(s.id))
        .toList()
      ..sort((a, b) => (b.confidence ?? '').compareTo(a.confidence ?? '')); // Highest confidence first
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${person.name} — Sources'),
      ),
      body: sources.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined,
                      size: 80, color: colorScheme.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No sources attached.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search for historical records to build\na robust, well-documented tree.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Search Records'),
                    onPressed: () => Navigator.push(
                      context,
                      fadeSlideRoute(
                        builder: (_) => RecordSearchScreen(person: person),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
              itemCount: sources.length,
              itemBuilder: (context, index) {
                final source = sources[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      fadeSlideRoute(builder: (_) => SourceDetailScreen()),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_sourceIcon(source.type),
                                  size: 20, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  source.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _ConfidenceBadge(confidence: source.confidence),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${source.type} · ${source.repository}',
                            style: TextStyle(
                                fontSize: 12, color: colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (source.citedFacts.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: source.citedFacts
                                  .map((fact) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          fact,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_manual',
            onPressed: () => _addManualSource(context),
            child: const Icon(Icons.add),
            tooltip: 'Add Manual Source',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'search_records',
            onPressed: () => Navigator.push(
              context,
              fadeSlideRoute(
                builder: (_) => RecordSearchScreen(person: person),
              ),
            ),
            icon: const Icon(Icons.search),
            label: const Text('Search Records'),
          ),
        ],
      ),
    );
  }

  IconData _sourceIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('census')) return Icons.people_outline;
    if (t.contains('newspaper') || t.contains('obituary')) return Icons.newspaper;
    if (t.contains('cemetery') || t.contains('grave')) return Icons.location_on;
    if (t.contains('book')) return Icons.menu_book;
    if (t.contains('government') || t.contains('civil')) return Icons.account_balance;
    if (t.contains('database') || t.contains('online')) return Icons.language;
    if (t.contains('dna')) return Icons.biotech;
    return Icons.description;
  }

  Future<void> _addManualSource(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manual source entry coming soon.')),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final String confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    
    switch (confidence) {
      case 'A':
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green.shade800;
        label = 'A - Primary';
        break;
      case 'B':
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blue.shade800;
        label = 'B - Secondary';
        break;
      case 'C':
        bg = Colors.orange.withValues(alpha: 0.15);
        fg = Colors.orange.shade800;
        label = 'C - Tertiary';
        break;
      default:
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red.shade800;
        label = 'D - Unreliable';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
