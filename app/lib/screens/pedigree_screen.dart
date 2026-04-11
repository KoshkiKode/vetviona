import 'package:flutter/material.dart';
import '../utils/page_routes.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../providers/tree_provider.dart';
import 'person_detail_screen.dart';

class PedigreeScreen extends StatefulWidget {
  final Person? initialPerson;

  const PedigreeScreen({super.key, this.initialPerson});

  @override
  State<PedigreeScreen> createState() => _PedigreeScreenState();
}

class _PedigreeScreenState extends State<PedigreeScreen> {
  Person? _focusedPerson;
  int _maxGenerations = 4;

  // Controller for the searchable name field.
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusedPerson = widget.initialPerson;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default to home person if not already set.
    if (_focusedPerson == null) {
      final provider = context.read<TreeProvider>();
      final persons = provider.persons;
      if (persons.isNotEmpty) {
        final homeId = provider.homePersonId;
        _focusedPerson = homeId != null
            ? persons.firstWhere((p) => p.id == homeId,
                orElse: () => persons.first)
            : persons.first;
        _searchCtrl.text = _focusedPerson!.name;
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final persons = provider.persons;

    if (persons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pedigree Chart')),
        body: const Center(child: Text('No people in the tree yet.')),
      );
    }

    // Initialise focused person if still null after didChangeDependencies.
    _focusedPerson ??= persons.first;

    final personMap = {for (final p in persons) p.id: p};

    // Alphabetically sorted list for the dropdown.
    final sortedPersons = [...persons]..sort((a, b) => a.name.compareTo(b.name));

    // Build generation lists — generation[0] = [focusedPerson], generation[1] = parents, etc.
    final generations = <List<Person?>>[];
    List<Person?> current = [_focusedPerson];
    for (int g = 0; g < _maxGenerations; g++) {
      generations.add(current);
      final next = <Person?>[];
      for (final p in current) {
        if (p == null) {
          next.add(null);
          next.add(null);
        } else {
          final ids = p.parentIds;
          next.add(ids.isNotEmpty ? personMap[ids[0]] : null);
          next.add(ids.length > 1 ? personMap[ids[1]] : null);
        }
      }
      current = next;
    }

    // Chart height: rightmost generation has 2^(maxGenerations-1) slots, each 80dp tall.
    const slotHeight = 80.0;
    final rightmostCount = 1 << (_maxGenerations - 1);
    final chartHeight = slotHeight * rightmostCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedigree Chart'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Generations',
            initialValue: _maxGenerations,
            icon: const Icon(Icons.layers_outlined),
            onSelected: (v) => setState(() => _maxGenerations = v),
            itemBuilder: (_) => [
              for (int g = 2; g <= 4; g++)
                PopupMenuItem(
                  value: g,
                  child: Text('$g generations'),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Searchable person picker
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) => DropdownMenu<String>(
                controller: _searchCtrl,
                width: constraints.maxWidth,
                enableFilter: true,
                enableSearch: true,
                label: const Text('Focus person'),
                initialSelection: _focusedPerson?.id,
                dropdownMenuEntries: sortedPersons
                    .map((p) => DropdownMenuEntry<String>(
                          value: p.id,
                          label: p.name,
                        ))
                    .toList(),
                onSelected: (id) {
                  if (id == null) return;
                  final person = persons.firstWhere((p) => p.id == id);
                  setState(() => _focusedPerson = person);
                },
              ),
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              constrained: false,
              minScale: 0.3,
              maxScale: 3.0,
              boundaryMargin: const EdgeInsets.all(100),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    height: chartHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int g = 0; g < generations.length; g++) ...[
                          SizedBox(
                            width: 148,
                            child: Column(
                              children: [
                                for (final person in generations[g])
                                  Expanded(
                                    child: Center(
                                      child: _PedigreeBox(
                                        person: person,
                                        onReCenter: person == null
                                            ? null
                                            : () => setState(() {
                                                _focusedPerson = person;
                                                _searchCtrl.text = person.name;
                                              }),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (g < generations.length - 1)
                            const SizedBox(width: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PedigreeBox extends StatelessWidget {
  final Person? person;
  final VoidCallback? onReCenter;

  const _PedigreeBox({required this.person, this.onReCenter});

  Color _nodeColor(ColorScheme colorScheme) {
    if (person == null) return colorScheme.surfaceContainerHighest;
    if (person!.gender?.toLowerCase() == 'male') return colorScheme.primary;
    if (person!.gender?.toLowerCase() == 'female') return colorScheme.error;
    return colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _nodeColor(colorScheme);

    if (person == null) {
      return Container(
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline,
                size: 28, color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 4),
            Text(
              'Unknown',
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? colorScheme.onPrimary
            : colorScheme.onSurface;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        fadeSlideRoute(
          builder: (_) => PersonDetailScreen(person: person),
        ),
      ),
      onLongPress: onReCenter,
      child: Container(
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.onPrimary.withOpacity(0.2),
              child: Text(
                person!.name.isNotEmpty ? person!.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              person!.name,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (person!.birthDate != null) ...[
              const SizedBox(height: 2),
              Text(
                'b. ${person!.birthDate!.year}',
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
