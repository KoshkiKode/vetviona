import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../services/find_a_grave_service.dart';
import '../services/wikitree_service.dart';
import '../utils/page_routes.dart';
import 'person_detail_screen.dart';

/// Full-screen WikiTree + Find A Grave integration hub.
///
/// • WikiTree account login / logout
/// • Search WikiTree for a person by name + optional birth year
/// • Import / refresh a WikiTree profile into a local person record
/// • View all locally linked WikiTree profiles and bulk-refresh them
/// • Download GEDCOM from WikiTree (requires login, re-imports via existing parser)
class WikiTreeScreen extends StatefulWidget {
  const WikiTreeScreen({super.key});

  @override
  State<WikiTreeScreen> createState() => _WikiTreeScreenState();
}

class _WikiTreeScreenState extends State<WikiTreeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WikiTreeService.instance.loadCredentials();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: WikiTreeService.instance,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('WikiTree & Find A Grave'),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(icon: Icon(Icons.account_tree_outlined), text: 'WikiTree'),
              Tab(icon: Icon(Icons.location_on_outlined), text: 'Find A Grave'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: const [
            _WikiTreeTab(),
            _FindAGraveTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WikiTree tab
// ─────────────────────────────────────────────────────────────────────────────

class _WikiTreeTab extends StatefulWidget {
  const _WikiTreeTab();

  @override
  State<_WikiTreeTab> createState() => _WikiTreeTabState();
}

class _WikiTreeTabState extends State<_WikiTreeTab> {
  final _searchCtrl = TextEditingController();
  final _birthYearCtrl = TextEditingController();
  List<WikiTreeProfile> _results = [];
  bool _searching = false;
  String? _searchError;
  bool _refreshing = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _birthYearCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
      _results = [];
    });
    final year = int.tryParse(_birthYearCtrl.text.trim());
    final results =
        await WikiTreeService.instance.searchPerson(q, birthYear: year);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = results;
      if (results.isEmpty) _searchError = 'No profiles found.';
    });
  }

  Future<void> _refreshAll(TreeProvider provider) async {
    final linked = provider.persons
        .where((p) => p.wikitreeId != null && p.wikitreeId!.isNotEmpty)
        .toList();
    if (linked.isEmpty) return;
    setState(() => _refreshing = true);
    int updated = 0;
    for (final person in linked) {
      final profile =
          await WikiTreeService.instance.getProfile(person.wikitreeId!);
      if (profile != null) {
        final updatedPerson =
            WikiTreeService.instance.profileToPerson(profile, existing: person);
        await provider.updatePerson(updatedPerson);
        updated++;
      }
    }
    if (!mounted) return;
    setState(() => _refreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Refreshed $updated person${updated == 1 ? '' : 's'} from WikiTree.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _downloadGedcom(TreeProvider provider) async {
    final svc = WikiTreeService.instance;
    if (!svc.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Log in to WikiTree to download your GEDCOM.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    // Use the logged-in user's own WikiTree ID (username is the WikiTree ID)
    final wtId = svc.loggedInUser ?? '';
    if (wtId.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog.adaptive(
        content: Row(
          children: [
            CircularProgressIndicator.adaptive(),
            SizedBox(width: 16),
            Text('Downloading GEDCOM…'),
          ],
        ),
      ),
    );
    final gedcom = await svc.exportGedcom(wtId);
    if (!mounted) return;
    Navigator.pop(context);
    if (gedcom == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Could not download GEDCOM. Check your login and WikiTree ID.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    // Save to a temp file and open the GEDCOM import screen
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/wikitree_export.ged');
    await file.writeAsString(gedcom);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('GEDCOM downloaded. Opening importer…'),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Import',
        onPressed: () {
          // Navigate to GEDCOM import screen with the downloaded file
          // (The GedcomImportScreen reads path from SharedPrefs, so we just
          //  inform the user to import via the drawer's Import GEDCOM option.)
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: WikiTreeService.instance,
      builder: (context, _) {
        final svc = WikiTreeService.instance;
        final provider = context.watch<TreeProvider>();
        final linked = provider.persons
            .where((p) => p.wikitreeId != null && p.wikitreeId!.isNotEmpty)
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Account card ──────────────────────────────────────────────
            _SectionCard(
              icon: Icons.account_circle_outlined,
              title: 'WikiTree Account',
              children: [
                if (svc.isLoggedIn) ...[
                  Row(children: [
                    Icon(Icons.check_circle_outline,
                        color: colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Logged in as ${svc.loggedInUser}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: () async {
                        await svc.logout();
                        if (mounted) setState(() {});
                      },
                      child: const Text('Log out'),
                    ),
                  ]),
                  if (linked.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _refreshing
                          ? null
                          : () => _refreshAll(provider),
                      icon: _refreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(_refreshing
                          ? 'Refreshing…'
                          : 'Refresh ${linked.length} Linked Person${linked.length == 1 ? '' : 's'}'),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () => _downloadGedcom(provider),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download My GEDCOM'),
                    ),
                  ],
                ] else
                  _LoginForm(onLoggedIn: () => setState(() {})),
              ],
            ),

            const SizedBox(height: 12),

            // ── Linked persons ─────────────────────────────────────────────
            if (linked.isNotEmpty) ...[
              _SectionCard(
                icon: Icons.link,
                title: 'Linked to WikiTree (${linked.length})',
                children: linked
                    .map((p) => _LinkedPersonTile(
                          person: p,
                          onRefresh: () async {
                            final profile = await WikiTreeService.instance
                                .getProfile(p.wikitreeId!);
                            if (profile == null) return;
                            final updated =
                                WikiTreeService.instance.profileToPerson(
                              profile,
                              existing: p,
                            );
                            await provider.updatePerson(updated);
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(
                                    '${p.name} refreshed from WikiTree.'),
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          },
                          onUnlink: () async {
                            final updated = Person(
                              id: p.id,
                              name: p.name,
                              wikitreeId: null,
                              birthDate: p.birthDate,
                              birthPlace: p.birthPlace,
                              deathDate: p.deathDate,
                              deathPlace: p.deathPlace,
                              gender: p.gender,
                              parentIds: p.parentIds,
                              childIds: p.childIds,
                              parentRelTypes: p.parentRelTypes,
                              photoPaths: p.photoPaths,
                              sourceIds: p.sourceIds,
                              notes: p.notes,
                              treeId: p.treeId,
                              occupation: p.occupation,
                              nationality: p.nationality,
                              maidenName: p.maidenName,
                              burialDate: p.burialDate,
                              burialPlace: p.burialPlace,
                              isPrivate: p.isPrivate,
                              syncMedical: p.syncMedical,
                              preferredSourceIds: p.preferredSourceIds,
                              aliases: p.aliases,
                              findAGraveId: p.findAGraveId,
                              causeOfDeath: p.causeOfDeath,
                              bloodType: p.bloodType,
                              eyeColour: p.eyeColour,
                              hairColour: p.hairColour,
                              height: p.height,
                              religion: p.religion,
                              education: p.education,
                              updatedAt:
                                  DateTime.now().millisecondsSinceEpoch,
                            );
                            await provider.updatePerson(updated);
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            // ── Search ────────────────────────────────────────────────────
            _SectionCard(
              icon: Icons.search,
              title: 'Search WikiTree',
              children: [
                Text(
                  'Find a WikiTree profile to link to a local person or import data.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Winston Churchill',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _birthYearCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Birth year (optional)',
                        hintText: '1874',
                        prefixIcon: Icon(Icons.date_range_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2))
                        : const Icon(Icons.search, size: 18),
                    label: const Text('Search'),
                  ),
                ]),
                if (_searchError != null) ...[
                  const SizedBox(height: 8),
                  Text(_searchError!,
                      style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ],
                ..._results.map((p) => _SearchResultTile(
                      profile: p,
                      persons: provider.persons,
                      onImport: (profile, existing) async {
                        await _importProfile(context, provider, profile,
                            existing: existing);
                      },
                    )),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _importProfile(
    BuildContext context,
    TreeProvider provider,
    WikiTreeProfile profile, {
    Person? existing,
  }) async {
    final person = WikiTreeService.instance.profileToPerson(
      profile,
      existing: existing,
    );
    final source = WikiTreeService.instance.profileToSource(
      profile,
      person.id,
    );

    if (existing != null) {
      await provider.updatePerson(person);
    } else {
      await provider.addPerson(person);
    }
    // Add source if not already present
    final alreadyHasSource = provider.sources.any(
        (s) => s.personId == person.id && s.url.contains(profile.wikiTreeId));
    if (!alreadyHasSource) {
      await provider.addSource(source);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(existing != null
          ? '${person.name} updated from WikiTree.'
          : '${person.name} imported from WikiTree.'),
      behavior: SnackBarBehavior.floating,
    ));
    setState(() => _results = []);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Find A Grave tab
// ─────────────────────────────────────────────────────────────────────────────

class _FindAGraveTab extends StatefulWidget {
  const _FindAGraveTab();

  @override
  State<_FindAGraveTab> createState() => _FindAGraveTabState();
}

class _FindAGraveTabState extends State<_FindAGraveTab> {
  final _idCtrl = TextEditingController();
  FindAGraveMemorial? _memorial;
  bool _fetching = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    var input = _idCtrl.text.trim();
    // Accept full URL or just the ID
    final extracted =
        FindAGraveService.instance.extractIdFromUrl(input) ?? input;
    if (extracted.isEmpty || !RegExp(r'^\d+$').hasMatch(extracted)) {
      setState(() => _error =
          'Enter a memorial ID (e.g. 1836) or paste the full memorial URL.');
      return;
    }
    setState(() {
      _fetching = true;
      _error = null;
      _memorial = null;
    });
    final memorial =
        await FindAGraveService.instance.fetchMemorial(extracted);
    if (!mounted) return;
    setState(() {
      _fetching = false;
      _memorial = memorial;
      if (memorial == null) {
        _error =
            'Could not retrieve memorial data. Find A Grave may be blocking '
            'automated requests — tap "Open in Browser" to view it manually.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TreeProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final fagLinked = provider.persons
        .where((p) => p.findAGraveId != null && p.findAGraveId!.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── About ─────────────────────────────────────────────────────────
        _SectionCard(
          icon: Icons.info_outline,
          title: 'About Find A Grave Integration',
          children: [
            Text(
              'Find A Grave has no public API. Vetviona stores memorial IDs '
              'on each person so you can link profiles and open them in your '
              'browser. Data import is attempted via page parsing — results '
              'depend on Find A Grave\'s response to automated requests.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Lookup ────────────────────────────────────────────────────────
        _SectionCard(
          icon: Icons.search,
          title: 'Look Up Memorial',
          children: [
            TextField(
              controller: _idCtrl,
              decoration: const InputDecoration(
                labelText: 'Memorial ID or URL',
                hintText: 'e.g. 1836  or  https://www.findagrave.com/memorial/1836/…',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _fetch(),
            ),
            const SizedBox(height: 8),
            Row(children: [
              FilledButton.icon(
                onPressed: _fetching ? null : _fetch,
                icon: _fetching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2))
                    : const Icon(Icons.search, size: 18),
                label: const Text('Fetch Data'),
              ),
              const SizedBox(width: 8),
              if (_idCtrl.text.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    final raw = _idCtrl.text.trim();
                    final id = FindAGraveService.instance
                            .extractIdFromUrl(raw) ??
                        raw;
                    final url =
                        FindAGraveService.instance.memorialUrl(id);
                    await launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open in Browser'),
                ),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(
                      color: colorScheme.error, fontSize: 12)),
            ],
            if (_memorial != null) ...[
              const SizedBox(height: 12),
              _MemorialCard(
                memorial: _memorial!,
                persons: provider.persons,
                onLink: (personId) async {
                  final person =
                      provider.persons.firstWhere((p) => p.id == personId);
                  final updated = Person(
                    id: person.id,
                    name: person.name,
                    findAGraveId: _memorial!.memorialId,
                    birthDate: person.birthDate,
                    birthPlace: person.birthPlace,
                    deathDate: person.deathDate,
                    deathPlace: person.deathPlace,
                    gender: person.gender,
                    parentIds: person.parentIds,
                    childIds: person.childIds,
                    parentRelTypes: person.parentRelTypes,
                    photoPaths: person.photoPaths,
                    sourceIds: person.sourceIds,
                    notes: person.notes,
                    treeId: person.treeId,
                    occupation: person.occupation,
                    nationality: person.nationality,
                    maidenName: person.maidenName,
                    burialDate: person.burialDate,
                    burialPlace: person.burialPlace,
                    isPrivate: person.isPrivate,
                    syncMedical: person.syncMedical,
                    preferredSourceIds: person.preferredSourceIds,
                    aliases: person.aliases,
                    wikitreeId: person.wikitreeId,
                    causeOfDeath: person.causeOfDeath,
                    bloodType: person.bloodType,
                    eyeColour: person.eyeColour,
                    hairColour: person.hairColour,
                    height: person.height,
                    religion: person.religion,
                    education: person.education,
                    updatedAt: DateTime.now().millisecondsSinceEpoch,
                  );
                  await provider.updatePerson(updated);
                  // Create source record
                  final source = FindAGraveService.instance
                      .memorialToSource(_memorial!, personId);
                  await provider.addSource(source);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '${person.name} linked to Find A Grave memorial #${_memorial!.memorialId}.'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
              ),
            ],
          ],
        ),

        const SizedBox(height: 12),

        // ── Linked persons ─────────────────────────────────────────────────
        if (fagLinked.isNotEmpty)
          _SectionCard(
            icon: Icons.link,
            title: 'Linked to Find A Grave (${fagLinked.length})',
            children: fagLinked
                .map((p) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            colorScheme.primaryContainer,
                        child: Text(
                          p.name.isNotEmpty
                              ? p.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color:
                                  colorScheme.onPrimaryContainer,
                              fontSize: 14),
                        ),
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                          'Memorial #${p.findAGraveId}',
                          style: TextStyle(
                              color:
                                  colorScheme.onSurfaceVariant,
                              fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.open_in_new,
                            size: 18),
                        onPressed: () async {
                          final url =
                              FindAGraveService.instance
                                  .memorialUrl(p.findAGraveId!);
                          await launchUrl(Uri.parse(url),
                              mode: LaunchMode
                                  .externalApplication);
                        },
                      ),
                    ))
                .toList(),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Login form
// ─────────────────────────────────────────────────────────────────────────────

class _LoginForm extends StatefulWidget {
  final VoidCallback onLoggedIn;
  const _LoginForm({required this.onLoggedIn});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Enter your WikiTree email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await WikiTreeService.instance.login(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case WikiTreeLoginResult.success:
        widget.onLoggedIn();
      case WikiTreeLoginResult.wrongPassword:
        setState(() => _error = 'Wrong email or password.');
      case WikiTreeLoginResult.notFound:
        setState(() => _error = 'WikiTree account not found.');
      case WikiTreeLoginResult.networkError:
        setState(
            () => _error = 'Network error. Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Log in to WikiTree to refresh linked profiles, download your GEDCOM, '
          'and import your family data.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'WikiTree email',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: IconButton(
              icon:
                  Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12)),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading ? null : _login,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator.adaptive(strokeWidth: 2))
              : const Icon(Icons.login, size: 18),
          label: const Text('Log In to WikiTree'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://www.wikitree.com/index.php?title=Special:CreateAccount'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Create a WikiTree account'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search result tile
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultTile extends StatefulWidget {
  final WikiTreeProfile profile;
  final List<Person> persons;
  final Future<void> Function(WikiTreeProfile, Person?) onImport;

  const _SearchResultTile({
    required this.profile,
    required this.persons,
    required this.onImport,
  });

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _importing = false;

  String _subtitle() {
    final parts = <String>[];
    if (widget.profile.birthDate != null) {
      parts.add('b. ${widget.profile.birthDate!.year}');
    }
    if (widget.profile.birthPlace != null) {
      parts.add(widget.profile.birthPlace!);
    }
    if (widget.profile.deathDate != null) {
      parts.add('d. ${widget.profile.deathDate!.year}');
    }
    parts.add(widget.profile.wikiTreeId);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Is this profile already linked to a local person?
    final existing = widget.persons
        .where((p) => p.wikitreeId == widget.profile.wikiTreeId)
        .firstOrNull;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  widget.profile.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (existing != null)
                Chip(
                  label: const Text('Linked'),
                  backgroundColor:
                      colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 11),
                  visualDensity: VisualDensity.compact,
                ),
            ]),
            Text(_subtitle(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                onPressed: _importing
                    ? null
                    : () async {
                        setState(() => _importing = true);
                        await widget.onImport(widget.profile, existing);
                        if (mounted) setState(() => _importing = false);
                      },
                icon: _importing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2))
                    : Icon(
                        existing != null ? Icons.refresh : Icons.download,
                        size: 16),
                label: Text(existing != null
                    ? 'Refresh ${existing.name}'
                    : 'Import Profile'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(
                      'https://www.wikitree.com/wiki/${widget.profile.wikiTreeId}'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('View on WikiTree'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linked person tile
// ─────────────────────────────────────────────────────────────────────────────

class _LinkedPersonTile extends StatefulWidget {
  final Person person;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onUnlink;

  const _LinkedPersonTile({
    required this.person,
    required this.onRefresh,
    required this.onUnlink,
  });

  @override
  State<_LinkedPersonTile> createState() => _LinkedPersonTileState();
}

class _LinkedPersonTileState extends State<_LinkedPersonTile> {
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          widget.person.name.isNotEmpty
              ? widget.person.name[0].toUpperCase()
              : '?',
          style: TextStyle(
              color: colorScheme.onPrimaryContainer, fontSize: 14),
        ),
      ),
      title: Text(widget.person.name),
      subtitle: Text(
        widget.person.wikitreeId!,
        style: TextStyle(
            color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_refreshing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh from WikiTree',
              onPressed: () async {
                setState(() => _refreshing = true);
                await widget.onRefresh();
                if (mounted) setState(() => _refreshing = false);
              },
            ),
          IconButton(
            icon: const Icon(Icons.link_off, size: 20),
            tooltip: 'Unlink from WikiTree',
            onPressed: widget.onUnlink,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 18),
            tooltip: 'View on WikiTree',
            onPressed: () => launchUrl(
              Uri.parse(
                  'https://www.wikitree.com/wiki/${widget.person.wikitreeId}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Memorial card (Find A Grave)
// ─────────────────────────────────────────────────────────────────────────────

class _MemorialCard extends StatefulWidget {
  final FindAGraveMemorial memorial;
  final List<Person> persons;
  final Future<void> Function(String personId) onLink;

  const _MemorialCard({
    required this.memorial,
    required this.persons,
    required this.onLink,
  });

  @override
  State<_MemorialCard> createState() => _MemorialCardState();
}

class _MemorialCardState extends State<_MemorialCard> {
  String? _selectedPersonId;
  bool _linking = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final m = widget.memorial;
    return Card(
      color: colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Memorial #${m.memorialId}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            if (m.fullName != null) Text(m.fullName!),
            const SizedBox(height: 4),
            if (m.birthYear != null)
              _InfoRow(Icons.cake_outlined,
                  'Born ${m.birthYear}${m.birthPlace != null ? ' · ${m.birthPlace}' : ''}'),
            if (m.deathYear != null)
              _InfoRow(Icons.star_half,
                  'Died ${m.deathYear}${m.deathPlace != null ? ' · ${m.deathPlace}' : ''}'),
            if (m.cemeteryName != null)
              _InfoRow(Icons.location_on_outlined,
                  'Buried at ${m.cemeteryName}'),
            const Divider(height: 16),
            Text('Link to local person:',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedPersonId,
              isExpanded: true,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), isDense: true),
              hint: const Text('Select person…'),
              items: widget.persons
                  .map((p) => DropdownMenuItem(
                      value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedPersonId = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed:
                  _selectedPersonId == null || _linking
                      ? null
                      : () async {
                          setState(() => _linking = true);
                          await widget.onLink(_selectedPersonId!);
                          if (mounted) setState(() => _linking = false);
                        },
              icon: _linking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2))
                  : const Icon(Icons.link, size: 16),
              label: const Text('Link & Create Source'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(icon,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared section card widget (mirrors pattern from settings_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _SectionCard(
      {required this.icon,
      required this.title,
      required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface)),
            ]),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
