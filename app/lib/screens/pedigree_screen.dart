import 'package:flutter/material.dart';
import '../utils/page_routes.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../tree_core/tree_preset.dart';
import 'person_detail_screen.dart';

// ── Pedigree layout constants ─────────────────────────────────────────────────

/// Width of each generation column.
const double _kPedColWidth = 148.0;

/// Gap between adjacent generation columns.
const double _kPedColGap = 20.0;

/// Height of each slot in the rightmost (most-ancestor) generation column.
/// Must accommodate: avatar 36px + spacing 6px + 2-line name ~30px +
/// spacing 2px + birth year ~12px + vertical padding 20px ≈ 106px.
/// 110px gives a comfortable margin and is the minimum unit for all rows.
const double _kPedSlotHeight = 110.0;

/// Canvas padding applied on all four sides.
const double _kPedPadding = 24.0;

class PedigreeScreen extends StatefulWidget {
  final Person? initialPerson;

  /// Visual preset supplied by [FamilyTreeScreen].
  final TreePreset? preset;

  /// Override for the initial max-generations value.
  final int? initialMaxGenerations;

  const PedigreeScreen({
    super.key,
    this.initialPerson,
    this.preset,
    this.initialMaxGenerations,
  });

  @override
  State<PedigreeScreen> createState() => _PedigreeScreenState();
}

class _PedigreeScreenState extends State<PedigreeScreen> {
  Person? _focusedPerson;
  late int _maxGenerations;

  // Controller for the searchable name field.
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusedPerson = widget.initialPerson;
    // Use initialMaxGenerations if provided; otherwise use preset default
    // (capped to 4 for pedigree chart readability) or fall back to 4.
    final presetDefault = widget.preset?.defaultAncestorGens ?? 4;
    _maxGenerations = widget.initialMaxGenerations ?? presetDefault.clamp(2, 6);
  }

  Person _stableDefaultPerson(List<Person> people) {
    final sorted = [...people]..sort((a, b) => a.id.compareTo(b.id));
    return sorted.first;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default to home person if not already set.
    if (_focusedPerson == null) {
      final provider = context.read<TreeProvider>();
      final persons = provider.persons;
      if (persons.isNotEmpty) {
        final homeId = provider.homePersonId;
        final fallback = _stableDefaultPerson(persons);
        _focusedPerson = homeId != null
            ? persons.firstWhere((p) => p.id == homeId, orElse: () => fallback)
            : fallback;
        _searchCtrl.text = _focusedPerson!.name;
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final persons = provider.persons;

    if (persons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pedigree Chart')),
        body: const Center(child: Text('No people in the tree yet.')),
      );
    }

    // Initialise focused person if still null after didChangeDependencies.
    _focusedPerson ??= _stableDefaultPerson(persons);

    final personMap = {for (final p in persons) p.id: p};

    // Re-validate: if the focused person was deleted from the tree, reset.
    if (!personMap.containsKey(_focusedPerson!.id)) {
      _focusedPerson = _stableDefaultPerson(persons);
      _searchCtrl.text = _focusedPerson!.name;
    }

    // Alphabetically sorted list for the dropdown.
    final sortedPersons = [...persons]
      ..sort((a, b) => a.name.compareTo(b.name));

    // Build generation lists — generation[0] = [focusedPerson], generation[1] = parents, etc.
    final generations = <List<Person?>>[];
    List<Person?> current = [_focusedPerson];
    for (int g = 0; g < _maxGenerations; g++) {
      generations.add(current);
      final next = <Person?>[];
      for (final p in current) {
        if (p == null) {
          next.add(null);
          next.add(null);
        } else {
          final ids = p.parentIds;
          next.add(ids.isNotEmpty ? personMap[ids[0]] : null);
          next.add(ids.length > 1 ? personMap[ids[1]] : null);
        }
      }
      current = next;
    }

    // ── Chart dimensions ───────────────────────────────────────────────────────
    // The rightmost column has 2^(maxGenerations-1) slots, each _kPedSlotHeight
    // dp tall. All other columns divide this height equally among their slots.
    final int rightmostCount = 1 << (_maxGenerations - 1);
    final double chartHeight = _kPedSlotHeight * rightmostCount;
    final double chartWidth =
        _maxGenerations * _kPedColWidth +
        (_maxGenerations - 1) * _kPedColGap;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedigree Chart'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Generations',
            initialValue: _maxGenerations,
            icon: const Icon(Icons.layers_outlined),
            onSelected: (v) => setState(() => _maxGenerations = v),
            itemBuilder: (_) => [
              for (int g = 2; g <= 6; g++)
                PopupMenuItem(value: g, child: Text('$g generations')),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Searchable person picker
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) => DropdownMenu<String>(
                controller: _searchCtrl,
                width: constraints.maxWidth,
                enableFilter: true,
                enableSearch: true,
                label: const Text('Focus person'),
                initialSelection: _focusedPerson?.id,
                dropdownMenuEntries: sortedPersons
                    .map(
                      (p) =>
                          DropdownMenuEntry<String>(value: p.id, label: p.name),
                    )
                    .toList(),
                onSelected: (id) {
                  if (id == null) return;
                  final fallback = _stableDefaultPerson(persons);
                  final person = persons.firstWhere(
                    (p) => p.id == id,
                    orElse: () => fallback,
                  );
                  setState(() {
                    _focusedPerson = person;
                    _searchCtrl.text = person.name;
                  });
                },
              ),
            ),
          ),
          Expanded(
            // InteractiveViewer(constrained: false) is the correct pattern for a
            // large, zoomable/pannable canvas.  Do NOT nest a SingleChildScrollView
            // inside it — that fights the InteractiveViewer's own pan gestures and
            // causes the scroll view to receive infinite constraints (it never
            // actually scrolls).  Instead we give the SizedBox explicit
            // chartWidth/chartHeight so InteractiveViewer knows the canvas bounds.
            child: InteractiveViewer(
              constrained: false,
              minScale: 0.2,
              maxScale: 3.0,
              boundaryMargin: const EdgeInsets.all(400),
              child: Padding(
                padding: const EdgeInsets.all(_kPedPadding),
                child: SizedBox(
                  width: chartWidth,
                  height: chartHeight,
                  child: Stack(
                    children: [
                      // ── Connector lines (drawn behind the person boxes) ──────
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _PedigreeLinePainter(
                            maxGenerations: _maxGenerations,
                            chartHeight: chartHeight,
                            lineColor: colorScheme.outline.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ),
                      // ── Person boxes ─────────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int g = 0; g < generations.length; g++) ...[
                            SizedBox(
                              width: _kPedColWidth,
                              child: Column(
                                children: [
                                  for (final person in generations[g])
                                    Expanded(
                                      // ClipRect ensures the box never visually
                                      // overflows into an adjacent row's cell.
                                      child: ClipRect(
                                        child: Center(
                                          child: _PedigreeBox(
                                            person: person,
                                            onReCenter: person == null
                                                ? null
                                                : () => setState(() {
                                                    _focusedPerson = person;
                                                    _searchCtrl.text =
                                                        person.name;
                                                  }),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (g < generations.length - 1)
                              const SizedBox(width: _kPedColGap),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pedigree connector-line painter ──────────────────────────────────────────

/// Draws the classic pedigree chart connector lines on a canvas whose size
/// matches the [SizedBox] that hosts the generation columns.
///
/// For each generation column g (except the last) and each slot i in that
/// column the painter draws:
///
///   child ─── midX ─── parent0
///              │
///             midX ─── parent1
///
/// where midX is the horizontal midpoint of the gap between columns g and g+1.
/// The lines are drawn purely from the slot geometry — no person data is
/// needed, so the structure is always rendered even for "Unknown" ancestors.
class _PedigreeLinePainter extends CustomPainter {
  final int maxGenerations;
  final double chartHeight;
  final Color lineColor;

  const _PedigreeLinePainter({
    required this.maxGenerations,
    required this.chartHeight,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int g = 0; g < maxGenerations - 1; g++) {
      final int slotCount = 1 << g; // 2^g slots in generation g
      final double slotH = chartHeight / slotCount;

      // X coordinates for this column pair.
      final double colRight = g * (_kPedColWidth + _kPedColGap) + _kPedColWidth;
      final double nextColLeft = (g + 1) * (_kPedColWidth + _kPedColGap);
      final double midX = colRight + _kPedColGap / 2;

      for (int i = 0; i < slotCount; i++) {
        // Y centers.
        final double childY = (i + 0.5) * slotH;
        final double parent0Y = (i + 0.25) * slotH;
        final double parent1Y = (i + 0.75) * slotH;

        // Horizontal from child right-edge → midX.
        canvas.drawLine(Offset(colRight, childY), Offset(midX, childY), paint);

        // Vertical bus connecting the two parent entry points.
        canvas.drawLine(Offset(midX, parent0Y), Offset(midX, parent1Y), paint);

        // Horizontal from midX → each parent left-edge.
        canvas.drawLine(
          Offset(midX, parent0Y),
          Offset(nextColLeft, parent0Y),
          paint,
        );
        canvas.drawLine(
          Offset(midX, parent1Y),
          Offset(nextColLeft, parent1Y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PedigreeLinePainter old) =>
      old.maxGenerations != maxGenerations ||
      old.chartHeight != chartHeight ||
      old.lineColor != lineColor;
}

// ── Person card ───────────────────────────────────────────────────────────────

class _PedigreeBox extends StatelessWidget {
  final Person? person;
  final VoidCallback? onReCenter;

  const _PedigreeBox({required this.person, this.onReCenter});

  Color _nodeColor(ColorScheme colorScheme) {
    if (person == null) return colorScheme.surfaceContainerHighest;
    if (person!.gender?.toLowerCase() == 'male') return colorScheme.primary;
    if (person!.gender?.toLowerCase() == 'female') return colorScheme.error;
    return colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _nodeColor(colorScheme);

    if (person == null) {
      return Container(
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: 28,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              'Unknown',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        fadeSlideRoute(builder: (_) => PersonDetailScreen(person: person)),
      ),
      onLongPress: onReCenter,
      child: Container(
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.2),
              child: Text(
                person!.name.isNotEmpty ? person!.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              person!.name,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (person!.birthDate != null) ...[
              const SizedBox(height: 2),
              Text(
                'b. ${person!.birthDate!.year}',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
