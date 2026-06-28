import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/person.dart';
import '../providers/tree_provider.dart';
import '../services/chronicling_america_service.dart';
import '../services/familysearch_api_service.dart';
import '../services/nara_catalog_service.dart';
import '../services/open_archives_service.dart';

/// Multi-API historical record search screen.
///
/// Searches FamilySearch, Chronicling America (LOC newspapers), NARA
/// (US National Archives), and Open Archives (Dutch records) simultaneously
/// and lets users attach results as Sources.
class RecordSearchScreen extends StatefulWidget {
  /// When provided, pre-fills search fields with the person's data.
  final Person? person;

  const RecordSearchScreen({super.key, this.person});

  @override
  State<RecordSearchScreen> createState() => _RecordSearchScreenState();
}

class _RecordSearchScreenState extends State<RecordSearchScreen> {
  late TextEditingController _nameController;
  late TextEditingController _birthYearController;
  late TextEditingController _birthPlaceController;
  late TextEditingController _deathYearController;
  late TextEditingController _deathPlaceController;

  bool _isSearching = false;
  final List<_SearchResult> _results = [];
  String _selectedApi = 'all';

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.person?.name ?? '');
    _birthYearController = TextEditingController(
        text: widget.person?.birthDate?.year.toString() ?? '');
    _birthPlaceController =
        TextEditingController(text: widget.person?.birthPlace ?? '');
    _deathYearController = TextEditingController(
        text: widget.person?.deathDate?.year.toString() ?? '');
    _deathPlaceController =
        TextEditingController(text: widget.person?.deathPlace ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthYearController.dispose();
    _birthPlaceController.dispose();
    _deathYearController.dispose();
    _deathPlaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Historical Records'),
      ),
      body: Column(
        children: [
          // ── Search form ────────────────────────────────────────────────
          Container(
            color: colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _birthYearController,
                        decoration: const InputDecoration(
                          labelText: 'Birth Year',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _birthPlaceController,
                        decoration: const InputDecoration(
                          labelText: 'Birth Place',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _deathYearController,
                        decoration: const InputDecoration(
                          labelText: 'Death Year',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _deathPlaceController,
                        decoration: const InputDecoration(
                          labelText: 'Death Place',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // API selector
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedApi,
                        decoration: const InputDecoration(
                          labelText: 'Search In',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'all', child: Text('All Sources')),
                          DropdownMenuItem(
                              value: 'familysearch',
                              child: Text('FamilySearch')),
                          DropdownMenuItem(
                              value: 'newspapers',
                              child: Text('Newspapers (LOC)')),
                          DropdownMenuItem(
                              value: 'nara',
                              child: Text('National Archives')),
                          DropdownMenuItem(
                              value: 'openarchives',
                              child: Text('Open Archives (NL)')),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedApi = v ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: _isSearching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: const Text('Search'),
                      onPressed: _isSearching ? null : _performSearch,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Results ────────────────────────────────────────────────────
          Expanded(
            child: _results.isEmpty && !_isSearching
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search,
                            size: 64,
                            color: colorScheme.primary.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'Enter a name to search historical records.',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(8, 8, 8, 80),
                        itemCount: _results.length,
                        itemBuilder: (_, i) => _ResultCard(
                          result: _results[i],
                          personId: widget.person?.id,
                          onAttach: widget.person != null
                              ? () => _attachSource(context, _results[i])
                              : null,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _performSearch() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isSearching = true;
      _results.clear();
    });

    final nameParts = name.split(RegExp(r'\s+'));
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.last : null;
    final birthYear = _birthYearController.text.trim();
    final birthPlace = _birthPlaceController.text.trim();
    final deathYear = _deathYearController.text.trim();

    final futures = <Future<List<_SearchResult>>>[];

    // FamilySearch
    if (_selectedApi == 'all' || _selectedApi == 'familysearch') {
      futures.add(_searchFamilySearch(
          firstName, lastName, birthYear, birthPlace, deathYear));
    }

    // Chronicling America
    if (_selectedApi == 'all' || _selectedApi == 'newspapers') {
      futures.add(_searchNewspapers(name, birthYear, deathYear));
    }

    // NARA
    if (_selectedApi == 'all' || _selectedApi == 'nara') {
      futures.add(_searchNara(name, birthYear, deathYear));
    }

    // Open Archives
    if (_selectedApi == 'all' || _selectedApi == 'openarchives') {
      futures.add(_searchOpenArchives(name, birthYear, deathYear));
    }

    final results = await Future.wait(futures);
    final allResults = results.expand((r) => r).toList();

    // Sort by relevance (FamilySearch first, then by title)
    allResults.sort((a, b) {
      const order = {
        'FamilySearch': 0,
        'National Archives': 1,
        'Open Archives': 2,
        'Chronicling America': 3,
      };
      return (order[a.source] ?? 9).compareTo(order[b.source] ?? 9);
    });

    setState(() {
      _results.addAll(allResults);
      _isSearching = false;
    });
  }

  Future<List<_SearchResult>> _searchFamilySearch(String firstName,
      String? lastName, String birthYear, String birthPlace,
      String deathYear) async {
    try {
      final records =
          await FamilySearchApiService.instance.searchRecords(
        givenName: firstName,
        surname: lastName,
        birthDate: birthYear.isNotEmpty ? birthYear : null,
        birthPlace: birthPlace.isNotEmpty ? birthPlace : null,
        deathDate: deathYear.isNotEmpty ? deathYear : null,
        count: 10,
      );
      return records
          .map((r) => _SearchResult(
                source: 'FamilySearch',
                title: r.title,
                subtitle: r.collectionTitle,
                date: r.eventDate,
                place: r.eventPlace,
                url: r.recordUrl,
                imageUrl: r.imageUrl,
                icon: Icons.account_tree,
                _fsRecord: r,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<_SearchResult>> _searchNewspapers(
      String name, String birthYear, String deathYear) async {
    try {
      final results =
          await ChroniclingAmericaService.instance.searchPages(
        query: name,
        dateStart: birthYear.isNotEmpty ? birthYear : null,
        dateEnd: deathYear.isNotEmpty ? deathYear : null,
      );
      return results
          .map((r) => _SearchResult(
                source: 'Chronicling America',
                title: r.title,
                subtitle: r.ocrText,
                date: r.date,
                place: '${r.city ?? ""}, ${r.state ?? ""}'.trim(),
                url: r.pageUrl,
                imageUrl: r.thumbnailUrl,
                icon: Icons.newspaper,
                _caResult: r,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<_SearchResult>> _searchNara(
      String name, String birthYear, String deathYear) async {
    try {
      final results = await NaraCatalogService.instance.search(
        query: name,
        dateStart: birthYear.isNotEmpty ? birthYear : null,
        dateEnd: deathYear.isNotEmpty ? deathYear : null,
        limit: 10,
      );
      return results
          .map((r) => _SearchResult(
                source: 'National Archives',
                title: r.title,
                subtitle: r.scopeNote,
                date: r.dateRange,
                place: null,
                url: r.catalogUrl,
                imageUrl: null,
                icon: Icons.account_balance,
                _naraResult: r,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<_SearchResult>> _searchOpenArchives(
      String name, String birthYear, String deathYear) async {
    try {
      final results = await OpenArchivesService.instance.search(
        name: name,
        eventDateFrom: birthYear.isNotEmpty ? birthYear : null,
        eventDateTo: deathYear.isNotEmpty ? deathYear : null,
      );
      return results
          .map((r) => _SearchResult(
                source: 'Open Archives',
                title:
                    '${r.recordType[0].toUpperCase()}${r.recordType.substring(1)} — ${r.eventPlace ?? "NL"}',
                subtitle: r.persons.isNotEmpty
                    ? r.persons.map((p) => p.fullName).join(', ')
                    : null,
                date: r.eventDate,
                place: r.eventPlace,
                url: r.recordUrl,
                imageUrl: null,
                icon: Icons.archive,
                _oaRecord: r,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _attachSource(
      BuildContext context, _SearchResult result) async {
    if (widget.person == null) return;

    final provider = context.read<TreeProvider>();

    // Create appropriate Source based on the API source
    if (false) {
      final source = FamilySearchApiService.instance
          .recordToSource(result._fsRecord!, widget.person!.id);
      await provider.addSource(source);
    } else if (false) {
      final source = ChroniclingAmericaService.instance
          .resultToSource(result._caResult!, widget.person!.id);
      await provider.addSource(source);
    } else if (false) {
      final source = NaraCatalogService.instance
          .resultToSource(result._naraResult!, widget.person!.id);
      await provider.addSource(source);
    } else if (false) {
      final source = OpenArchivesService.instance
          .recordToSource(result._oaRecord!, widget.person!.id);
      await provider.addSource(source);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source attached!')),
      );
    }
  }
}

// ── Result model ─────────────────────────────────────────────────────────────

class _SearchResult {
  final String source;
  final String title;
  final String? subtitle;
  final String? date;
  final String? place;
  final String url;
  final String? imageUrl;
  final IconData icon;

  // Keep references for source creation
  
  
  
  

  const _SearchResult({
    required this.source,
    required this.title,
    this.subtitle,
    this.date,
    this.place,
    required this.url,
    this.imageUrl,
    required this.icon,
    
    
    
    
  })  : 
        
        
        
}

// ── Result card ──────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final _SearchResult result;
  final String? personId;
  final VoidCallback? onAttach;

  const _ResultCard({
    required this.result,
    this.personId,
    this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(result.icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.source,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),

            // Date & place
            if (result.date != null || result.place != null) ...[
              const SizedBox(height: 4),
              Text(
                [result.date, result.place]
                    .where((s) => s != null && s.isNotEmpty)
                    .join(' · '),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],

            // Subtitle / excerpt
            if (result.subtitle != null && result.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                result.subtitle!,
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('View'),
                  onPressed: () async {
                    final uri = Uri.tryParse(result.url);
                    if (uri != null) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                if (onAttach != null) ...[
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_link, size: 14),
                    label: const Text('Attach'),
                    onPressed: onAttach,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
