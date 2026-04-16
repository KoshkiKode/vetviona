import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/partnership.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../services/sync_service.dart';
import '../tree_core/tree_preset.dart';
import '../tree_core/tree_visibility_engine.dart';
import '../utils/page_routes.dart';
import '../widgets/quick_add_person_dialog.dart';
import 'pedigree_screen.dart';
import 'person_detail_screen.dart';
import 'tree_layout.dart';

// Zoom / viewer constants
const double _kMinScale = 0.05;
const double _kMaxScale = 5.0;

/// How far (in logical pixels) the user can pan past the canvas edge in any
/// direction.  Large enough to comfortably explore huge trees.
const double _kBoundaryMargin = 6000.0;

/// Vertical offset of generation row labels above the top of their row.
const double _kGenLabelTopOffset = 20.0;

/// Controls the Bézier S-curve tension: proportional fraction of [dy] used
/// as the control-point offset from each end of the edge.
const double _kEdgeTensionFactor = 0.5;

/// Maximum tension as a fraction of the active row gap, capping how much the
/// curve can bow when rows are very far apart.
const double _kMaxTensionRatio = 0.6;

/// Radius (px) of the couple-knot circle widget (half of its 28 px diameter).
/// All edge geometry that touches the knot uses this value so that the
/// connector lines start/end exactly at the circle boundary.
const double _kCoupleKnotRadius = 14.0;

const double _kEmptySlotTier1Opacity = 0.28;
const double _kEmptySlotOpacityBase = 0.18;
const double _kEmptySlotOpacityMin = 0.08;

// Edge painter — supports bezier, orthogonal, and straight connector styles.
class _EdgePainter extends CustomPainter {
  final Map<String, TreeNodeInfo> nodes;
  final List<TreeEdgeInfo> edges;
  final Color edgeColor;
  final Color coupleColor;
  final TreeEdgeStyle edgeStyle;
  final double nodeWidth;
  final double nodeHeight;

  /// Actual row gap from the active preset — used to scale the bezier tension
  /// cap so curves look proportional at every density setting.
  final double rowGap;

  /// Line thickness for parent→child connectors.  Reads directly from the
  /// active preset so every layout's own stroke weight is honoured.
  final double edgeStrokeWidth;

  _EdgePainter({
    required this.nodes,
    required this.edges,
    required this.edgeColor,
    required this.coupleColor,
    this.edgeStyle = TreeEdgeStyle.bezier,
    this.nodeWidth = kTreeNodeW,
    this.nodeHeight = kTreeNodeH,
    this.rowGap = kTreeRowGap,
    this.edgeStrokeWidth = 1.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final parentPaint = Paint()
      ..color = edgeColor
      ..strokeWidth = edgeStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final couplePaint = Paint()
      ..color = coupleColor
      ..strokeWidth = edgeStrokeWidth + 0.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final edge in edges) {
      final fromNode = nodes[edge.from];
      final toNode = nodes[edge.to];
      if (fromNode == null || toNode == null) continue;

      if (edge.isCouple) {
        // Couple connector: run from the partner card's nearest horizontal
        // edge to the knot circle's nearest edge — nothing passes through a
        // widget.  `toNode` is always the knot; `fromNode` is the partner.
        final knotCx = toNode.x + nodeWidth / 2;
        final knotCy = toNode.y + nodeHeight / 2;
        final fromCy = fromNode.y + nodeHeight / 2;
        final Offset startPt;
        final Offset endPt;
        if (fromNode.x + nodeWidth / 2 < knotCx) {
          // Partner is to the left of the knot.
          startPt = Offset(fromNode.x + nodeWidth, fromCy);
          endPt = Offset(knotCx - _kCoupleKnotRadius, knotCy);
        } else {
          // Partner is to the right of the knot.
          startPt = Offset(fromNode.x, fromCy);
          endPt = Offset(knotCx + _kCoupleKnotRadius, knotCy);
        }
        canvas.drawLine(startPt, endPt, couplePaint);
      } else {
        final fromCx = fromNode.x + nodeWidth / 2;
        // For knot nodes the connector exits from the bottom of the visible
        // 28 px circle (centre + radius), not from the centre of the
        // allocation box, so the line is never hidden inside the circle.
        final fromBot = fromNode.isCoupleKnot
            ? fromNode.y + nodeHeight / 2 + _kCoupleKnotRadius
            : fromNode.y + nodeHeight;
        final toCx = toNode.x + nodeWidth / 2;
        final toTop = toNode.y;

        switch (edgeStyle) {
          case TreeEdgeStyle.bezier:
            // Smooth S-curve — tension capped relative to the *active* row
            // gap so the curve looks proportional at every density setting.
            final dy = (toTop - fromBot).abs();
            final tension = (dy * _kEdgeTensionFactor).clamp(
              0,
              rowGap * _kMaxTensionRatio,
            );
            final path = Path()
              ..moveTo(fromCx, fromBot)
              ..cubicTo(
                fromCx,
                fromBot + tension,
                toCx,
                toTop - tension,
                toCx,
                toTop,
              );
            canvas.drawPath(path, parentPaint);

          case TreeEdgeStyle.orthogonal:
            // Right-angle elbow: down → horizontal → down, with rounded
            // corners for a professional finish.  The horizontal rung sits
            // exactly midway between the two rows (0.5 fraction).
            final midY = fromBot + (toTop - fromBot) * 0.5;
            final dx = (toCx - fromCx).abs();
            if (dx < 1.0) {
              // Nodes are directly above each other — plain vertical line.
              canvas.drawLine(
                Offset(fromCx, fromBot),
                Offset(toCx, toTop),
                parentPaint,
              );
            } else {
              // Rounded-elbow path: clamp radius so it never exceeds 1/3 of
              // the available vertical space or the horizontal distance.
              final r = math.min(6.0, math.min((toTop - fromBot) / 3, dx / 3));
              final hDir = toCx > fromCx ? r : -r;
              final path = Path()
                ..moveTo(fromCx, fromBot)
                ..lineTo(fromCx, midY - r)
                ..quadraticBezierTo(fromCx, midY, fromCx + hDir, midY)
                ..lineTo(toCx - hDir, midY)
                ..quadraticBezierTo(toCx, midY, toCx, midY + r)
                ..lineTo(toCx, toTop);
              canvas.drawPath(path, parentPaint);
            }

          case TreeEdgeStyle.straight:
            // Never draw oblique diagonals in family lines; keep right-angle
            // routing even when "straight" is requested.
            final midY = fromBot + (toTop - fromBot) * 0.5;
            final dx = (toCx - fromCx).abs();
            if (dx < 1.0) {
              canvas.drawLine(
                Offset(fromCx, fromBot),
                Offset(toCx, toTop),
                parentPaint,
              );
            } else {
              final r = math.min(6.0, math.min((toTop - fromBot) / 3, dx / 3));
              final hDir = toCx > fromCx ? r : -r;
              final path = Path()
                ..moveTo(fromCx, fromBot)
                ..lineTo(fromCx, midY - r)
                ..quadraticBezierTo(fromCx, midY, fromCx + hDir, midY)
                ..lineTo(toCx - hDir, midY)
                ..quadraticBezierTo(toCx, midY, toCx, midY + r)
                ..lineTo(toCx, toTop);
              canvas.drawPath(path, parentPaint);
            }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.nodes.length != nodes.length ||
      old.edges.length != edges.length ||
      old.edgeColor != edgeColor ||
      old.coupleColor != coupleColor ||
      old.edgeStyle != edgeStyle ||
      old.nodeWidth != nodeWidth ||
      old.nodeHeight != nodeHeight ||
      old.rowGap != rowGap ||
      old.edgeStrokeWidth != edgeStrokeWidth;
}

// Main Screen
class TreeDiagramScreen extends StatefulWidget {
  /// Optional visual preset override.  When null the screen loads its own
  /// persisted settings (standalone usage).  When provided by [FamilyTreeScreen]
  /// the preset comes from the shared settings strip.
  final TreePreset? preset;

  /// Ancestor generations to show when resetting.  Overrides the preset
  /// default when provided by [FamilyTreeScreen].
  final int? ancestorGens;

  /// Descendant generations to show when resetting.  Overrides the preset
  /// default when provided by [FamilyTreeScreen].
  final int? descendantGens;

  /// Whether to render empty "Add…" add-slots.  Defaults to true when null.
  final bool? showEmptyAddSlots;

  /// How many tiers of empty add-slots to render.  Defaults to 1 when null.
  final int? emptyAddSlotTiers;

  const TreeDiagramScreen({
    super.key,
    this.preset,
    this.ancestorGens,
    this.descendantGens,
    this.showEmptyAddSlots,
    this.emptyAddSlotTiers,
  });
  @override
  State<TreeDiagramScreen> createState() => _TreeDiagramScreenState();
}

class _TreeDiagramScreenState extends State<TreeDiagramScreen> {
  final TransformationController _txCtrl = TransformationController();
  String _searchQuery = '';
  String? _selectedPersonId;
  bool _showLegend = false;

  // ── Layout cache ─────────────────────────────────────────────────────────────
  // The layout computation (BFS + 8 refinement passes) is expensive for large
  // trees.  We cache the result and only recompute when the inputs actually
  // change — primarily when the visible set, person/partnership data, focal
  // person, or active preset changes.  This prevents unnecessary recomputes
  // triggered by SyncService status changes or other unrelated provider pings.
  TreeLayout? _cachedLayout;
  Set<String>? _cachedVisibleIds;
  int _cachedPersonsLen = -1;
  int _cachedPartnershipsLen = -1;
  String? _cachedFocalId;
  TreePreset? _cachedPreset;

  /// Returns true if [newIds] differs from the previously cached visible set.
  bool _visibleIdsChanged(Set<String> newIds) {
    final prev = _cachedVisibleIds;
    if (prev == null || prev.length != newIds.length) return true;
    return !prev.containsAll(newIds);
  }

  // ── Preset / settings ───────────────────────────────────────────────────────
  /// Returns the effective preset: the one passed in by FamilyTreeScreen (if
  /// any), otherwise the Hybrid default (standalone usage).
  TreePreset get _preset => widget.preset ?? TreePreset.classic;

  int get _effectiveAncestorGens =>
      math.min(widget.ancestorGens ?? _preset.defaultAncestorGens, 1);
  int get _effectiveDescendantGens =>
      math.min(widget.descendantGens ?? _preset.defaultDescendantGens, 1);

  // Local toggles that start from the widget params (or defaults) and can be
  // changed in the standalone AppBar.  When hosted in FamilyTreeScreen these
  // are initialised from the shared settings.
  late bool _localShowSlots;
  late int _localEmptyTiers;

  bool get _effectiveShowEmptySlots => _localShowSlots;
  int get _effectiveEmptyTiers => _localEmptyTiers;

  // ── Visibility engine ───────────────────────────────────────────────────────
  /// Central visibility-state manager.  Initialised in didChangeDependencies
  /// from the provider data.
  TreeVisibilityEngine? _engine;

  /// Whether the engine is currently showing all persons (bypassing the home
  /// focus).
  bool _showingAll = false;

  /// Tracks the last known home person ID so we can reset when it changes.
  String? _lastHomePersonId;

  /// Most recently computed layout — used by fit-to-view.
  TreeLayout? _lastLayout;

  /// Last measured body viewport size — used by fit-to-view.
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _localShowSlots = widget.showEmptyAddSlots ?? true;
    _localEmptyTiers = widget.emptyAddSlotTiers ?? 1;
    // Auto-fit the view once the first frame is drawn so the tree is
    // properly centered and scaled on all platforms (especially desktop).
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  @override
  void didUpdateWidget(covariant TreeDiagramScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showEmptyAddSlots != null &&
        widget.showEmptyAddSlots != oldWidget.showEmptyAddSlots) {
      _localShowSlots = widget.showEmptyAddSlots!;
    }
    if (widget.emptyAddSlotTiers != null &&
        widget.emptyAddSlotTiers != oldWidget.emptyAddSlotTiers) {
      _localEmptyTiers = widget.emptyAddSlotTiers!;
    }

    final depthChanged =
        oldWidget.ancestorGens != widget.ancestorGens ||
        oldWidget.descendantGens != widget.descendantGens;
    if (depthChanged) {
      final provider = context.read<TreeProvider>();
      final persons = provider.persons;
      final partnerships = provider.partnerships;
      final effectiveHomeId =
          provider.homePersonId ??
          (persons.isNotEmpty ? persons.first.id : null);
      if (effectiveHomeId == null) return;
      setState(() {
        _showingAll = false;
        _engine = TreeVisibilityEngine(
          persons: persons,
          partnerships: partnerships,
          homePersonId: effectiveHomeId,
        );
        _engine!.resetToHome(
          ancestorGens: _effectiveAncestorGens,
          descendantGens: _effectiveDescendantGens,
        );
        _lastHomePersonId = effectiveHomeId;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<TreeProvider>();
    final effectiveHomeId =
        provider.homePersonId ??
        (provider.persons.isNotEmpty ? provider.persons.first.id : null);

    if (_engine == null) {
      // First init.
      _engine = TreeVisibilityEngine(
        persons: provider.persons,
        partnerships: provider.partnerships,
        homePersonId: effectiveHomeId,
      );
      _engine!.resetToHome(
        ancestorGens: _effectiveAncestorGens,
        descendantGens: _effectiveDescendantGens,
      );
      _lastHomePersonId = effectiveHomeId;
    } else if (effectiveHomeId != _lastHomePersonId) {
      // Home person changed — rebuild visibility from new home.
      _showingAll = false;
      _engine = TreeVisibilityEngine(
        persons: provider.persons,
        partnerships: provider.partnerships,
        homePersonId: effectiveHomeId,
      );
      _engine!.resetToHome(
        ancestorGens: _effectiveAncestorGens,
        descendantGens: _effectiveDescendantGens,
      );
      _lastHomePersonId = effectiveHomeId;
    } else {
      // Data updated but same home — preserve expansion state.
      _engine = _engine!.withUpdatedData(
        persons: provider.persons,
        partnerships: provider.partnerships,
      );
      // If the user had expanded the whole tree, make sure any newly added
      // persons are also included in the visible set.
      if (_showingAll) {
        _engine!.showAll();
      }
    }
  }

  void _resetToHome(List<Person> persons, List<Partnership> partnerships) {
    final effectiveHomeId =
        context.read<TreeProvider>().homePersonId ??
        (persons.isNotEmpty ? persons.first.id : null);
    if (effectiveHomeId == null) return;
    setState(() {
      _showingAll = false;
      _engine = TreeVisibilityEngine(
        persons: persons,
        partnerships: partnerships,
        homePersonId: effectiveHomeId,
      );
      _engine!.resetToHome(
        ancestorGens: _effectiveAncestorGens,
        descendantGens: _effectiveDescendantGens,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  /// Makes all persons in the tree visible at once.
  void _showAll(List<Person> persons) {
    setState(() {
      _showingAll = true;
      _engine!.showAll();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  /// Adds [person]'s parents (and their partners) to the visible set.
  void _expandParents(
    Person person,
    Map<String, Person> personMap,
    List<Partnership> partnerships,
  ) {
    setState(() => _engine!.expandParents(person.id));
  }

  /// Adds [person]'s children (and their partners) to the visible set.
  void _expandChildren(
    Person person,
    Map<String, Person> personMap,
    List<Partnership> partnerships,
  ) {
    setState(() => _engine!.expandChildren(person.id));
  }

  /// Adds [person]'s siblings to the visible set.
  void _expandSiblings(
    Person person,
    Map<String, Person> personMap,
    List<Partnership> partnerships,
  ) {
    setState(() => _engine!.expandSiblings(person.id));
  }

  /// BFS-expands ALL ancestors of [person] (and each ancestor's partners).
  void _expandAllAncestors(
    Person person,
    Map<String, Person> personMap,
    List<Partnership> partnerships,
  ) {
    setState(() => _engine!.expandAllAncestors(person.id));
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  /// BFS-expands ALL descendants of [person].
  void _expandAllDescendants(Person person, Map<String, Person> personMap) {
    setState(() => _engine!.expandAllDescendants(person.id));
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  @override
  void dispose() {
    _txCtrl.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final s = _txCtrl.value.getMaxScaleOnAxis();
    final ns = (s * factor).clamp(_kMinScale, _kMaxScale);
    _txCtrl.value = _txCtrl.value.clone()..scale(ns / s);
  }

  void _resetView() => _txCtrl.value = Matrix4.identity();

  /// Scales and centres the view so all visible nodes fit in the viewport.
  void _fitView() {
    final layout = _lastLayout;
    final vp = _viewportSize;
    if (layout == null || layout.canvasSize == Size.zero || vp == Size.zero) {
      _resetView();
      return;
    }
    const padding = 48.0;
    final sx = (vp.width - padding * 2) / layout.canvasSize.width;
    final sy = (vp.height - padding * 2) / layout.canvasSize.height;
    final scale = (sx < sy ? sx : sy).clamp(_kMinScale, 1.0);
    final scaledW = layout.canvasSize.width * scale;
    final scaledH = layout.canvasSize.height * scale;
    final tx = (vp.width - scaledW) / 2;
    final ty = (vp.height - scaledH) / 2;
    _txCtrl.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);
  }

  void _showPersonSheet(
    BuildContext context,
    Person person,
    Map<String, Person> personMap,
    List<Partnership> partnerships,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasHiddenParents = _engine!.hasHiddenAncestors(person.id);
    final hasHiddenChildren = _engine!.hasHiddenDescendants(person.id);
    final hasHiddenSiblings = _engine!.hasHiddenSiblings(person.id);

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Color avatarBg = colorScheme.secondary;
        if (person.gender?.toLowerCase() == 'male')
          avatarBg = colorScheme.primary;
        if (person.gender?.toLowerCase() == 'female')
          avatarBg = colorScheme.error;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: avatarBg,
                    child: Text(
                      person.name.isNotEmpty
                          ? person.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (person.birthDate != null ||
                            person.deathDate != null)
                          Text(
                            [
                              if (person.birthDate != null)
                                'b. ${person.birthDate!.year}',
                              if (person.deathDate != null)
                                'd. ${person.deathDate!.year}',
                            ].join('  ·  '),
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (person.birthPlace != null)
                          Text(
                            person.birthPlace!,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (person.occupation != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.work_outline,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      person.occupation!,
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              // Primary actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Full Profile'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          fadeSlideRoute(
                            builder: (_) => PersonDetailScreen(person: person),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text('Focus'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedPersonId = person.id;
                          _engine!.focusOn(
                            person.id,
                            ancestorGens: _effectiveAncestorGens,
                            descendantGens: _effectiveDescendantGens,
                          );
                        });
                        _resetView();
                      },
                    ),
                  ),
                ],
              ),
              // Expand actions — only shown when there is something to expand
              if (hasHiddenParents ||
                  hasHiddenChildren ||
                  hasHiddenSiblings) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasHiddenParents)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.keyboard_arrow_up, size: 16),
                        label: const Text('Show Parents'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandParents(person, personMap, partnerships);
                        },
                      ),
                    if (hasHiddenChildren)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        label: const Text('Show Children'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandChildren(person, personMap, partnerships);
                        },
                      ),
                    if (hasHiddenSiblings)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.people_outline, size: 16),
                        label: const Text('Show Siblings'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandSiblings(person, personMap, partnerships);
                        },
                      ),
                  ],
                ),
              ],
              // "Expand all" chain actions
              if (hasHiddenParents || hasHiddenChildren) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasHiddenParents)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.account_tree, size: 16),
                        label: const Text('All Ancestors'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandAllAncestors(person, personMap, partnerships);
                        },
                      ),
                    if (hasHiddenChildren)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.account_tree, size: 16),
                        label: const Text('All Descendants'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandAllDescendants(person, personMap);
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _quickAddFromTree({
    required Person anchor,
    required _TreeQuickRelation relation,
    required int tier,
  }) async {
    final provider = context.read<TreeProvider>();
    final current = provider.persons
        .where((p) => p.id == anchor.id)
        .firstOrNull;
    if (current == null) return;
    if (relation == _TreeQuickRelation.sibling && current.parentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a parent first, then add siblings')),
      );
      return;
    }

    // For son/daughter, find any visible partner of the anchor so we can
    // record both as parents and route the knot→child edge correctly.
    String? visiblePartnerId;
    if (relation == _TreeQuickRelation.son ||
        relation == _TreeQuickRelation.daughter) {
      for (final part in provider.partnerships) {
        String? partnerId;
        if (part.person1Id == current.id) partnerId = part.person2Id;
        if (part.person2Id == current.id) partnerId = part.person1Id;
        if (partnerId != null && _engine!.visibleIds.contains(partnerId)) {
          visiblePartnerId = partnerId;
          break;
        }
      }
    }

    final input = await showQuickAddPersonDialog(
      context,
      title: relation.dialogTitle,
      subtitle: relation.subtitleFor(current.name, tier),
      confirmLabel: relation.confirmLabel,
      initialGender: relation.defaultGender,
    );
    if (input == null) return;

    try {
      final parentIds =
          (relation == _TreeQuickRelation.son ||
              relation == _TreeQuickRelation.daughter)
          ? [current.id, if (visiblePartnerId != null) visiblePartnerId]
          : <String>[];
      final parentRelTypes = {for (final pid in parentIds) pid: 'biological'};

      final created = Person(
        id: '',
        name: input.name,
        gender: input.gender ?? relation.defaultGender,
        parentIds: parentIds,
        parentRelTypes: parentRelTypes,
        childIds:
            relation == _TreeQuickRelation.mom ||
                relation == _TreeQuickRelation.dad
            ? [current.id]
            : [],
      );
      await provider.addPerson(created);

      switch (relation) {
        case _TreeQuickRelation.mom:
        case _TreeQuickRelation.dad:
          if (!current.parentIds.contains(created.id)) {
            current.parentIds.add(created.id);
            current.parentRelTypes[created.id] = 'biological';
            await provider.updatePerson(current);
          }
          break;
        case _TreeQuickRelation.spouse:
          await provider.addPartnership(
            Partnership(id: '', person1Id: current.id, person2Id: created.id),
          );
          break;
        case _TreeQuickRelation.sibling:
          created.parentIds = List<String>.from(current.parentIds);
          created.parentRelTypes = {
            for (final parentId in current.parentIds)
              parentId: current.parentRelType(parentId),
          };
          await provider.updatePerson(created);
          for (final parentId in current.parentIds) {
            final parent = provider.persons
                .where((p) => p.id == parentId)
                .firstOrNull;
            if (parent == null || parent.childIds.contains(created.id))
              continue;
            parent.childIds.add(created.id);
            await provider.updatePerson(parent);
          }
          break;
        case _TreeQuickRelation.son:
        case _TreeQuickRelation.daughter:
          if (!current.childIds.contains(created.id)) {
            current.childIds.add(created.id);
            await provider.updatePerson(current);
          }
          // Also update the partner's childIds if a visible partner was found.
          if (visiblePartnerId != null) {
            final partner = provider.persons
                .where((p) => p.id == visiblePartnerId)
                .firstOrNull;
            if (partner != null && !partner.childIds.contains(created.id)) {
              partner.childIds.add(created.id);
              await provider.updatePerson(partner);
            }
          }
          break;
      }

      if (!mounted) return;
      setState(() {
        _selectedPersonId = current.id;
        _engine!.addVisibleId(created.id);
      });
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  List<Widget> _buildEmptyAddSlots({
    required TreeLayout layout,
    required String anchorId,
    required Map<String, Person> personMap,
    required ColorScheme colorScheme,
  }) {
    if (!_effectiveShowEmptySlots) return const [];
    final anchorNode = layout.nodes[anchorId];
    final anchorPerson = personMap[anchorId];
    if (anchorNode == null || anchorPerson == null) return const [];

    // Determine which parent genders the anchor already has so we don't show
    // a ghost "Add mom?" / "Add dad?" slot when that parent already exists.
    final existingParentGenders = anchorPerson.parentIds
        .map((pid) => personMap[pid]?.gender?.toLowerCase())
        .whereType<String>()
        .toSet();
    final hasMom = existingParentGenders.contains('female');
    final hasDad = existingParentGenders.contains('male');

    final slots = <Widget>[];
    final relations = <_AddSlotSpec>[
      if (!hasMom) const _AddSlotSpec(_TreeQuickRelation.mom, -1, -1),
      if (!hasDad) const _AddSlotSpec(_TreeQuickRelation.dad, 1, -1),
      const _AddSlotSpec(_TreeQuickRelation.sibling, -1, 0),
      const _AddSlotSpec(_TreeQuickRelation.spouse, 1, 0),
      const _AddSlotSpec(_TreeQuickRelation.son, -1, 1),
      const _AddSlotSpec(_TreeQuickRelation.daughter, 1, 1),
    ];

    final nw = _preset.nodeWidth;
    final nh = _preset.nodeHeight;
    final baseDx = nw + _preset.colGap;
    final baseDy = nh + (_preset.rowGap * 0.55);
    final maxLeft = (layout.canvasSize.width - nw) < 0
        ? 0.0
        : (layout.canvasSize.width - nw);
    final maxTop = (layout.canvasSize.height - nh) < 0
        ? 0.0
        : (layout.canvasSize.height - nh);

    for (int tier = 1; tier <= _effectiveEmptyTiers; tier++) {
      for (final slot in relations) {
        final relation = slot.relation;
        final targetLeft =
            (anchorNode.x + slot.horizontalMultiplier * baseDx * tier).clamp(
              0.0,
              maxLeft,
            );
        final targetTop =
            (anchorNode.y + slot.verticalMultiplier * baseDy * tier).clamp(
              0.0,
              maxTop,
            );
        final opacity = _slotOpacityForTier(tier);

        slots.add(
          Positioned(
            left: targetLeft,
            top: targetTop,
            width: nw,
            height: nh,
            child: _EmptyAddNode(
              text: relation.label,
              tier: tier,
              colorScheme: colorScheme,
              opacity: opacity,
              onTap: () => _quickAddFromTree(
                anchor: anchorPerson,
                relation: relation,
                tier: tier,
              ),
            ),
          ),
        );
      }
    }
    return slots;
  }

  double _slotOpacityForTier(int tier) {
    if (tier <= 1) return _kEmptySlotTier1Opacity;
    return (_kEmptySlotOpacityBase / tier).clamp(
      _kEmptySlotOpacityMin,
      _kEmptySlotOpacityBase,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final syncService = context.watch<SyncService>();
    final colorScheme = Theme.of(context).colorScheme;
    final persons = provider.persons;
    final partnerships = provider.partnerships;

    if (persons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Tree')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 80,
                color: colorScheme.primary.withOpacity(0.35),
              ),
              const SizedBox(height: 16),
              Text(
                'No people in the tree yet.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add people from the home screen.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final personMap = {for (final p in persons) p.id: p};

    // Ensure engine is initialised (guard against rare edge cases).
    if (_engine == null || !_engine!.hasVisible) {
      final homeId =
          provider.homePersonId ??
          (persons.isNotEmpty ? persons.first.id : null);
      if (homeId != null) {
        _engine = TreeVisibilityEngine(
          persons: persons,
          partnerships: partnerships,
          homePersonId: homeId,
        );
        _engine!.resetToHome(
          ancestorGens: _effectiveAncestorGens,
          descendantGens: _effectiveDescendantGens,
        );
        _lastHomePersonId = homeId;
      }
    }

    final visibleIds = _engine?.visibleIds ?? const <String>{};

    // Build layout from visible persons only using the current preset config.
    final visiblePersons = persons
        .where((p) => visibleIds.contains(p.id))
        .toList();
    final visiblePartnerships = partnerships
        .where(
          (part) =>
              visibleIds.contains(part.person1Id) &&
              visibleIds.contains(part.person2Id),
        )
        .toList();

    final layoutConfig = TreeLayoutConfig(
      nodeWidth: _preset.nodeWidth,
      nodeHeight: _preset.nodeHeight,
      colGap: _preset.colGap,
      rowGap: _preset.rowGap,
    );
    // Resolve the focal person for layout centering: prefer home person, fall
    // back to the selected person, then the first visible person.
    final focalId =
        (provider.homePersonId != null &&
                visibleIds.contains(provider.homePersonId))
            ? provider.homePersonId
            : (_selectedPersonId != null &&
                    visibleIds.contains(_selectedPersonId))
                ? _selectedPersonId
                : (visiblePersons.isNotEmpty ? visiblePersons.first.id : null);

    // Only recompute the layout when the inputs actually changed.  This avoids
    // running the expensive BFS + 8-pass refinement on every SyncService ping
    // or other unrelated provider notification that rebuilds this widget.
    if (_cachedLayout == null ||
        _visibleIdsChanged(visibleIds) ||
        _cachedPersonsLen != persons.length ||
        _cachedPartnershipsLen != partnerships.length ||
        _cachedFocalId != focalId ||
        _cachedPreset != _preset) {
      final fresh = TreeLayout(
        visiblePersons,
        visiblePartnerships,
        layoutConfig,
        focalId,
      );
      fresh.compute();
      _cachedLayout = fresh;
      _cachedVisibleIds = Set<String>.from(visibleIds);
      _cachedPersonsLen = persons.length;
      _cachedPartnershipsLen = partnerships.length;
      _cachedFocalId = focalId;
      _cachedPreset = _preset;
      _lastLayout = fresh;
    }
    final layout = _cachedLayout!;
    final searchLower = _searchQuery.toLowerCase();

    // Live collaboration: show how many peers are currently synced/syncing.
    final peerCount = syncService.discoveredPeers.length;
    final isSyncing = syncService.status == SyncStatus.syncing;
    final isCollaborating =
        syncService.isServerRunning && (peerCount > 0 || isSyncing);

    final shownCount = visiblePersons.length;
    final totalCount = persons.length;
    final anchorId =
        (_selectedPersonId != null && personMap.containsKey(_selectedPersonId))
        ? _selectedPersonId
        : (provider.homePersonId != null &&
              personMap.containsKey(provider.homePersonId))
        ? provider.homePersonId
        : (visiblePersons.isNotEmpty ? visiblePersons.first.id : null);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Family Tree'),
            const SizedBox(width: 8),
            // Node count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                shownCount == totalCount
                    ? '$totalCount'
                    : '$shownCount / $totalCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            // Live collaboration indicator
            if (isCollaborating) ...[
              const SizedBox(width: 6),
              _LiveDot(isSyncing: isSyncing, peerCount: peerCount),
            ],
          ],
        ),
        actions: [
          // Show all / focus home toggle
          IconButton(
            icon: Icon(
              _showingAll ? Icons.center_focus_strong : Icons.account_tree,
            ),
            tooltip: _showingAll ? 'Focus on home person' : 'Show entire tree',
            onPressed: _showingAll
                ? () => _resetToHome(persons, partnerships)
                : () => _showAll(persons),
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Reset to home person',
            onPressed: () => _resetToHome(persons, partnerships),
          ),
          IconButton(
            icon: const Icon(Icons.legend_toggle),
            tooltip: 'Legend',
            onPressed: () => setState(() => _showLegend = !_showLegend),
          ),
          IconButton(
            icon: Icon(
              _localShowSlots
                  ? Icons.person_add_alt_1
                  : Icons.person_add_disabled,
            ),
            tooltip: _localShowSlots
                ? 'Hide empty add slots'
                : 'Show empty add slots',
            onPressed: () => setState(() => _localShowSlots = !_localShowSlots),
          ),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Pedigree Chart',
            onPressed: () => Navigator.push(
              context,
              fadeSlideRoute(builder: (_) => const PedigreeScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.onPrimary.withOpacity(0.15),
                hintStyle: TextStyle(
                  color: colorScheme.onPrimary.withOpacity(0.7),
                ),
                prefixIconColor: colorScheme.onPrimary.withOpacity(0.8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
              ),
              style: TextStyle(color: colorScheme.onPrimary),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          // Track viewport size for fit-to-view.
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            children: [
              InteractiveViewer(
                transformationController: _txCtrl,
                constrained: false,
                minScale: _kMinScale,
                maxScale: _kMaxScale,
                boundaryMargin: const EdgeInsets.all(_kBoundaryMargin),
                child: SizedBox(
                  width: layout.canvasSize.width,
                  height: layout.canvasSize.height,
                  child: Stack(
                    children: [
                      // Edge lines — style driven by the active preset
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _EdgePainter(
                            nodes: layout.nodes,
                            edges: layout.edges,
                            edgeColor: colorScheme.outline.withOpacity(0.5),
                            coupleColor: colorScheme.tertiary.withOpacity(0.7),
                            edgeStyle: _preset.edgeStyle,
                            nodeWidth: _preset.nodeWidth,
                            nodeHeight: _preset.nodeHeight,
                            rowGap: _preset.rowGap,
                            edgeStrokeWidth: _preset.edgeStrokeWidth,
                          ),
                        ),
                      ),

                      // Generation row labels (left rail) — hidden for compact layout
                      if (_preset.showGenerationLabels)
                        for (final row in layout.generationRows)
                          Positioned(
                            left: 0,
                            top: (row.y - _kGenLabelTopOffset).clamp(
                              0.0,
                              double.infinity,
                            ),
                            child: _GenLabel(
                              generation: row.generation,
                              colorScheme: colorScheme,
                            ),
                          ),

                      // Person / couple-knot nodes
                      for (final node in layout.nodes.values)
                        Positioned(
                          left: node.x,
                          top: node.y,
                          width: _preset.nodeWidth,
                          height: _preset.nodeHeight,
                          child: node.isCoupleKnot && _preset.showCoupleKnot
                              ? _CoupleKnot(
                                  node: node,
                                  partnerships: visiblePartnerships,
                                  colorScheme: colorScheme,
                                )
                              : node.isCoupleKnot
                              ? const SizedBox.shrink()
                              : _PersonNodeWidget(
                                  person:
                                      personMap[node.id] ??
                                      Person(id: node.id, name: '?'),
                                  colorScheme: colorScheme,
                                  preset: _preset,
                                  isHighlighted:
                                      searchLower.isNotEmpty &&
                                      (personMap[node.id]?.name
                                              .toLowerCase()
                                              .contains(searchLower) ??
                                          false),
                                  isSelected: _selectedPersonId == node.id,
                                  hasHiddenAncestors:
                                      _engine?.hasHiddenAncestors(node.id) ??
                                      false,
                                  hasHiddenDescendants:
                                      _engine?.hasHiddenDescendants(node.id) ??
                                      false,
                                  onTap: () {
                                    final p = personMap[node.id];
                                    if (p == null) return;
                                    setState(() => _selectedPersonId = node.id);
                                    _showPersonSheet(
                                      context,
                                      p,
                                      personMap,
                                      partnerships,
                                    );
                                  },
                                ),
                        ),
                      if (anchorId != null)
                        ..._buildEmptyAddSlots(
                          layout: layout,
                          anchorId: anchorId,
                          personMap: personMap,
                          colorScheme: colorScheme,
                        ),
                    ],
                  ),
                ),
              ),

              // Legend overlay
              if (_showLegend)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _LegendCard(
                    colorScheme: colorScheme,
                    onClose: () => setState(() => _showLegend = false),
                  ),
                ),

              // Zoom controls (bottom-right)
              Positioned(
                bottom: 24,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ZoomFab(
                      heroTag: 'ft_zi',
                      icon: Icons.add,
                      onPressed: () => _zoom(1.3),
                    ),
                    const SizedBox(height: 8),
                    _ZoomFab(
                      heroTag: 'ft_zo',
                      icon: Icons.remove,
                      onPressed: () => _zoom(1 / 1.3),
                    ),
                    const SizedBox(height: 8),
                    _ZoomFab(
                      heroTag: 'ft_zr',
                      icon: Icons.fit_screen,
                      tooltip: 'Fit to view',
                      onPressed: _fitView,
                    ),
                    const SizedBox(height: 8),
                    _ZoomFab(
                      heroTag: 'ft_zreset',
                      icon: Icons.filter_center_focus,
                      tooltip: 'Reset zoom',
                      onPressed: _resetView,
                    ),
                  ],
                ),
              ),

              // Zoom % indicator (bottom-left)
              Positioned(
                bottom: 24,
                left: 16,
                child: _ZoomIndicator(controller: _txCtrl),
              ),

              // Search match count (bottom-centre)
              if (searchLower.isNotEmpty)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: () {
                        final count = persons
                            .where(
                              (p) => p.name.toLowerCase().contains(searchLower),
                            )
                            .length;
                        return Container(
                          key: ValueKey(count),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.inverseSurface.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            count == 0
                                ? 'No matches'
                                : '$count match${count == 1 ? "" : "es"}',
                            style: TextStyle(
                              color: colorScheme.onInverseSurface,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _TreeQuickRelation {
  mom,
  dad,
  sibling,
  spouse,
  son,
  daughter;

  String get label {
    switch (this) {
      case _TreeQuickRelation.mom:
        return 'Add mom?';
      case _TreeQuickRelation.dad:
        return 'Add dad?';
      case _TreeQuickRelation.sibling:
        return 'Add sibling?';
      case _TreeQuickRelation.spouse:
        return 'Add spouse?';
      case _TreeQuickRelation.son:
        return 'Add son?';
      case _TreeQuickRelation.daughter:
        return 'Add daughter?';
    }
  }

  String get dialogTitle {
    switch (this) {
      case _TreeQuickRelation.mom:
        return 'Add Mom';
      case _TreeQuickRelation.dad:
        return 'Add Dad';
      case _TreeQuickRelation.sibling:
        return 'Add Sibling';
      case _TreeQuickRelation.spouse:
        return 'Add Spouse';
      case _TreeQuickRelation.son:
        return 'Add Son';
      case _TreeQuickRelation.daughter:
        return 'Add Daughter';
    }
  }

  String get confirmLabel => dialogTitle;

  String? get defaultGender {
    switch (this) {
      case _TreeQuickRelation.mom:
      case _TreeQuickRelation.daughter:
        return 'Female';
      case _TreeQuickRelation.dad:
      case _TreeQuickRelation.son:
        return 'Male';
      case _TreeQuickRelation.sibling:
      case _TreeQuickRelation.spouse:
        return null;
    }
  }

  String subtitleFor(String anchorName, int tier) {
    final tierText = tier > 1 ? ' (tier $tier)' : '';
    switch (this) {
      case _TreeQuickRelation.mom:
      case _TreeQuickRelation.dad:
        return 'Create and link $dialogTitle for $anchorName$tierText.';
      case _TreeQuickRelation.sibling:
        return 'Create and link a sibling for $anchorName$tierText.';
      case _TreeQuickRelation.spouse:
        return 'Create and link a spouse for $anchorName$tierText.';
      case _TreeQuickRelation.son:
      case _TreeQuickRelation.daughter:
        return 'Create and link $dialogTitle for $anchorName$tierText.';
    }
  }
}

class _AddSlotSpec {
  final _TreeQuickRelation relation;
  final double horizontalMultiplier;
  final double verticalMultiplier;

  const _AddSlotSpec(
    this.relation,
    this.horizontalMultiplier,
    this.verticalMultiplier,
  );
}

class _EmptyAddNode extends StatelessWidget {
  final String text;
  final int tier;
  final ColorScheme colorScheme;
  final double opacity;
  final VoidCallback onTap;

  const _EmptyAddNode({
    required this.text,
    required this.tier,
    required this.colorScheme,
    required this.opacity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(opacity),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.32),
              width: 1.1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_add_alt_1, size: 15),
              const SizedBox(height: 4),
              Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              if (tier > 1)
                Text(
                  'Tier $tier',
                  style: TextStyle(
                    fontSize: 8,
                    color: colorScheme.onPrimaryContainer.withOpacity(0.85),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Person node widget — renders differently based on the active preset card style.
class _PersonNodeWidget extends StatelessWidget {
  final Person person;
  final ColorScheme colorScheme;
  final TreePreset preset;
  final bool isHighlighted;
  final bool isSelected;
  final bool hasHiddenAncestors;
  final bool hasHiddenDescendants;
  final VoidCallback onTap;

  const _PersonNodeWidget({
    required this.person,
    required this.colorScheme,
    this.preset = TreePreset.classic,
    required this.isHighlighted,
    required this.isSelected,
    this.hasHiddenAncestors = false,
    this.hasHiddenDescendants = false,
    required this.onTap,
  });

  Color _borderColor() {
    if (isHighlighted) return Colors.amber;
    if (isSelected) return colorScheme.primary;
    if (person.gender?.toLowerCase() == 'male') return colorScheme.primary;
    if (person.gender?.toLowerCase() == 'female') return colorScheme.error;
    return colorScheme.secondary;
  }

  Color _accentColor() {
    if (person.gender?.toLowerCase() == 'male') return colorScheme.primary;
    if (person.gender?.toLowerCase() == 'female') return colorScheme.error;
    return colorScheme.secondary;
  }

  /// Returns the text colour that contrasts with [_accentColor()] according to
  /// the active colour scheme — so the avatar initial is always legible.
  Color _onAccentColor() {
    if (person.gender?.toLowerCase() == 'male') return colorScheme.onPrimary;
    if (person.gender?.toLowerCase() == 'female') return colorScheme.onError;
    return colorScheme.onSecondary;
  }

  @override
  Widget build(BuildContext context) {
    switch (preset.cardStyle) {
      case TreeCardStyle.box:
        return _buildBox(context);
      case TreeCardStyle.minimal:
        return _buildMinimal(context);
      case TreeCardStyle.card:
        return _buildCard(context);
    }
  }

  /// Standard card style (rounded card with gender strip).
  Widget _buildCard(BuildContext context) {
    final borderColor = _borderColor();
    final accentColor = _accentColor();
    final onAccentColor = _onAccentColor();
    final bool isDead = person.deathDate != null;
    final card = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isHighlighted || isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(isSelected ? 0.3 : 0.12),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (preset.showGenderStrip)
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.85),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: accentColor,
                          child: Text(
                            person.name.isNotEmpty
                                ? person.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: onAccentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            person.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDead)
                          Icon(
                            Icons.star,
                            size: 10,
                            color: colorScheme.onSurfaceVariant.withOpacity(
                              0.6,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if ((preset.showBirthYear && person.birthDate != null) ||
                        (preset.showDeathYear && person.deathDate != null))
                      Text(
                        [
                          if (preset.showBirthYear && person.birthDate != null)
                            '${person.birthDate!.year}',
                          if (preset.showDeathYear && person.deathDate != null)
                            '${person.deathDate!.year}',
                        ].join(' – '),
                        style: TextStyle(
                          fontSize: 9,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (preset.showBirthPlace && person.birthPlace != null)
                      Text(
                        person.birthPlace!,
                        style: TextStyle(
                          fontSize: 9,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!hasHiddenAncestors && !hasHiddenDescendants) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        if (hasHiddenAncestors)
          Positioned(
            top: -7,
            left: 0,
            right: 0,
            child: Center(
              child: _ExpandDot(
                icon: Icons.keyboard_arrow_up,
                colorScheme: colorScheme,
              ),
            ),
          ),
        if (hasHiddenDescendants)
          Positioned(
            bottom: -7,
            left: 0,
            right: 0,
            child: Center(
              child: _ExpandDot(
                icon: Icons.keyboard_arrow_down,
                colorScheme: colorScheme,
              ),
            ),
          ),
      ],
    );
  }

  /// Compact box style (dense layout).
  Widget _buildBox(BuildContext context) {
    final accentColor = _accentColor();
    final bool isDead = person.deathDate != null;
    final box = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isHighlighted ? Colors.amber : accentColor.withOpacity(0.7),
            width: isHighlighted || isSelected ? 2.0 : 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    person.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDead)
                  Icon(
                    Icons.star,
                    size: 9,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
              ],
            ),
            if (preset.showBirthYear && person.birthDate != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text(
                  'b. ${person.birthDate!.year}',
                  style: TextStyle(
                    fontSize: 9,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (!hasHiddenAncestors && !hasHiddenDescendants) return box;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        box,
        if (hasHiddenAncestors)
          Positioned(
            top: -6,
            left: 0,
            right: 0,
            child: Center(
              child: _ExpandDot(
                icon: Icons.keyboard_arrow_up,
                colorScheme: colorScheme,
              ),
            ),
          ),
        if (hasHiddenDescendants)
          Positioned(
            bottom: -6,
            left: 0,
            right: 0,
            child: Center(
              child: _ExpandDot(
                icon: Icons.keyboard_arrow_down,
                colorScheme: colorScheme,
              ),
            ),
          ),
      ],
    );
  }

  /// Text-only minimal style.
  Widget _buildMinimal(BuildContext context) {
    final accentColor = _accentColor();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? colorScheme.primary
                  : accentColor.withOpacity(0.5),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              person.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (person.birthDate != null || person.deathDate != null)
              Text(
                [
                  if (person.birthDate != null) '${person.birthDate!.year}',
                  if (person.deathDate != null) '†${person.deathDate!.year}',
                ].join(' '),
                style: TextStyle(
                  fontSize: 9,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small circular indicator showing that hidden relatives exist in a direction.
class _ExpandDot extends StatelessWidget {
  final IconData icon;
  final ColorScheme colorScheme;
  const _ExpandDot({required this.icon, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: colorScheme.primary.withOpacity(0.4), blurRadius: 4),
        ],
      ),
      child: Icon(icon, size: 12, color: colorScheme.onPrimary),
    );
  }
}

// Couple knot widget
class _CoupleKnot extends StatelessWidget {
  final TreeNodeInfo node;
  final List<Partnership> partnerships;
  final ColorScheme colorScheme;
  const _CoupleKnot({
    required this.node,
    required this.partnerships,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final partId = node.id.startsWith('knot_') ? node.id.substring(5) : '';
    final part = partnerships.where((p) => p.id == partId).firstOrNull;
    final year = part?.startDate?.year;
    return Center(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer,
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.tertiary, width: 1.5),
        ),
        child: Center(
          child: year != null
              ? Text(
                  '${year % 100}',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onTertiaryContainer,
                  ),
                )
              : Icon(Icons.favorite, size: 10, color: colorScheme.tertiary),
        ),
      ),
    );
  }
}

// Legend card
class _LegendCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final VoidCallback onClose;
  const _LegendCard({required this.colorScheme, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Legend',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _LegendItem(color: colorScheme.primary, label: 'Male'),
            _LegendItem(color: colorScheme.error, label: 'Female'),
            _LegendItem(color: colorScheme.secondary, label: 'Other / Unknown'),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 2,
                  color: colorScheme.outline.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  'Parent – child',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 2,
                  color: colorScheme.tertiary.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Partnership',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.tertiaryContainer,
                    border: Border.all(color: colorScheme.tertiary, width: 1.5),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.favorite,
                      size: 8,
                      color: colorScheme.tertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Union knot',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  size: 12,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text('Deceased', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 24,
            decoration: BoxDecoration(
              color: color.withOpacity(0.85),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// Zoom helpers
class _ZoomFab extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const _ZoomFab({
    required this.heroTag,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: FloatingActionButton.small(
        heroTag: heroTag,
        onPressed: onPressed,
        elevation: 2,
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _ZoomIndicator extends StatefulWidget {
  final TransformationController controller;
  const _ZoomIndicator({required this.controller});
  @override
  State<_ZoomIndicator> createState() => _ZoomIndicatorState();
}

class _ZoomIndicatorState extends State<_ZoomIndicator> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pct = (widget.controller.value.getMaxScaleOnAxis() * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// Generation row label rendered in the tree canvas.
class _GenLabel extends StatelessWidget {
  final int generation;
  final ColorScheme colorScheme;
  const _GenLabel({required this.generation, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final label = generation == 0 ? 'Home' : 'Gen ${generation + 1}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// Animated pulsing dot shown in the AppBar when live-sync is active.
class _LiveDot extends StatefulWidget {
  final bool isSyncing;
  final int peerCount;
  const _LiveDot({required this.isSyncing, required this.peerCount});
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.isSyncing ? cs.tertiary : Colors.green;
    return Tooltip(
      message: widget.isSyncing
          ? 'Syncing…'
          : 'Live sync active — ${widget.peerCount} '
                'device${widget.peerCount == 1 ? '' : 's'} connected',
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.4 + 0.6 * _ctrl.value),
          ),
        ),
      ),
    );
  }
}
