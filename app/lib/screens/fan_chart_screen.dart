// app/lib/screens/fan_chart_screen.dart
//
// Radial ancestor fan chart.
//
// The home person appears in a circle at the centre.  Each generation of
// ancestors fills a concentric ring divided into equal arc segments.  Up to
// [_maxGenerations] rings are shown.
//
// Tapping any arc segment navigates to the PersonDetailScreen for that person.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../utils/page_routes.dart';
import 'person_detail_screen.dart';

// ── Canvas constants ──────────────────────────────────────────────────────────
const double _kCenterRadius = 46.0;
const double _kCanvasW = 900.0;
const double _kCanvasH = 780.0;
// Centre point — leave room for the top arcs.
final Offset _kCenter = Offset(_kCanvasW / 2, _kCanvasH * 0.60);
// Outer radius used by the last generation.
const double _kMaxOuterRadius = 370.0;

// ── Fan chart screen ──────────────────────────────────────────────────────────

/// Fan chart showing the home person at centre with ancestors radiating
/// outward in concentric half-rings (upper semicircle, father side on the
/// left, mother side on the right).
class FanChartScreen extends StatefulWidget {
  const FanChartScreen({super.key});

  @override
  State<FanChartScreen> createState() => _FanChartScreenState();
}

class _FanChartScreenState extends State<FanChartScreen> {
  final TransformationController _txCtrl = TransformationController();
  int _maxGenerations = 4;
  String? _rootPersonId;

  // Cached per-segment data built in build() and used for hit-testing.
  final List<_SegmentHit> _hitSegments = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
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
      ..translate(tx, ty)
      ..scale(scale);
  }

  // ── Ancestor map build ──────────────────────────────────────────────────────

  /// Returns a map of `(generation, slotIndex) → Person?`.
  ///
  /// Generation 0 = root, generation 1 = parents (2 slots), etc.
  /// Slot 0 is always on the left (father/first-parent) side.
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
              builder: (_) => PersonDetailScreen(person: hit!.person!)),
        );
      }
      return;
    }

    // Check each arc segment.
    if (homeDist > _kCenterRadius && homeDist <= _kMaxOuterRadius) {
      // Determine the angle (-π … 0 for the upper semicircle).
      final angle = math.atan2(
        local.dy - _kCenter.dy,
        local.dx - _kCenter.dx,
      );
      // Only respond in the upper semicircle (negative y relative to centre).
      if (angle >= -math.pi && angle <= 0) {
        final ringWidth =
            (_kMaxOuterRadius - _kCenterRadius) / _maxGenerations;
        final gen =
            ((homeDist - _kCenterRadius) / ringWidth).ceil().clamp(1, _maxGenerations);
        final count = 1 << gen; // 2^gen
        // slot 0 = left (-π side), slot count-1 = right (0 side)
        final slot = ((angle + math.pi) / (math.pi / count)).floor().clamp(0, count - 1);
        final hit = _hitSegments
            .where((s) => s.gen == gen && s.slot == slot)
            .firstOrNull;
        if (hit?.person != null) {
          Navigator.push(
            context,
            fadeSlideRoute(
                builder: (_) => PersonDetailScreen(person: hit!.person!)),
          );
        }
      }
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
    final homeId = _rootPersonId ?? provider.homePersonId ?? persons.first.id;
    final root = pm[homeId] ?? persons.first;

    final ancestorMap = _buildAncestorMap(root, pm, _maxGenerations);

    // Rebuild hit segments list.
    _hitSegments.clear();
    for (int gen = 0; gen <= _maxGenerations; gen++) {
      final count = gen == 0 ? 1 : (1 << gen);
      for (int slot = 0; slot < count; slot++) {
        _hitSegments.add(_SegmentHit(gen, slot, ancestorMap[(gen, slot)]));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fan Chart'),
        actions: [
          // Generation depth selector
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
          // Root person picker
          PopupMenuButton<String>(
            tooltip: 'Change root person',
            icon: const Icon(Icons.person_outline),
            onSelected: (id) =>
                setState(() => _rootPersonId = id),
            itemBuilder: (_) => persons
                .map((p) => PopupMenuItem(
                      value: p.id,
                      child: Text(p.name),
                    ))
                .toList(),
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
                maxGenerations: _maxGenerations,
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
    _txCtrl.value = _txCtrl.value.clone()..scale(ns / s);
  }
}

// ── Hit segment record ────────────────────────────────────────────────────────

class _SegmentHit {
  final int gen;
  final int slot;
  final Person? person;
  const _SegmentHit(this.gen, this.slot, this.person);
}

// ── Fan chart painter ─────────────────────────────────────────────────────────

class _FanPainter extends CustomPainter {
  final Map<(int, int), Person?> ancestorMap;
  final int maxGenerations;
  final ColorScheme colorScheme;

  const _FanPainter({
    required this.ancestorMap,
    required this.maxGenerations,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ringWidth = (_kMaxOuterRadius - _kCenterRadius) / maxGenerations;

    // ── Generation rings ──────────────────────────────────────────────────────
    for (int gen = maxGenerations; gen >= 1; gen--) {
      final innerR = _kCenterRadius + (gen - 1) * ringWidth;
      final outerR = _kCenterRadius + gen * ringWidth;
      final count = 1 << gen; // 2^gen

      for (int slot = 0; slot < count; slot++) {
        final person = ancestorMap[(gen, slot)];

        // Arc angles: fan spans from π (left) to 0 (right) through the top
        // (counterclockwise = negative sweep in Flutter canvas).
        // Slot 0 is leftmost (-π side), slot count-1 is rightmost (0 side).
        final startAngle = math.pi - slot * (math.pi / count);
        final sweepAngle = -(math.pi / count);

        _drawSegment(
          canvas,
          innerR: innerR,
          outerR: outerR,
          startAngle: startAngle,
          sweepAngle: sweepAngle,
          person: person,
          gen: gen,
        );

        // Draw name label if the arc is wide enough.
        if (person != null && ringWidth > 30) {
          _drawLabel(canvas, person, innerR, outerR, startAngle, sweepAngle,
              gen, ringWidth);
        }
      }
    }

    // ── Home person circle ────────────────────────────────────────────────────
    final home = ancestorMap[(0, 0)];
    final homePaint = Paint()
      ..color = colorScheme.primary.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(_kCenter, _kCenterRadius, homePaint);
    canvas.drawCircle(
        _kCenter,
        _kCenterRadius,
        Paint()
          ..color = colorScheme.primaryContainer
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);

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
      tp.paint(
          canvas,
          _kCenter.translate(
              -tp.width / 2, -tp.height / 2));
    }

    // ── Outer border arc ──────────────────────────────────────────────────────
    final borderPaint = Paint()
      ..color = colorScheme.outline.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final outerRect = Rect.fromCircle(
        center: _kCenter, radius: _kMaxOuterRadius);
    canvas.drawArc(outerRect, math.pi, -math.pi, false, borderPaint);
    // Straight base line
    canvas.drawLine(
      _kCenter.translate(-_kMaxOuterRadius, 0),
      _kCenter.translate(_kMaxOuterRadius, 0),
      borderPaint,
    );
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
        ? colorScheme.surfaceContainerHighest.withOpacity(0.35)
        : person.gender?.toLowerCase() == 'male'
            ? colorScheme.primary.withOpacity(0.18 + gen * 0.04)
            : person.gender?.toLowerCase() == 'female'
                ? colorScheme.error.withOpacity(0.18 + gen * 0.04)
                : colorScheme.secondary.withOpacity(0.18 + gen * 0.04);

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = colorScheme.outline.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    final path = _arcSegmentPath(innerR, outerR, startAngle, sweepAngle);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  Path _arcSegmentPath(
      double innerR, double outerR, double startAngle, double sweepAngle) {
    final innerRect = Rect.fromCircle(center: _kCenter, radius: innerR);
    final outerRect = Rect.fromCircle(center: _kCenter, radius: outerR);
    final path = Path();
    // Outer arc start point.
    path.moveTo(
      _kCenter.dx + outerR * math.cos(startAngle),
      _kCenter.dy + outerR * math.sin(startAngle),
    );
    // Outer arc (from startAngle to startAngle + sweepAngle).
    path.arcTo(outerRect, startAngle, sweepAngle, false);
    // Line from outer arc end to inner arc end.
    path.lineTo(
      _kCenter.dx + innerR * math.cos(startAngle + sweepAngle),
      _kCenter.dy + innerR * math.sin(startAngle + sweepAngle),
    );
    // Inner arc (reverse direction).
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
          color: colorScheme.onSurface.withOpacity(0.85),
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

    // Rotate text to read radially outward (perpendicular to the radius).
    // Adjust so text is always right-side up in the upper semicircle.
    double rotation = midAngle + math.pi / 2;
    // If angle is between -π/2 and 0 (right half), flip by π so text reads
    // left-to-right from the viewer's perspective.
    if (midAngle > -math.pi / 2 && midAngle <= 0) {
      rotation += math.pi;
    }
    canvas.rotate(rotation);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  static String _shortName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return name;
    // First name on line 1, last name on line 2 (truncated).
    final last = parts.last;
    return '${parts.first}\n${last.length > 8 ? '${last.substring(0, 7)}…' : last}';
  }

  @override
  bool shouldRepaint(_FanPainter old) =>
      old.ancestorMap.length != ancestorMap.length ||
      old.maxGenerations != maxGenerations;
}
