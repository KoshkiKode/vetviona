import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/person.dart';
import '../providers/tree_provider.dart';
import 'login_screen.dart';
import 'person_detail_screen.dart';
import 'relationship_finder_screen.dart';
import 'settings_screen.dart';
import 'tree_diagram_screen.dart';
import 'tree_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final filteredPersons = _searchQuery.isEmpty
        ? provider.persons
        : provider.searchPersons(_searchQuery);

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
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: filteredPersons.length,
                    itemBuilder: (context, i) =>
                        _PersonCard(person: filteredPersons[i]),
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
                    backgroundColor: Colors.orange,
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
                ? Colors.orange
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
                  ?.copyWith(color: Colors.grey),
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
                    color: Colors.white.withOpacity(0.2),
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
          const Divider(),
          // Multiple family trees are desktop-only for now.
          if (currentAppTier == AppTier.desktopPro) ...[
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
                          ?.copyWith(color: Colors.grey)),
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

  Future<void> _importGEDCOM(
      BuildContext context, TreeProvider provider) async {
    final result = await FilePicker.platform.pickFiles(
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
  const _PersonCard({required this.person});

  Color _avatarColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (person.gender?.toLowerCase() == 'male') {
      return const Color(0xFF1565C0);
    } else if (person.gender?.toLowerCase() == 'female') {
      return const Color(0xFFAD1457);
    }
    return colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarColor = _avatarColor(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PersonDetailScreen(person: person),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: avatarColor,
                child: Text(
                  person.name.isNotEmpty
                      ? person.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
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
                    Text(
                      person.name,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    if (_subtitle() != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _subtitle()!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
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
                            color: avatarColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            person.gender!,
                            style: TextStyle(
                                fontSize: 11,
                                color: avatarColor,
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
