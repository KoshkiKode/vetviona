import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/life_event.dart';
import '../models/partnership.dart';
import '../models/person.dart';
import '../models/source.dart';
import '../providers/tree_provider.dart';
import '../services/gedcom_parser.dart';

/// Resumable, pauseable GEDCOM importer.
///
/// Use [mergeMode] = true ("Combine GEDCOM") to deduplicate incoming people
/// against the currently loaded tree, skipping anyone whose name and birth
/// year already exist and remapping relationship IDs accordingly.
class GedcomImportScreen extends StatefulWidget {
  final String filePath;
  final bool mergeMode;

  const GedcomImportScreen({
    super.key,
    required this.filePath,
    this.mergeMode = false,
  });

  @override
  State<GedcomImportScreen> createState() => _GedcomImportScreenState();
}

class _GedcomImportScreenState extends State<GedcomImportScreen> {
  // ── SharedPreferences keys ─────────────────────────────────────────────────
  static const _kPath = 'gedcom_import_path';
  static const _kTreeId = 'gedcom_import_tree_id';
  static const _kPersonIdx = 'gedcom_import_person_idx';
  static const _kPartnerIdx = 'gedcom_import_partner_idx';
  static const _kEventIdx = 'gedcom_import_event_idx';
  static const _kSourceIdx = 'gedcom_import_source_idx';

  // ── State ──────────────────────────────────────────────────────────────────
  GedcomResult? _parsed;
  // idMap: GEDCOM person ID → resolved DB ID.
  // For duplicates (merge mode): gedcomId → existingDbId.
  // For new people: gedcomId → gedcomId.
  Map<String, String> _idMap = {};

  bool _isParsing = true;
  bool _isImporting = false;
  bool _isPaused = false;
  bool _isDone = false;
  bool _isCancelled = false;

  int _personIdx = 0;
  int _partnerIdx = 0;
  int _eventIdx = 0;
  int _sourceIdx = 0;

  int _addedPersons = 0;
  int _skippedPersons = 0;
  int _addedPartnerships = 0;
  int _addedEvents = 0;
  int _addedSources = 0;

  String _statusMessage = 'Parsing GEDCOM file…';
  String _errorMessage = '';

  Completer<void>? _resumeCompleter;

  @override
  void initState() {
    super.initState();
    _start();
  }

  // ── Entry point ─────────────────────────────────────────────────────────────
  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = context.read<TreeProvider>();

    // Check for a previous interrupted import of the same file + tree.
    final savedPath = prefs.getString(_kPath);
    final savedTreeId = prefs.getString(_kTreeId);
    bool resuming = false;
    if (savedPath == widget.filePath && savedTreeId == provider.currentTreeId) {
      final confirmed = await _askResume();
      if (confirmed == true) {
        resuming = true;
        _personIdx = prefs.getInt(_kPersonIdx) ?? 0;
        _partnerIdx = prefs.getInt(_kPartnerIdx) ?? 0;
        _eventIdx = prefs.getInt(_kEventIdx) ?? 0;
        _sourceIdx = prefs.getInt(_kSourceIdx) ?? 0;
      }
    }

    if (!resuming) {
      await _clearSavedState(prefs);
    }

    // Parse the GEDCOM.
    try {
      if (mounted) setState(() => _statusMessage = 'Parsing GEDCOM file…');
      final result = await GEDCOMParser().parse(widget.filePath);
      if (!mounted) return;
      setState(() {
        _parsed = result;
        _isParsing = false;
        _isImporting = true;
      });

      // Save the import checkpoint.
      await prefs.setString(_kPath, widget.filePath);
      await prefs.setString(_kTreeId, provider.currentTreeId);

      // Build the ID mapping (only needed when mergeMode is active).
      _idMap = _buildIdMap(result, provider);

      await _runImport(provider, prefs);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isParsing = false;
          _isImporting = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  // ── Build duplicate-ID map ──────────────────────────────────────────────────
  /// Returns a mapping from every GEDCOM person ID to the DB ID that should
  /// be used when writing that person's relationships.
  ///
  /// In merge mode, people whose name + birth-year already exist in the DB
  /// are mapped to the existing record's ID so relationships link correctly.
  Map<String, String> _buildIdMap(
      GedcomResult result, TreeProvider provider) {
    final map = <String, String>{};
    for (final gp in result.persons) {
      if (widget.mergeMode) {
        final existingId = _findDuplicateId(gp, provider);
        map[gp.id] = existingId ?? gp.id;
      } else {
        map[gp.id] = gp.id;
      }
    }
    return map;
  }

  /// Returns the DB id of an existing person matching [gp] by name + birth-year,
  /// or null if no match.
  String? _findDuplicateId(
      dynamic gp, TreeProvider provider) {
    final nameLower = (gp.name as String).toLowerCase().trim();
    if (nameLower.isEmpty) return null;
    for (final ep in provider.persons) {
      if (ep.name.toLowerCase().trim() != nameLower) continue;
      if (gp.birthDate != null && ep.birthDate != null) {
        if ((gp.birthDate as DateTime).year != ep.birthDate!.year) continue;
      }
      return ep.id;
    }
    return null;
  }

  // ── Import loop ─────────────────────────────────────────────────────────────
  //
  // Each phase now uses a single SQLite batch transaction instead of individual
  // per-row inserts.  This drops the time for a 2,500-person import from
  // ~20 minutes (2,500 DB round-trips + 2,500 notifyListeners rebuilds) to a
  // few seconds (4 batch commits + 4 notifyListeners calls total).
  //
  // Phase checkpointing (for the resume-on-crash feature) is done once per
  // phase rather than once per row.  The trade-off is acceptable: a crash
  // mid-phase restarts only that phase, not the whole import.
  Future<void> _runImport(
      TreeProvider provider, SharedPreferences prefs) async {
    final parsed = _parsed!;

    // ── Phase 1: Persons ────────────────────────────────────────────────────
    if (_personIdx == 0) {
      if (_isCancelled) return _cancelImport(prefs);
      if (_isPaused) await _waitForResume();
      if (_isCancelled) return _cancelImport(prefs);

      _setStatus('Preparing ${parsed.persons.length} people…');
      await Future.delayed(Duration.zero); // let the UI update

      // Build the list of persons to actually insert (skip duplicates).
      final toAdd = <Person>[];
      final existingIds = {for (final p in provider.persons) p.id};
      for (final person in parsed.persons) {
        final resolvedId = _idMap[person.id] ?? person.id;
        final isDuplicate = widget.mergeMode && resolvedId != person.id;
        if (isDuplicate || existingIds.contains(person.id)) {
          _skippedPersons++;
          continue;
        }
        // Remap parentIds and childIds using the ID map.
        person.parentIds =
            person.parentIds.map((id) => _idMap[id] ?? id).toList();
        person.childIds =
            person.childIds.map((id) => _idMap[id] ?? id).toList();
        toAdd.add(person);
      }

      // Free-tier limit check.
      if (provider.personLimit != null) {
        final available = provider.personLimit! - provider.persons.length;
        if (available <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Free-tier person limit reached. Upgrade to add more.')));
          }
          return _cancelImport(prefs);
        }
        if (toAdd.length > available) toAdd.length = available;
      }

      _setStatus('Importing ${toAdd.length} people…');
      await Future.delayed(Duration.zero);

      await provider.importPersonsBatch(toAdd);
      _addedPersons = toAdd.length;

      _personIdx = parsed.persons.length; // mark phase complete
      await prefs.setInt(_kPersonIdx, _personIdx);
    }

    // In merge mode, update existing parents so they list the new children.
    if (widget.mergeMode) {
      _setStatus('Linking family relationships…');
      await Future.delayed(Duration.zero);
      await _linkOrphanedChildren(provider);
    }

    // ── Phase 2: Partnerships ───────────────────────────────────────────────
    if (_partnerIdx == 0) {
      if (_isCancelled) return _cancelImport(prefs);
      if (_isPaused) await _waitForResume();
      if (_isCancelled) return _cancelImport(prefs);

      _setStatus('Preparing ${parsed.partnerships.length} families…');
      await Future.delayed(Duration.zero);

      final existingPairs = <String>{};
      for (final pt in provider.partnerships) {
        existingPairs.add('${pt.person1Id}|${pt.person2Id}');
        existingPairs.add('${pt.person2Id}|${pt.person1Id}');
      }

      final toAdd = <Partnership>[];
      for (final partnership in parsed.partnerships) {
        partnership.person1Id =
            _idMap[partnership.person1Id] ?? partnership.person1Id;
        partnership.person2Id =
            _idMap[partnership.person2Id] ?? partnership.person2Id;
        final key = '${partnership.person1Id}|${partnership.person2Id}';
        if (!existingPairs.contains(key)) {
          toAdd.add(partnership);
          existingPairs.add(key);
          existingPairs
              .add('${partnership.person2Id}|${partnership.person1Id}');
        }
      }

      _setStatus('Importing ${toAdd.length} families…');
      await Future.delayed(Duration.zero);

      await provider.importPartnershipsBatch(toAdd);
      _addedPartnerships = toAdd.length;

      _partnerIdx = parsed.partnerships.length;
      await prefs.setInt(_kPartnerIdx, _partnerIdx);
    }

    // ── Phase 3: Life Events ────────────────────────────────────────────────
    if (_eventIdx == 0) {
      if (_isCancelled) return _cancelImport(prefs);
      if (_isPaused) await _waitForResume();
      if (_isCancelled) return _cancelImport(prefs);

      _setStatus('Preparing ${parsed.lifeEvents.length} life events…');
      await Future.delayed(Duration.zero);

      final knownPersonIds = {for (final p in provider.persons) p.id};
      final toAdd = <LifeEvent>[];
      for (final event in parsed.lifeEvents) {
        final resolvedPersonId = _idMap[event.personId] ?? event.personId;
        if (!knownPersonIds.contains(resolvedPersonId)) continue;
        toAdd.add(LifeEvent(
          id: event.id,
          personId: resolvedPersonId,
          title: event.title,
          date: event.date,
          place: event.place,
          notes: event.notes,
          treeId: provider.currentTreeId,
        ));
      }

      _setStatus('Importing ${toAdd.length} life events…');
      await Future.delayed(Duration.zero);

      await provider.importLifeEventsBatch(toAdd);
      _addedEvents = toAdd.length;

      _eventIdx = parsed.lifeEvents.length;
      await prefs.setInt(_kEventIdx, _eventIdx);
    }

    // ── Phase 4: Sources ────────────────────────────────────────────────────
    if (_sourceIdx == 0) {
      if (_isCancelled) return _cancelImport(prefs);
      if (_isPaused) await _waitForResume();
      if (_isCancelled) return _cancelImport(prefs);

      _setStatus('Preparing ${parsed.sources.length} sources…');
      await Future.delayed(Duration.zero);

      final knownPersonIds = {for (final p in provider.persons) p.id};
      final toAdd = <Source>[];
      for (final src in parsed.sources) {
        final resolvedPersonId = _idMap[src.personId] ?? src.personId;
        if (!knownPersonIds.contains(resolvedPersonId)) continue;
        toAdd.add(Source(
          id: src.id,
          personId: resolvedPersonId,
          title: src.title,
          type: src.type,
          url: src.url,
          author: src.author,
          publisher: src.publisher,
          volumePage: src.volumePage,
          treeId: provider.currentTreeId,
        ));
      }

      _setStatus('Linking ${toAdd.length} sources…');
      await Future.delayed(Duration.zero);

      await provider.importSourcesBatch(toAdd);
      _addedSources = toAdd.length;

      _sourceIdx = parsed.sources.length;
      await prefs.setInt(_kSourceIdx, _sourceIdx);
    }

    // ── Done ────────────────────────────────────────────────────────────────
    await _clearSavedState(prefs);
    if (mounted) {
      setState(() {
        _isImporting = false;
        _isDone = true;
        _statusMessage = 'Import complete!';
      });
    }
  }

  // ── Orphaned-child linker ────────────────────────────────────────────────────

  /// After adding new persons (which have remapped parentIds), update any
  /// existing parent person in the DB whose childIds do not yet include the
  /// new child.
  Future<void> _linkOrphanedChildren(TreeProvider provider) async {
    for (final person in _parsed!.persons) {
      final resolvedId = _idMap[person.id] ?? person.id;
      if (resolvedId == person.id) {
        // This is a newly imported person — ensure existing parents list it.
        for (final parentId in person.parentIds) {
          final parentIdx =
              provider.persons.indexWhere((p) => p.id == parentId);
          if (parentIdx == -1) continue;
          if (!provider.persons[parentIdx].childIds.contains(resolvedId)) {
            provider.persons[parentIdx].childIds.add(resolvedId);
            await provider.updatePerson(provider.persons[parentIdx]);
          }
        }
      }
    }
  }

  // ── Pause / Resume / Cancel ─────────────────────────────────────────────────
  Future<void> _waitForResume() async {
    _resumeCompleter = Completer<void>();
    await _resumeCompleter!.future;
    _resumeCompleter = null;
  }

  void _togglePause() {
    if (!_isImporting) return;
    setState(() => _isPaused = !_isPaused);
    if (!_isPaused) {
      _resumeCompleter?.complete();
    }
  }

  Future<void> _cancelImport(SharedPreferences prefs) async {
    await _clearSavedState(prefs);
    if (mounted) Navigator.pop(context);
  }

  void _requestCancel() {
    _isCancelled = true;
    _resumeCompleter?.complete(); // unblock if paused
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Future<bool?> _askResume() => showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Resume Import?'),
          content: const Text(
              'A previous import of this file was interrupted. Resume where it left off?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Start Over')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Resume')),
          ],
        ),
      );

  Future<void> _clearSavedState(SharedPreferences prefs) async {
    await prefs.remove(_kPath);
    await prefs.remove(_kTreeId);
    await prefs.remove(_kPersonIdx);
    await prefs.remove(_kPartnerIdx);
    await prefs.remove(_kEventIdx);
    await prefs.remove(_kSourceIdx);
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final parsed = _parsed;
    final totalPersons = parsed?.persons.length ?? 0;
    final totalPartnerships = parsed?.partnerships.length ?? 0;
    final totalEvents = parsed?.lifeEvents.length ?? 0;
    final totalSources = parsed?.sources.length ?? 0;
    final total =
        totalPersons + totalPartnerships + totalEvents + totalSources;
    final current =
        _personIdx + _partnerIdx + _eventIdx + _sourceIdx;
    final progress = total > 0 ? current / total : 0.0;

    return PopScope(
      canPop: !_isImporting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isImporting) {
          _showCancelConfirmation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.mergeMode ? 'Combine GEDCOM' : 'Import GEDCOM'),
          automaticallyImplyLeading: !_isImporting,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: _errorMessage.isNotEmpty
              ? _buildError()
              : _isParsing
                  ? _buildParsing()
                  : _isDone
                      ? _buildDone(colorScheme, totalSources)
                      : _buildProgress(colorScheme, progress),
        ),
      ),
    );
  }

  Widget _buildParsing() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Parsing GEDCOM file…'),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        ),
      );

  Widget _buildDone(ColorScheme cs, int totalSources) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: cs.primary),
            const SizedBox(height: 16),
            Text('Import Complete!',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            _SummaryRow(label: 'People added', value: _addedPersons),
            if (widget.mergeMode)
              _SummaryRow(
                  label: 'People skipped (duplicates)',
                  value: _skippedPersons),
            _SummaryRow(
                label: 'Families added', value: _addedPartnerships),
            _SummaryRow(label: 'Events added', value: _addedEvents),
            if (totalSources > 0)
              _SummaryRow(
                  label: 'Sources linked', value: _addedSources),
            const SizedBox(height: 28),
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done')),
          ],
        ),
      );

  Widget _buildProgress(ColorScheme cs, double progress) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_statusMessage,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          LinearProgressIndicator(
              value: progress.isNaN || progress.isInfinite ? null : progress),
          const SizedBox(height: 8),
          Text('${(progress.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall),
          if (_isPaused) ...[
            const SizedBox(height: 8),
            Text('Paused — tap Resume to continue',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.secondary)),
          ],
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _showCancelConfirmation,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _togglePause,
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                label: Text(_isPaused ? 'Resume' : 'Pause'),
              ),
            ],
          ),
        ],
      );

  void _showCancelConfirmation() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Import?'),
        content: const Text(
            'Cancelling will discard all progress. You will need to start the import again from the beginning.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Going')),
          FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _requestCancel();
              },
              child: const Text('Cancel Import')),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$value',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
