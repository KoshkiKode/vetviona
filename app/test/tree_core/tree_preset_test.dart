// app/test/tree_core/tree_preset_test.dart
//
// Additional unit tests for TreePreset focusing on aspects not covered by
// tree_settings_test.dart:
//   • TreeCardStyle enum membership and count
//   • TreeEdgeStyle enum membership and count
//   • TreePresetType enum membership and count
//   • Positive metric invariants (nodeHeight, colGap, rowGap, edgeStrokeWidth)
//   • Classic vs. compact comparative geometry
//   • Card / edge style assignments per preset

import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/tree_core/tree_preset.dart';

void main() {
  // ── TreeCardStyle enum ────────────────────────────────────────────────────

  group('TreeCardStyle', () {
    test('has exactly 3 variants', () {
      expect(TreeCardStyle.values.length, 3);
    });

    test('contains card, box, and minimal', () {
      expect(
        TreeCardStyle.values,
        containsAll([TreeCardStyle.card, TreeCardStyle.box, TreeCardStyle.minimal]),
      );
    });
  });

  // ── TreeEdgeStyle enum ────────────────────────────────────────────────────

  group('TreeEdgeStyle', () {
    test('has exactly 3 variants', () {
      expect(TreeEdgeStyle.values.length, 3);
    });

    test('contains bezier, orthogonal, and straight', () {
      expect(
        TreeEdgeStyle.values,
        containsAll([
          TreeEdgeStyle.bezier,
          TreeEdgeStyle.orthogonal,
          TreeEdgeStyle.straight,
        ]),
      );
    });
  });

  // ── TreePresetType enum ───────────────────────────────────────────────────

  group('TreePresetType', () {
    test('has exactly 2 variants', () {
      expect(TreePresetType.values.length, 2);
    });

    test('contains classic and compact', () {
      expect(
        TreePresetType.values,
        containsAll([TreePresetType.classic, TreePresetType.compact]),
      );
    });
  });

  // ── Positive metric invariants (all presets) ──────────────────────────────

  group('TreePreset — all presets have positive metrics', () {
    for (final preset in TreePreset.all) {
      test('${preset.displayName}: nodeHeight > 0', () {
        expect(
          preset.nodeHeight,
          greaterThan(0),
          reason: '${preset.displayName} nodeHeight must be positive',
        );
      });

      test('${preset.displayName}: colGap > 0', () {
        expect(
          preset.colGap,
          greaterThan(0),
          reason: '${preset.displayName} colGap must be positive',
        );
      });

      test('${preset.displayName}: rowGap > 0', () {
        expect(
          preset.rowGap,
          greaterThan(0),
          reason: '${preset.displayName} rowGap must be positive',
        );
      });

      test('${preset.displayName}: edgeStrokeWidth > 0', () {
        expect(
          preset.edgeStrokeWidth,
          greaterThan(0),
          reason: '${preset.displayName} edgeStrokeWidth must be positive',
        );
      });

      test('${preset.displayName}: displayName is non-empty', () {
        expect(preset.displayName.trim(), isNotEmpty);
      });

      test('${preset.displayName}: description is non-empty', () {
        expect(preset.description.trim(), isNotEmpty);
      });
    }
  });

  // ── Classic vs. compact comparative geometry ──────────────────────────────

  group('TreePreset — classic is larger than compact', () {
    test('classic nodeHeight > compact nodeHeight', () {
      expect(
        TreePreset.classic.nodeHeight,
        greaterThan(TreePreset.compact.nodeHeight),
      );
    });

    test('classic colGap > compact colGap', () {
      expect(
        TreePreset.classic.colGap,
        greaterThan(TreePreset.compact.colGap),
      );
    });

    test('classic rowGap > compact rowGap', () {
      expect(
        TreePreset.classic.rowGap,
        greaterThan(TreePreset.compact.rowGap),
      );
    });
  });

  // ── Card / edge style per preset ──────────────────────────────────────────

  group('TreePreset — card and edge styles', () {
    test('classic uses TreeCardStyle.card', () {
      expect(TreePreset.classic.cardStyle, TreeCardStyle.card);
    });

    test('compact uses TreeCardStyle.box', () {
      expect(TreePreset.compact.cardStyle, TreeCardStyle.box);
    });

    test('classic shows gender strip', () {
      expect(TreePreset.classic.showGenderStrip, isTrue);
    });

    test('compact hides gender strip', () {
      expect(TreePreset.compact.showGenderStrip, isFalse);
    });

    test('classic shows birth place', () {
      expect(TreePreset.classic.showBirthPlace, isTrue);
    });

    test('compact hides birth place', () {
      expect(TreePreset.compact.showBirthPlace, isFalse);
    });

    test('classic shows death year', () {
      expect(TreePreset.classic.showDeathYear, isTrue);
    });

    test('compact hides death year', () {
      expect(TreePreset.compact.showDeathYear, isFalse);
    });

    test('both presets show birth year', () {
      for (final preset in TreePreset.all) {
        expect(
          preset.showBirthYear,
          isTrue,
          reason: '${preset.displayName} should show birth year',
        );
      }
    });

    test('both presets show couple knot', () {
      for (final preset in TreePreset.all) {
        expect(
          preset.showCoupleKnot,
          isTrue,
          reason: '${preset.displayName} should show couple knot',
        );
      }
    });
  });

  // ── Defaults by type ──────────────────────────────────────────────────────

  group('TreePreset — generation defaults are reasonable', () {
    test('classic defaultAncestorGens is at least 1', () {
      expect(TreePreset.classic.defaultAncestorGens, greaterThanOrEqualTo(1));
    });

    test('classic defaultDescendantGens is at least 1', () {
      expect(TreePreset.classic.defaultDescendantGens, greaterThanOrEqualTo(1));
    });

    test('compact defaultAncestorGens is at least 1', () {
      expect(TreePreset.compact.defaultAncestorGens, greaterThanOrEqualTo(1));
    });

    test('compact defaultDescendantGens is at least 1', () {
      expect(TreePreset.compact.defaultDescendantGens, greaterThanOrEqualTo(1));
    });
  });

  // ── byType round-trips through all enum values ────────────────────────────

  group('TreePreset.byType', () {
    test('byType covers every TreePresetType value', () {
      for (final type in TreePresetType.values) {
        final preset = TreePreset.byType(type);
        expect(preset.type, type,
            reason: 'byType($type) returned wrong preset');
      }
    });
  });
}
