import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../services/duplicate_detector_service.dart';

/// Duplicate detection & merge screen.
///
/// Scans for potential duplicate persons using fuzzy name matching, date
/// proximity, and place comparison.  Presents side-by-side comparisons
/// with a merge wizard.
class DuplicateMergeScreen extends StatefulWidget {
  const DuplicateMergeScreen({super.key});

  @override
  State<DuplicateMergeScreen> createState() => _DuplicateMergeScreenState();
}

class _DuplicateMergeScreenState extends State<DuplicateMergeScreen> {
  List<DuplicatePair>? _pairs;
  bool _isScanning = false;
  double _threshold = 0.6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  void _scan() {
    setState(() => _isScanning = true);
    final provider = context.read<TreeProvider>();
    final pairs = DuplicateDetectorService.instance.findDuplicates(
      provider.persons,
      threshold: _threshold,
    );
    setState(() {
      _pairs = pairs;
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Sensitivity',
            onPressed: _showThresholdDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-scan',
            onPressed: _scan,
          ),
        ],
      ),
      body: _isScanning
          ? const Center(child: CircularProgressIndicator())
          : _pairs == null || _pairs!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: 80,
                          color: colorScheme.primary.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('No duplicates found!'),
                      const SizedBox(height: 8),
                      Text(
                        'Your tree looks clean.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  itemCount: _pairs!.length,
                  itemBuilder: (context, index) {
                    final pair = _pairs![index];
                    return _DuplicatePairCard(
                      pair: pair,
                      onMerge: () => _mergePair(context, pair),
                      onDismiss: () {
                        setState(() => _pairs!.removeAt(index));
                      },
                    );
                  },
                ),
    );
  }

  void _showThresholdDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog.adaptive(
          title: const Text('Sensitivity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lower values show more potential duplicates.\n'
                'Higher values show only strong matches.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: _threshold,
                min: 0.3,
                max: 0.9,
                divisions: 6,
                label: '${(_threshold * 100).round()}%',
                onChanged: (v) {
                  setDialogState(() => _threshold = v);
                },
              ),
              Text('Threshold: ${(_threshold * 100).round()}%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _threshold = _threshold);
                _scan();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mergePair(BuildContext context, DuplicatePair pair) async {
    final result = await showDialog<_MergeResult>(
      context: context,
      builder: (_) => _MergeDialog(pair: pair),
    );

    if (result != null && context.mounted) {
      final provider = context.read<TreeProvider>();
      await provider.mergePersons(
        keepId: result.keepId,
        removeId: result.removeId,
      );
      _scan(); // Re-scan
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Persons merged successfully.')),
        );
      }
    }
  }
}

// ── Pair card ────────────────────────────────────────────────────────────────

class _DuplicatePairCard extends StatelessWidget {
  final DuplicatePair pair;
  final VoidCallback onMerge;
  final VoidCallback onDismiss;

  const _DuplicatePairCard({
    required this.pair,
    required this.onMerge,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final confidenceColor = pair.confidence >= 0.8
        ? Colors.red
        : pair.confidence >= 0.6
            ? Colors.orange
            : Colors.amber;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Confidence header
            Row(
              children: [
                Icon(Icons.warning_amber, size: 18, color: confidenceColor),
                const SizedBox(width: 8),
                Text(
                  '${pair.confidenceLabel} duplicate (${(pair.confidence * 100).round()}%)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: confidenceColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Side-by-side comparison
            Row(
              children: [
                Expanded(child: _PersonSummary(person: pair.person1)),
                Container(
                  width: 1,
                  height: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: colorScheme.outlineVariant,
                ),
                Expanded(child: _PersonSummary(person: pair.person2)),
              ],
            ),

            // Match reasons
            if (pair.reasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: pair.reasons
                    .map((r) => Chip(
                          label: Text(r, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Not a duplicate'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.merge, size: 16),
                  label: const Text('Merge'),
                  onPressed: onMerge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonSummary extends StatelessWidget {
  final Person person;
  const _PersonSummary({required this.person});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          person.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (person.gender != null)
          Text(person.gender!, style: const TextStyle(fontSize: 12)),
        if (person.birthDate != null)
          Text('b. ${df.format(person.birthDate!)}',
              style: const TextStyle(fontSize: 12)),
        if (person.birthPlace != null)
          Text(person.birthPlace!,
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        if (person.deathDate != null)
          Text('d. ${df.format(person.deathDate!)}',
              style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ── Merge dialog ─────────────────────────────────────────────────────────────

class _MergeResult {
  final String keepId;
  final String removeId;
  const _MergeResult({required this.keepId, required this.removeId});
}

class _MergeDialog extends StatefulWidget {
  final DuplicatePair pair;
  const _MergeDialog({required this.pair});

  @override
  State<_MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends State<_MergeDialog> {
  late String _keepId;

  @override
  void initState() {
    super.initState();
    _keepId = widget.pair.person1.id;
  }

  @override
  Widget build(BuildContext context) {
    final removeId = _keepId == widget.pair.person1.id
        ? widget.pair.person2.id
        : widget.pair.person1.id;
    final keepPerson = _keepId == widget.pair.person1.id
        ? widget.pair.person1
        : widget.pair.person2;
    final removePerson = _keepId == widget.pair.person1.id
        ? widget.pair.person2
        : widget.pair.person1;

    return AlertDialog.adaptive(
      title: const Text('Merge Persons'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Which record should be kept as the primary?'),
            const SizedBox(height: 12),

            RadioListTile<String>(
              value: widget.pair.person1.id,
              groupValue: _keepId,
              title: Text(widget.pair.person1.name),
              subtitle: Text(
                _personSubtitle(widget.pair.person1),
                style: const TextStyle(fontSize: 12),
              ),
              onChanged: (v) => setState(() => _keepId = v!),
            ),
            RadioListTile<String>(
              value: widget.pair.person2.id,
              groupValue: _keepId,
              title: Text(widget.pair.person2.name),
              subtitle: Text(
                _personSubtitle(widget.pair.person2),
                style: const TextStyle(fontSize: 12),
              ),
              onChanged: (v) => setState(() => _keepId = v!),
            ),

            const SizedBox(height: 12),
            Text(
              'The other record ("${removePerson.name}") will be deleted, '
              'and its relationships, sources, and events will be transferred '
              'to "${keepPerson.name}".',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _MergeResult(keepId: _keepId, removeId: removeId),
          ),
          child: const Text('Merge'),
        ),
      ],
    );
  }

  String _personSubtitle(Person p) {
    final parts = <String>[];
    if (p.gender != null) parts.add(p.gender!);
    if (p.birthDate != null) {
      parts.add('b. ${DateFormat('yyyy').format(p.birthDate!)}');
    }
    if (p.birthPlace != null) parts.add(p.birthPlace!);
    return parts.join(' · ');
  }
}
