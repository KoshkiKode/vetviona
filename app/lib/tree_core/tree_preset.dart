// app/lib/tree_core/tree_preset.dart
//
// Defines the four visual presets used across all family-tree views.
//
// Each preset is an immutable configuration bundle that drives every visual
// and layout decision.  Swapping presets is a single-variable change —
// all screens read from the active TreePreset.

/// How edges (parent→child connectors) are drawn.
enum TreeEdgeStyle {
  /// Smooth S-shaped Bézier curves — modern, flowing look.
  bezier,

  /// Right-angle elbow connectors — Ancestry.com style.
  orthogonal,

  /// Diagonal straight lines — FamilySearch minimalist style.
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

/// One of the four selectable visual presets.
enum TreePresetType {
  /// Wide cards, right-angle connectors, generation labels — Ancestry.com–inspired.
  ancestry,

  /// Compact boxes, Bézier edges, more family visible — MyHeritage–inspired.
  myHeritage,

  /// Pedigree emphasis, straight connectors, ancestor depth — FamilySearch–inspired.
  familySearch,

  /// Balanced defaults, all features enabled — Vetviona Hybrid.
  hybrid,
}

/// Immutable configuration bundle for one visual preset.
///
/// All screens read from the active [TreePreset] so that swapping presets is
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

  /// Ancestry.com–inspired: wide cards, right-angle connectors, row labels.
  static const ancestry = TreePreset._(
    type: TreePresetType.ancestry,
    displayName: 'Ancestry',
    description: 'Wide cards · right-angle connectors · generation labels',
    nodeWidth: 164.0,
    nodeHeight: 94.0,
    colGap: 52.0,
    rowGap: 116.0,
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

  /// MyHeritage–inspired: compact boxes, Bézier edges, more family visible.
  static const myHeritage = TreePreset._(
    type: TreePresetType.myHeritage,
    displayName: 'MyHeritage',
    description: 'Compact boxes · Bézier edges · more family visible',
    nodeWidth: 118.0,
    nodeHeight: 70.0,
    colGap: 26.0,
    rowGap: 78.0,
    edgeStyle: TreeEdgeStyle.bezier,
    edgeStrokeWidth: 1.5,
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

  /// FamilySearch–inspired: pedigree focus, straight connectors, ancestor depth.
  static const familySearch = TreePreset._(
    type: TreePresetType.familySearch,
    displayName: 'FamilySearch',
    description: 'Pedigree focus · straight connectors · ancestor depth',
    nodeWidth: 150.0,
    nodeHeight: 86.0,
    colGap: 42.0,
    rowGap: 104.0,
    edgeStyle: TreeEdgeStyle.straight,
    edgeStrokeWidth: 1.6,
    cardStyle: TreeCardStyle.card,
    showGenderStrip: true,
    showCoupleKnot: false,
    showGenerationLabels: true,
    showBirthYear: true,
    showDeathYear: true,
    showBirthPlace: false,
    defaultAncestorGens: 4,
    defaultDescendantGens: 1,
  );

  /// Vetviona Hybrid: balanced defaults, all features, user-adjustable.
  static const hybrid = TreePreset._(
    type: TreePresetType.hybrid,
    displayName: 'Hybrid',
    description: 'Balanced defaults · all features · user-adjustable',
    nodeWidth: 136.0,
    nodeHeight: 86.0,
    colGap: 44.0,
    rowGap: 100.0,
    edgeStyle: TreeEdgeStyle.bezier,
    edgeStrokeWidth: 1.8,
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

  /// All four presets in display order.
  static const all = [ancestry, myHeritage, familySearch, hybrid];

  /// Look up a preset by [type].
  static TreePreset byType(TreePresetType type) {
    switch (type) {
      case TreePresetType.ancestry:
        return ancestry;
      case TreePresetType.myHeritage:
        return myHeritage;
      case TreePresetType.familySearch:
        return familySearch;
      case TreePresetType.hybrid:
        return hybrid;
    }
  }
}
