import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/tree_provider.dart';
import '../services/completeness_service.dart';
import 'duplicate_merge_screen.dart';
import 'on_this_day_screen.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final persons = provider.persons;
    final completeness = CompletenessService.instance.scoreTree(
      persons,
      allSources: provider.sources,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tree Statistics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick actions
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.calendar_today,
                  title: 'On This Day',
                  subtitle: 'Births & deaths today',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OnThisDayScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionCard(
                  icon: Icons.merge,
                  title: 'Merge Duplicates',
                  subtitle: 'Find matching records',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DuplicateMergeScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Text('Overall Completeness',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tree Score: ${completeness.averageScore}/100'),
                      Text('Grade: ${completeness.grade}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: completeness.averageScore / 100,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatColumn('Well Documented', completeness.wellDocumented.toString()),
                      _StatColumn('Needs Work', completeness.needsWork.toString()),
                      _StatColumn('Critical', completeness.critical.toString(),
                          color: Theme.of(context).colorScheme.error),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatColumn(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
