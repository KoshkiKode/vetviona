import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/heritage.dart';
import '../models/person.dart';
import '../models/dna_kit.dart';
import '../providers/tree_provider.dart';

/// Heritage / ethnicity / DNA screen.
///
/// Shows a donut chart of ethnicity composition and lets users manually
/// enter heritage percentages or link to external DNA results.
class HeritageScreen extends StatefulWidget {
  final Person person;
  const HeritageScreen({super.key, required this.person});

  @override
  State<HeritageScreen> createState() => _HeritageScreenState();
}

class _HeritageScreenState extends State<HeritageScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final heritages = provider.heritages
        .where((h) => h.personId == widget.person.id)
        .toList()
      ..sort((a, b) => (b.percentage ?? 0).compareTo(a.percentage ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.person.name} — Heritage'),
      ),
      body: heritages.isEmpty
          ? _EmptyState(onAdd: () => _addHeritage(context))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                // ── Donut chart ──────────────────────────────────────────
                SizedBox(
                  height: 260,
                  child: _HeritageDonutChart(heritages: heritages),
                ),
                const SizedBox(height: 24),

                // ── DNA service links ────────────────────────────────────
                _DnaServiceLinks(heritages: heritages),
                const SizedBox(height: 16),

                // ── Heritage entries ─────────────────────────────────────
                Text('Ethnicity Breakdown',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...heritages.map((h) => _HeritageEntry(
                      heritage: h,
                      onEdit: () => _editHeritage(context, h),
                      onDelete: () => _deleteHeritage(context, provider, h),
                    )),
                const SizedBox(height: 32),

                // ── Haplogroups ──────────────────────────────────────────
                Text('Haplogroups',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _HaplogroupsSection(person: widget.person),
                const SizedBox(height: 32),

                // ── DNA Kits ─────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DNA Kits',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextButton.icon(
                      onPressed: () => _addDnaKit(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Kit'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _DnaKitsSection(personId: widget.person.id),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addHeritage(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Heritage'),
      ),
    );
  }

  Future<void> _addHeritage(BuildContext context) async {
    final result = await showDialog<Heritage>(
      context: context,
      builder: (_) => _HeritageDialog(personId: widget.person.id),
    );
    if (result != null && context.mounted) {
      await context.read<TreeProvider>().addHeritage(result);
    }
  }

  Future<void> _editHeritage(BuildContext context, Heritage heritage) async {
    final result = await showDialog<Heritage>(
      context: context,
      builder: (_) => _HeritageDialog(
        personId: widget.person.id,
        existing: heritage,
      ),
    );
    if (result != null && context.mounted) {
      await context.read<TreeProvider>().updateHeritage(result);
    }
  }

  Future<void> _deleteHeritage(
      BuildContext context, TreeProvider provider, Heritage heritage) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog.adaptive(
        title: const Text('Delete Heritage Entry'),
        content:
            Text('Remove "${heritage.region}" from this person\'s heritage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await provider.deleteHeritage(heritage.id);
    }
  }

  Future<void> _addDnaKit(BuildContext context) async {
    final result = await showDialog<DnaKit>(
      context: context,
      builder: (_) => _DnaKitDialog(personId: widget.person.id),
    );
    if (result != null && context.mounted) {
      await context.read<TreeProvider>().addDnaKit(result);
    }
  }
}

class _HaplogroupsSection extends StatelessWidget {
  final Person person;
  const _HaplogroupsSection({required this.person});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: const Text('Y-DNA Haplogroup (Paternal)'),
          subtitle: Text(person.yHaplogroup ?? 'Unknown'),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editHaplogroup(context, true),
          ),
        ),
        ListTile(
          title: const Text('mtDNA Haplogroup (Maternal)'),
          subtitle: Text(person.mtHaplogroup ?? 'Unknown'),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editHaplogroup(context, false),
          ),
        ),
      ],
    );
  }

  Future<void> _editHaplogroup(BuildContext context, bool isY) async {
    final ctrl = TextEditingController(text: isY ? person.yHaplogroup : person.mtHaplogroup);
    final val = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${isY ? 'Y-DNA' : 'mtDNA'} Haplogroup'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: isY ? 'e.g. R-M269' : 'e.g. H1a',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );

    if (val != null && context.mounted) {
      if (isY) {
        person.yHaplogroup = val.isEmpty ? null : val.trim();
      } else {
        person.mtHaplogroup = val.isEmpty ? null : val.trim();
      }
      person.updatedAt = DateTime.now().millisecondsSinceEpoch;
      // This directly triggers sync and db update
      context.read<TreeProvider>().updatePerson(person);
    }
  }
}

class _DnaKitsSection extends StatelessWidget {
  final String personId;
  const _DnaKitsSection({required this.personId});

  @override
  Widget build(BuildContext context) {
    final kits = context.watch<TreeProvider>().dnaKitsFor(personId);
    if (kits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No DNA kits added yet.'),
      );
    }
    return Column(
      children: kits.map((k) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.biotech),
            title: Text('${k.testingCompany} (${k.testType.name.toUpperCase()})'),
            subtitle: Text('Kit: ${k.kitNumber ?? 'Unknown'} • Tested: ${k.dateTested?.year ?? 'Unknown'}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => context.read<TreeProvider>().deleteDnaKit(k.id),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DnaKitDialog extends StatefulWidget {
  final String personId;
  const _DnaKitDialog({required this.personId});

  @override
  State<_DnaKitDialog> createState() => _DnaKitDialogState();
}

class _DnaKitDialogState extends State<_DnaKitDialog> {
  DnaTestType _testType = DnaTestType.autosomal;
  String _testingCompany = 'AncestryDNA';
  final _kitNumberCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add DNA Kit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<DnaTestType>(
            initialValue: _testType,
            decoration: const InputDecoration(labelText: 'Test Type'),
            items: DnaTestType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
            onChanged: (v) => setState(() => _testType = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _testingCompany,
            decoration: const InputDecoration(labelText: 'Testing Company'),
            items: Heritage.dnaServices.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _testingCompany = v!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _kitNumberCtrl,
            decoration: const InputDecoration(labelText: 'Kit Number (Optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final kit = DnaKit(
              personId: widget.personId,
              testType: _testType,
              testingCompany: _testingCompany,
              kitNumber: _kitNumberCtrl.text.trim().isEmpty ? null : _kitNumberCtrl.text.trim(),
            );
            Navigator.pop(context, kit);
          },
          child: const Text('Add Kit'),
        ),
      ],
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline,
              size: 80, color: colorScheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No heritage data yet.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add ethnicity estimates from DNA tests\nor enter them manually.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Heritage'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

// ── Donut chart ──────────────────────────────────────────────────────────────

class _HeritageDonutChart extends StatelessWidget {
  final List<Heritage> heritages;
  const _HeritageDonutChart({required this.heritages});

  static const _colors = [
    Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800),
    Color(0xFF9C27B0), Color(0xFFE91E63), Color(0xFF00BCD4),
    Color(0xFFFF5722), Color(0xFF607D8B), Color(0xFF795548),
    Color(0xFF8BC34A), Color(0xFF3F51B5), Color(0xFFCDDC39),
    Color(0xFFFFC107), Color(0xFF009688), Color(0xFFf44336),
  ];

  @override
  Widget build(BuildContext context) {
    final total = heritages
        .map((h) => h.percentage ?? 0)
        .fold(0.0, (a, b) => a + b);

    return CustomPaint(
      painter: _DonutPainter(
        heritages: heritages,
        colors: _colors,
        total: total > 0 ? total : 100,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${total.toStringAsFixed(0)}%',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Total',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<Heritage> heritages;
  final List<Color> colors;
  final double total;

  _DonutPainter({
    required this.heritages,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;
    const strokeWidth = 36.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;

    for (int i = 0; i < heritages.length; i++) {
      final pct = heritages[i].percentage ?? 0;
      if (pct <= 0) continue;
      final sweepAngle = (pct / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

// ── Heritage entry card ──────────────────────────────────────────────────────

class _HeritageEntry extends StatelessWidget {
  final Heritage heritage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HeritageEntry({
    required this.heritage,
    required this.onEdit,
    required this.onDelete,
  });

  static const _colors = _HeritageDonutChart._colors;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Find index for color matching
    final colorIndex =
        Heritage.commonRegions.indexOf(heritage.region) % _colors.length;
    final dotColor =
        colorIndex >= 0 ? _colors[colorIndex] : colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(heritage.region),
        subtitle: heritage.dnaService != null
            ? Text(heritage.dnaService!, style: const TextStyle(fontSize: 12))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (heritage.percentage != null)
              Text(
                '${heritage.percentage!.toStringAsFixed(1)}%',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── DNA service links ────────────────────────────────────────────────────────

class _DnaServiceLinks extends StatelessWidget {
  final List<Heritage> heritages;
  const _DnaServiceLinks({required this.heritages});

  @override
  Widget build(BuildContext context) {
    final services = heritages
        .where((h) =>
            h.dnaService != null &&
            h.dnaResultsUrl != null &&
            h.dnaResultsUrl!.isNotEmpty)
        .map((h) => MapEntry(h.dnaService!, h.dnaResultsUrl!))
        .toSet()
        .toList();

    if (services.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Linked DNA Services',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: services
              .map((s) => ActionChip(
                    avatar: const Icon(Icons.open_in_new, size: 16),
                    label: Text(s.key),
                    onPressed: () async {
                      final uri = Uri.tryParse(s.value);
                      if (uri != null) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ── Add/Edit dialog ──────────────────────────────────────────────────────────

class _HeritageDialog extends StatefulWidget {
  final String personId;
  final Heritage? existing;

  const _HeritageDialog({required this.personId, this.existing});

  @override
  State<_HeritageDialog> createState() => _HeritageDialogState();
}

class _HeritageDialogState extends State<_HeritageDialog> {
  late String _region;
  late TextEditingController _percentageController;
  late TextEditingController _notesController;
  late TextEditingController _dnaUrlController;
  String? _dnaService;

  @override
  void initState() {
    super.initState();
    _region = widget.existing?.region ?? Heritage.commonRegions.first;
    _percentageController = TextEditingController(
      text: widget.existing?.percentage?.toStringAsFixed(1) ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
    _dnaUrlController = TextEditingController(
      text: widget.existing?.dnaResultsUrl ?? '',
    );
    _dnaService = widget.existing?.dnaService;
  }

  @override
  void dispose() {
    _percentageController.dispose();
    _notesController.dispose();
    _dnaUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text(widget.existing != null ? 'Edit Heritage' : 'Add Heritage'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Region picker
            DropdownButtonFormField<String>(
              initialValue: Heritage.commonRegions.contains(_region)
                  ? _region
                  : Heritage.commonRegions.first,
              decoration: const InputDecoration(
                labelText: 'Region / Ethnicity',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: Heritage.commonRegions
                  .map((r) =>
                      DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _region = v!),
            ),
            const SizedBox(height: 12),

            // Percentage
            TextField(
              controller: _percentageController,
              decoration: const InputDecoration(
                labelText: 'Percentage (%)',
                border: OutlineInputBorder(),
                hintText: 'e.g. 25.5',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),

            // DNA service
            DropdownButtonFormField<String>(
              initialValue: _dnaService,
              decoration: const InputDecoration(
                labelText: 'DNA Service',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...Heritage.dnaServices.map((s) =>
                    DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() => _dnaService = v),
            ),
            const SizedBox(height: 12),

            // DNA results URL
            TextField(
              controller: _dnaUrlController,
              decoration: const InputDecoration(
                labelText: 'DNA Results URL (optional)',
                border: OutlineInputBorder(),
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
          onPressed: () {
            final pct = double.tryParse(_percentageController.text.trim());
            final heritage = Heritage(
              id: widget.existing?.id ?? const Uuid().v4(),
              personId: widget.personId,
              region: _region,
              percentage: pct,
              notes: _notesController.text.trim().isNotEmpty
                  ? _notesController.text.trim()
                  : null,
              dnaService: _dnaService,
              dnaResultsUrl: _dnaUrlController.text.trim().isNotEmpty
                  ? _dnaUrlController.text.trim()
                  : null,
              treeId: widget.existing?.treeId,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            );
            Navigator.pop(context, heritage);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
