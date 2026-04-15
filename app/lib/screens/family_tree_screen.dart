// app/lib/screens/family_tree_screen.dart
//
// Unified family-tree entry screen.
//
// Hosts three tabs (Interactive Tree, Descendants, Pedigree), a horizontally
// scrollable preset-picker strip, and a settings bottom-sheet — all sharing
// the same TreeViewSettings so the user's choices persist across tabs and app
// restarts.

import 'package:flutter/material.dart';

import '../tree_core/tree_preset.dart';
import '../tree_core/tree_settings.dart';
import '../widgets/tree_settings_sheet.dart';
import 'descendants_screen.dart';
import 'pedigree_screen.dart';
import 'tree_diagram_screen.dart';

/// The top-level family-tree screen.
///
/// Use [initialTabIndex] to deep-link to a specific view:
///   - 0 = Interactive Tree (default)
///   - 1 = Descendants Chart
///   - 2 = Pedigree Chart
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
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
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

  void _onPresetChanged(TreePresetType type) {
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
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'Interactive'),
            Tab(icon: Icon(Icons.family_restroom), text: 'Descendants'),
            Tab(icon: Icon(Icons.linear_scale), text: 'Pedigree'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Preset picker strip ──────────────────────────────────────────
          _PresetPickerStrip(
            current: _settings.preset,
            onSelected: _onPresetChanged,
            colorScheme: colorScheme,
          ),
          // ── Tab views ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              // Disable swipe so the InteractiveViewer inside each tab can
              // handle horizontal pan without conflicting.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                TreeDiagramScreen(
                  preset: preset,
                  ancestorGens: _settings.ancestorGenerations,
                  descendantGens: _settings.descendantGenerations,
                  showEmptyAddSlots: _settings.showEmptyAddSlots,
                  emptyAddSlotTiers: _settings.emptyAddSlotTiers,
                ),
                DescendantsScreen(preset: preset),
                PedigreeScreen(
                  preset: preset,
                  initialMaxGenerations: _settings.ancestorGenerations
                      .clamp(2, 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Preset picker strip ───────────────────────────────────────────────────────

/// Horizontal scrollable strip of [ChoiceChip]s for switching presets.
class _PresetPickerStrip extends StatelessWidget {
  final TreePresetType current;
  final ValueChanged<TreePresetType> onSelected;
  final ColorScheme colorScheme;

  const _PresetPickerStrip({
    required this.current,
    required this.onSelected,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: TreePreset.all.map((preset) {
          final selected = preset.type == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(preset.displayName),
              avatar: Icon(_iconFor(preset.type),
                  size: 14,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant),
              selected: selected,
              selectedColor: colorScheme.primary,
              onSelected: (_) => onSelected(preset.type),
              labelStyle: TextStyle(
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  static IconData _iconFor(TreePresetType type) {
    switch (type) {
      case TreePresetType.ancestry:
        return Icons.account_tree;
      case TreePresetType.myHeritage:
        return Icons.family_restroom;
      case TreePresetType.familySearch:
        return Icons.linear_scale;
      case TreePresetType.hybrid:
        return Icons.tune;
    }
  }
}
