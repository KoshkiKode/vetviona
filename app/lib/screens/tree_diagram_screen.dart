import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/partnership.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../services/sync_service.dart';
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
/// Sits inside the [kTreeRowGap] space between consecutive rows.
const double _kGenLabelTopOffset = 20.0;

/// Controls the Bézier S-curve tension: proportional fraction of [dy] used
/// as the control-point offset from each end of the edge.
const double _kEdgeTensionFactor = 0.5;

/// Maximum tension as a fraction of [kTreeRowGap], capping how much the
/// curve can bow when rows are very far apart.
const double _kMaxTensionRatio = 0.6;
const double _kEmptySlotBaseDy = kTreeNodeH + (kTreeRowGap * 0.55);
const double _kEmptySlotTier1Opacity = 0.28;
const double _kEmptySlotOpacityBase = 0.18;
const double _kEmptySlotOpacityMin = 0.08;

// Edge painter — uses smooth cubic-Bézier curves for parent→child edges
// and straight lines for partnership (couple) connections.
class _EdgePainter extends CustomPainter {
  final Map<String, TreeNodeInfo> nodes;
  final List<TreeEdgeInfo> edges;
  final Color edgeColor;
  final Color coupleColor;

  _EdgePainter({required this.nodes, required this.edges, required this.edgeColor, required this.coupleColor});

  @override
  void paint(Canvas canvas, Size size) {
    final parentPaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final couplePaint = Paint()
      ..color = coupleColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final edge in edges) {
      final fromNode = nodes[edge.from];
      final toNode = nodes[edge.to];
      if (fromNode == null || toNode == null) continue;

      if (edge.isCouple) {
        // Straight line between couple nodes / knot
        canvas.drawLine(
          Offset(fromNode.x + kTreeNodeW / 2, fromNode.y + kTreeNodeH / 2),
          Offset(toNode.x + kTreeNodeW / 2, toNode.y + kTreeNodeH / 2),
          couplePaint,
        );
      } else {
        // Smooth S-curve from the bottom-centre of the parent/knot to the
        // top-centre of the child node.
        final fromCx = fromNode.x + kTreeNodeW / 2;
        final fromBot = fromNode.isCoupleKnot
            ? fromNode.y + kTreeNodeH / 2  // knot centre
            : fromNode.y + kTreeNodeH;     // person bottom
        final toCx = toNode.x + kTreeNodeW / 2;
        final toTop = toNode.y;
        final dy = (toTop - fromBot).abs();
        final tension = (dy * _kEdgeTensionFactor).clamp(0, kTreeRowGap * _kMaxTensionRatio);

        final path = Path()
          ..moveTo(fromCx, fromBot)
          ..cubicTo(
            fromCx, fromBot + tension,
            toCx, toTop - tension,
            toCx, toTop,
          );
        canvas.drawPath(path, parentPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.nodes != nodes || old.edges != edges ||
      old.edgeColor != edgeColor || old.coupleColor != coupleColor;
}

// Main Screen
class TreeDiagramScreen extends StatefulWidget {
  const TreeDiagramScreen({super.key});
  @override
  State<TreeDiagramScreen> createState() => _TreeDiagramScreenState();
}

class _TreeDiagramScreenState extends State<TreeDiagramScreen> {
  final TransformationController _txCtrl = TransformationController();
  String _searchQuery = '';
  String? _selectedPersonId;
  bool _showLegend = false;
  bool _showEmptyAddSlots = true;
  int _emptyAddSlotTiers = 1;

  /// When true, every person in the tree is visible (not just the focal family).
  bool _showingAll = false;

  /// IDs of persons currently rendered in the tree.
  Set<String> _visiblePersonIds = {};

  /// Tracks the last known home person ID so we can reset when it changes.
  String? _lastHomePersonId;

  /// Most recently computed layout — used by fit-to-view.
  TreeLayout? _lastLayout;

  /// Last measured body viewport size — used by fit-to-view.
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    // Auto-fit the view once the first frame is drawn so the tree is
    // properly centered and scaled on all platforms (especially desktop).
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<TreeProvider>();
    final effectiveHomeId = provider.homePersonId ??
        (provider.persons.isNotEmpty ? provider.persons.first.id : null);

    if (effectiveHomeId != _lastHomePersonId || _visiblePersonIds.isEmpty) {
      _lastHomePersonId = effectiveHomeId;
      if (effectiveHomeId != null) {
        _visiblePersonIds = _buildInitialFamily(
          effectiveHomeId,
          provider.persons,
          provider.partnerships,
        );
      }
    }
  }

  /// Returns the IDs of the immediate family unit centred on [homeId]:
  /// the home person, their parents (+ each parent's partner), their own
  /// partners, and their children.
  static Set<String> _buildInitialFamily(
    String homeId,
    List<Person> persons,
    List<Partnership> partnerships,
  ) {
    final personMap = {for (final p in persons) p.id: p};
    final visible = <String>{homeId};
    final home = personMap[homeId];
    if (home == null) return visible;

    // Partners of the home person
    for (final part in partnerships) {
      if (part.person1Id == homeId && personMap.containsKey(part.person2Id)) {
        visible.add(part.person2Id);
      } else if (part.person2Id == homeId &&
          personMap.containsKey(part.person1Id)) {
        visible.add(part.person1Id);
      }
    }

    // Parents of the home person (and their partners)
    for (final parentId in home.parentIds) {
      if (!personMap.containsKey(parentId)) continue;
      visible.add(parentId);
      for (final part in partnerships) {
        if (part.person1Id == parentId &&
            personMap.containsKey(part.person2Id)) {
          visible.add(part.person2Id);
        } else if (part.person2Id == parentId &&
            personMap.containsKey(part.person1Id)) {
          visible.add(part.person1Id);
        }
      }
    }

    // Children of the home person
    for (final childId in home.childIds) {
      if (personMap.containsKey(childId)) visible.add(childId);
    }

    return visible;
  }

  void _resetToHome(List<Person> persons, List<Partnership> partnerships) {
    final effectiveHomeId = context.read<TreeProvider>().homePersonId ??
        (persons.isNotEmpty ? persons.first.id : null);
    if (effectiveHomeId == null) return;
    setState(() {
      _showingAll = false;
      _visiblePersonIds =
          _buildInitialFamily(effectiveHomeId, persons, partnerships);
    });
    _resetView();
  }

  /// Makes all persons in the tree visible at once.
  void _showAll(List<Person> persons) {
    setState(() {
      _showingAll = true;
      _visiblePersonIds = persons.map((p) => p.id).toSet();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  /// Adds [person]'s parents (and their partners) to the visible set.
  void _expandParents(
    Person person,
    Map<String, Person> personMap,
    List<Partnership> partnerships,
  ) {
    final newIds = <String>{};
    for (final parentId in person.parentIds) {
      if (!personMap.containsKey(parentId)) continue;
      newIds.add(parentId);
      for (final part in partnerships) {
        if (part.person1Id == parentId &&
            personMap.containsKey(part.person2Id)) {
          newIds.add(part.person2Id);
        } else if (part.person2Id == parentId &&
            personMap.containsKey(part.person1Id)) {
          newIds.add(part.person1Id);
        }
      }
    }
    if (newIds.isNotEmpty) {
      setState(() => _visiblePersonIds = {..._visiblePersonIds, ...newIds});
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    }
  }

  /// Adds [person]'s children to the visible set.
  void _expandChildren(Person person, Map<String, Person> personMap) {
    final newIds = person.childIds
        .where((id) => personMap.containsKey(id))
        .toSet();
    if (newIds.isNotEmpty) {
      setState(() => _visiblePersonIds = {..._visiblePersonIds, ...newIds});
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    }
  }

  /// Adds [person]'s siblings (children of the same parents) to the visible set.
  void _expandSiblings(Person person, Map<String, Person> personMap) {
    final newIds = <String>{};
    for (final parentId in person.parentIds) {
      final parent = personMap[parentId];
      if (parent == null) continue;
      for (final sibId in parent.childIds) {
        if (sibId != person.id && personMap.containsKey(sibId)) {
          newIds.add(sibId);
        }
      }
    }
    if (newIds.isNotEmpty) {
      setState(() => _visiblePersonIds = {..._visiblePersonIds, ...newIds});
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    }
  }

  /// BFS-expands ALL ancestors of [person] (and each ancestor's partners).
  void _expandAllAncestors(
    Person person,
    Map<String, Person> personMap,
    List<Partnership> partnerships,
  ) {
    final newIds = <String>{};
    final queue = Queue<Person>()..add(person);
    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      for (final parentId in p.parentIds) {
        if (!personMap.containsKey(parentId)) continue;
        if (!_visiblePersonIds.contains(parentId) && !newIds.contains(parentId)) {
          newIds.add(parentId);
          queue.add(personMap[parentId]!);
        }
        // Include each parent's partners so couple knots render correctly.
        for (final part in partnerships) {
          String? partnerId;
          if (part.person1Id == parentId) partnerId = part.person2Id;
          if (part.person2Id == parentId) partnerId = part.person1Id;
          if (partnerId != null &&
              personMap.containsKey(partnerId) &&
              !_visiblePersonIds.contains(partnerId) &&
              !newIds.contains(partnerId)) {
            newIds.add(partnerId);
          }
        }
      }
    }
    if (newIds.isNotEmpty) {
      setState(() => _visiblePersonIds = {..._visiblePersonIds, ...newIds});
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    }
  }

  /// BFS-expands ALL descendants of [person].
  void _expandAllDescendants(Person person, Map<String, Person> personMap) {
    final newIds = <String>{};
    final queue = Queue<Person>()..add(person);
    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      for (final childId in p.childIds) {
        if (!personMap.containsKey(childId)) continue;
        if (!_visiblePersonIds.contains(childId) && !newIds.contains(childId)) {
          newIds.add(childId);
          queue.add(personMap[childId]!);
        }
      }
    }
    if (newIds.isNotEmpty) {
      setState(() => _visiblePersonIds = {..._visiblePersonIds, ...newIds});
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    }
  }

  @override
  void dispose() { _txCtrl.dispose(); super.dispose(); }

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
    final sx = (vp.width  - padding * 2) / layout.canvasSize.width;
    final sy = (vp.height - padding * 2) / layout.canvasSize.height;
    final scale = (sx < sy ? sx : sy).clamp(_kMinScale, 1.0);
    final scaledW = layout.canvasSize.width  * scale;
    final scaledH = layout.canvasSize.height * scale;
    final tx = (vp.width  - scaledW) / 2;
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
    final hasHiddenParents = person.parentIds
        .any((id) => personMap.containsKey(id) && !_visiblePersonIds.contains(id));
    final hasHiddenChildren = person.childIds
        .any((id) => personMap.containsKey(id) && !_visiblePersonIds.contains(id));
    final hasHiddenSiblings = person.parentIds.any((parentId) {
      final parent = personMap[parentId];
      if (parent == null) return false;
      return parent.childIds.any(
          (id) => id != person.id && personMap.containsKey(id) && !_visiblePersonIds.contains(id));
    });

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Color avatarBg = colorScheme.secondary;
        if (person.gender?.toLowerCase() == 'male') avatarBg = colorScheme.primary;
        if (person.gender?.toLowerCase() == 'female') avatarBg = colorScheme.error;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                CircleAvatar(
                  radius: 28, backgroundColor: avatarBg,
                  child: Text(
                    person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.name,
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    if (person.birthDate != null || person.deathDate != null)
                      Text(
                        [if (person.birthDate != null) 'b. ${person.birthDate!.year}',
                         if (person.deathDate != null) 'd. ${person.deathDate!.year}'].join('  ·  '),
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant)),
                    if (person.birthPlace != null)
                      Text(person.birthPlace!,
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant)),
                  ])),
              ]),
              if (person.occupation != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.work_outline, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(person.occupation!, style: Theme.of(ctx).textTheme.bodyMedium),
                ]),
              ],
              const SizedBox(height: 20),
              // Primary actions
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline), label: const Text('Full Profile'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context,
                        fadeSlideRoute(builder: (_) => PersonDetailScreen(person: person)));
                  })),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(
                  icon: const Icon(Icons.center_focus_strong), label: const Text('Focus'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedPersonId = person.id;
                      _visiblePersonIds = _buildInitialFamily(
                          person.id,
                          personMap.values.toList(),
                          partnerships);
                    });
                    _resetView();
                  })),
              ]),
              // Expand actions — only shown when there is something to expand
              if (hasHiddenParents || hasHiddenChildren || hasHiddenSiblings) ...[
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
                        }),
                    if (hasHiddenChildren)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        label: const Text('Show Children'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandChildren(person, personMap);
                        }),
                    if (hasHiddenSiblings)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.people_outline, size: 16),
                        label: const Text('Show Siblings'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandSiblings(person, personMap);
                        }),
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
                        }),
                    if (hasHiddenChildren)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.account_tree, size: 16),
                        label: const Text('All Descendants'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _expandAllDescendants(person, personMap);
                        }),
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
    final current = provider.persons.where((p) => p.id == anchor.id).firstOrNull;
    if (current == null) return;
    if (relation == _TreeQuickRelation.sibling && current.parentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a parent first, then add siblings')),
      );
      return;
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
      final created = Person(
        id: '',
        name: input.name,
        gender: input.gender ?? relation.defaultGender,
        parentIds: relation == _TreeQuickRelation.son ||
                relation == _TreeQuickRelation.daughter
            ? [current.id]
            : [],
        parentRelTypes: relation == _TreeQuickRelation.son ||
                relation == _TreeQuickRelation.daughter
            ? {current.id: 'biological'}
            : {},
        childIds: relation == _TreeQuickRelation.mom ||
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
            Partnership(
              id: '',
              person1Id: current.id,
              person2Id: created.id,
            ),
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
            final parent =
                provider.persons.where((p) => p.id == parentId).firstOrNull;
            if (parent == null || parent.childIds.contains(created.id)) continue;
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
          break;
      }

      if (!mounted) return;
      setState(() {
        _selectedPersonId = current.id;
        _visiblePersonIds = {..._visiblePersonIds, created.id};
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  List<Widget> _buildEmptyAddSlots({
    required TreeLayout layout,
    required String anchorId,
    required Map<String, Person> personMap,
    required ColorScheme colorScheme,
  }) {
    if (!_showEmptyAddSlots) return const [];
    final anchorNode = layout.nodes[anchorId];
    final anchorPerson = personMap[anchorId];
    if (anchorNode == null || anchorPerson == null) return const [];

    final slots = <Widget>[];
    final relations = <(_TreeQuickRelation, double, double)>[
      (_TreeQuickRelation.mom, -1, -1),
      (_TreeQuickRelation.dad, 1, -1),
      (_TreeQuickRelation.sibling, -1, 0),
      (_TreeQuickRelation.spouse, 1, 0),
      (_TreeQuickRelation.son, -1, 1),
      (_TreeQuickRelation.daughter, 1, 1),
    ];

    final baseDx = kTreeNodeW + kTreeColGap;
    const baseDy = _kEmptySlotBaseDy;
    final maxLeft = (layout.canvasSize.width - kTreeNodeW) < 0
        ? 0.0
        : (layout.canvasSize.width - kTreeNodeW);
    final maxTop = (layout.canvasSize.height - kTreeNodeH) < 0
        ? 0.0
        : (layout.canvasSize.height - kTreeNodeH);

    for (int tier = 1; tier <= _emptyAddSlotTiers; tier++) {
      for (final slot in relations) {
        final relation = slot.$1;
        final targetLeft = (anchorNode.x + slot.$2 * baseDx * tier)
            .clamp(0.0, maxLeft);
        final targetTop = (anchorNode.y + slot.$3 * baseDy * tier)
            .clamp(0.0, maxTop);
        final opacity = tier == 1
            ? _kEmptySlotTier1Opacity
            : (_kEmptySlotOpacityBase / tier)
                .clamp(_kEmptySlotOpacityMin, _kEmptySlotOpacityBase);

        slots.add(
          Positioned(
            left: targetLeft,
            top: targetTop,
            width: kTreeNodeW,
            height: kTreeNodeH,
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
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree_outlined, size: 80,
                color: colorScheme.primary.withOpacity(0.35)),
            const SizedBox(height: 16),
            Text('No people in the tree yet.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Add people from the home screen.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
          ])),
      );
    }

    final personMap = {for (final p in persons) p.id: p};

    // Ensure visible set is initialised (e.g. first build after load).
    if (_visiblePersonIds.isEmpty) {
      final homeId = provider.homePersonId ??
          (persons.isNotEmpty ? persons.first.id : null);
      if (homeId != null) {
        _visiblePersonIds =
            _buildInitialFamily(homeId, persons, partnerships);
        _lastHomePersonId = homeId;
      }
    }

    // Build layout from visible persons only.
    final visiblePersons = persons
        .where((p) => _visiblePersonIds.contains(p.id))
        .toList();
    final visiblePartnerships = partnerships.where((part) =>
        _visiblePersonIds.contains(part.person1Id) &&
        _visiblePersonIds.contains(part.person2Id)).toList();

    final layout = TreeLayout(visiblePersons, visiblePartnerships);
    layout.compute();
    _lastLayout = layout;
    final searchLower = _searchQuery.toLowerCase();

    // Live collaboration: show how many peers are currently synced/syncing.
    final peerCount = syncService.discoveredPeers.length;
    final isSyncing = syncService.status == SyncStatus.syncing;
    final isCollaborating = syncService.isServerRunning &&
        (peerCount > 0 || isSyncing);

    final shownCount = visiblePersons.length;
    final totalCount = persons.length;
    final anchorId = (_selectedPersonId != null &&
            personMap.containsKey(_selectedPersonId))
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
            icon: Icon(_showingAll ? Icons.center_focus_strong : Icons.account_tree),
            tooltip: _showingAll ? 'Focus on home person' : 'Show entire tree',
            onPressed: _showingAll
                ? () => _resetToHome(persons, partnerships)
                : () => _showAll(persons)),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Reset to home person',
            onPressed: () => _resetToHome(persons, partnerships)),
          IconButton(
            icon: const Icon(Icons.legend_toggle),
            tooltip: 'Legend',
            onPressed: () => setState(() => _showLegend = !_showLegend)),
          IconButton(
            icon: Icon(
              _showEmptyAddSlots
                  ? Icons.person_add_alt_1
                  : Icons.person_add_disabled,
            ),
            tooltip: _showEmptyAddSlots
                ? 'Hide empty add slots'
                : 'Show empty add slots',
            onPressed: () =>
                setState(() => _showEmptyAddSlots = !_showEmptyAddSlots),
          ),
          PopupMenuButton<int>(
            tooltip: 'Set add-slot tiers',
            icon: const Icon(Icons.layers_outlined),
            onSelected: (tier) => setState(() => _emptyAddSlotTiers = tier),
            itemBuilder: (_) => List.generate(
              3,
              (i) => i + 1,
            ).map((tier) {
              return PopupMenuItem<int>(
                value: tier,
                child: Row(
                  children: [
                    if (_emptyAddSlotTiers == tier)
                      const Icon(Icons.check, size: 16),
                    if (_emptyAddSlotTiers == tier) const SizedBox(width: 8),
                    Text('Add tiers: $tier'),
                  ],
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Pedigree Chart',
            onPressed: () => Navigator.push(
                context, fadeSlideRoute(builder: (_) => const PedigreeScreen()))),
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
                        onPressed: () => setState(() => _searchQuery = ''))
                    : null,
                filled: true,
                fillColor: colorScheme.onPrimary.withOpacity(0.15),
                hintStyle: TextStyle(color: colorScheme.onPrimary.withOpacity(0.7)),
                prefixIconColor: colorScheme.onPrimary.withOpacity(0.8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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

          return Stack(children: [
            InteractiveViewer(
              transformationController: _txCtrl,
              constrained: false,
              minScale: _kMinScale,
              maxScale: _kMaxScale,
              boundaryMargin: const EdgeInsets.all(_kBoundaryMargin),
              child: SizedBox(
                width: layout.canvasSize.width,
                height: layout.canvasSize.height,
                child: Stack(children: [
                  // Bezier edge lines
                  Positioned.fill(child: CustomPaint(painter: _EdgePainter(
                    nodes: layout.nodes, edges: layout.edges,
                    edgeColor: colorScheme.outline.withOpacity(0.5),
                    coupleColor: colorScheme.tertiary.withOpacity(0.7)))),

                  // Generation row labels (left rail)
                  for (final row in layout.generationRows)
                    Positioned(
                      left: 0,
                      top: row.y - _kGenLabelTopOffset,
                      child: _GenLabel(
                        generation: row.generation,
                        colorScheme: colorScheme,
                      ),
                    ),

                  // Person / couple-knot nodes
                  for (final node in layout.nodes.values)
                    Positioned(
                      left: node.x, top: node.y, width: kTreeNodeW, height: kTreeNodeH,
                      child: node.isCoupleKnot
                          ? _CoupleKnot(
                              node: node,
                              partnerships: visiblePartnerships,
                              colorScheme: colorScheme)
                          : _PersonNodeWidget(
                              person: personMap[node.id] ?? Person(id: node.id, name: '?'),
                              colorScheme: colorScheme,
                              isHighlighted: searchLower.isNotEmpty &&
                                  (personMap[node.id]?.name.toLowerCase().contains(searchLower) ?? false),
                              isSelected: _selectedPersonId == node.id,
                              hasHiddenAncestors: (() {
                                final p = personMap[node.id];
                                if (p == null) return false;
                                return p.parentIds.any((id) =>
                                    personMap.containsKey(id) &&
                                    !_visiblePersonIds.contains(id));
                              })(),
                              hasHiddenDescendants: (() {
                                final p = personMap[node.id];
                                if (p == null) return false;
                                return p.childIds.any((id) =>
                                    personMap.containsKey(id) &&
                                    !_visiblePersonIds.contains(id));
                              })(),
                              onTap: () {
                                final p = personMap[node.id];
                                if (p == null) return;
                                setState(() => _selectedPersonId = node.id);
                                _showPersonSheet(context, p, personMap, partnerships);
                               }),
                     ),
                  if (anchorId != null)
                    ..._buildEmptyAddSlots(
                      layout: layout,
                      anchorId: anchorId,
                      personMap: personMap,
                      colorScheme: colorScheme,
                    ),
                ]),
              ),
            ),

            // Legend overlay
            if (_showLegend)
              Positioned(
                top: 8, right: 8,
                child: _LegendCard(
                    colorScheme: colorScheme,
                    onClose: () => setState(() => _showLegend = false))),

            // Zoom controls (bottom-right)
            Positioned(
              bottom: 24, right: 16,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _ZoomFab(heroTag: 'ft_zi', icon: Icons.add, onPressed: () => _zoom(1.3)),
                const SizedBox(height: 8),
                _ZoomFab(heroTag: 'ft_zo', icon: Icons.remove, onPressed: () => _zoom(1 / 1.3)),
                const SizedBox(height: 8),
                _ZoomFab(heroTag: 'ft_zr', icon: Icons.fit_screen,
                    tooltip: 'Fit to view', onPressed: _fitView),
                const SizedBox(height: 8),
                _ZoomFab(heroTag: 'ft_zreset', icon: Icons.filter_center_focus,
                    tooltip: 'Reset zoom', onPressed: _resetView),
              ])),

            // Zoom % indicator (bottom-left)
            Positioned(bottom: 24, left: 16, child: _ZoomIndicator(controller: _txCtrl)),

            // Search match count (bottom-centre)
            if (searchLower.isNotEmpty)
              Positioned(
                bottom: 24, left: 0, right: 0,
                child: Center(child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: () {
                    final count = persons
                        .where((p) => p.name.toLowerCase().contains(searchLower))
                        .length;
                    return Container(
                      key: ValueKey(count),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.inverseSurface.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        count == 0
                            ? 'No matches'
                            : '$count match${count == 1 ? "" : "es"}',
                        style: TextStyle(
                            color: colorScheme.onInverseSurface, fontSize: 13)));
                  }(),
                ))),
          ]);
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

// Person node widget
class _PersonNodeWidget extends StatelessWidget {
  final Person person;
  final ColorScheme colorScheme;
  final bool isHighlighted;
  final bool isSelected;
  final bool hasHiddenAncestors;
  final bool hasHiddenDescendants;
  final VoidCallback onTap;

  const _PersonNodeWidget({
    required this.person, required this.colorScheme,
    required this.isHighlighted, required this.isSelected,
    this.hasHiddenAncestors = false,
    this.hasHiddenDescendants = false,
    required this.onTap});

  Color _borderColor() {
    if (isHighlighted) return Colors.amber;
    if (isSelected) return colorScheme.primary;
    if (person.gender?.toLowerCase() == 'male') return colorScheme.primary;
    if (person.gender?.toLowerCase() == 'female') return colorScheme.error;
    return colorScheme.secondary;
  }

  Color _avatarBg() {
    if (person.gender?.toLowerCase() == 'male') return colorScheme.primary;
    if (person.gender?.toLowerCase() == 'female') return colorScheme.error;
    return colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor();
    final avatarBg = _avatarBg();
    final bool isDead = person.deathDate != null;
    final card = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isHighlighted || isSelected ? 2.5 : 1.5),
          boxShadow: [BoxShadow(color: borderColor.withOpacity(isSelected ? 0.3 : 0.12), blurRadius: isSelected ? 8 : 4, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(width: 6, decoration: BoxDecoration(
            color: avatarBg.withOpacity(0.85),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)))),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 14, backgroundColor: avatarBg,
                  child: Text(person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                    style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(width: 6),
                Expanded(child: Text(person.name,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: colorScheme.onSurface),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
                if (isDead) Icon(Icons.star, size: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
              ]),
              const SizedBox(height: 3),
              if (person.birthDate != null || person.deathDate != null)
                Text(
                  [if (person.birthDate != null) '${person.birthDate!.year}',
                   if (person.deathDate != null) '${person.deathDate!.year}'].join(' – '),
                  style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant)),
              if (person.birthPlace != null)
                Text(person.birthPlace!, style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant.withOpacity(0.8)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          )),
        ]),
      ),
    );

    // Wrap in a Stack to overlay expand indicator dots.
    if (!hasHiddenAncestors && !hasHiddenDescendants) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        if (hasHiddenAncestors)
          Positioned(
            top: -7,
            left: 0, right: 0,
            child: Center(child: _ExpandDot(
              icon: Icons.keyboard_arrow_up, colorScheme: colorScheme))),
        if (hasHiddenDescendants)
          Positioned(
            bottom: -7,
            left: 0, right: 0,
            child: Center(child: _ExpandDot(
              icon: Icons.keyboard_arrow_down, colorScheme: colorScheme))),
      ],
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
        boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.4), blurRadius: 4)],
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
  const _CoupleKnot({required this.node, required this.partnerships, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final partId = node.id.startsWith('knot_') ? node.id.substring(5) : '';
    final part = partnerships.where((p) => p.id == partId).firstOrNull;
    final year = part?.startDate?.year;
    return Center(child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: colorScheme.tertiaryContainer, shape: BoxShape.circle,
        border: Border.all(color: colorScheme.tertiary, width: 1.5)),
      child: Center(child: year != null
          ? Text('${year % 100}', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colorScheme.onTertiaryContainer))
          : Icon(Icons.favorite, size: 10, color: colorScheme.tertiary)),
    ));
  }
}

// Legend card
class _LegendCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final VoidCallback onClose;
  const _LegendCard({required this.colorScheme, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(elevation: 4, child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Legend', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          GestureDetector(onTap: onClose, child: Icon(Icons.close, size: 16, color: colorScheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 8),
        _LegendItem(color: colorScheme.primary, label: 'Male'),
        _LegendItem(color: colorScheme.error, label: 'Female'),
        _LegendItem(color: colorScheme.secondary, label: 'Other / Unknown'),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 24, height: 2, color: colorScheme.outline.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text('Parent – child', style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 24, height: 2, color: colorScheme.tertiary.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text('Partnership', style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 16, height: 16,
            decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.tertiaryContainer,
              border: Border.all(color: colorScheme.tertiary, width: 1.5)),
            child: Center(child: Icon(Icons.favorite, size: 8, color: colorScheme.tertiary))),
          const SizedBox(width: 8),
          Text('Union knot', style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.star, size: 12, color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
          const SizedBox(width: 8),
          Text('Deceased', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ]),
    ));
  }
}

class _LegendItem extends StatelessWidget {
  final Color color; final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 24, decoration: BoxDecoration(color: color.withOpacity(0.85), borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]));
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
  void initState() { super.initState(); widget.controller.addListener(_rebuild); }
  @override
  void dispose() { widget.controller.removeListener(_rebuild); super.dispose(); }
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
        border: Border.all(color: colorScheme.outline.withOpacity(0.2))),
      child: Text('$pct%', style: TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w500)));
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
