import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/partnership.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../services/pdf_report_service.dart';
import '../services/purchase_service.dart';
import '../utils/page_routes.dart';
import '../utils/platform_utils.dart';
import 'calendar_screen.dart';
import 'wikitree_screen.dart';
import 'conflict_resolver_screen.dart';
import 'descendants_screen.dart';
import 'family_timeline_screen.dart';
import 'gedcom_import_screen.dart';
import 'login_screen.dart';
import 'medical_history_screen.dart';
import 'pedigree_screen.dart';
import 'person_detail_screen.dart';
import 'relationship_certificate_screen.dart';
import 'relationship_finder_screen.dart';
import 'research_tasks_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'sync_screen.dart';
import 'tree_diagram_screen.dart';
import 'tree_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String? _filterGender;
  bool? _filterLiving;
  String _sortBy = 'name';
  bool _sortAscending = true;
  List<String> _recentIds = [];

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

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
    // Watch PurchaseService so the FAB and person-count label rebuild
    // immediately after a successful in-app purchase or restore.
    context.watch<PurchaseService>();
    final colorScheme = Theme.of(context).colorScheme;
    final filteredPersons = _applyFiltersAndSort(provider.persons);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    final fab = FloatingActionButton.extended(
      onPressed: provider.isAtPersonLimit
          ? () {
              HapticFeedback.heavyImpact();
              _showUpgradeDialog(context);
            }
          : () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                fadeSlideRoute(
                    builder: (_) => const PersonDetailScreen()),
              );
            },
      tooltip: provider.isAtPersonLimit
          ? 'Person limit reached — tap to upgrade'
          : 'Add a new person to your family tree',
      icon: Icon(
          provider.isAtPersonLimit ? Icons.lock_outline : Icons.person_add),
      label: Text(
          provider.isAtPersonLimit ? 'Limit Reached' : 'Add Person'),
    );

    final mainContent = _buildMainContent(
        context, provider, filteredPersons, colorScheme, isWide);

    Widget screen;
    if (isWide) {
      // Tablet / desktop: NavigationRail on the left, content on the right.
      screen = Scaffold(
        key: _scaffoldKey,
        appBar: _buildGlassAppBar(context, colorScheme, provider),
        drawer: _buildDrawer(context, provider),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NavigationRail(
              selectedIndex: 0,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (index) {
                switch (index) {
                  case 1:
                    Navigator.push(context,
                        fadeSlideRoute(builder: (_) => const TreeDiagramScreen()));
                  case 2:
                    Navigator.push(context,
                        fadeSlideRoute(builder: (_) => const CalendarScreen()));
                  case 3:
                    _scaffoldKey.currentState?.openDrawer();
                }
              },
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('People'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  selectedIcon: Icon(Icons.account_tree),
                  label: Text('Tree'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: Text('Calendar'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.menu),
                  selectedIcon: Icon(Icons.menu_open),
                  label: Text('More'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: mainContent),
          ],
        ),
        floatingActionButton: fab,
      );
    } else {
      screen = Scaffold(
        key: _scaffoldKey,
        extendBodyBehindAppBar: false,
        appBar: _buildGlassAppBar(context, colorScheme, provider),
        drawer: _buildDrawer(context, provider),
        body: mainContent,
        bottomNavigationBar: _buildNavBar(context),
        floatingActionButton: fab,
      );
    }

    // ── Desktop keyboard shortcuts ─────────────────────────────────────────
    // Only active on desktop (Windows / macOS / Linux).  Mobile platforms
    // don't need app-level shortcuts (they have touch/haptics instead).
    if (!isDesktop) return screen;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // ⌘N / Ctrl+N  → Add Person
        const SingleActivator(LogicalKeyboardKey.keyN,
            meta: true, control: false): const _AddPersonIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN,
            control: true, meta: false): const _AddPersonIntent(),
        // ⌘F / Ctrl+F  → Focus search bar
        const SingleActivator(LogicalKeyboardKey.keyF,
            meta: true, control: false): const _FocusSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF,
            control: true, meta: false): const _FocusSearchIntent(),
        // ⌘, / Ctrl+,  → Settings
        const SingleActivator(LogicalKeyboardKey.comma,
            meta: true, control: false): const _OpenSettingsIntent(),
        const SingleActivator(LogicalKeyboardKey.comma,
            control: true, meta: false): const _OpenSettingsIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _AddPersonIntent: CallbackAction<_AddPersonIntent>(
            onInvoke: (_) {
              if (!provider.isAtPersonLimit) {
                Navigator.push(
                  context,
                  fadeSlideRoute(builder: (_) => const PersonDetailScreen()),
                );
              }
              return null;
            },
          ),
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _searchFocusNode.requestFocus();
              return null;
            },
          ),
          _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
            onInvoke: (_) {
              Navigator.push(
                context,
                fadeSlideRoute(builder: (_) => const SettingsScreen()),
              );
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: screen),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    TreeProvider provider,
    List<Person> filteredPersons,
    ColorScheme colorScheme,
    bool isWide,
  ) {
    if (filteredPersons.isEmpty) {
      return _buildEmptyState(context, provider);
    }
    return Column(
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
            padding: EdgeInsets.only(bottom: isWide ? 80 : 100),
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
                      fadeSlideRoute(
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
    );
  }

  // ── Glass AppBar ─────────────────────────────────────────────────────────

  PreferredSizeWidget _buildGlassAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    TreeProvider provider,
  ) {
    final primary = colorScheme.primary;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 60),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AppBar(
            backgroundColor: primary.withOpacity(0.92),
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
                icon: const Icon(Icons.account_tree_outlined),
                tooltip: 'Tree Diagram',
                onPressed: () => Navigator.push(
                  context,
                  fadeSlideRoute(builder: (_) => const TreeDiagramScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.family_restroom),
                tooltip: 'Descendants Chart',
                onPressed: () => Navigator.push(
                  context,
                  fadeSlideRoute(builder: (_) => const DescendantsScreen()),
                ),
              ),
              _buildAuthButton(context, provider),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: TextField(
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search people\u2026',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: colorScheme.onPrimary.withOpacity(0.13),
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
        ),
      ),
    );
  }

  // ── Bottom Navigation Bar ────────────────────────────────────────────────

  Widget _buildNavBar(BuildContext context) {
    return NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            // Already on People tab — scroll to top is handled by list itself
            break;
          case 1:
            Navigator.push(
              context,
              fadeSlideRoute(builder: (_) => const TreeDiagramScreen()),
            );
          case 2:
            Navigator.push(
              context,
              fadeSlideRoute(builder: (_) => const CalendarScreen()),
            );
          case 3:
            _scaffoldKey.currentState?.openDrawer();
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'People',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_tree_outlined),
          selectedIcon: Icon(Icons.account_tree),
          label: 'Tree',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Calendar',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu),
          selectedIcon: Icon(Icons.menu_open),
          label: 'More',
        ),
      ],
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
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatChip(
            icon: Icons.people,
            label: personLabel,
            color: isFree && provider.isAtPersonLimit
                ? colorScheme.outlineVariant
                : colorScheme.primary,
          ),
          if (!isFree)
            _StatChip(
              icon: Icons.park,
              label:
                  '${provider.treeNames.length} tree${provider.treeNames.length == 1 ? '' : 's'}',
              color: colorScheme.tertiary,
            ),
          if (isFree && provider.isAtPersonLimit)
            Tooltip(
              message: 'You have reached the free-tier person limit. Tap to upgrade.',
              child: GestureDetector(
                onTap: () => _showUpgradeDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: colorScheme.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rocket_launch_outlined,
                          size: 14, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Upgrade',
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                  fadeSlideRoute(
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
        fadeSlideRoute(builder: (_) => const LoginScreen()),
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
                  fadeSlideRoute(
                      builder: (_) => const TreeDiagramScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text('Family Tree List'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  fadeSlideRoute(builder: (_) => const TreeScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.device_hub_outlined),
            title: const Text('Relationship Finder'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                fadeSlideRoute(
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
                fadeSlideRoute(builder: (_) => const PedigreeScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_tree),
            title: const Text('Descendants Chart'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                fadeSlideRoute(builder: (_) => const DescendantsScreen()),
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
                fadeSlideRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: const Text('RootLoop™ Sync'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                fadeSlideRoute(builder: (_) => const SyncScreen()),
              );
            },
          ),
          const Divider(),
          // ── Unique Features ─────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Research Tools',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Statistics & Insights'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                fadeSlideRoute(
                    builder: (_) => const StatisticsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.timeline_outlined),
            title: const Text('Family Timeline'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                fadeSlideRoute(
                    builder: (_) => const FamilyTimelineScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_hospital_outlined),
            title: const Text('Family Medical History'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                fadeSlideRoute(
                    builder: (_) => const MedicalHistoryScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('Research Tasks'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                fadeSlideRoute(
                    builder: (_) => const ResearchTasksScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('WikiTree & Find A Grave'),
            subtitle: const Text('Import, sync, link external profiles'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                fadeSlideRoute(builder: (_) => const WikiTreeScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: const Text('Relationship Certificate'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                fadeSlideRoute(
                    builder: (_) =>
                        const RelationshipCertificateScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Evidence Conflict Resolver'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                fadeSlideRoute(
                    builder: (_) => const ConflictResolverScreen()),
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
            ...provider.trees.map((tree) {
              final treeId = tree['id']!;
              final treeName = tree['name']!;
              final isActive = treeId == provider.currentTreeId;
              return ListTile(
                leading: Icon(
                  Icons.park_outlined,
                  color: isActive ? colorScheme.primary : null,
                ),
                title: Text(
                  treeName,
                  style: isActive
                      ? TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        )
                      : null,
                ),
                trailing: isActive
                    ? Icon(Icons.check_circle_outline,
                        size: 18, color: colorScheme.primary)
                    : PopupMenuButton<String>(
                        tooltip: 'Tree options',
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'switch',
                              child: ListTile(
                                leading: Icon(Icons.swap_horiz),
                                title: Text('Switch to'),
                                contentPadding: EdgeInsets.zero,
                              )),
                          const PopupMenuItem(
                              value: 'rename',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Rename'),
                                contentPadding: EdgeInsets.zero,
                              )),
                          if (treeId != 'default')
                            PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete_outline,
                                      color:
                                          Theme.of(context).colorScheme.error),
                                  title: Text('Delete',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)),
                                  contentPadding: EdgeInsets.zero,
                                )),
                        ],
                        onSelected: (action) {
                          switch (action) {
                            case 'switch':
                              Navigator.pop(context);
                              provider.switchTree(treeId);
                            case 'rename':
                              _renameTreeDialog(
                                  context, provider, treeId, treeName);
                            case 'delete':
                              _deleteTreeConfirm(
                                  context, provider, treeId, treeName);
                          }
                        },
                      ),
                dense: true,
                onTap: isActive
                    ? null
                    : () {
                        Navigator.pop(context);
                        provider.switchTree(treeId);
                      },
              );
            }),
            const Divider(),
          ],
          // GEDCOM import/export is a Desktop Pro feature.
          if (currentAppTier == AppTier.desktopPro) ...[
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Import GEDCOM'),
              onTap: () {
                Navigator.pop(context);
                _importGEDCOM(context, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.merge_outlined),
              title: const Text('Combine GEDCOM'),
              subtitle: const Text('Merge into existing tree (deduplicates)'),
              onTap: () {
                Navigator.pop(context);
                _combineGEDCOM(context, provider);
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
          ],
          ListTile(
            leading: const Icon(Icons.table_view_outlined),
            title: const Text('Export to CSV'),
            onTap: () {
              Navigator.pop(context);
              _exportCSV(context, provider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Export Family Book PDF'),
            onTap: () {
              Navigator.pop(context);
              _exportPDF(context, provider);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  fadeSlideRoute(builder: (_) => const SettingsScreen()));
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
      builder: (ctx) => AlertDialog.adaptive(
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
    controller.dispose();
  }

  Future<void> _renameTreeDialog(BuildContext context, TreeProvider provider,
      String treeId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Rename Tree'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'New tree name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Rename')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != currentName) {
      await provider.renameTree(treeId, newName);
    }
    controller.dispose();
  }

  Future<void> _deleteTreeConfirm(BuildContext context, TreeProvider provider,
      String treeId, String treeName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Delete Tree?'),
        content: Text(
            'This will permanently delete "$treeName" and all its people, '
            'sources, and partnerships. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteTree(treeId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$treeName" deleted.')),
        );
      }
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
                        fadeSlideRoute(
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
      builder: (ctx) => AlertDialog.adaptive(
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

  /// Shows a dialog asking whether to include full details for living people.
  ///
  /// Returns `true` if the user wants full data, `false` for generic labels,
  /// or `null` if the dialog was dismissed.
  Future<bool?> _askLivingDataPolicy(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Living People'),
        content: const Text(
          'How should living people (no recorded death date) appear in the export?\n\n'
          '• Generic labels — names and personal details are replaced with "Living" to protect privacy (default).\n'
          '• Full details — all data is included as-is.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Generic Labels'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Full Details'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCSV(
      BuildContext context, TreeProvider provider) async {
    final includeLivingData = await _askLivingDataPolicy(context);
    if (includeLivingData == null) return; // cancelled

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
        // Private persons are always excluded from exports.
        if (p.isPrivate) continue;

        String formatDate(DateTime? d) =>
          d != null ? d.toIso8601String().split('T').first : '';

        final isLiving = p.deathDate == null;

        // Resolve the display name for partner/parent/child resolution.
        // If the referenced person is living and we're genericising, show
        // "Living" instead of their real name.
        String resolveName(String id) {
          final ref = personMap[id];
          if (ref == null) return id;
          if (!includeLivingData && ref.deathDate == null) return 'Living';
          return ref.name;
        }

        final parents = p.parentIds.map(resolveName).join('; ');
        final children = p.childIds.map(resolveName).join('; ');
        final partners =
            provider.partnerIdsFor(p.id).map(resolveName).join('; ');

        // Personal detail columns — blanked out for living people unless the
        // user explicitly chose to include full data.
        final String name;
        final String gender, birthDate, birthPlace, deathDate, deathPlace,
            occupation, nationality, maidenName, burialDate, burialPlace, notes;
        if (!includeLivingData && isLiving) {
          name = 'Living';
          gender = birthDate = birthPlace = deathDate = deathPlace =
              occupation = nationality = maidenName =
              burialDate = burialPlace = notes = '';
        } else {
          name = p.name;
          gender = p.gender ?? '';
          birthDate = formatDate(p.birthDate);
          birthPlace = p.birthPlace ?? '';
          deathDate = formatDate(p.deathDate);
          deathPlace = p.deathPlace ?? '';
          occupation = p.occupation ?? '';
          nationality = p.nationality ?? '';
          maidenName = p.maidenName ?? '';
          burialDate = formatDate(p.burialDate);
          burialPlace = p.burialPlace ?? '';
          notes = p.notes ?? '';
        }

        final values = [
          name, gender, birthDate, birthPlace, deathDate, deathPlace,
          occupation, nationality, maidenName, burialDate, burialPlace, notes,
          parents, children, partners,
        ];

        buf.writeln(values.map(quoteCsvField).join(','));
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
    if (result != null && result.files.single.path != null && context.mounted) {
      Navigator.push(
        context,
        fadeSlideRoute(
          builder: (_) => GedcomImportScreen(
            filePath: result.files.single.path!,
            mergeMode: false,
          ),
        ),
      );
    }
  }

  Future<void> _combineGEDCOM(
      BuildContext context, TreeProvider provider) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ged', 'gedcom'],
    );
    if (result != null && result.files.single.path != null && context.mounted) {
      Navigator.push(
        context,
        fadeSlideRoute(
          builder: (_) => GedcomImportScreen(
            filePath: result.files.single.path!,
            mergeMode: true,
          ),
        ),
      );
    }
  }

  Future<void> _exportGEDCOM(
      BuildContext context, TreeProvider provider) async {
    final includeLivingData = await _askLivingDataPolicy(context);
    if (includeLivingData == null) return; // cancelled

    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/vetviona_export_$timestamp.ged';
      await provider.exportGEDCOM(path, includeLivingData: includeLivingData);
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

  Future<void> _exportPDF(
      BuildContext context, TreeProvider provider) async {
    final includeLivingData = await _askLivingDataPolicy(context);
    if (includeLivingData == null) return;

    try {
      final path = await PdfReportService.generate(
        persons: provider.persons,
        partnerships: provider.partnerships,
        lifeEvents: provider.lifeEvents,
        medicalConditions: provider.medicalConditions,
        sources: provider.sources,
        treeName: provider.currentTreeName,
        includeLivingData: includeLivingData,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF saved to: $path')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
      }
    }
  }

  void _showUpgradeDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        icon: Icon(Icons.rocket_launch_outlined,
            color: colorScheme.primary, size: 40),
        title: const Text('Upgrade Vetviona'),
        content: Consumer<PurchaseService>(
          builder: (consumerCtx, purchaseService, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You've reached the free tier limit of $freeMobilePersonLimit people.",
                style: Theme.of(consumerCtx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _UpgradeTierRow(
                icon: Icons.phone_android,
                tier: 'Mobile Paid',
                description: 'Unlimited people · RootLoop™ Auto Sync',
                color: colorScheme.secondary,
              ),
              const SizedBox(height: 8),
              _UpgradeTierRow(
                icon: Icons.computer,
                tier: 'Desktop Pro',
                description:
                    'All mobile features · Multi-tree · Advanced export',
                color: colorScheme.primary,
              ),
              if (purchaseService.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  purchaseService.errorMessage!,
                  style: TextStyle(
                      color: colorScheme.error, fontSize: 12),
                ),
              ],
              if (purchaseService.product != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Mobile Paid: ${purchaseService.product!.price}',
                  style: Theme.of(consumerCtx)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now'),
          ),
          Consumer<PurchaseService>(
            builder: (consumerCtx, purchaseService, _) {
              if (purchaseService.isPurchased) {
                return FilledButton.icon(
                  icon:
                      const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Purchased'),
                  onPressed: () => Navigator.pop(ctx),
                );
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: purchaseService.isLoading
                        ? null
                        : () => purchaseService.restorePurchases(),
                    child: const Text('Restore'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: purchaseService.isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator.adaptive(),
                          )
                        : const Icon(
                            Icons.shopping_cart_outlined, size: 16),
                    label: const Text('Upgrade'),
                    onPressed: purchaseService.isLoading
                        ? null
                        : () async {
                            if (purchaseService.product == null) {
                              await purchaseService.loadProduct();
                            }
                            await purchaseService.buyMobilePaid();
                          },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UpgradeTierRow extends StatelessWidget {
  final IconData icon;
  final String tier;
  final String description;
  final Color color;

  const _UpgradeTierRow({
    required this.icon,
    required this.tier,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tier,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                description,
                style: TextStyle(
                    fontSize: 11,
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
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

  void _openPerson(BuildContext context) {
    Navigator.push(
      context,
      fadeSlideRoute(builder: (_) => PersonDetailScreen(person: person)),
    );
  }

  /// Shows the quick-action context menu.
  ///
  /// [position] is only used on desktop (right-click at cursor position).
  /// On mobile it anchors to the bottom of the screen.
  Future<void> _showContextMenu(
      BuildContext context, Offset? position) async {
    final choice = await showMenu<String>(
      context: context,
      position: position != null
          ? RelativeRect.fromLTRB(
              position.dx, position.dy, position.dx + 1, position.dy + 1)
          : RelativeRect.fromLTRB(
              0,
              MediaQuery.sizeOf(context).height - 200,
              MediaQuery.sizeOf(context).width,
              0,
            ),
      items: [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        const PopupMenuItem(value: 'copy_name', child: Text('Copy Name')),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'edit':
        _openPerson(context);
      case 'copy_name':
        await Clipboard.setData(ClipboardData(text: person.name));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied "${person.name}"'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (avatarBg, avatarFg) = _avatarColors(context);
    final hasPhoto = person.photoPaths.isNotEmpty;
    final warnings = _validationWarnings();

    final defaultTap = () => _openPerson(context);

    return Card(
      child: GestureDetector(
        // Desktop: right-click → context menu at cursor
        onSecondaryTapUp: isDesktop
            ? (details) =>
                _showContextMenu(context, details.globalPosition)
            : null,
        // Mobile: long-press → context menu + haptic
        onLongPress: isMobile
            ? () {
                HapticFeedback.mediumImpact();
                _showContextMenu(context, null);
              }
            : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap ?? defaultTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
              hasPhoto
                  ? Hero(
                      tag: 'person_avatar_${person.id}',
                      child: CircleAvatar(
                        radius: 26,
                        backgroundImage:
                            FileImage(File(person.photoPaths.first)),
                        backgroundColor: avatarBg,
                        onBackgroundImageError: (_, __) {},
                      ),
                    )
                  : Hero(
                      tag: 'person_avatar_${person.id}',
                      child: CircleAvatar(
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
                        if (person.isPrivate)
                          Tooltip(
                            message: 'Private — excluded from exports & sync',
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.lock_outline,
                                size: 16,
                                color: colorScheme.primary,
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

// ── Desktop keyboard shortcut intents ─────────────────────────────────────────

class _AddPersonIntent extends Intent {
  const _AddPersonIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
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
