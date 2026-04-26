// app/lib/screens/family_tree_screen.dart
//
// Unified family-tree entry screen.
//
// Hosts five view tabs, a two-option layout-style selector strip, and a
// settings bottom-sheet — all sharing the same TreeViewSettings so the
// user's choices persist across tabs and app restarts.
//
// Tab indices:
//   0 = Interactive Tree
//   1 = Fan Chart
//   2 = Ancestry
//   3 = Descendancy
//   4 = Pedigree

import 'package:flutter/material.dart';

import '../tree_core/tree_preset.dart';
import '../tree_core/tree_settings.dart';
import '../widgets/tree_settings_sheet.dart';
import 'ancestry_chart_screen.dart';
import 'descendants_screen.dart';
import 'fan_chart_screen.dart';
import 'pedigree_screen.dart';
import 'tree_diagram_screen.dart';

/// The top-level family-tree screen.
///
/// Pass [initialTabIndex] to open a specific view directly:
///   0 = Interactive Tree (default)
///   1 = Fan Chart
///   2 = Ancestry
///   3 = Descendancy
///   4 = Pedigree
class FamilyTreeScreen extends StatefulWidget {
  final int initialTabIndex;

  const FamilyTreeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  TreeViewSettings _settings = TreeViewSettings();
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final s = await TreeViewSettings.load();
    if (mounted) {
      setState(() {
        _settings = s;
        _settingsLoaded = true;
      });
    }
  }

  void _onLayoutChanged(TreePresetType type) {
    setState(() => _settings = _settings.copyWith(preset: type));
    _settings.save();
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TreeSettingsSheet(
        settings: _settings,
        onChanged: (s) {
          setState(() => _settings = s);
          s.save();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!_settingsLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Tree')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final preset = TreePreset.byType(_settings.preset);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Tree'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Tree Settings',
            onPressed: _openSettingsSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'Interactive'),
            Tab(icon: Icon(Icons.donut_large_outlined), text: 'Fan Chart'),
            Tab(icon: Icon(Icons.arrow_upward), text: 'Ancestry'),
            Tab(icon: Icon(Icons.family_restroom), text: 'Descendancy'),
            Tab(icon: Icon(Icons.schema_outlined), text: 'Pedigree'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Layout style strip (2 options) ───────────────────────────────
          _LayoutStyleStrip(
            current: _settings.preset,
            onSelected: _onLayoutChanged,
            colorScheme: colorScheme,
          ),
          // ── Tab views ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              // Disable swipe so InteractiveViewer inside each tab can
              // handle horizontal pan without conflicting.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // 0: Interactive Tree
                TreeDiagramScreen(
                  preset: preset,
                  ancestorGens: _settings.ancestorGenerations,
                  descendantGens: _settings.descendantGenerations,
                  showEmptyAddSlots: _settings.showEmptyAddSlots,
                  emptyAddSlotTiers: _settings.emptyAddSlotTiers,
                ),
                // 1: Fan Chart
                FanChartScreen(
                  initialGenerations: _settings.ancestorGenerations.clamp(
                    2,
                    8,
                  ),
                ),
                // 2: Ancestry
                AncestryChartScreen(
                  preset: preset,
                  ancestorGens: _settings.ancestorGenerations,
                ),
                // 3: Descendancy
                DescendantsScreen(
                  preset: preset,
                  descendantGens: _settings.descendantGenerations,
                ),
                // 4: Pedigree
                PedigreeScreen(
                  preset: preset,
                  initialMaxGenerations: _settings.ancestorGenerations.clamp(
                    2,
                    6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Layout style strip ────────────────────────────────────────────────────────

/// Two-option horizontal strip for switching the node layout style.
class _LayoutStyleStrip extends StatelessWidget {
  final TreePresetType current;
  final ValueChanged<TreePresetType> onSelected;
  final ColorScheme colorScheme;

  const _LayoutStyleStrip({
    required this.current,
    required this.onSelected,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Layout:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ...TreePreset.all.map((preset) {
            final selected = preset.type == current;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(preset.displayName),
                avatar: Icon(
                  _iconFor(preset.type),
                  size: 14,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
                selected: selected,
                selectedColor: colorScheme.primary,
                onSelected: (_) => onSelected(preset.type),
                labelStyle: TextStyle(
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
        ],
      ),
    );
  }

  static IconData _iconFor(TreePresetType type) {
    switch (type) {
      case TreePresetType.classic:
        return Icons.account_tree;
      case TreePresetType.compact:
        return Icons.density_medium;
    }
  }
}
