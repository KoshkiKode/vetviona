// app/lib/tree_core/tree_settings.dart
//
// Persistent user preferences for all family-tree views.
//
// Settings are stored via SharedPreferences so they survive app restarts
// and are shared across all platforms (mobile, desktop).

import 'package:shared_preferences/shared_preferences.dart';

import 'tree_preset.dart';

/// Persistent user preferences for the family-tree views.
///
/// Load with [TreeViewSettings.load]; persist with [save].
/// All fields have sensible defaults so first-launch works without any
/// stored data.
class TreeViewSettings {
  /// Visual layout currently selected.
  TreePresetType preset;

  /// How many ancestor generations to show when opening / resetting the tree.
  int ancestorGenerations;

  /// How many descendant generations to show when opening / resetting the tree.
  int descendantGenerations;

  /// Whether to render the inline "Add…" placeholder slots on the canvas.
  bool showEmptyAddSlots;

  /// How many tiers of empty add slots to render (1–3).
  int emptyAddSlotTiers;

  TreeViewSettings({
    this.preset = TreePresetType.classic,
    this.ancestorGenerations = 2,
    this.descendantGenerations = 2,
    this.showEmptyAddSlots = true,
    this.emptyAddSlotTiers = 1,
  });

  // ── SharedPreferences keys ──────────────────────────────────────────────────
  static const _kPreset = 'tvs_preset';
  static const _kAncestorGens = 'tvs_ancestor_gens';
  static const _kDescendantGens = 'tvs_descendant_gens';
  static const _kEmptySlots = 'tvs_empty_slots';
  static const _kEmptyTiers = 'tvs_empty_tiers';

  // ── Persistence ─────────────────────────────────────────────────────────────

  /// Loads settings from SharedPreferences.  Falls back to defaults for any
  /// value that has not been stored yet.
  static Future<TreeViewSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final presetStr = prefs.getString(_kPreset);
    TreePresetType preset = TreePresetType.classic;
    if (presetStr != null) {
      try {
        preset = TreePresetType.values.byName(presetStr);
      } catch (_) {
        // Unknown value (e.g. stale data from an old build) — keep default.
      }
    }
    return TreeViewSettings(
      preset: preset,
      ancestorGenerations: prefs.getInt(_kAncestorGens) ?? 2,
      descendantGenerations: prefs.getInt(_kDescendantGens) ?? 2,
      showEmptyAddSlots: prefs.getBool(_kEmptySlots) ?? true,
      emptyAddSlotTiers: prefs.getInt(_kEmptyTiers) ?? 1,
    );
  }

  /// Persists all settings to SharedPreferences.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_kPreset, preset.name),
      prefs.setInt(_kAncestorGens, ancestorGenerations),
      prefs.setInt(_kDescendantGens, descendantGenerations),
      prefs.setBool(_kEmptySlots, showEmptyAddSlots),
      prefs.setInt(_kEmptyTiers, emptyAddSlotTiers),
    ]);
  }

  // ── Copying ─────────────────────────────────────────────────────────────────

  /// Returns a copy of these settings with the given fields overridden.
  TreeViewSettings copyWith({
    TreePresetType? preset,
    int? ancestorGenerations,
    int? descendantGenerations,
    bool? showEmptyAddSlots,
    int? emptyAddSlotTiers,
  }) =>
      TreeViewSettings(
        preset: preset ?? this.preset,
        ancestorGenerations: ancestorGenerations ?? this.ancestorGenerations,
        descendantGenerations:
            descendantGenerations ?? this.descendantGenerations,
        showEmptyAddSlots: showEmptyAddSlots ?? this.showEmptyAddSlots,
        emptyAddSlotTiers: emptyAddSlotTiers ?? this.emptyAddSlotTiers,
      );
}
