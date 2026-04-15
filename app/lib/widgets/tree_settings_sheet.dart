// app/lib/widgets/tree_settings_sheet.dart
//
// Modal bottom-sheet UI for adjusting tree view settings.
// Shows preset cards, depth sliders, and density toggles.

import 'package:flutter/material.dart';

import '../tree_core/tree_preset.dart';
import '../tree_core/tree_settings.dart';

/// A scrollable modal bottom sheet for editing [TreeViewSettings].
///
/// Call via `showModalBottomSheet`:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   useSafeArea: true,
///   builder: (_) => TreeSettingsSheet(
///     settings: _settings,
///     onChanged: (s) { setState(() => _settings = s); s.save(); },
///   ),
/// );
/// ```
class TreeSettingsSheet extends StatefulWidget {
  final TreeViewSettings settings;
  final ValueChanged<TreeViewSettings> onChanged;

  const TreeSettingsSheet({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<TreeSettingsSheet> createState() => _TreeSettingsSheetState();
}

class _TreeSettingsSheetState extends State<TreeSettingsSheet> {
  late TreeViewSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings.copyWith();
  }

  void _update(TreeViewSettings updated) {
    setState(() => _settings = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: CustomScrollView(
            controller: scrollCtrl,
            slivers: [
              // Handle bar
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outline.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              // Title row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        'Tree Settings',
                        style: textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ),
              // Section: Layout Style
              SliverToBoxAdapter(
                child: _Section(
                  title: 'Layout Style',
                  child: Column(
                    children: TreePreset.all.map((preset) {
                      final selected = preset.type == _settings.preset;
                      return _PresetTile(
                        preset: preset,
                        selected: selected,
                        colorScheme: colorScheme,
                        onTap: () => _update(
                            _settings.copyWith(preset: preset.type)),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Section: Generations
              SliverToBoxAdapter(
                child: _Section(
                  title: 'Generations to show',
                  child: Column(
                    children: [
                      _DepthSlider(
                        label: 'Ancestors',
                        icon: Icons.keyboard_arrow_up,
                        value: _settings.ancestorGenerations,
                        min: 1,
                        max: 6,
                        colorScheme: colorScheme,
                        onChanged: (v) => _update(
                            _settings.copyWith(ancestorGenerations: v)),
                      ),
                      const SizedBox(height: 4),
                      _DepthSlider(
                        label: 'Descendants',
                        icon: Icons.keyboard_arrow_down,
                        value: _settings.descendantGenerations,
                        min: 1,
                        max: 6,
                        colorScheme: colorScheme,
                        onChanged: (v) => _update(
                            _settings.copyWith(descendantGenerations: v)),
                      ),
                    ],
                  ),
                ),
              ),
              // Section: Canvas
              SliverToBoxAdapter(
                child: _Section(
                  title: 'Canvas',
                  child: Column(
                    children: [
                      SwitchListTile(
                        dense: true,
                        title: const Text('Show "Add…" placeholder slots'),
                        subtitle: const Text(
                            'Quick-add buttons for missing relatives'),
                        value: _settings.showEmptyAddSlots,
                        onChanged: (v) => _update(
                            _settings.copyWith(showEmptyAddSlots: v)),
                      ),
                      if (_settings.showEmptyAddSlots)
                        _DepthSlider(
                          label: 'Add-slot tiers',
                          icon: Icons.layers_outlined,
                          value: _settings.emptyAddSlotTiers,
                          min: 1,
                          max: 3,
                          colorScheme: colorScheme,
                          onChanged: (v) => _update(
                              _settings.copyWith(emptyAddSlotTiers: v)),
                        ),
                    ],
                  ),
                ),
              ),
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final TreePreset preset;
  final bool selected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.outline.withOpacity(0.2),
                width: selected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _iconFor(preset.type),
                  size: 22,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: selected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? colorScheme.onPrimaryContainer.withOpacity(0.75)
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle,
                      size: 18, color: colorScheme.primary),
              ],
            ),
          ),
        ),
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

class _DepthSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;
  final int min;
  final int max;
  final ColorScheme colorScheme;
  final ValueChanged<int> onChanged;

  const _DepthSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.colorScheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13, color: colorScheme.onSurface),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              label: '$value',
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
