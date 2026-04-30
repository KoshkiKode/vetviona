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
      expect(s.preset, TreePresetType.classic);
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
        preset: TreePresetType.classic,
        ancestorGenerations: 3,
        descendantGenerations: 1,
        showEmptyAddSlots: false,
        emptyAddSlotTiers: 2,
      );
      final copy = original.copyWith(preset: TreePresetType.compact);
      expect(copy.preset, TreePresetType.compact);
      expect(copy.ancestorGenerations, 3);
      expect(copy.descendantGenerations, 1);
      expect(copy.showEmptyAddSlots, isFalse);
      expect(copy.emptyAddSlotTiers, 2);
    });

    test('copyWith without args produces equivalent settings', () {
      final original = TreeViewSettings(
          preset: TreePresetType.compact, ancestorGenerations: 4);
      final copy = original.copyWith();
      expect(copy.preset, TreePresetType.compact);
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
      expect(s.preset, TreePresetType.classic);
      expect(s.ancestorGenerations, 1);
      expect(s.descendantGenerations, 1);
      expect(s.showEmptyAddSlots, isTrue);
      expect(s.emptyAddSlotTiers, 1);
    });

    test('save() then load() round-trips all fields', () async {
      final original = TreeViewSettings(
        preset: TreePresetType.compact,
        ancestorGenerations: 4,
        descendantGenerations: 3,
        showEmptyAddSlots: false,
        emptyAddSlotTiers: 2,
      );
      await original.save();

      final loaded = await TreeViewSettings.load();
      expect(loaded.preset, TreePresetType.compact);
      expect(loaded.ancestorGenerations, 4);
      expect(loaded.descendantGenerations, 3);
      expect(loaded.showEmptyAddSlots, isFalse);
      expect(loaded.emptyAddSlotTiers, 2);
    });

    test('save and load for each layout type', () async {
      for (final type in TreePresetType.values) {
        SharedPreferences.setMockInitialValues({});
        final s = TreeViewSettings(preset: type);
        await s.save();
        final loaded = await TreeViewSettings.load();
        expect(loaded.preset, type,
            reason: 'Round-trip failed for layout ${type.name}');
      }
    });

    test('load() falls back to classic for unknown preset string', () async {
      SharedPreferences.setMockInitialValues({'tvs_preset': 'unknownPreset'});
      final s = await TreeViewSettings.load();
      expect(s.preset, TreePresetType.classic);
    });
  });

  // ── TreePreset.byType ─────────────────────────────────────────────────────────
  group('TreePreset.byType', () {
    test('returns the correct layout for every type', () {
      expect(TreePreset.byType(TreePresetType.classic), TreePreset.classic);
      expect(TreePreset.byType(TreePresetType.compact), TreePreset.compact);
    });
  });

  // ── TreePreset static members ─────────────────────────────────────────────────
  group('TreePreset.all', () {
    test('contains exactly two layouts', () {
      expect(TreePreset.all.length, 2);
      final types = TreePreset.all.map((p) => p.type).toSet();
      expect(types, containsAll(TreePresetType.values));
    });

    test('all layout nodeWidths are positive', () {
      for (final p in TreePreset.all) {
        expect(p.nodeWidth, greaterThan(0),
            reason: '${p.displayName} has non-positive nodeWidth');
      }
    });

    test('classic layout uses orthogonal edge style', () {
      expect(TreePreset.classic.edgeStyle, TreeEdgeStyle.orthogonal);
    });

    test('compact layout uses bezier edge style', () {
      expect(TreePreset.compact.edgeStyle, TreeEdgeStyle.bezier);
    });

    test('compact layout has smaller node width than classic', () {
      expect(TreePreset.compact.nodeWidth,
          lessThan(TreePreset.classic.nodeWidth));
    });

    test('compact layout shows more generations by default than classic', () {
      expect(TreePreset.compact.defaultAncestorGens,
          greaterThanOrEqualTo(TreePreset.classic.defaultAncestorGens));
    });

    test('classic layout shows generation labels', () {
      expect(TreePreset.classic.showGenerationLabels, isTrue);
    });

    test('compact layout hides generation labels', () {
      expect(TreePreset.compact.showGenerationLabels, isFalse);
    });
  });
}
