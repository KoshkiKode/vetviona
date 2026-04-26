// app/lib/screens/fan_chart_screen.dart
//
// Radial fan chart for ancestors or descendants.
//
// View modes
// ──────────
//  • Direction: ancestors (parents radiating outward from the home person)
//    or descendants (children radiating outward).
//  • Sweep:     180° (classic half-circle), 270° (three-quarter), or 360°
//    (full circle).
//  • Generations: 2 – 8 rings.
//  • Root person: any person in the tree.
//
// Tapping any arc segment opens that person's detail screen.  The chart can
// also be exported to a high-resolution vector PDF via the printing package.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../utils/page_routes.dart';
import 'person_detail_screen.dart';

// ── Canvas constants ──────────────────────────────────────────────────────────
const double _kCenterRadius = 46.0;
const double _kCanvasW = 900.0;
const double _kCanvasH = 900.0;
final Offset _kCenter = Offset(_kCanvasW / 2, _kCanvasH / 2);
const double _kMaxOuterRadius = 400.0;

// ── View mode enums ───────────────────────────────────────────────────────────
enum FanDirection { ancestors, descendants }

enum FanSweep { half, threeQuarter, full }

extension on FanSweep {
  /// Total sweep angle in radians.
  double get angle {
    switch (this) {
      case FanSweep.half:
        return math.pi;
      case FanSweep.threeQuarter:
        return math.pi * 1.5;
      case FanSweep.full:
        return math.pi * 2;
    }
  }

  String get label {
    switch (this) {
      case FanSweep.half:
        return '180°';
      case FanSweep.threeQuarter:
        return '270°';
      case FanSweep.full:
        return '360°';
    }
  }
}

// ── Fan chart screen ──────────────────────────────────────────────────────────

/// Fan chart showing the home person at centre with ancestors (or
/// descendants) radiating outward in concentric rings.
class FanChartScreen extends StatefulWidget {
  /// Initial generation depth (rings) to render.  Clamped to [2, 8].
  /// When null the chart starts with 4 rings.
  final int? initialGenerations;

  /// Initial fan sweep.  Defaults to half-circle (180°).
  final FanSweep initialSweep;

  /// Initial fan direction (ancestors vs descendants).
  final FanDirection initialDirection;

  const FanChartScreen({
    super.key,
    this.initialGenerations,
    this.initialSweep = FanSweep.half,
    this.initialDirection = FanDirection.ancestors,
  });

  @override
  State<FanChartScreen> createState() => _FanChartScreenState();
}

class _FanChartScreenState extends State<FanChartScreen> {
  final TransformationController _txCtrl = TransformationController();
  late int _maxGenerations;
  late FanSweep _sweep;
  late FanDirection _direction;
  String? _rootPersonId;

  // Cached per-segment data built in build() and used for hit-testing.
  final List<_SegmentHit> _hitSegments = [];

  @override
  void initState() {
    super.initState();
    _maxGenerations = (widget.initialGenerations ?? 4).clamp(2, 8);
    _sweep = widget.initialSweep;
    _direction = widget.initialDirection;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  @override
  void didUpdateWidget(covariant FanChartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the chart in sync with the shared FamilyTreeScreen settings.
    if (widget.initialGenerations != null &&
        widget.initialGenerations != oldWidget.initialGenerations) {
      setState(
        () => _maxGenerations = widget.initialGenerations!.clamp(2, 8),
      );
    }
  }

  @override
  void dispose() {
    _txCtrl.dispose();
    super.dispose();
  }

  void _fitView() {
    final viewportSize = context.size;
    if (viewportSize == null) return;
    const padding = 24.0;
    final sx = (viewportSize.width - padding * 2) / _kCanvasW;
    final sy = (viewportSize.height - padding * 2) / _kCanvasH;
    final scale = (sx < sy ? sx : sy).clamp(0.1, 1.0);
    final scaledW = _kCanvasW * scale;
    final scaledH = _kCanvasH * scale;
    final tx = (viewportSize.width - scaledW) / 2;
    final ty = (viewportSize.height - scaledH) / 2;
    _txCtrl.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0.0, 1.0)
      ..scaleByDouble(scale, scale, scale, 1.0);
  }

  Person _stableDefaultPerson(List<Person> people) {
    final sorted = [...people]..sort((a, b) => a.id.compareTo(b.id));
    return sorted.first;
  }

  // ── Slot count per generation ──────────────────────────────────────────────
  /// Returns the number of slots in [gen] for the active direction.
  ///
  /// Ancestors always double per generation (2^gen) — every person has two
  /// biological parents.  Descendants are far less regular: a person can
  /// have any number of children, so the slot count is determined by the
  /// actual tree data via [_buildDescendantMap].  This helper returns the
  /// declared upper bound used by the painter's fallback geometry.
  int _slotsAtGen(int gen) => 1 << gen;

  // ── Ancestor map build ──────────────────────────────────────────────────────

  /// Returns a map of `(generation, slotIndex) → Person?` for ancestors.
  ///
  /// Generation 0 = root, generation 1 = parents (2 slots), etc.
  /// Slot 0 is always the first parent.
  static Map<(int, int), Person?> _buildAncestorMap(
    Person root,
    Map<String, Person> pm,
    int maxGen,
  ) {
    final result = <(int, int), Person?>{};
    result[(0, 0)] = root;

    for (int gen = 0; gen < maxGen; gen++) {
      final count = 1 << gen; // 2^gen
      for (int slot = 0; slot < count; slot++) {
        final person = result[(gen, slot)];
        final parentIds = person?.parentIds ?? [];
        result[(gen + 1, slot * 2)] =
            pm[parentIds.isNotEmpty ? parentIds[0] : ''];
        result[(gen + 1, slot * 2 + 1)] =
            pm[parentIds.length > 1 ? parentIds[1] : ''];
      }
    }
    return result;
  }

  /// Returns a map of `(generation, slotIndex) → Person?` for descendants.
  ///
  /// Each generation's slot count grows with the actual children present:
  /// gen N has `sum over gen N-1 of max(1, childCount)` slots.  Empty slots
  /// (children that don't exist) are filled with `null` so the geometry
  /// remains regular and tappable.
  static Map<(int, int), Person?> _buildDescendantMap(
    Person root,
    Map<String, Person> pm,
    int maxGen,
  ) {
    final result = <(int, int), Person?>{};
    result[(0, 0)] = root;

    // children[gen] is the list of (slotIndex, person?) at that generation.
    final List<List<MapEntry<int, Person?>>> byGen = [
      [MapEntry(0, root)],
    ];

    for (int gen = 0; gen < maxGen; gen++) {
      final parents = byGen[gen];
      final next = <MapEntry<int, Person?>>[];
      int slotCounter = 0;
      for (final entry in parents) {
        final p = entry.value;
        final childIds = p?.childIds ?? const <String>[];
        if (childIds.isEmpty) {
          // Reserve a single placeholder slot so the wedge above stays
          // visually aligned with its parent.
          result[(gen + 1, slotCounter)] = null;
          next.add(MapEntry(slotCounter, null));
          slotCounter++;
        } else {
          for (final cid in childIds) {
            final child = pm[cid];
            result[(gen + 1, slotCounter)] = child;
            next.add(MapEntry(slotCounter, child));
            slotCounter++;
          }
        }
      }
      byGen.add(next);
    }
    return result;
  }

  Map<(int, int), Person?> _buildMap(
    Person root,
    Map<String, Person> pm,
  ) =>
      _direction == FanDirection.ancestors
          ? _buildAncestorMap(root, pm, _maxGenerations)
          : _buildDescendantMap(root, pm, _maxGenerations);

  /// Counts the actual slots that exist at [gen] in [map].  For ancestors
  /// this is always `2^gen`; for descendants it varies with the tree.
  int _slotCountAt(int gen, Map<(int, int), Person?> map) {
    if (_direction == FanDirection.ancestors) return _slotsAtGen(gen);
    int n = 0;
    while (map.containsKey((gen, n))) {
      n++;
    }
    return n == 0 ? 1 : n;
  }

  // ── Hit-testing ─────────────────────────────────────────────────────────────

  void _handleTap(TapUpDetails details, Map<String, Person> pm) {
    // Convert tap position to the fan-chart canvas coordinate space.
    final local = _txCtrl.toScene(details.localPosition);

    // Check home-person circle first.
    final homeDist = (local - _kCenter).distance;
    if (homeDist <= _kCenterRadius) {
      final hit = _hitSegments
          .where((s) => s.gen == 0 && s.slot == 0)
          .firstOrNull;
      if (hit?.person != null) {
        Navigator.push(
          context,
          fadeSlideRoute(
            builder: (_) => PersonDetailScreen(person: hit!.person!),
          ),
        );
      }
      return;
    }

    // Check each arc segment.
    if (homeDist > _kCenterRadius && homeDist <= _kMaxOuterRadius) {
      final ringWidth = (_kMaxOuterRadius - _kCenterRadius) / _maxGenerations;
      final gen = ((homeDist - _kCenterRadius) / ringWidth).ceil().clamp(
        1,
        _maxGenerations,
      );

      // Determine angle relative to the chart's start angle.
      final rawAngle = math.atan2(
        local.dy - _kCenter.dy,
        local.dx - _kCenter.dx,
      );
      // Start angle is computed the same way as in the painter.
      final startAngle = -math.pi / 2 - _sweep.angle / 2;
      // Normalise rawAngle so it lies in [startAngle, startAngle + 2π).
      double a = rawAngle;
      while (a < startAngle) {
        a += 2 * math.pi;
      }
      while (a >= startAngle + 2 * math.pi) {
        a -= 2 * math.pi;
      }
      final angleFromStart = a - startAngle;
      if (angleFromStart < 0 || angleFromStart > _sweep.angle) return;

      final hit = _hitSegments
          .where((s) => s.gen == gen)
          .where((s) {
            final segCount = s.totalSlots;
            final slotSpan = _sweep.angle / segCount;
            final slotStart = s.slot * slotSpan;
            final slotEnd = (s.slot + 1) * slotSpan;
            return angleFromStart >= slotStart && angleFromStart < slotEnd;
          })
          .firstOrNull;
      if (hit?.person != null) {
        Navigator.push(
          context,
          fadeSlideRoute(
            builder: (_) => PersonDetailScreen(person: hit!.person!),
          ),
        );
      }
    }
  }

  // ── PDF export ──────────────────────────────────────────────────────────────

  Future<void> _exportPdf(
    Person root,
    Map<(int, int), Person?> ancestorMap,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _buildFanPdf(root, ancestorMap);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'fan_chart_${_safeFilenamePart(root.name)}',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }

  /// Reduces a person name to characters safe for use in a filename on every
  /// platform (no path separators, control characters, or shell metachars).
  static String _safeFilenamePart(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (cleaned.isEmpty) return 'unknown';
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  /// Builds a single-page A3 landscape PDF with a vector fan chart.
  Future<Uint8List> _buildFanPdf(
    Person root,
    Map<(int, int), Person?> ancestorMap,
  ) async {
    final doc = pw.Document(title: 'Fan Chart — ${root.name}');
    final pageFormat = PdfPageFormat.a3.landscape;
    final usableW = pageFormat.width - 48;
    final usableH = pageFormat.height - 96;
    final scale = math.min(usableW / _kCanvasW, usableH / _kCanvasH);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _direction == FanDirection.ancestors
                    ? 'Ancestor Fan Chart — ${root.name}'
                    : 'Descendant Fan Chart — ${root.name}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Expanded(
                child: pw.Center(
                  child: pw.SizedBox(
                    width: _kCanvasW * scale,
                    height: _kCanvasH * scale,
                    child: pw.CustomPaint(
                      size: PdfPoint(_kCanvasW * scale, _kCanvasH * scale),
                      painter: (canvas, size) => _paintFanPdf(
                        canvas: canvas,
                        size: size,
                        ancestorMap: ancestorMap,
                        slotCounter: _slotCountAt,
                        scale: scale,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  void _paintFanPdf({
    required PdfGraphics canvas,
    required PdfPoint size,
    required Map<(int, int), Person?> ancestorMap,
    required int Function(int, Map<(int, int), Person?>) slotCounter,
    required double scale,
  }) {
    final ringWidth = (_kMaxOuterRadius - _kCenterRadius) / _maxGenerations;
    final cx = _kCenter.dx * scale;
    final cy = size.y - _kCenter.dy * scale; // PDF Y up

    final startAngle = -math.pi / 2 - _sweep.angle / 2;

    for (int gen = _maxGenerations; gen >= 1; gen--) {
      final innerR = (_kCenterRadius + (gen - 1) * ringWidth) * scale;
      final outerR = (_kCenterRadius + gen * ringWidth) * scale;
      final count = slotCounter(gen, ancestorMap);
      final span = _sweep.angle / count;

      for (int slot = 0; slot < count; slot++) {
        final person = ancestorMap[(gen, slot)];
        final segStart = startAngle + slot * span;
        // Convert canvas-frame angle (Y-down) to PDF-frame angle (Y-up):
        // negate.
        final pdfStart = -segStart;
        final pdfSweep = -span;

        final fill = _segmentPdfFill(person, gen);
        canvas
          ..setFillColor(fill)
          ..setStrokeColor(PdfColors.grey400)
          ..setLineWidth(0.4);
        _arcSegmentPdf(
          canvas,
          cx,
          cy,
          innerR,
          outerR,
          pdfStart,
          pdfSweep,
        );
        canvas.fillAndStrokePath();
      }
    }

    // Centre disk.
    canvas
      ..setFillColor(PdfColors.indigo400)
      ..setStrokeColor(PdfColors.indigo700)
      ..setLineWidth(0.8)
      ..drawEllipse(cx, cy, _kCenterRadius * scale, _kCenterRadius * scale)
      ..fillAndStrokePath();
    final home = ancestorMap[(0, 0)];
    if (home != null) {
      final font = canvas.defaultFont;
      if (font != null) {
        canvas.setFillColor(PdfColors.white);
        canvas.drawString(
          font,
          9.0 * scale,
          _shortNamePdf(home.name),
          cx - (_kCenterRadius * 0.7) * scale,
          cy - 3 * scale,
        );
      }
    }
  }

  PdfColor _segmentPdfFill(Person? person, int gen) {
    if (person == null) {
      return PdfColors.grey200;
    }
    final g = person.gender?.toLowerCase();
    if (g == 'male') {
      // Blue palette: lighten the red and green channels for outer rings.
      return _shadeForGen(gen, baseR: 0, baseG: 0, baseB: 255);
    } else if (g == 'female') {
      // Pink palette: keep red strong, lighten green/blue.
      return _shadeForGen(gen, baseR: 255, baseG: 64, baseB: 96);
    }
    // Unknown gender — neutral warm grey palette.
    return _shadeForGen(gen, baseR: 180, baseG: 170, baseB: 150);
  }

  /// Generates a per-generation tint of [baseR],[baseG],[baseB] that gets
  /// lighter (more white) for outer rings.  `gen` 1 → most saturated,
  /// `gen` 8 → most washed out.  Returns an opaque [PdfColor].
  static PdfColor _shadeForGen(
    int gen, {
    required int baseR,
    required int baseG,
    required int baseB,
  }) {
    // Lerp factor: 0.18 (gen 1) → ~0.7 (gen 8) toward white.
    final t = (0.18 + (gen - 1) * 0.075).clamp(0.0, 0.85);
    int mix(int channel) =>
        (channel + (255 - channel) * t).round().clamp(0, 255).toInt();
    return PdfColor.fromInt(
      0xFF000000 | (mix(baseR) << 16) | (mix(baseG) << 8) | mix(baseB),
    );
  }

  static String _shortNamePdf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return name;
    return '${parts.first} ${parts.last}';
  }

  void _arcSegmentPdf(
    PdfGraphics canvas,
    double cx,
    double cy,
    double innerR,
    double outerR,
    double startAngle,
    double sweep,
  ) {
    // Approximate the arc with a polyline; PDF supports arcs but this keeps
    // the renderer dependency-free and is plenty smooth for printing.
    const int steps = 32;
    canvas.moveTo(
      cx + outerR * math.cos(startAngle),
      cy + outerR * math.sin(startAngle),
    );
    for (int i = 1; i <= steps; i++) {
      final a = startAngle + sweep * (i / steps);
      canvas.lineTo(cx + outerR * math.cos(a), cy + outerR * math.sin(a));
    }
    canvas.lineTo(
      cx + innerR * math.cos(startAngle + sweep),
      cy + innerR * math.sin(startAngle + sweep),
    );
    for (int i = steps - 1; i >= 0; i--) {
      final a = startAngle + sweep * (i / steps);
      canvas.lineTo(cx + innerR * math.cos(a), cy + innerR * math.sin(a));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final persons = provider.persons;
    final colorScheme = Theme.of(context).colorScheme;

    if (persons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fan Chart')),
        body: const Center(child: Text('No people in the tree yet.')),
      );
    }

    final pm = {for (final p in persons) p.id: p};
    final fallback = _stableDefaultPerson(persons);
    final homeId = _rootPersonId ?? provider.homePersonId ?? fallback.id;
    final root = pm[homeId] ?? fallback;

    final ancestorMap = _buildMap(root, pm);

    // Rebuild hit segments list.
    _hitSegments.clear();
    for (int gen = 0; gen <= _maxGenerations; gen++) {
      final count = gen == 0 ? 1 : _slotCountAt(gen, ancestorMap);
      for (int slot = 0; slot < count; slot++) {
        _hitSegments.add(
          _SegmentHit(gen, slot, count, ancestorMap[(gen, slot)]),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fan Chart'),
        actions: [
          // Direction toggle
          IconButton(
            tooltip: _direction == FanDirection.ancestors
                ? 'Switch to descendants'
                : 'Switch to ancestors',
            icon: Icon(
              _direction == FanDirection.ancestors
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
            ),
            onPressed: () => setState(
              () => _direction = _direction == FanDirection.ancestors
                  ? FanDirection.descendants
                  : FanDirection.ancestors,
            ),
          ),
          // Sweep selector
          PopupMenuButton<FanSweep>(
            tooltip: 'Sweep angle',
            initialValue: _sweep,
            icon: const Icon(Icons.donut_small_outlined),
            onSelected: (v) => setState(() => _sweep = v),
            itemBuilder: (_) => [
              for (final s in FanSweep.values)
                PopupMenuItem(value: s, child: Text(s.label)),
            ],
          ),
          // Generation depth selector
          PopupMenuButton<int>(
            tooltip: 'Generations',
            initialValue: _maxGenerations,
            icon: const Icon(Icons.layers_outlined),
            onSelected: (v) => setState(() => _maxGenerations = v),
            itemBuilder: (_) => [
              for (int g = 2; g <= 8; g++)
                PopupMenuItem(value: g, child: Text('$g generations')),
            ],
          ),
          // Root person picker
          PopupMenuButton<String>(
            tooltip: 'Change root person',
            icon: const Icon(Icons.person_outline),
            onSelected: (id) => setState(() => _rootPersonId = id),
            itemBuilder: (_) => persons
                .map((p) => PopupMenuItem(value: p.id, child: Text(p.name)))
                .toList(),
          ),
          // Print to PDF
          IconButton(
            tooltip: 'Print to PDF',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => _exportPdf(root, ancestorMap),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _handleTap(details, pm),
        child: InteractiveViewer(
          transformationController: _txCtrl,
          constrained: false,
          minScale: 0.1,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(400),
          child: SizedBox(
            width: _kCanvasW,
            height: _kCanvasH,
            child: CustomPaint(
              painter: _FanPainter(
                ancestorMap: ancestorMap,
                slotCountAt: (g) => _slotCountAt(g, ancestorMap),
                maxGenerations: _maxGenerations,
                sweep: _sweep,
                direction: _direction,
                colorScheme: colorScheme,
              ),
            ),
          ),
        ),
      ),
      // Zoom controls
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'fc_zi',
            onPressed: () => _zoom(1.3),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 6),
          FloatingActionButton.small(
            heroTag: 'fc_zo',
            onPressed: () => _zoom(1 / 1.3),
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 6),
          FloatingActionButton.small(
            heroTag: 'fc_fit',
            onPressed: _fitView,
            tooltip: 'Fit to view',
            child: const Icon(Icons.fit_screen),
          ),
        ],
      ),
    );
  }

  void _zoom(double factor) {
    final s = _txCtrl.value.getMaxScaleOnAxis();
    final ns = (s * factor).clamp(0.1, 5.0);
    _txCtrl.value = _txCtrl.value.clone()
      ..scaleByDouble(ns / s, ns / s, ns / s, 1.0);
  }
}

// ── Hit segment record ────────────────────────────────────────────────────────

class _SegmentHit {
  final int gen;
  final int slot;
  final int totalSlots;
  final Person? person;
  const _SegmentHit(this.gen, this.slot, this.totalSlots, this.person);
}

// ── Fan chart painter ─────────────────────────────────────────────────────────

class _FanPainter extends CustomPainter {
  final Map<(int, int), Person?> ancestorMap;
  final int Function(int gen) slotCountAt;
  final int maxGenerations;
  final FanSweep sweep;
  final FanDirection direction;
  final ColorScheme colorScheme;

  const _FanPainter({
    required this.ancestorMap,
    required this.slotCountAt,
    required this.maxGenerations,
    required this.sweep,
    required this.direction,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ringWidth = (_kMaxOuterRadius - _kCenterRadius) / maxGenerations;
    // Centre the sweep at the top (12 o'clock) for ancestors, bottom for
    // descendants — matches genealogical convention.
    final centreAngle = direction == FanDirection.ancestors
        ? -math.pi / 2
        : math.pi / 2;
    final startAngle = centreAngle - sweep.angle / 2;

    // ── Generation rings ──────────────────────────────────────────────────────
    for (int gen = maxGenerations; gen >= 1; gen--) {
      final innerR = _kCenterRadius + (gen - 1) * ringWidth;
      final outerR = _kCenterRadius + gen * ringWidth;
      final count = slotCountAt(gen);
      if (count <= 0) continue;
      final segSpan = sweep.angle / count;

      for (int slot = 0; slot < count; slot++) {
        final person = ancestorMap[(gen, slot)];
        final segStart = startAngle + slot * segSpan;

        _drawSegment(
          canvas,
          innerR: innerR,
          outerR: outerR,
          startAngle: segStart,
          sweepAngle: segSpan,
          person: person,
          gen: gen,
        );

        if (person != null && ringWidth > 30) {
          _drawLabel(
            canvas,
            person,
            innerR,
            outerR,
            segStart,
            segSpan,
            gen,
            ringWidth,
          );
        }
      }
    }

    // ── Home person circle ────────────────────────────────────────────────────
    final home = ancestorMap[(0, 0)];
    final homePaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(_kCenter, _kCenterRadius, homePaint);
    canvas.drawCircle(
      _kCenter,
      _kCenterRadius,
      Paint()
        ..color = colorScheme.primaryContainer
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    if (home != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: _shortName(home.name),
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      tp.layout(maxWidth: _kCenterRadius * 1.7);
      tp.paint(canvas, _kCenter.translate(-tp.width / 2, -tp.height / 2));
    }

    // ── Outer border arc ──────────────────────────────────────────────────────
    final borderPaint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final outerRect = Rect.fromCircle(
      center: _kCenter,
      radius: _kMaxOuterRadius,
    );
    canvas.drawArc(outerRect, startAngle, sweep.angle, false, borderPaint);
    if (sweep != FanSweep.full) {
      // Closing chord lines from the centre.
      canvas.drawLine(
        _kCenter,
        _kCenter.translate(
          _kMaxOuterRadius * math.cos(startAngle),
          _kMaxOuterRadius * math.sin(startAngle),
        ),
        borderPaint,
      );
      canvas.drawLine(
        _kCenter,
        _kCenter.translate(
          _kMaxOuterRadius * math.cos(startAngle + sweep.angle),
          _kMaxOuterRadius * math.sin(startAngle + sweep.angle),
        ),
        borderPaint,
      );
    }
  }

  void _drawSegment(
    Canvas canvas, {
    required double innerR,
    required double outerR,
    required double startAngle,
    required double sweepAngle,
    required Person? person,
    required int gen,
  }) {
    final fillColor = person == null
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : person.gender?.toLowerCase() == 'male'
        ? colorScheme.primary.withValues(alpha: 0.18 + gen * 0.04)
        : person.gender?.toLowerCase() == 'female'
        ? colorScheme.error.withValues(alpha: 0.18 + gen * 0.04)
        : colorScheme.secondary.withValues(alpha: 0.18 + gen * 0.04);

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    final path = _arcSegmentPath(innerR, outerR, startAngle, sweepAngle);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  Path _arcSegmentPath(
    double innerR,
    double outerR,
    double startAngle,
    double sweepAngle,
  ) {
    final innerRect = Rect.fromCircle(center: _kCenter, radius: innerR);
    final outerRect = Rect.fromCircle(center: _kCenter, radius: outerR);
    final path = Path();
    path.moveTo(
      _kCenter.dx + outerR * math.cos(startAngle),
      _kCenter.dy + outerR * math.sin(startAngle),
    );
    path.arcTo(outerRect, startAngle, sweepAngle, false);
    path.lineTo(
      _kCenter.dx + innerR * math.cos(startAngle + sweepAngle),
      _kCenter.dy + innerR * math.sin(startAngle + sweepAngle),
    );
    path.arcTo(innerRect, startAngle + sweepAngle, -sweepAngle, false);
    path.close();
    return path;
  }

  void _drawLabel(
    Canvas canvas,
    Person person,
    double innerR,
    double outerR,
    double startAngle,
    double sweepAngle,
    int gen,
    double ringWidth,
  ) {
    final midAngle = startAngle + sweepAngle / 2;
    final midR = (innerR + outerR) / 2;
    final textX = _kCenter.dx + midR * math.cos(midAngle);
    final textY = _kCenter.dy + midR * math.sin(midAngle);

    final arcLen = midR * sweepAngle.abs();
    final fontSize = math.min(12.0, math.max(7.0, 14.0 - gen * 1.4));
    final maxW = arcLen.clamp(30.0, ringWidth + arcLen * 0.4);

    final tp = TextPainter(
      text: TextSpan(
        text: _shortName(person.name),
        style: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.85),
          fontSize: fontSize,
          fontWeight: gen <= 2 ? FontWeight.w600 : FontWeight.w400,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout(maxWidth: maxW);

    canvas.save();
    canvas.translate(textX, textY);

    // Rotate text so it reads radially outward, and flip when the angle
    // would otherwise leave the text upside-down.
    double rotation = midAngle + math.pi / 2;
    final twoPiNorm = ((midAngle % (2 * math.pi)) + 2 * math.pi) %
        (2 * math.pi);
    if (twoPiNorm > math.pi / 2 && twoPiNorm < math.pi * 1.5) {
      rotation += math.pi;
    }
    canvas.rotate(rotation);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  static String _shortName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return name;
    final last = parts.last;
    return '${parts.first}\n${last.length > 8 ? '${last.substring(0, 7)}…' : last}';
  }

  @override
  bool shouldRepaint(_FanPainter old) =>
      old.ancestorMap.length != ancestorMap.length ||
      old.maxGenerations != maxGenerations ||
      old.sweep != sweep ||
      old.direction != direction;
}
