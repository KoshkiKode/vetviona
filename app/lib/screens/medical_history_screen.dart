import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/medical_condition.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';

// ── Main screen ──────────────────────────────────────────────────────────────

/// Shows all medical conditions recorded for every person in the current tree,
/// grouped by category or person, with PDF export.
class MedicalHistoryScreen extends StatefulWidget {
  /// When [person] is provided the screen opens in per-person mode.
  final Person? person;

  const MedicalHistoryScreen({super.key, this.person});

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _disclaimerDismissed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.person == null ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final title = widget.person != null
        ? '${widget.person!.name} — Medical History'
        : 'Family Medical History';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: () => _exportPdf(context, provider),
          ),
        ],
        bottom: widget.person == null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.person_outline), text: 'By Person'),
                  Tab(
                      icon: Icon(Icons.category_outlined),
                      text: 'By Category'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          if (!_disclaimerDismissed) _DisclaimerBanner(
            onDismiss: () => setState(() => _disclaimerDismissed = true),
          ),
          Expanded(
            child: widget.person != null
                ? _PersonConditionsList(
                    provider: provider,
                    personId: widget.person!.id,
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _AllPersonsList(provider: provider),
                      _ByCategoryList(provider: provider),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Condition'),
        onPressed: () => _openConditionSheet(
          context,
          provider,
          widget.person?.id,
          null,
        ),
      ),
    );
  }

  // ── PDF export ─────────────────────────────────────────────────────────────

  Future<void> _exportPdf(BuildContext context, TreeProvider provider) async {
    try {
      final pdfBytes = await _buildPdf(provider);
      if (!context.mounted) return;

      // Use the printing package's layout preview / share sheet
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'family_medical_history',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    }
  }

  Future<List<int>> _buildPdf(TreeProvider provider) async {
    final doc = pw.Document();
    final now = DateFormat('d MMMM yyyy').format(DateTime.now());

    // Group conditions by person
    final personsWithConditions = provider.persons
        .where((p) => provider.medicalConditionsFor(p.id).isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Category colour map (PdfColor approximations of Material colours)
    const categoryColors = <String, PdfColor>{
      'Cardiovascular': PdfColors.red300,
      'Cancer': PdfColors.purple300,
      'Mental Health': PdfColors.indigo300,
      'Neurological': PdfColors.blue300,
      'Metabolic / Endocrine': PdfColors.orange300,
      'Autoimmune / Immune': PdfColors.teal300,
      'Respiratory': PdfColors.cyan300,
      'Genetic / Chromosomal': PdfColors.green300,
      'Musculoskeletal': PdfColors.brown300,
      'Gastrointestinal': PdfColors.amber300,
      'Renal / Urological': PdfColors.lightBlue300,
      'Reproductive / Gynaecological': PdfColors.pink300,
      'Dermatological': PdfColors.lime300,
      'Sensory (Vision / Hearing)': PdfColors.deepPurple300,
      'Haematological / Blood': PdfColors.deepOrange300,
      'Infectious / Tropical': PdfColors.yellow700,
      'Congenital / Developmental': PdfColors.lightGreen300,
    };

    PdfColor categoryColor(String cat) =>
        categoryColors[cat] ?? PdfColors.grey400;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Family Medical History',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800,
                  ),
                ),
                pw.Text(
                  'Generated by Vetviona  ·  $now',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.Divider(color: PdfColors.green800),
            pw.SizedBox(height: 4),
            // Disclaimer
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.orange400),
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4)),
                color: PdfColors.orange50,
              ),
              child: pw.Text(
                '⚠  IMPORTANT: This document is a personal family health history record for '
                'informational and genealogical purposes ONLY. It is NOT medical advice and '
                'should NOT be used to diagnose or treat any condition. Always consult a '
                'qualified healthcare professional for medical guidance.',
                style: pw.TextStyle(
                    fontSize: 8, color: PdfColors.orange900),
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
        build: (ctx) {
          if (personsWithConditions.isEmpty) {
            return [
              pw.Text('No medical conditions have been recorded yet.',
                  style: pw.TextStyle(color: PdfColors.grey600)),
            ];
          }

          final widgets = <pw.Widget>[];

          for (final person in personsWithConditions) {
            final conditions = provider.medicalConditionsFor(person.id);

            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 12, bottom: 4),
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: const pw.Border(
                    left: pw.BorderSide(
                        color: PdfColors.green700, width: 4),
                  ),
                ),
                child: pw.Text(
                  person.name,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
              ),
            );

            // Table of conditions for this person
            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: [
                  'Condition',
                  'Category',
                  'Age of Onset',
                  'Notes',
                  'Records'
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.green700),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                data: conditions.map((mc) {
                  return [
                    mc.condition,
                    mc.category,
                    mc.ageOfOnset ?? '—',
                    mc.notes ?? '—',
                    mc.attachmentPaths.isEmpty
                        ? '—'
                        : '${mc.attachmentPaths.length} file${mc.attachmentPaths.length == 1 ? '' : 's'}',
                  ];
                }).toList(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.5),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(2.5),
                  4: const pw.FlexColumnWidth(1),
                },
                rowDecoration: (idx, _) => idx % 2 == 0
                    ? null
                    : const pw.BoxDecoration(
                        color: PdfColors.grey100),
                border: pw.TableBorder.all(
                    color: PdfColors.grey300, width: 0.5),
              ),
            );
          }

          // ── Summary by category ──────────────────────────────────────
          widgets.add(pw.SizedBox(height: 16));
          widgets.add(
            pw.Text(
              'Summary by Category',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
          );
          widgets.add(pw.Divider(color: PdfColors.green400));

          final byCategory = <String, int>{};
          for (final mc in provider.medicalConditions) {
            byCategory[mc.category] =
                (byCategory[mc.category] ?? 0) + 1;
          }
          final sortedCats = byCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          widgets.add(
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sortedCats.map((e) {
                final color = categoryColor(e.key);
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    '${e.key}: ${e.value}',
                    style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          );

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  static void _openConditionSheet(
    BuildContext context,
    TreeProvider provider,
    String? preselectedPersonId,
    MedicalCondition? existing,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ConditionSheet(
        provider: provider,
        preselectedPersonId: preselectedPersonId,
        existing: existing,
      ),
    );
  }
}

// ── Disclaimer banner ────────────────────────────────────────────────────────

class _DisclaimerBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const _DisclaimerBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.tertiaryContainer.withOpacity(0.6),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 18, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is a personal family history tool for plotting inherited '
              'conditions across generations — not a medical database. '
              'Nothing here constitutes medical advice. '
              'Always consult a qualified healthcare professional.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                  ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                size: 16, color: colorScheme.onTertiaryContainer),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Dismiss',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ── By-person list ───────────────────────────────────────────────────────────

class _AllPersonsList extends StatelessWidget {
  final TreeProvider provider;
  const _AllPersonsList({required this.provider});

  @override
  Widget build(BuildContext context) {
    final persons = provider.persons
        .where((p) => provider.medicalConditionsFor(p.id).isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (persons.isEmpty) {
      return const _EmptyState(
          message: 'No medical conditions recorded yet.\nTap + to add one.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: persons.length,
      itemBuilder: (context, i) {
        final person = persons[i];
        final conditions = provider.medicalConditionsFor(person.id);
        return _PersonTile(
          person: person,
          conditions: conditions,
          provider: provider,
        );
      },
    );
  }
}

// ── By-category list ─────────────────────────────────────────────────────────

class _ByCategoryList extends StatelessWidget {
  final TreeProvider provider;
  const _ByCategoryList({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.medicalConditions.isEmpty) {
      return const _EmptyState(
          message: 'No medical conditions recorded yet.\nTap + to add one.');
    }

    final byCategory = <String, List<MedicalCondition>>{};
    for (final mc in provider.medicalConditions) {
      (byCategory[mc.category] ??= []).add(mc);
    }
    final categories = byCategory.keys.toList()..sort();
    final personMap = {for (final p in provider.persons) p.id: p};
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final category = categories[i];
        final items = byCategory[category]!;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ExpansionTile(
            leading:
                Icon(_categoryIcon(category), color: colorScheme.primary),
            title: Text(category,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${items.length} condition${items.length == 1 ? '' : 's'}'),
            children: items.map((mc) {
              final person = personMap[mc.personId];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24),
                title: Text(mc.condition),
                subtitle: Text(person?.name ?? mc.personId),
                trailing: _conditionTrailing(context, mc, provider),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ── Per-person conditions list ───────────────────────────────────────────────

class _PersonConditionsList extends StatelessWidget {
  final TreeProvider provider;
  final String personId;
  const _PersonConditionsList(
      {required this.provider, required this.personId});

  @override
  Widget build(BuildContext context) {
    final conditions = provider.medicalConditionsFor(personId);
    if (conditions.isEmpty) {
      return const _EmptyState(
          message:
              'No conditions recorded for this person.\nTap + to add one.');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: conditions
          .map((mc) =>
              _ConditionCard(condition: mc, provider: provider))
          .toList(),
    );
  }
}

// ── Person tile ───────────────────────────────────────────────────────────────

class _PersonTile extends StatelessWidget {
  final Person person;
  final List<MedicalCondition> conditions;
  final TreeProvider provider;

  const _PersonTile({
    required this.person,
    required this.conditions,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Text(person.name.isNotEmpty
              ? person.name[0].toUpperCase()
              : '?'),
        ),
        title: Text(person.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${conditions.length} condition${conditions.length == 1 ? '' : 's'}'),
        children: conditions
            .map((mc) =>
                _ConditionCard(condition: mc, provider: provider))
            .toList(),
      ),
    );
  }
}

// ── Condition card ────────────────────────────────────────────────────────────

class _ConditionCard extends StatelessWidget {
  final MedicalCondition condition;
  final TreeProvider provider;

  const _ConditionCard(
      {required this.condition, required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: ListTile(
          leading: Icon(_categoryIcon(condition.category),
              color: colorScheme.primary),
          title: Text(condition.condition,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(condition.category,
                  style: TextStyle(
                      color: colorScheme.primary, fontSize: 12)),
              if (condition.ageOfOnset != null &&
                  condition.ageOfOnset!.isNotEmpty)
                Text('Age of onset: ${condition.ageOfOnset}',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant)),
              if (condition.notes != null &&
                  condition.notes!.isNotEmpty)
                Text(condition.notes!,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              if (condition.attachmentPaths.isNotEmpty) ...[
                const SizedBox(height: 4),
                _AttachmentChip(
                  count: condition.attachmentPaths.length,
                  onTap: () => _showAttachmentsDialog(
                      context, condition),
                ),
              ],
            ],
          ),
          trailing: _conditionTrailing(context, condition, provider),
          isThreeLine: true,
        ),
      ),
    );
  }
}

void _showAttachmentsDialog(BuildContext context, MedicalCondition mc) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('${mc.condition} — Attached Files'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: mc.attachmentPaths.length,
          itemBuilder: (context, i) {
            final path = mc.attachmentPaths[i];
            final fileName = path.split('/').last.split('\\').last;
            final isImage =
                ['jpg', 'jpeg', 'png', 'heic', 'webp']
                    .contains(path.split('.').last.toLowerCase());
            return ListTile(
              leading: isImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(path),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    )
                  : const Icon(Icons.attach_file),
              title: Text(fileName,
                  style: const TextStyle(fontSize: 13)),
              onTap: isImage
                  ? () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.file(File(path)),
                          ),
                        ),
                      );
                    }
                  : null,
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    ),
  );
}

Widget _conditionTrailing(
    BuildContext context, MedicalCondition mc, TreeProvider provider) {
  final colorScheme = Theme.of(context).colorScheme;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18),
        tooltip: 'Edit',
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _ConditionSheet(
            provider: provider,
            preselectedPersonId: mc.personId,
            existing: mc,
          ),
        ),
      ),
      IconButton(
        icon:
            Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
        tooltip: 'Delete',
        onPressed: () => provider.deleteMedicalCondition(mc.id),
      ),
    ],
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle),
              child: Icon(Icons.local_hospital_outlined,
                  size: 40, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit sheet ──────────────────────────────────────────────────────────

class _ConditionSheet extends StatefulWidget {
  final TreeProvider provider;
  final String? preselectedPersonId;
  final MedicalCondition? existing;

  const _ConditionSheet({
    required this.provider,
    required this.preselectedPersonId,
    required this.existing,
  });

  @override
  State<_ConditionSheet> createState() => _ConditionSheetState();
}

class _ConditionSheetState extends State<_ConditionSheet> {
  late TextEditingController _conditionController;
  late TextEditingController _ageController;
  late TextEditingController _notesController;
  String? _selectedPersonId;
  String _selectedCategory = MedicalCondition.categories.first;
  late List<String> _attachmentPaths;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _conditionController = TextEditingController(text: e?.condition ?? '');
    _ageController = TextEditingController(text: e?.ageOfOnset ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _selectedPersonId = e?.personId ?? widget.preselectedPersonId;
    _selectedCategory = e?.category ?? MedicalCondition.categories.first;
    _attachmentPaths = List<String>.from(e?.attachmentPaths ?? []);
  }

  @override
  void dispose() {
    _conditionController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Opens a file picker so the user can attach medical records / scans.
  Future<void> _pickAttachments() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp',
        'doc', 'docx', 'txt', 'csv',
      ],
    );
    if (result != null) {
      final paths = result.files
          .map((f) => f.path)
          .whereType<String>()
          .toList();
      if (paths.isNotEmpty) {
        setState(() => _attachmentPaths.addAll(paths));
      }
    }
  }

  Future<void> _save() async {
    if (_conditionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a condition name.')),
      );
      return;
    }
    if (_selectedPersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a person.')),
      );
      return;
    }
    final mc = MedicalCondition(
      id: widget.existing?.id ?? const Uuid().v4(),
      personId: _selectedPersonId!,
      condition: _conditionController.text.trim(),
      category: _selectedCategory,
      ageOfOnset: _ageController.text.trim().isEmpty
          ? null
          : _ageController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      attachmentPaths: _attachmentPaths,
    );
    if (widget.existing == null) {
      await widget.provider.addMedicalCondition(mc);
    } else {
      await widget.provider.updateMedicalCondition(mc);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final persons = [...widget.provider.persons]
      ..sort((a, b) => a.name.compareTo(b.name));
    final colorScheme = Theme.of(context).colorScheme;
    final suggestions =
        MedicalCondition.suggestions[_selectedCategory] ?? [];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  widget.existing == null
                      ? 'Add Medical Condition'
                      : 'Edit Medical Condition',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            // Inline disclaimer
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14,
                      color: colorScheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For family history tracking only. Not medical advice.',
                      style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            // Person picker (only if not pre-selected)
            if (widget.preselectedPersonId == null)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText: 'Person',
                    border: OutlineInputBorder()),
                value: _selectedPersonId,
                items: persons
                    .map((p) =>
                        DropdownMenuItem(value: p.id, child: Text(p.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPersonId = v),
              )
            else
              _labelRow(
                  'Person',
                  widget.provider.persons
                      .firstWhere(
                          (p) => p.id == widget.preselectedPersonId,
                          orElse: () =>
                              Person(id: '', name: 'Unknown'))
                      .name),
            const SizedBox(height: 12),
            // Category
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'Category', border: OutlineInputBorder()),
              value: _selectedCategory,
              items: MedicalCondition.categories
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedCategory = v ?? _selectedCategory),
            ),
            // Suggestion chips
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Common conditions',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: suggestions.map((s) {
                  final isSelected =
                      _conditionController.text.trim() == s;
                  return FilterChip(
                    label: Text(s, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _conditionController.text = s),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            // Condition name
            TextFormField(
              controller: _conditionController,
              decoration: const InputDecoration(
                labelText: 'Condition',
                hintText: 'Enter or pick from suggestions above',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            // Age of onset
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Age of onset (optional)',
                hintText: 'e.g. 45, childhood, unknown',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            // ── Medical Records / Attachments ────────────────────────────
            _AttachmentsSection(
              paths: _attachmentPaths,
              onAdd: _pickAttachments,
              onRemove: (i) => setState(() => _attachmentPaths.removeAt(i)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _labelRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// ── Attachments section (inside the add/edit sheet) ─────────────────────────

class _AttachmentsSection extends StatelessWidget {
  final List<String> paths;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _AttachmentsSection({
    required this.paths,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Medical Records & Test Results',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Attach'),
              onPressed: onAdd,
            ),
          ],
        ),
        if (paths.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'No files attached. Tap Attach to add scans, lab results, or test reports.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          )
        else
          ...paths.asMap().entries.map((entry) {
            final i = entry.key;
            final path = entry.value;
            final fileName = path.split('/').last.split('\\').last;
            final isImage = _isImagePath(path);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: ListTile(
                dense: true,
                leading: isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(path),
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.broken_image_outlined,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Icon(_fileIcon(path), color: colorScheme.primary),
                title: Text(
                  fileName,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _fileTypeLabel(path),
                  style: TextStyle(
                      fontSize: 10, color: colorScheme.onSurfaceVariant),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: colorScheme.error),
                  tooltip: 'Remove',
                  onPressed: () => onRemove(i),
                ),
                onTap: () => _previewFile(context, path),
              ),
            );
          }),
      ],
    );
  }

  void _previewFile(BuildContext context, String path) {
    if (_isImagePath(path)) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.file(File(path),
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, size: 64))),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File: ${path.split('/').last.split('\\').last}'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  bool _isImagePath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'heic', 'webp'].contains(ext);
  }

  IconData _fileIcon(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'doc' || 'docx' => Icons.description_outlined,
      'csv' || 'txt' => Icons.table_chart_outlined,
      _ => Icons.attach_file,
    };
  }

  String _fileTypeLabel(String path) {
    final ext = path.split('.').last.toUpperCase();
    return ext;
  }
}

// ── Attachment chip shown on condition cards ──────────────────────────────────

class _AttachmentChip extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _AttachmentChip({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: colorScheme.secondary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file,
                size: 12, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 3),
            Text(
              '$count file${count == 1 ? '' : 's'}',
              style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _categoryIcon(String category) => switch (category) {
      'Cardiovascular' => Icons.favorite_border,
      'Cancer' => Icons.coronavirus_outlined,
      'Mental Health' => Icons.psychology_outlined,
      'Neurological' => Icons.biotech_outlined,
      'Metabolic / Endocrine' => Icons.science_outlined,
      'Autoimmune / Immune' => Icons.shield_outlined,
      'Respiratory' => Icons.air_outlined,
      'Genetic / Chromosomal' => Icons.account_tree_outlined,
      'Musculoskeletal' => Icons.accessibility_new_outlined,
      'Gastrointestinal' => Icons.restaurant_outlined,
      'Renal / Urological' => Icons.water_drop_outlined,
      'Reproductive / Gynaecological' => Icons.child_care_outlined,
      'Dermatological' => Icons.face_outlined,
      'Sensory (Vision / Hearing)' => Icons.hearing_outlined,
      'Haematological / Blood' => Icons.bloodtype_outlined,
      'Infectious / Tropical' => Icons.bug_report_outlined,
      'Congenital / Developmental' => Icons.baby_changing_station_outlined,
      _ => Icons.local_hospital_outlined,
    };
