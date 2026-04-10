import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/partnership.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import 'calendar_screen.dart';
import 'login_screen.dart';
import 'pedigree_screen.dart';
import 'person_detail_screen.dart';
import 'relationship_finder_screen.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';
import 'tree_diagram_screen.dart';
import 'tree_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  String? _filterGender;
  bool? _filterLiving;
  String _sortBy = 'name';
  bool _sortAscending = true;
  List<String> _recentIds = [];

  @override
  void initState() {
    super.initState();
    _loadRecentIds();
  }

  Future<void> _loadRecentIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('recentPersonIds') ?? '';
    if (mounted) {
      setState(() {
        _recentIds =
            raw.isEmpty ? [] : raw.split(',').where((s) => s.isNotEmpty).toList();
      });
    }
  }

  Future<void> _saveRecentId(String id) async {
    final ids = List<String>.from(_recentIds);
    ids.remove(id);
    ids.insert(0, id);
    if (ids.length > 5) ids.length = 5;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recentPersonIds', ids.join(','));
    if (mounted) setState(() => _recentIds = ids);
  }

  List<Person> _applyFiltersAndSort(List<Person> persons) {
    List<Person> result;
    if (_searchQuery.isEmpty) {
      result = persons;
    } else {
      final q = _searchQuery.toLowerCase();
      result = persons.where((p) {
        return p.name.toLowerCase().contains(q) ||
            (p.birthPlace?.toLowerCase().contains(q) ?? false) ||
            (p.deathPlace?.toLowerCase().contains(q) ?? false) ||
            (p.notes?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (_filterGender != null) {
      if (_filterGender == 'other') {
        result = result.where((p) {
          final g = p.gender?.toLowerCase();
          return g != null && g != 'male' && g != 'female';
        }).toList();
      } else {
        result = result
            .where((p) => p.gender?.toLowerCase() == _filterGender)
            .toList();
      }
    }

    if (_filterLiving != null) {
      result =
          result.where((p) => (p.deathDate == null) == _filterLiving).toList();
    }

    final sorted = List<Person>.from(result);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'birthYear':
          final aYear = a.birthDate?.year;
          final bYear = b.birthDate?.year;
          if (aYear == null && bYear == null) {
            cmp = 0;
          } else if (aYear == null) {
            cmp = 1;
          } else if (bYear == null) {
            cmp = -1;
          } else {
            cmp = aYear.compareTo(bYear);
          }
          break;
        default:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final filteredPersons = _applyFiltersAndSort(provider.persons);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree, size: 22, color: colorScheme.onPrimary),
            const SizedBox(width: 8),
            const Text(
              'Vetviona',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree),
            tooltip: 'Tree Diagram',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TreeDiagramScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Tree List',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TreeScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          _buildAuthButton(context, provider),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search people\u2026',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: colorScheme.onPrimary.withOpacity(0.15),
                hintStyle: TextStyle(
                    color: colorScheme.onPrimary.withOpacity(0.7)),
                prefixIconColor: colorScheme.onPrimary.withOpacity(0.8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(
                      color: colorScheme.onPrimary.withOpacity(0.5)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              style: TextStyle(color: colorScheme.onPrimary),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      drawer: _buildDrawer(context, provider),
      body: filteredPersons.isEmpty
          ? _buildEmptyState(context, provider)
          : Column(
              children: [
                _buildStatsBar(context, provider),
                if (provider.persons.isNotEmpty)
                  _StatisticsCard(
                    persons: provider.persons,
                    partnerships: provider.partnerships,
                  ),
                _buildDuplicateBanner(context, provider),
                if (_recentIds.isNotEmpty && _searchQuery.isEmpty)
                  _buildRecentPeople(context, provider),
                _buildFilterSortBar(context),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: filteredPersons.length,
                    itemBuilder: (context, i) {
                      final person = filteredPersons[i];
                      return _PersonCard(
                        person: person,
                        onTap: () async {
                          await _saveRecentId(person.id);
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PersonDetailScreen(person: person),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.isAtPersonLimit
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Free tier limit: $freeMobilePersonLimit people reached. Upgrade to add more.',
                    ),
                    backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                  ),
                )
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PersonDetailScreen()),
                ),
        tooltip: provider.isAtPersonLimit
            ? 'Person limit reached'
            : 'Add Person',
        icon: Icon(
            provider.isAtPersonLimit ? Icons.lock_outline : Icons.person_add),
        label: Text(
            provider.isAtPersonLimit ? 'Limit Reached' : 'Add Person'),
      ),
    );
  }

  Widget _buildStatsBar(BuildContext context, TreeProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFree = currentAppTier == AppTier.mobileFree;
    final personLabel = isFree
        ? '${provider.persons.length} / $freeMobilePersonLimit people'
        : '${provider.persons.length} people';
    return Container(
      color: colorScheme.primaryContainer.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.people,
            label: personLabel,
            color: isFree && provider.isAtPersonLimit
                ? colorScheme.outlineVariant
                : colorScheme.primary,
          ),
          if (!isFree) ...[
            const SizedBox(width: 8),
            _StatChip(
              icon: Icons.park,
              label:
                  '${provider.treeNames.length} tree${provider.treeNames.length == 1 ? '' : 's'}',
              color: colorScheme.tertiary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TreeProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 52,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              provider.persons.isEmpty
                  ? 'Your family tree is empty'
                  : 'No results for \u201c$_searchQuery\u201d',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              provider.persons.isEmpty
                  ? 'Start building your family history by adding the first person.'
                  : 'Try a different search term.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (provider.persons.isEmpty) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Add First Person'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PersonDetailScreen()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuthButton(BuildContext context, TreeProvider provider) {
    if (provider.isLoggedIn) {
      return IconButton(
        icon: const Icon(Icons.logout),
        tooltip: 'Logout (${provider.currentUser})',
        onPressed: () {
          provider.logout();
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logged out')));
        },
      );
    }
    return IconButton(
      icon: const Icon(Icons.login),
      tooltip: 'Login',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, TreeProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, colorScheme.primaryContainer],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.account_tree,
                      color: colorScheme.onPrimary, size: 36),
                ),
                const SizedBox(height: 10),
                Text(
                  'Vetviona',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (provider.isLoggedIn)
                  Text(
                    provider.currentUser ?? '',
                    style: TextStyle(
                        color: colorScheme.onPrimary.withOpacity(0.8)),
                  )
                else
                  Text(
                    'Not signed in',
                    style: TextStyle(
                        color: colorScheme.onPrimary.withOpacity(0.6),
                        fontSize: 12),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('Tree Diagram'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TreeDiagramScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text('Family Tree List'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TreeScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.device_hub_outlined),
            title: const Text('Relationship Finder'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const RelationshipFinderScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.family_restroom),
            title: const Text('Pedigree Chart'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PedigreeScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Birthdays & Anniversaries'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: const Text('RootLoop\u2122 Sync'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncScreen()),
              );
            },
          ),
          const Divider(),
          // Multiple family trees are available for paid tiers.
          if (currentAppTier != AppTier.mobileFree) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Trees',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    tooltip: 'New tree',
                    onPressed: () => _addTreeDialog(context, provider),
                  ),
                ],
              ),
            ),
            ...provider.treeNames.map((name) => ListTile(
                  leading: const Icon(Icons.park_outlined),
                  title: Text(name),
                  dense: true,
                )),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Import GEDCOM'),
            onTap: () {
              Navigator.pop(context);
              _importGEDCOM(context, provider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export GEDCOM'),
            onTap: () {
              Navigator.pop(context);
              _exportGEDCOM(context, provider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_view_outlined),
            title: const Text('Export to CSV'),
            onTap: () {
              Navigator.pop(context);
              _exportCSV(context, provider);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addTreeDialog(
      BuildContext context, TreeProvider provider) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Family Tree'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Tree name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await provider.addTree(name);
    }
  }

  Widget _buildFilterSortBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sortLabel = switch (_sortBy) {
      'birthYear' => _sortAscending ? 'Oldest first' : 'Youngest first',
      _ => _sortAscending ? 'Name A→Z' : 'Name Z→A',
    };
    return Container(
      color: colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Gender filters
            FilterChip(
              label: const Text('Male'),
              selected: _filterGender == 'male',
              onSelected: (v) => setState(
                  () => _filterGender = v ? 'male' : null),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('Female'),
              selected: _filterGender == 'female',
              onSelected: (v) => setState(
                  () => _filterGender = v ? 'female' : null),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('Other gender'),
              selected: _filterGender == 'other',
              onSelected: (v) => setState(
                  () => _filterGender = v ? 'other' : null),
            ),
            const SizedBox(width: 12),
            // Living/deceased filters
            FilterChip(
              label: const Text('Living'),
              selected: _filterLiving == true,
              onSelected: (v) => setState(
                  () => _filterLiving = v ? true : null),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('Deceased'),
              selected: _filterLiving == false,
              onSelected: (v) => setState(
                  () => _filterLiving = v ? false : null),
            ),
            const SizedBox(width: 12),
            // Sort popup
            PopupMenuButton<String>(
              tooltip: 'Sort',
              child: Chip(
                avatar: const Icon(Icons.sort, size: 16),
                label: Text(sortLabel),
              ),
              onSelected: (value) {
                setState(() {
                  switch (value) {
                    case 'nameAZ':
                      _sortBy = 'name';
                      _sortAscending = true;
                    case 'nameZA':
                      _sortBy = 'name';
                      _sortAscending = false;
                    case 'oldest':
                      _sortBy = 'birthYear';
                      _sortAscending = true;
                    case 'youngest':
                      _sortBy = 'birthYear';
                      _sortAscending = false;
                  }
                });
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'nameAZ', child: Text('Name A→Z')),
                PopupMenuItem(value: 'nameZA', child: Text('Name Z→A')),
                PopupMenuItem(value: 'oldest', child: Text('Oldest first')),
                PopupMenuItem(
                    value: 'youngest', child: Text('Youngest first')),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPeople(BuildContext context, TreeProvider provider) {
    final recent = _recentIds
        .map((id) =>
            provider.persons.where((p) => p.id == id).firstOrNull)
        .whereType<Person>()
        .toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Recently Viewed',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        SizedBox(
          height: 82,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recent.length,
            itemBuilder: (context, i) {
              final person = recent[i];
              final hasPhoto = person.photoPaths.isNotEmpty;
              Color avatarBg;
              Color avatarFg;
              if (person.gender?.toLowerCase() == 'male') {
                avatarBg = colorScheme.primary;
                avatarFg = colorScheme.onPrimary;
              } else if (person.gender?.toLowerCase() == 'female') {
                avatarBg = colorScheme.error;
                avatarFg = colorScheme.onError;
              } else {
                avatarBg = colorScheme.secondary;
                avatarFg = colorScheme.onSecondary;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await _saveRecentId(person.id);
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PersonDetailScreen(person: person),
                        ),
                      );
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      hasPhoto
                          ? CircleAvatar(
                              radius: 24,
                              backgroundImage:
                                  FileImage(File(person.photoPaths.first)),
                              backgroundColor: avatarBg,
                              onBackgroundImageError: (_, __) {},
                            )
                          : CircleAvatar(
                              radius: 24,
                              backgroundColor: avatarBg,
                              child: Text(
                                person.name.isNotEmpty
                                    ? person.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: avatarFg,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          person.name.split(' ').first,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Divider(
            height: 1,
            color: colorScheme.outlineVariant.withOpacity(0.5)),
      ],
    );
  }

  Widget _buildDuplicateBanner(BuildContext context, TreeProvider provider) {
    final dupes = provider.findDuplicates();
    if (dupes.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '\u26A0 Possible duplicates detected: ${dupes.length} group${dupes.length == 1 ? '' : 's'}',
              style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => _showDuplicatesDialog(context, provider, dupes),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }

  void _showDuplicatesDialog(BuildContext context, TreeProvider provider,
      List<List<Person>> dupes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Possible Duplicates'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: dupes.length,
            itemBuilder: (context, gi) {
              final group = dupes[gi];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (gi > 0) const Divider(height: 16),
                  Text(
                    'Group ${gi + 1}',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  for (int i = 0; i < group.length; i++)
                    for (int j = i + 1; j < group.length; j++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(group[i].name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  if (group[i].birthDate != null)
                                    Text(
                                        'b. ${group[i].birthDate!.year}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  const SizedBox(height: 2),
                                  Text(group[j].name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  if (group[j].birthDate != null)
                                    Text(
                                        'b. ${group[j].birthDate!.year}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await provider.mergePersons(
                                    group[i].id, group[j].id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Merged "${group[j].name}" into "${group[i].name}"'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Merge'),
                            ),
                          ],
                        ),
                      ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _exportCSV(
      BuildContext context, TreeProvider provider) async {
    try {
      String quoteCsvField(String field) {
        if (field.contains(',') ||
            field.contains('"') ||
            field.contains('\n')) {
          return '"${field.replaceAll('"', '""')}"';
        }
        return field;
      }

      final buf = StringBuffer();
      buf.writeln(
          'Name,Gender,Birth Date,Birth Place,Death Date,Death Place,Occupation,Nationality,Maiden Name,Burial Date,Burial Place,Notes,Parents,Children,Partners');

      final personMap = {for (final p in provider.persons) p.id: p};

      for (final p in provider.persons) {
        String fmt(DateTime? d) => d != null ? d.toIso8601String().split('T').first : '';

        final parents = p.parentIds
            .map((id) => personMap[id]?.name ?? id)
            .join('; ');
        final children = p.childIds
            .map((id) => personMap[id]?.name ?? id)
            .join('; ');
        final partners = provider
            .partnerIdsFor(p.id)
            .map((id) => personMap[id]?.name ?? id)
            .join('; ');

        final row = [
          p.name,
          p.gender ?? '',
          fmt(p.birthDate),
          p.birthPlace ?? '',
          fmt(p.deathDate),
          p.deathPlace ?? '',
          p.occupation ?? '',
          p.nationality ?? '',
          p.maidenName ?? '',
          fmt(p.burialDate),
          p.burialPlace ?? '',
          p.notes ?? '',
          parents,
          children,
          partners,
        ].map(quoteCsvField).join(',');

        buf.writeln(row);
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/vetviona_export_$timestamp.csv');
      await file.writeAsString(buf.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV exported to: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV export failed: $e')),
        );
      }
    }
  }

  Future<void> _importGEDCOM(
      BuildContext context, TreeProvider provider) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ged', 'gedcom'],
    );
    if (result != null && result.files.single.path != null) {
      try {
        await provider.importGEDCOM(result.files.single.path!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('GEDCOM imported successfully')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Import failed: $e')));
        }
      }
    }
  }

  Future<void> _exportGEDCOM(
      BuildContext context, TreeProvider provider) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/vetviona_export_$timestamp.ged';
      await provider.exportGEDCOM(path);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Exported to: $path')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final Person person;
  final VoidCallback? onTap;
  const _PersonCard({required this.person, this.onTap});

  /// Returns `(backgroundColor, foregroundColor)` based on gender.
  (Color, Color) _avatarColors(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (person.gender?.toLowerCase() == 'male') {
      return (colorScheme.primary, colorScheme.onPrimary);
    } else if (person.gender?.toLowerCase() == 'female') {
      return (colorScheme.error, colorScheme.onError);
    }
    return (colorScheme.secondary, colorScheme.onSecondary);
  }

  List<String> _validationWarnings() {
    final warnings = <String>[];
    final now = DateTime.now();
    if (person.birthDate != null && person.deathDate != null) {
      if (person.birthDate!.isAfter(person.deathDate!)) {
        warnings.add('Birth date is after death date');
      }
    }
    if (person.birthDate != null && person.birthDate!.isAfter(now)) {
      warnings.add('Birth date is in the future');
    }
    if (person.deathDate != null && person.deathDate!.isAfter(now)) {
      warnings.add('Death date is in the future');
    }
    return warnings;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (avatarBg, avatarFg) = _avatarColors(context);
    final hasPhoto = person.photoPaths.isNotEmpty;
    final warnings = _validationWarnings();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap ??
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonDetailScreen(person: person),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              hasPhoto
                  ? CircleAvatar(
                      radius: 26,
                      backgroundImage:
                          FileImage(File(person.photoPaths.first)),
                      backgroundColor: avatarBg,
                      onBackgroundImageError: (_, __) {},
                    )
                  : CircleAvatar(
                      radius: 26,
                      backgroundColor: avatarBg,
                      child: Text(
                        person.name.isNotEmpty
                            ? person.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: avatarFg,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            person.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (warnings.isNotEmpty)
                          Tooltip(
                            message: warnings.first,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_subtitle() != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _subtitle()!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (person.gender != null &&
                        person.gender!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: avatarBg.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            person.gender!,
                            style: TextStyle(
                                fontSize: 11,
                                color: avatarBg,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  String? _subtitle() {
    final parts = <String>[];
    if (person.birthDate != null) {
      parts.add('b. ${person.birthDate!.year}');
    }
    if (person.birthPlace != null && person.birthPlace!.isNotEmpty) {
      parts.add(person.birthPlace!);
    }
    if (person.deathDate != null) {
      parts.add('d. ${person.deathDate!.year}');
    }
    if (parts.isEmpty) return null;
    return parts.join(' \u00b7 ');
  }
}

// ── Statistics ─────────────────────────────────────────────────────────────────

class _TreeStats {
  final int totalPeople;
  final int livingCount;
  final int deceasedCount;
  final double? avgLifespan;
  final List<MapEntry<String, int>> topSurnames;
  final String? mostCommonDecade;
  final int generationCount;

  const _TreeStats({
    required this.totalPeople,
    required this.livingCount,
    required this.deceasedCount,
    required this.avgLifespan,
    required this.topSurnames,
    required this.mostCommonDecade,
    required this.generationCount,
  });
}

class _StatisticsCard extends StatelessWidget {
  final List<Person> persons;
  final List<Partnership> partnerships;

  const _StatisticsCard(
      {required this.persons, required this.partnerships});

  static _TreeStats _computeStats(
      List<Person> persons, List<Partnership> partnerships) {
    final living = persons.where((p) => p.deathDate == null).length;
    final deceased = persons.length - living;

    // Average lifespan
    double? avgLifespan;
    final lifespans = persons
        .where((p) => p.birthDate != null && p.deathDate != null)
        .map((p) => p.deathDate!.year - p.birthDate!.year)
        .toList();
    if (lifespans.isNotEmpty) {
      avgLifespan = lifespans.reduce((a, b) => a + b) / lifespans.length;
    }

    // Top surnames (last word of name, typically the family surname)
    final surnameCounts = <String, int>{};
    for (final p in persons) {
      final surname = p.name.trim().split(' ').last;
      if (surname.isNotEmpty) {
        surnameCounts[surname] = (surnameCounts[surname] ?? 0) + 1;
      }
    }
    final topSurnames = surnameCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = topSurnames.take(3).toList();

    // Birth decade distribution
    String? mostCommonDecade;
    final decadeCounts = <int, int>{};
    for (final p in persons) {
      if (p.birthDate != null) {
        final decade = (p.birthDate!.year ~/ 10) * 10;
        decadeCounts[decade] = (decadeCounts[decade] ?? 0) + 1;
      }
    }
    if (decadeCounts.isNotEmpty) {
      final topDecade =
          decadeCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      mostCommonDecade = '${topDecade.key}s: ${topDecade.value} people';
    }

    // Generation count: BFS max depth from root to leaf
    int generations = 0;
    if (persons.isNotEmpty) {
      final personMap = {for (final p in persons) p.id: p};
      final roots = persons.where((p) =>
          p.parentIds.isEmpty ||
          !p.parentIds.any((id) => personMap.containsKey(id)));
      var current = <String>{for (final r in roots) r.id};
      final visited = <String>{};
      while (current.isNotEmpty) {
        generations++;
        final next = <String>{};
        for (final id in current) {
          if (visited.contains(id)) continue;
          visited.add(id);
          final p = personMap[id];
          if (p == null) continue;
          for (final childId in p.childIds) {
            if (!visited.contains(childId) &&
                personMap.containsKey(childId)) {
              next.add(childId);
            }
          }
        }
        current = next;
      }
    }

    return _TreeStats(
      totalPeople: persons.length,
      livingCount: living,
      deceasedCount: deceased,
      avgLifespan: avgLifespan,
      topSurnames: top3,
      mostCommonDecade: mostCommonDecade,
      generationCount: generations,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats(persons, partnerships);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading:
            Icon(Icons.bar_chart, color: colorScheme.primary),
        title: const Text(
          'Statistics',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _StatRow(
                  icon: Icons.people,
                  label: 'Total people',
                  value: '${stats.totalPeople}',
                ),
                _StatRow(
                  icon: Icons.favorite,
                  label: 'Living',
                  value: '${stats.livingCount}',
                  valueColor: colorScheme.tertiary,
                ),
                _StatRow(
                  icon: Icons.star_border,
                  label: 'Deceased',
                  value: '${stats.deceasedCount}',
                  valueColor: colorScheme.onSurfaceVariant,
                ),
                if (stats.avgLifespan != null)
                  _StatRow(
                    icon: Icons.hourglass_bottom,
                    label: 'Avg lifespan',
                    value: '${stats.avgLifespan!.toStringAsFixed(1)} yrs',
                  ),
                if (stats.mostCommonDecade != null)
                  _StatRow(
                    icon: Icons.date_range_outlined,
                    label: 'Most common decade',
                    value: stats.mostCommonDecade!,
                  ),
                if (stats.topSurnames.isNotEmpty)
                  _StatRow(
                    icon: Icons.family_restroom,
                    label: 'Top surnames',
                    value: stats.topSurnames
                        .map((e) => '${e.key} (${e.value})')
                        .join(', '),
                  ),
                if (stats.generationCount > 0)
                  _StatRow(
                    icon: Icons.account_tree_outlined,
                    label: 'Generations',
                    value: '${stats.generationCount}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
