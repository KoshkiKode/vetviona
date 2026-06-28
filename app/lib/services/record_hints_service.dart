import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/person.dart';
import '../models/record_hint.dart';
import 'chronicling_america_service.dart';
import 'familysearch_api_service.dart';
import 'nara_catalog_service.dart';
import 'open_archives_service.dart';
import 'wikitree_service.dart';

/// Background service that searches external APIs for historical records
/// matching persons in the tree, and stores them as [RecordHint]s.
///
/// This is the equivalent of Ancestry's "shaky leaf" hints or FamilySearch's
/// record hints.  It runs on-demand (when the user taps "Find Hints") or
/// can be called for a single person.
class RecordHintsService {
  RecordHintsService._();
  static final RecordHintsService instance = RecordHintsService._();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// The callback to persist hints — set by the TreeProvider during init.
  Future<void> Function(RecordHint hint)? onHintDiscovered;

  /// The callback to check if a hint already exists (to avoid duplicates).
  bool Function(String personId, String apiSource, String externalRecordId)?
      hintExists;

  /// Searches all available APIs for hints for a single [person].
  ///
  /// Returns newly discovered hints (already persisted via [onHintDiscovered]).
  Future<List<RecordHint>> findHintsForPerson(Person person) async {
    final hints = <RecordHint>[];

    // Skip persons with minimal data
    final nameParts = person.name.trim().split(RegExp(r'\s+'));
    if (nameParts.isEmpty || person.name.trim().isEmpty) return hints;

    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.last : null;
    final birthYear = person.birthDate?.year.toString();
    final deathYear = person.deathDate?.year.toString();

    // ── FamilySearch Records ──────────────────────────────────────────────
    try {
      final fsResults = await FamilySearchApiService.instance.searchRecords(
        givenName: firstName,
        surname: lastName,
        birthDate: birthYear,
        birthPlace: person.birthPlace,
        deathDate: deathYear,
        count: 5,
      );

      for (final record in fsResults) {
        final confidence = _computeConfidence(person, record.personName,
            record.eventDate, record.eventPlace);
        if (confidence < 0.3) continue;

        final hint = RecordHint(
          id: const Uuid().v4(),
          personId: person.id,
          apiSource: 'familysearch',
          externalRecordId: record.recordId,
          title: record.title,
          summary: record.collectionTitle,
          recordUrl: record.recordUrl,
          imageUrl: record.imageUrl,
          confidence: confidence,
          treeId: person.treeId,
          discoveredAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        if (_shouldAdd(hint)) {
          hints.add(hint);
          await onHintDiscovered?.call(hint);
        }
      }
    } catch (e) {
      debugPrint('RecordHintsService: FamilySearch error: $e');
    }

    // ── WikiTree ──────────────────────────────────────────────────────────
    try {
      if (WikiTreeService.instance.isLoggedIn) {
        final wtResults = await WikiTreeService.instance.searchPerson(
          '${firstName ?? ''} ${lastName ?? ''}'.trim(),
          birthYear: birthYear != null ? int.tryParse(birthYear) : null,
        );

        for (final profile in wtResults.take(5)) {
          final confidence = _computeConfidence(
            person,
            '${profile.firstName ?? ''} ${profile.lastName ?? ''}'.trim(),
            profile.birthDate?.year.toString(),
            profile.birthPlace,
          );
          if (confidence < 0.3) continue;

          final hint = RecordHint(
            id: const Uuid().v4(),
            personId: person.id,
            apiSource: 'wikitree',
            externalRecordId: profile.wikiTreeId,
            title: '${profile.firstName ?? ''} ${profile.lastName ?? ''}'.trim(),
            summary:
                'WikiTree profile ${profile.wikiTreeId}',
            recordUrl:
                'https://www.wikitree.com/wiki/${profile.wikiTreeId}',
            confidence: confidence,
            treeId: person.treeId,
            discoveredAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );

          if (_shouldAdd(hint)) {
            hints.add(hint);
            await onHintDiscovered?.call(hint);
          }
        }
      }
    } catch (e) {
      debugPrint('RecordHintsService: WikiTree error: $e');
    }

    // ── Chronicling America (US newspapers) ───────────────────────────────
    try {
      final query = '${person.name}'
          '${birthYear != null ? ' $birthYear' : ''}'
          '${deathYear != null ? ' $deathYear' : ''}';

      final caResults = await ChroniclingAmericaService.instance.searchPages(
        query: query,
        dateStart: birthYear,
        dateEnd: deathYear,
      );

      for (final result in caResults.take(3)) {
        final hint = RecordHint(
          id: const Uuid().v4(),
          personId: person.id,
          apiSource: 'chronicling_america',
          externalRecordId: result.pageUrl,
          title: result.title,
          summary: result.ocrText,
          recordUrl: result.pageUrl,
          imageUrl: result.thumbnailUrl,
          confidence: 0.3, // newspaper matches are inherently lower confidence
          treeId: person.treeId,
          discoveredAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        if (_shouldAdd(hint)) {
          hints.add(hint);
          await onHintDiscovered?.call(hint);
        }
      }
    } catch (e) {
      debugPrint('RecordHintsService: Chronicling America error: $e');
    }

    // ── NARA (US National Archives) ───────────────────────────────────────
    try {
      final naraResults = await NaraCatalogService.instance.search(
        query: person.name,
        dateStart: birthYear,
        dateEnd: deathYear,
        limit: 3,
      );

      for (final result in naraResults) {
        final hint = RecordHint(
          id: const Uuid().v4(),
          personId: person.id,
          apiSource: 'nara',
          externalRecordId: result.naId,
          title: result.title,
          summary: result.scopeNote,
          recordUrl: result.catalogUrl,
          imageUrl: result.digitalObjectUrl,
          confidence: 0.35,
          treeId: person.treeId,
          discoveredAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        if (_shouldAdd(hint)) {
          hints.add(hint);
          await onHintDiscovered?.call(hint);
        }
      }
    } catch (e) {
      debugPrint('RecordHintsService: NARA error: $e');
    }

    // ── Open Archives (Dutch records) ─────────────────────────────────────
    try {
      final oaResults = await OpenArchivesService.instance.search(
        name: person.name,
        eventDateFrom: birthYear,
        eventDateTo: deathYear,
        perPage: 3,
      );

      for (final record in oaResults) {
        final confidence = _computeConfidence(
          person,
          record.persons.isNotEmpty ? record.persons.first.fullName : null,
          record.eventDate,
          record.eventPlace,
        );
        if (confidence < 0.3) continue;

        final hint = RecordHint(
          id: const Uuid().v4(),
          personId: person.id,
          apiSource: 'open_archives',
          externalRecordId: record.recordId,
          title:
              '${_capitalize(record.recordType)} — ${record.eventPlace ?? "Netherlands"}',
          summary:
              '${record.eventDate ?? ""} ${record.eventPlace ?? ""}'.trim(),
          recordUrl: record.recordUrl,
          confidence: confidence,
          treeId: person.treeId,
          discoveredAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        if (_shouldAdd(hint)) {
          hints.add(hint);
          await onHintDiscovered?.call(hint);
        }
      }
    } catch (e) {
      debugPrint('RecordHintsService: Open Archives error: $e');
    }

    return hints;
  }

  /// Runs hint discovery for multiple persons (e.g. all persons missing
  /// sources).  Call [onProgress] to report incremental progress.
  Future<List<RecordHint>> findHintsForPersons(
    List<Person> persons, {
    void Function(int completed, int total)? onProgress,
  }) async {
    _isRunning = true;
    final allHints = <RecordHint>[];

    for (int i = 0; i < persons.length; i++) {
      if (!_isRunning) break; // allow cancellation

      final hints = await findHintsForPerson(persons[i]);
      allHints.addAll(hints);
      onProgress?.call(i + 1, persons.length);

      // Rate-limit: small delay between persons to be a good API citizen
      if (i < persons.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    _isRunning = false;
    return allHints;
  }

  /// Cancels an in-progress hint discovery run.
  void cancel() {
    _isRunning = false;
  }

  // ── Confidence scoring ────────────────────────────────────────────────────

  /// Computes a match confidence between a local person and a record result.
  double _computeConfidence(
    Person person,
    String? recordName,
    String? recordDate,
    String? recordPlace,
  ) {
    double score = 0.0;
    int factors = 0;

    // Name match
    if (recordName != null && recordName.isNotEmpty) {
      factors++;
      final localName = person.name.toLowerCase().trim();
      final remoteName = recordName.toLowerCase().trim();
      if (localName == remoteName) {
        score += 1.0;
      } else {
        // Partial match — check surname
        final localParts = localName.split(RegExp(r'\s+'));
        final remoteParts = remoteName.split(RegExp(r'\s+'));
        final localSurname = localParts.last;
        final remoteSurname = remoteParts.last;
        if (localSurname == remoteSurname) {
          score += 0.7;
          // First name match too?
          if (localParts.first == remoteParts.first) {
            score += 0.2;
          }
        } else {
          score += 0.2; // some name similarity
        }
      }
    }

    // Date match (year)
    if (recordDate != null && recordDate.isNotEmpty) {
      factors++;
      final recordYear = _extractYear(recordDate);
      final birthYear = person.birthDate?.year;
      final deathYear = person.deathDate?.year;

      if (recordYear != null) {
        if (birthYear != null && (recordYear - birthYear).abs() <= 1) {
          score += 1.0;
        } else if (deathYear != null && (recordYear - deathYear).abs() <= 1) {
          score += 1.0;
        } else if (birthYear != null && (recordYear - birthYear).abs() <= 5) {
          score += 0.5;
        } else if (deathYear != null && (recordYear - deathYear).abs() <= 5) {
          score += 0.5;
        } else {
          score += 0.1;
        }
      }
    }

    // Place match
    if (recordPlace != null &&
        recordPlace.isNotEmpty &&
        (person.birthPlace != null || person.deathPlace != null)) {
      factors++;
      final rPlace = recordPlace.toLowerCase();
      final bPlace = person.birthPlace?.toLowerCase() ?? '';
      final dPlace = person.deathPlace?.toLowerCase() ?? '';

      if (rPlace == bPlace || rPlace == dPlace) {
        score += 1.0;
      } else if (bPlace.contains(rPlace) ||
          rPlace.contains(bPlace) ||
          dPlace.contains(rPlace) ||
          rPlace.contains(dPlace)) {
        score += 0.6;
      } else {
        score += 0.1;
      }
    }

    if (factors == 0) return 0.3; // no data to compare
    return (score / factors).clamp(0.0, 1.0);
  }

  int? _extractYear(String dateStr) {
    final match = RegExp(r'(\d{4})').firstMatch(dateStr);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  bool _shouldAdd(RecordHint hint) {
    if (hintExists != null) {
      return !hintExists!(hint.personId, hint.apiSource, hint.externalRecordId);
    }
    return true;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// Extension on RecordHint for the digitalObjectUrl field used by NARA hints.
extension RecordHintNara on RecordHint {
  // This is stored in the imageUrl field for NARA results.
  String? get digitalObjectUrl => imageUrl;
}
