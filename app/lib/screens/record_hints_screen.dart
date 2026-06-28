import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/person.dart';
import '../models/record_hint.dart';
import '../models/source.dart';
import '../providers/tree_provider.dart';
import '../services/record_hints_service.dart';

/// Full-screen record hints review — the "shaky leaf" equivalent.
///
/// Shows all pending, accepted, and dismissed hints with the ability to:
/// - Accept a hint (creates a Source record)
/// - Dismiss a hint
/// - View the external record
/// - Run a new hint scan for persons missing sources
class RecordHintsScreen extends StatefulWidget {
  /// When provided, only shows hints for this person.
  final Person? person;

  const RecordHintsScreen({super.key, this.person});

  @override
  State<RecordHintsScreen> createState() => _RecordHintsScreenState();
}

class _RecordHintsScreenState extends State<RecordHintsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _isScanning = false;
  int _scanProgress = 0;
  int _scanTotal = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // Filter hints
    List<RecordHint> allHints;
    if (widget.person != null) {
      allHints = provider.recordHints
          .where((h) => h.personId == widget.person!.id)
          .toList();
    } else {
      allHints = provider.recordHints;
    }

    final pending = allHints.where((h) => h.isPending).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final accepted = allHints.where((h) => h.isAccepted).toList();
    final dismissed = allHints.where((h) => h.isDismissed).toList();

    final title = widget.person != null
        ? '${widget.person!.name} — Record Hints'
        : 'Record Hints';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isScanning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Scanning $_scanProgress/$_scanTotal…',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            tooltip: _isScanning ? 'Scanning…' : 'Scan for hints',
            onPressed: _isScanning ? _cancelScan : () => _startScan(provider),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              icon: Badge(
                label: Text('${pending.length}'),
                isLabelVisible: pending.isNotEmpty,
                child: const Icon(Icons.lightbulb_outline),
              ),
              text: 'Pending',
            ),
            Tab(
              icon: const Icon(Icons.check_circle_outline),
              text: 'Accepted (${accepted.length})',
            ),
            Tab(
              icon: const Icon(Icons.cancel_outlined),
              text: 'Dismissed (${dismissed.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _HintList(
            hints: pending,
            emptyMessage: 'No pending hints.\nTap the search icon to scan.',
            emptyIcon: Icons.lightbulb_outline,
            onAccept: (h) => _acceptHint(context, provider, h),
            onDismiss: (h) => _dismissHint(provider, h),
            provider: provider,
          ),
          _HintList(
            hints: accepted,
            emptyMessage: 'No accepted hints yet.',
            emptyIcon: Icons.check_circle_outline,
            provider: provider,
          ),
          _HintList(
            hints: dismissed,
            emptyMessage: 'No dismissed hints.',
            emptyIcon: Icons.cancel_outlined,
            onRestore: (h) => _restoreHint(provider, h),
            provider: provider,
          ),
        ],
      ),
    );
  }

  Future<void> _startScan(TreeProvider provider) async {
    final persons = widget.person != null
        ? [widget.person!]
        : provider.persons
            .where((p) =>
                provider.sources
                    .where((s) =>
                        s.personId == p.id || p.sourceIds.contains(s.id))
                    .isEmpty)
            .toList();

    if (persons.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('All persons already have sources attached.')),
        );
      }
      return;
    }

    setState(() {
      _isScanning = true;
      _scanProgress = 0;
      _scanTotal = persons.length;
    });

    RecordHintsService.instance.onHintDiscovered = (hint) async {
      await provider.addRecordHint(hint);
    };
    RecordHintsService.instance.hintExists = (personId, api, extId) {
      return provider.recordHints.any((h) =>
          h.personId == personId &&
          h.apiSource == api &&
          h.externalRecordId == extId);
    };

    await RecordHintsService.instance.findHintsForPersons(
      persons,
      onProgress: (completed, total) {
        if (mounted) {
          setState(() {
            _scanProgress = completed;
            _scanTotal = total;
          });
        }
      },
    );

    if (mounted) {
      setState(() => _isScanning = false);
      final pending =
          provider.recordHints.where((h) => h.isPending).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan complete. $pending pending hints.')),
      );
    }
  }

  void _cancelScan() {
    RecordHintsService.instance.cancel();
    setState(() => _isScanning = false);
  }

  Future<void> _acceptHint(
      BuildContext context, TreeProvider provider, RecordHint hint) async {
    hint.status = 'accepted';
    hint.resolvedAt = DateTime.now().millisecondsSinceEpoch;
    hint.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await provider.updateRecordHint(hint);

    // Auto-create a Source from the hint
    final source = Source(
      id: const Uuid().v4(),
      personId: hint.personId,
      title: hint.title,
      type: 'Record Hint',
      url: hint.recordUrl,
      imagePath: hint.imageUrl,
      extractedInfo: hint.summary,
      treeId: hint.treeId,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await provider.addSourceFromHint(hint, source);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hint accepted — source created.')),
      );
    }
  }

  Future<void> _dismissHint(TreeProvider provider, RecordHint hint) async {
    hint.status = 'dismissed';
    hint.resolvedAt = DateTime.now().millisecondsSinceEpoch;
    hint.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await provider.updateRecordHint(hint);
  }

  Future<void> _restoreHint(TreeProvider provider, RecordHint hint) async {
    hint.status = 'pending';
    hint.resolvedAt = null;
    hint.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await provider.updateRecordHint(hint);
  }
}

// ── Hint list widget ─────────────────────────────────────────────────────────

class _HintList extends StatelessWidget {
  final List<RecordHint> hints;
  final String emptyMessage;
  final IconData emptyIcon;
  final Future<void> Function(RecordHint)? onAccept;
  final Future<void> Function(RecordHint)? onDismiss;
  final Future<void> Function(RecordHint)? onRestore;
  final TreeProvider provider;

  const _HintList({
    required this.hints,
    required this.emptyMessage,
    required this.emptyIcon,
    this.onAccept,
    this.onDismiss,
    this.onRestore,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    if (hints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
      itemCount: hints.length,
      itemBuilder: (context, index) {
        final hint = hints[index];
        final person = provider.persons
            .where((p) => p.id == hint.personId)
            .firstOrNull;

        return _HintCard(
          hint: hint,
          personName: person?.name ?? 'Unknown',
          onAccept: onAccept != null ? () => onAccept!(hint) : null,
          onDismiss: onDismiss != null ? () => onDismiss!(hint) : null,
          onRestore: onRestore != null ? () => onRestore!(hint) : null,
        );
      },
    );
  }
}

class _HintCard extends StatelessWidget {
  final RecordHint hint;
  final String personName;
  final VoidCallback? onAccept;
  final VoidCallback? onDismiss;
  final VoidCallback? onRestore;

  const _HintCard({
    required this.hint,
    required this.personName,
    this.onAccept,
    this.onDismiss,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final confidenceColor = _confidenceColor(hint.confidence, colorScheme);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(_apiIcon(hint.apiSource),
                    size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hint.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Confidence badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: confidenceColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hint.confidenceLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: confidenceColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Person name
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'For: $personName',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                // Source badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _apiLabel(hint.apiSource),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),

            // Summary
            if (hint.summary != null && hint.summary!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                hint.summary!,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View'),
                  onPressed: () => _openUrl(hint.recordUrl),
                ),
                if (onRestore != null) ...[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Restore'),
                    onPressed: onRestore,
                  ),
                ],
                if (onDismiss != null) ...[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Dismiss'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    onPressed: onDismiss,
                  ),
                ],
                if (onAccept != null) ...[
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accept'),
                    onPressed: onAccept,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  IconData _apiIcon(String api) {
    switch (api) {
      case 'familysearch':
        return Icons.account_tree;
      case 'wikitree':
        return Icons.nature;
      case 'chronicling_america':
        return Icons.newspaper;
      case 'nara':
        return Icons.account_balance;
      case 'open_archives':
        return Icons.archive;
      case 'find_a_grave':
        return Icons.location_on;
      default:
        return Icons.description;
    }
  }

  String _apiLabel(String api) {
    switch (api) {
      case 'familysearch':
        return 'FamilySearch';
      case 'wikitree':
        return 'WikiTree';
      case 'chronicling_america':
        return 'Newspapers (LOC)';
      case 'nara':
        return 'Nat\'l Archives';
      case 'open_archives':
        return 'Open Archives';
      case 'find_a_grave':
        return 'Find A Grave';
      default:
        return api;
    }
  }

  Color _confidenceColor(double confidence, ColorScheme cs) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.5) return Colors.orange;
    return cs.error;
  }
}
