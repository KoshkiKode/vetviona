import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../providers/tree_provider.dart';
import 'login_screen.dart';
import 'person_detail_screen.dart';
import 'settings_screen.dart';
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
    final filteredPersons = _searchQuery.isEmpty
        ? provider.persons
        : provider.searchPersons(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vetviona'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree),
            tooltip: 'Tree View',
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
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search people\u2026',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      drawer: _buildDrawer(context, provider),
      body: filteredPersons.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    provider.persons.isEmpty
                        ? 'No people yet.\nTap + to add the first person.'
                        : 'No results for "$_searchQuery".',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: filteredPersons.length,
              itemBuilder: (context, i) =>
                  _PersonCard(person: filteredPersons[i]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PersonDetailScreen()),
        ),
        tooltip: 'Add Person',
        child: const Icon(Icons.person_add),
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
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Logged out')));
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
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.account_tree, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                Text(
                  'Vetviona',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
                if (provider.isLoggedIn)
                  Text(
                    provider.currentUser ?? '',
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.account_tree),
            title: const Text('Family Tree'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TreeScreen()));
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Trees',
                    style: Theme.of(context).textTheme.labelLarge),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'New tree',
                  onPressed: () => _addTreeDialog(context, provider),
                ),
              ],
            ),
          ),
          ...provider.treeNames.asMap().entries.map((entry) {
            return ListTile(
              leading: const Icon(Icons.park),
              title: Text(entry.value),
              selected: entry.key < provider.treeNames.length,
              onTap: () {
                Navigator.pop(context);
              },
            );
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Import GEDCOM'),
            onTap: () {
              Navigator.pop(context);
              _importGEDCOM(context, provider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export GEDCOM'),
            onTap: () {
              Navigator.pop(context);
              _exportGEDCOM(context, provider);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
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

  Future<void> _addTreeDialog(BuildContext context, TreeProvider provider) async {
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
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await provider.addTree(name);
    }
  }

  Future<void> _importGEDCOM(BuildContext context, TreeProvider provider) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ged', 'gedcom'],
    );
    if (result != null && result.files.single.path != null) {
      try {
        await provider.importGEDCOM(result.files.single.path!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('GEDCOM imported successfully')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Import failed: $e')));
        }
      }
    }
  }

  Future<void> _exportGEDCOM(BuildContext context, TreeProvider provider) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/vetviona_export.ged';
      await provider.exportGEDCOM(path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to: $path')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}

class _PersonCard extends StatelessWidget {
  final Person person;
  const _PersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
          ),
        ),
        title: Text(person.name),
        subtitle: _buildSubtitle(),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PersonDetailScreen(person: person),
          ),
        ),
      ),
    );
  }

  Widget? _buildSubtitle() {
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
    return Text(parts.join(' \u00b7 '), maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}
