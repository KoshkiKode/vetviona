// Widget tests for TreeSettingsSheet.
//
// Tests rendering, preset tile selection, depth slider changes, the
// empty-add-slots toggle, and the close button — no platform channels needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetviona_app/tree_core/tree_preset.dart';
import 'package:vetviona_app/tree_core/tree_settings.dart';
import 'package:vetviona_app/widgets/tree_settings_sheet.dart';

// Helper: show the sheet inside a minimal MaterialApp and capture every
// settings value that arrives via the onChanged callback.
// We use a large SurfaceSize so the whole sheet content fits in one viewport.
Future<List<TreeViewSettings>> _showSheet(
  WidgetTester tester, {
  TreeViewSettings? initial,
}) async {
  final callbacks = <TreeViewSettings>[];
  final settings = initial ?? TreeViewSettings();

  await tester.binding.setSurfaceSize(const Size(800, 1600));

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: ctx,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => TreeSettingsSheet(
                settings: settings,
                onChanged: callbacks.add,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return callbacks;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Rendering ────────────────────────────────────────────────────────────────

  group('TreeSettingsSheet — rendering', () {
    testWidgets('renders "Tree Settings" heading', (tester) async {
      await _showSheet(tester);
      expect(find.text('Tree Settings'), findsOneWidget);
    });

    testWidgets('shows close button', (tester) async {
      await _showSheet(tester);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows Layout Style section label', (tester) async {
      await _showSheet(tester);
      expect(find.text('LAYOUT STYLE'), findsOneWidget);
    });

    testWidgets('shows Generations section label', (tester) async {
      await _showSheet(tester);
      expect(find.text('GENERATIONS TO SHOW'), findsOneWidget);
    });

    testWidgets('shows Canvas section label', (tester) async {
      await _showSheet(tester);
      expect(find.text('CANVAS'), findsOneWidget);
    });

    testWidgets('shows a tile for every preset', (tester) async {
      await _showSheet(tester);
      for (final preset in TreePreset.all) {
        expect(find.text(preset.displayName), findsOneWidget);
      }
    });

    testWidgets('shows Ancestors and Descendants slider labels', (tester) async {
      await _showSheet(tester);
      expect(find.text('Ancestors'), findsOneWidget);
      expect(find.text('Descendants'), findsOneWidget);
    });

    testWidgets('shows the empty-add-slots switch', (tester) async {
      await _showSheet(tester);
      expect(
        find.widgetWithText(SwitchListTile, 'Show "Add…" placeholder slots'),
        findsOneWidget,
      );
    });
  });

  // ── Close button ─────────────────────────────────────────────────────────────

  group('TreeSettingsSheet — close button', () {
    testWidgets('tapping close dismisses the sheet', (tester) async {
      await _showSheet(tester);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Tree Settings'), findsNothing);
    });
  });

  // ── Preset selection ─────────────────────────────────────────────────────────

  group('TreeSettingsSheet — preset selection', () {
    testWidgets('tapping a non-selected preset fires onChanged with new preset',
        (tester) async {
      // Start with Classic selected; tap Compact.
      final callbacks = await _showSheet(
        tester,
        initial: TreeViewSettings(preset: TreePresetType.classic),
      );

      final compactPreset =
          TreePreset.all.firstWhere((p) => p.type == TreePresetType.compact);

      await tester.tap(find.text(compactPreset.displayName));
      await tester.pumpAndSettle();

      expect(callbacks, isNotEmpty);
      expect(callbacks.last.preset, TreePresetType.compact);
    });

    testWidgets('tapping current preset still fires onChanged', (tester) async {
      final callbacks = await _showSheet(
        tester,
        initial: TreeViewSettings(preset: TreePresetType.compact),
      );
      final compactPreset =
          TreePreset.all.firstWhere((p) => p.type == TreePresetType.compact);

      await tester.tap(find.text(compactPreset.displayName));
      await tester.pumpAndSettle();

      expect(callbacks, isNotEmpty);
      expect(callbacks.last.preset, TreePresetType.compact);
    });
  });

  // ── Empty-add-slots toggle ───────────────────────────────────────────────────

  group('TreeSettingsSheet — empty-add-slots toggle', () {
    testWidgets(
        'toggling switch OFF fires onChanged with showEmptyAddSlots=false',
        (tester) async {
      final callbacks = await _showSheet(
        tester,
        initial: TreeViewSettings(showEmptyAddSlots: true),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(callbacks.last.showEmptyAddSlots, isFalse);
    });

    testWidgets(
        'toggling switch ON fires onChanged with showEmptyAddSlots=true',
        (tester) async {
      final callbacks = await _showSheet(
        tester,
        initial: TreeViewSettings(showEmptyAddSlots: false),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(callbacks.last.showEmptyAddSlots, isTrue);
    });

    testWidgets('Add-slot tiers slider is hidden when showEmptyAddSlots=false',
        (tester) async {
      await _showSheet(
        tester,
        initial: TreeViewSettings(showEmptyAddSlots: false),
      );
      expect(find.text('Add-slot tiers'), findsNothing);
    });

    testWidgets('Add-slot tiers slider appears when showEmptyAddSlots=true',
        (tester) async {
      await _showSheet(
        tester,
        initial: TreeViewSettings(showEmptyAddSlots: true),
      );
      expect(find.text('Add-slot tiers'), findsOneWidget);
    });

    testWidgets('enabling the switch reveals the Add-slot tiers slider',
        (tester) async {
      final callbacks = await _showSheet(
        tester,
        initial: TreeViewSettings(showEmptyAddSlots: false),
      );

      // Tiers slider should not be present initially.
      expect(find.text('Add-slot tiers'), findsNothing);

      // Enable the switch.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(callbacks.last.showEmptyAddSlots, isTrue);
      expect(find.text('Add-slot tiers'), findsOneWidget);
    });
  });

  // ── onChanged value integrity ─────────────────────────────────────────────────

  group('TreeSettingsSheet — onChanged value integrity', () {
    testWidgets('first callback carries initial preset value', (tester) async {
      final callbacks = await _showSheet(
        tester,
        initial: TreeViewSettings(preset: TreePresetType.classic),
      );

      final compactPreset =
          TreePreset.all.firstWhere((p) => p.type == TreePresetType.compact);
      await tester.tap(find.text(compactPreset.displayName));
      await tester.pumpAndSettle();

      // The callback should have correct preset but should not lose other fields.
      final last = callbacks.last;
      expect(last.preset, TreePresetType.compact);
      // ancestorGenerations should be a non-negative int (default value).
      expect(last.ancestorGenerations, isNonNegative);
      expect(last.descendantGenerations, isNonNegative);
    });
  });
}
