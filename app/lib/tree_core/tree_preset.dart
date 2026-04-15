// app/lib/tree_core/tree_preset.dart
//
// Defines the two visual layouts used across all family-tree views.
//
// Each preset is an immutable configuration bundle that drives every visual
// and layout decision.  Swapping layouts is a single-variable change —
// all screens read from the active TreePreset.

/// How edges (parent→child connectors) are drawn.
enum TreeEdgeStyle {
  /// Smooth S-shaped Bézier curves — modern, flowing look.
  bezier,

  /// Right-angle elbow connectors — structured, formal look.
  orthogonal,

  /// Diagonal straight lines — minimal, lightweight look.
  straight,
}

/// How individual person cards are rendered.
enum TreeCardStyle {
  /// Rounded card with drop-shadow and a coloured gender strip on the left.
  card,

  /// Rectangular box — no shadow, tighter padding, no gender strip.
  box,

  /// Name + year range only — maximum information density.
  minimal,
}

/// One of the two selectable visual layouts.
enum TreePresetType {
  /// Spacious cards, right-angle connectors, full detail view.
  classic,

  /// Dense layout, bezier curves, more family visible at once.
  compact,
}

/// Immutable configuration bundle for one visual layout.
///
/// All screens read from the active [TreePreset] so that swapping layouts is
/// a single-variable change.
class TreePreset {
  final TreePresetType type;
  final String displayName;
  final String description;

  // ── Node geometry ───────────────────────────────────────────────────────────
  final double nodeWidth;
  final double nodeHeight;
  final double colGap;
  final double rowGap;

  // ── Edge rendering ──────────────────────────────────────────────────────────
  final TreeEdgeStyle edgeStyle;
  final double edgeStrokeWidth;

  // ── Card style ──────────────────────────────────────────────────────────────
  final TreeCardStyle cardStyle;
  final bool showGenderStrip;
  final bool showCoupleKnot;
  final bool showGenerationLabels;
  final bool showBirthYear;
  final bool showDeathYear;
  final bool showBirthPlace;

  // ── Visibility defaults ─────────────────────────────────────────────────────
  final int defaultAncestorGens;
  final int defaultDescendantGens;

  const TreePreset._({
    required this.type,
    required this.displayName,
    required this.description,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.colGap,
    required this.rowGap,
    required this.edgeStyle,
    this.edgeStrokeWidth = 1.8,
    required this.cardStyle,
    this.showGenderStrip = true,
    this.showCoupleKnot = true,
    this.showGenerationLabels = true,
    this.showBirthYear = true,
    this.showDeathYear = true,
    this.showBirthPlace = true,
    this.defaultAncestorGens = 2,
    this.defaultDescendantGens = 2,
  });

  // ── Preset definitions ──────────────────────────────────────────────────────

  /// Spacious card layout: wide cards, right-angle connectors, full details.
  static const classic = TreePreset._(
    type: TreePresetType.classic,
    displayName: 'Classic',
    description: 'Spacious cards · right-angle connectors · full detail',
    nodeWidth: 156.0,
    nodeHeight: 92.0,
    colGap: 48.0,
    rowGap: 112.0,
    edgeStyle: TreeEdgeStyle.orthogonal,
    edgeStrokeWidth: 2.0,
    cardStyle: TreeCardStyle.card,
    showGenderStrip: true,
    showCoupleKnot: true,
    showGenerationLabels: true,
    showBirthYear: true,
    showDeathYear: true,
    showBirthPlace: true,
    defaultAncestorGens: 2,
    defaultDescendantGens: 2,
  );

  /// Dense layout: compact nodes, bezier curves, more family visible at once.
  static const compact = TreePreset._(
    type: TreePresetType.compact,
    displayName: 'Compact',
    description: 'Dense nodes · bezier curves · more family visible',
    nodeWidth: 124.0,
    nodeHeight: 76.0,
    colGap: 28.0,
    rowGap: 86.0,
    edgeStyle: TreeEdgeStyle.bezier,
    edgeStrokeWidth: 1.6,
    cardStyle: TreeCardStyle.box,
    showGenderStrip: false,
    showCoupleKnot: true,
    showGenerationLabels: false,
    showBirthYear: true,
    showDeathYear: false,
    showBirthPlace: false,
    defaultAncestorGens: 3,
    defaultDescendantGens: 3,
  );

  /// All two layouts in display order.
  static const all = [classic, compact];

  /// Look up a preset by [type].
  static TreePreset byType(TreePresetType type) {
    switch (type) {
      case TreePresetType.classic:
        return classic;
      case TreePresetType.compact:
        return compact;
    }
  }
}
