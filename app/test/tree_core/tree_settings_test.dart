// app/test/tree_core/tree_settings_test.dart
//
// Unit tests for TreeViewSettings serialisation / defaults.
// Uses SharedPreferences mock so no real storage is needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetviona_app/tree_core/tree_preset.dart';
import 'package:vetviona_app/tree_core/tree_settings.dart';

void main() {
  // ── Defaults ─────────────────────────────────────────────────────────────────
  group('TreeViewSettings — defaults', () {
    test('newly constructed settings have sensible defaults', () {
      final s = TreeViewSettings();
      expect(s.preset, TreePresetType.hybrid);
      expect(s.ancestorGenerations, 2);
      expect(s.descendantGenerations, 2);
      expect(s.showEmptyAddSlots, isTrue);
      expect(s.emptyAddSlotTiers, 1);
    });
  });

  // ── copyWith ──────────────────────────────────────────────────────────────────
  group('TreeViewSettings.copyWith', () {
    test('returns a new instance with only the overridden field changed', () {
      final original = TreeViewSettings(
        preset: TreePresetType.ancestry,
        ancestorGenerations: 3,
        descendantGenerations: 1,
        showEmptyAddSlots: false,
        emptyAddSlotTiers: 2,
      );
      final copy = original.copyWith(preset: TreePresetType.myHeritage);
      expect(copy.preset, TreePresetType.myHeritage);
      expect(copy.ancestorGenerations, 3);
      expect(copy.descendantGenerations, 1);
      expect(copy.showEmptyAddSlots, isFalse);
      expect(copy.emptyAddSlotTiers, 2);
    });

    test('copyWith without args produces equivalent settings', () {
      final original = TreeViewSettings(
          preset: TreePresetType.familySearch,
          ancestorGenerations: 4);
      final copy = original.copyWith();
      expect(copy.preset, TreePresetType.familySearch);
      expect(copy.ancestorGenerations, 4);
    });
  });

  // ── Persistence ───────────────────────────────────────────────────────────────
  group('TreeViewSettings persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load() returns defaults when nothing has been saved', () async {
      final s = await TreeViewSettings.load();
      expect(s.preset, TreePresetType.hybrid);
      expect(s.ancestorGenerations, 2);
      expect(s.descendantGenerations, 2);
      expect(s.showEmptyAddSlots, isTrue);
      expect(s.emptyAddSlotTiers, 1);
    });

    test('save() then load() round-trips all fields', () async {
      final original = TreeViewSettings(
        preset: TreePresetType.ancestry,
        ancestorGenerations: 4,
        descendantGenerations: 3,
        showEmptyAddSlots: false,
        emptyAddSlotTiers: 2,
      );
      await original.save();

      final loaded = await TreeViewSettings.load();
      expect(loaded.preset, TreePresetType.ancestry);
      expect(loaded.ancestorGenerations, 4);
      expect(loaded.descendantGenerations, 3);
      expect(loaded.showEmptyAddSlots, isFalse);
      expect(loaded.emptyAddSlotTiers, 2);
    });

    test('save and load for each preset type', () async {
      for (final type in TreePresetType.values) {
        SharedPreferences.setMockInitialValues({});
        final s = TreeViewSettings(preset: type);
        await s.save();
        final loaded = await TreeViewSettings.load();
        expect(loaded.preset, type,
            reason: 'Round-trip failed for preset ${type.name}');
      }
    });

    test('load() falls back to hybrid for unknown preset string', () async {
      SharedPreferences.setMockInitialValues({'tvs_preset': 'unknownPreset'});
      final s = await TreeViewSettings.load();
      expect(s.preset, TreePresetType.hybrid);
    });
  });

  // ── TreePreset.byType ─────────────────────────────────────────────────────────
  group('TreePreset.byType', () {
    test('returns the correct preset for every type', () {
      expect(TreePreset.byType(TreePresetType.ancestry), TreePreset.ancestry);
      expect(
          TreePreset.byType(TreePresetType.myHeritage), TreePreset.myHeritage);
      expect(TreePreset.byType(TreePresetType.familySearch),
          TreePreset.familySearch);
      expect(TreePreset.byType(TreePresetType.hybrid), TreePreset.hybrid);
    });
  });

  // ── TreePreset static members ─────────────────────────────────────────────────
  group('TreePreset.all', () {
    test('contains all four presets', () {
      expect(TreePreset.all.length, 4);
      final types = TreePreset.all.map((p) => p.type).toSet();
      expect(types, containsAll(TreePresetType.values));
    });

    test('all preset nodeWidths are positive', () {
      for (final p in TreePreset.all) {
        expect(p.nodeWidth, greaterThan(0),
            reason: '${p.displayName} has non-positive nodeWidth');
      }
    });

    test('FamilySearch preset defaults to more ancestor gens than descendants',
        () {
      expect(TreePreset.familySearch.defaultAncestorGens,
          greaterThan(TreePreset.familySearch.defaultDescendantGens));
    });

    test('MyHeritage preset has compact nodeWidth (< 130)', () {
      expect(TreePreset.myHeritage.nodeWidth, lessThan(130));
    });

    test('Ancestry preset uses orthogonal edge style', () {
      expect(TreePreset.ancestry.edgeStyle, TreeEdgeStyle.orthogonal);
    });

    test('FamilySearch preset uses straight edge style', () {
      expect(TreePreset.familySearch.edgeStyle, TreeEdgeStyle.straight);
    });

    test('FamilySearch preset does not show couple knots', () {
      expect(TreePreset.familySearch.showCoupleKnot, isFalse);
    });
  });
}
