import 'dart:io';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/life_event.dart';
import '../models/partnership.dart';
import '../models/person.dart';
import '../models/source.dart';
import '../utils/input_sanitizer.dart';

/// Return value from [GEDCOMParser.parse].
class GedcomResult {
  final List<Person> persons;
  final List<Partnership> partnerships;
  final List<LifeEvent> lifeEvents;
  final List<Source> sources;
  const GedcomResult({
    required this.persons,
    required this.partnerships,
    this.lifeEvents = const [],
    this.sources = const [],
  });
}

/// GEDCOM tag → LifeEvent title mapping.
const _gedcomEventTags = {
  'BAPM': 'Baptism',
  'CHR': 'Christening',
  'CONF': 'Confirmation',
  'GRAD': 'Graduation',
  'IMMI': 'Immigration',
  'EMIG': 'Emigration',
  'NATU': 'Naturalization',
  'RESI': 'Residence',
  'CENS': 'Census',
  'MILI': 'Military Service',
  'EVEN': 'Event',
};

/// LifeEvent title → GEDCOM tag mapping (for export).
const _titleToGedcomTag = {
  'Baptism': 'BAPM',
  'Christening': 'CHR',
  'Confirmation': 'CONF',
  'Graduation': 'GRAD',
  'Immigration': 'IMMI',
  'Emigration': 'EMIG',
  'Naturalization': 'NATU',
  'Residence': 'RESI',
  'Census': 'CENS',
  'Military Service': 'MILI',
};

class GEDCOMParser {
  static final _uuid = Uuid();

  Future<GedcomResult> parse(String filePath) async {
    final file = File(filePath);
    final lines = await file.readAsLines();
    final persons = <String, Person>{};
    final families = <String, Map<String, dynamic>>{};
    final builtLifeEvents = <LifeEvent>[];

    // SOUR record definitions: gedcom source id → {title, auth, publ}
    final sourceDefs = <String, Map<String, String>>{};
    // Person→Source references: {personId, sourceId, page?}
    final sourRefs = <Map<String, String?>>[];

    String? currentId;
    String? currentTag;
    Person? currentPerson;
    Map<String, dynamic>? currentFamily;
    Map<String, String>? currentSourceDef;

    // Pending life event being built while scanning level-2 sub-tags.
    Map<String, dynamic>? pendingEvent;
    // Pending SOUR reference from a 1 SOUR @Sx@ in an INDI record.
    Map<String, String?>? pendingSourRef;

    void flushPendingEvent(String personId) {
      if (pendingEvent == null) return;
      final tag = pendingEvent!['tag'] as String? ?? '';
      final title = tag == 'EVEN'
          ? (pendingEvent!['type'] as String? ?? 'Event')
          : (_gedcomEventTags[tag] ?? tag);
      builtLifeEvents.add(
        LifeEvent(
          id: _uuid.v4(),
          personId: personId,
          title: title,
          date: pendingEvent!['date'] as DateTime?,
          place: pendingEvent!['place'] as String?,
          notes: pendingEvent!['notes'] as String?,
        ),
      );
      pendingEvent = null;
    }

    for (final line in lines) {
      final parts = line.trim().split(' ');
      if (parts.isEmpty) continue;
      final level = int.tryParse(parts[0]) ?? -1;
      if (level < 0) continue;
      final tag = parts.length > 1 ? parts[1] : '';
      final value = parts.length > 2 ? parts.sublist(2).join(' ') : '';

      if (level == 0) {
        if (currentPerson != null && currentId != null) {
          final id = currentId;
          if (pendingEvent != null) flushPendingEvent(id);
          persons[id] = currentPerson;
        }
        currentPerson = null;
        currentFamily = null;
        currentTag = null;
        currentId = null;
        pendingEvent = null;
        pendingSourRef = null;
        currentSourceDef = null;

        if (value == 'INDI') {
          currentId = tag.replaceAll('@', '');
          currentPerson = Person(id: currentId, name: '');
        } else if (value == 'FAM') {
          final famId = tag.replaceAll('@', '');
          families[famId] = {'children': <String>[]};
          currentFamily = families[famId];
          currentId = famId;
        } else if (value == 'SOUR') {
          final srcId = tag.replaceAll('@', '');
          sourceDefs[srcId] = {};
          currentSourceDef = sourceDefs[srcId];
          currentId = srcId;
        }
      } else if (level == 1 && currentPerson != null) {
        // Flush any pending event when we start a new level-1 tag.
        if (pendingEvent != null) flushPendingEvent(currentId!);
        pendingEvent = null;
        pendingSourRef = null;
        currentTag = tag;

        if (tag == 'NAME') {
          currentPerson.name = value.replaceAll('/', '').trim();
        } else if (tag == 'SEX') {
          currentPerson.gender = value;
        } else if (tag == 'OCCU') {
          currentPerson.occupation = value;
        } else if (tag == 'RELI') {
          currentPerson.religion = value;
        } else if (tag == '_WIKITREEID' ||
            tag == '_WT_USER' ||
            tag == '_WIKITREE_ID') {
          // WikiTree-exported GEDCOMs include the profile page name here.
          // e.g.  1 _WIKITREEID Churchill-4
          final wtId = value.trim();
          if (wtId.isNotEmpty) currentPerson.wikitreeId = wtId;
        } else if (tag == '_FINDAGRAVEID' || tag == '_FINDAGRAVE') {
          final fagId = value.trim();
          if (fagId.isNotEmpty) currentPerson.findAGraveId = fagId;
        } else if (tag == '_FAMILYSEARCHID' ||
            tag == '_FAMILYSEARCH' ||
            tag == '_FSID') {
          final fsId = value.trim();
          if (fsId.isNotEmpty) currentPerson.familySearchId = fsId;
        } else if (_gedcomEventTags.containsKey(tag) ||
            tag == 'BURI' ||
            tag == 'DEAT' ||
            tag == 'BIRT') {
          // We handle BIRT/DEAT/BURI at level 2; for event tags start tracking.
          if (_gedcomEventTags.containsKey(tag)) {
            pendingEvent = {'tag': tag};
          }
        } else if (tag == 'SOUR') {
          // Reference to a source record: value is @S1@ or inline title.
          final refId = value.replaceAll('@', '').trim();
          if (refId.isNotEmpty) {
            pendingSourRef = {'personId': currentId, 'sourceId': refId};
            sourRefs.add(pendingSourRef);
          }
        } else if (tag == 'NATI') {
          if (value.isNotEmpty) currentPerson.nationality = value;
        } else if (tag == 'EDUC') {
          if (value.isNotEmpty) currentPerson.education = value;
        } else if (tag == '_MARN') {
          if (value.isNotEmpty) currentPerson.maidenName = value;
        } else if (tag == '_ALIAS') {
          final alias = value.trim();
          if (alias.isNotEmpty && !currentPerson.aliases.contains(alias)) {
            currentPerson.aliases.add(alias);
          }
        } else if (tag == 'NOTE') {
          // Individual-level note. Skip pointer form (@N1@); accept inline text.
          final isPointer = value.startsWith('@') && value.endsWith('@');
          if (!isPointer && value.isNotEmpty) currentPerson.notes = value;
        }
      } else if (level == 1 && currentSourceDef != null) {
        currentTag = tag;
        if (tag == 'TITL') {
          currentSourceDef['title'] = value;
        } else if (tag == 'AUTH') {
          currentSourceDef['auth'] = value;
        } else if (tag == 'PUBL') {
          currentSourceDef['publ'] = value;
        }
      } else if (level == 1 && currentFamily != null) {
        currentTag = tag;
        final id = value.replaceAll('@', '');
        if (tag == 'HUSB') {
          currentFamily['husb'] = id;
        } else if (tag == 'WIFE') {
          currentFamily['wife'] = id;
        } else if (tag == 'CHIL') {
          (currentFamily['children'] as List<String>).add(id);
        }
      } else if (level == 2 && currentPerson != null) {
        if (currentTag == 'BIRT' && tag == 'DATE') {
          currentPerson.birthDate = _parseDate(value);
        } else if (currentTag == 'BIRT' && tag == 'PLAC') {
          currentPerson.birthPlace = value;
        } else if (currentTag == 'DEAT' && tag == 'DATE') {
          currentPerson.deathDate = _parseDate(value);
        } else if (currentTag == 'DEAT' && tag == 'PLAC') {
          currentPerson.deathPlace = value;
        } else if (currentTag == 'DEAT' && tag == 'CAUS') {
          currentPerson.causeOfDeath = value;
        } else if (currentTag == 'BURI' && tag == 'DATE') {
          currentPerson.burialDate = _parseDate(value);
        } else if (currentTag == 'BURI' && tag == 'PLAC') {
          currentPerson.burialPlace = value;
        } else if (pendingEvent != null) {
          // Sub-tags for a life event.
          if (tag == 'DATE') {
            pendingEvent!['date'] = _parseDate(value);
          } else if (tag == 'PLAC') {
            pendingEvent!['place'] = value;
          } else if (tag == 'NOTE') {
            pendingEvent!['notes'] = value;
          } else if (tag == 'TYPE') {
            pendingEvent!['type'] = value;
          }
        } else if (currentTag == 'SOUR' &&
            pendingSourRef != null &&
            tag == 'PAGE') {
          // Page/citation reference for a source.
          pendingSourRef['page'] = value;
        }
      } else if (level == 2 && currentFamily != null) {
        if (currentTag == 'MARR' && tag == 'DATE') {
          currentFamily['startDate'] = value;
        } else if (currentTag == 'MARR' && tag == 'PLAC') {
          currentFamily['startPlace'] = value;
        } else if (currentTag == 'DIV' && tag == 'DATE') {
          currentFamily['endDate'] = value;
          currentFamily['status'] = 'divorced';
        } else if (currentTag == 'DIV' && tag == 'PLAC') {
          currentFamily['endPlace'] = value;
        }
      }
    }

    if (currentPerson != null && currentId != null) {
      final id = currentId;
      if (pendingEvent != null) flushPendingEvent(id);
      persons[id] = currentPerson;
    }

    // Build Partnership records and link parent–child data
    final builtPartnerships = <Partnership>[];
    int famCounter = 0;
    for (final entry in families.entries) {
      final fam = entry.value;
      final husbId = fam['husb'] as String?;
      final wifeId = fam['wife'] as String?;
      final children = fam['children'] as List<String>;

      if (husbId != null && wifeId != null) {
        final famId = 'gedcom_${entry.key}_$famCounter';
        famCounter++;
        final partnership = Partnership(
          id: famId,
          person1Id: husbId,
          person2Id: wifeId,
          status: fam['status'] as String? ?? 'married',
          startDate: fam['startDate'] != null
              ? _parseDate(fam['startDate'] as String)
              : null,
          startPlace: fam['startPlace'] as String?,
          endDate: fam['endDate'] != null
              ? _parseDate(fam['endDate'] as String)
              : null,
          endPlace: fam['endPlace'] as String?,
        );
        builtPartnerships.add(partnership);
      }

      for (final childId in children) {
        final child = persons[childId];
        if (child == null) continue;
        if (husbId != null && !child.parentIds.contains(husbId)) {
          child.parentIds.add(husbId);
        }
        if (wifeId != null && !child.parentIds.contains(wifeId)) {
          child.parentIds.add(wifeId);
        }
        if (husbId != null) {
          final husb = persons[husbId];
          if (husb != null && !husb.childIds.contains(childId)) {
            husb.childIds.add(childId);
          }
        }
        if (wifeId != null) {
          final wife = persons[wifeId];
          if (wife != null && !wife.childIds.contains(childId)) {
            wife.childIds.add(childId);
          }
        }
      }
    }

    // Build sources and detect FindAGrave memorial IDs embedded in them.
    final findAGraveIds = <String, String>{};
    final familySearchIds = <String, String>{};
    final builtSources = _buildSources(
      sourRefs,
      sourceDefs,
      findAGravePersonIds: findAGraveIds,
      familySearchPersonIds: familySearchIds,
    );

    // Apply any discovered FindAGrave IDs to the person records.
    for (final entry in findAGraveIds.entries) {
      final person = persons[entry.key];
      if (person != null) person.findAGraveId ??= entry.value;
    }
    for (final entry in familySearchIds.entries) {
      final person = persons[entry.key];
      if (person != null) person.familySearchId ??= entry.value;
    }

    return GedcomResult(
      persons: persons.values.map((p) {
        // Sanitise all text fields coming from the GEDCOM file so that a
        // crafted import cannot persist control characters or over-long values.
        p
          ..name = InputSanitizer.name(p.name)
          ..birthPlace = InputSanitizer.shortField(p.birthPlace)
          ..deathPlace = InputSanitizer.shortField(p.deathPlace)
          ..notes = InputSanitizer.mediumField(p.notes)
          ..occupation = InputSanitizer.shortField(p.occupation)
          ..nationality = InputSanitizer.shortField(p.nationality)
          ..maidenName = InputSanitizer.shortField(p.maidenName)
          ..burialPlace = InputSanitizer.shortField(p.burialPlace)
          ..religion = InputSanitizer.shortField(p.religion)
          ..education = InputSanitizer.shortField(p.education)
          ..aliases = p.aliases
              .map((a) => InputSanitizer.sanitizeRequired(a))
              .toList();
        return p;
      }).toList(),
      partnerships: builtPartnerships,
      lifeEvents: builtLifeEvents.map((e) {
        e
          ..title = InputSanitizer.sanitizeRequired(
            e.title,
            maxLength: InputSanitizer.maxShortField,
          )
          ..place = InputSanitizer.shortField(e.place)
          ..notes = InputSanitizer.mediumField(e.notes);
        return e;
      }).toList(),
      sources: builtSources.map((s) {
        s
          ..title = InputSanitizer.sanitizeRequired(
            s.title,
            maxLength: InputSanitizer.maxShortField,
          )
          ..author = InputSanitizer.shortField(s.author)
          ..publisher = InputSanitizer.shortField(s.publisher)
          ..volumePage = InputSanitizer.shortField(s.volumePage);
        return s;
      }).toList(),
    );
  }

  /// Build [Source] objects from the collected SOUR definitions and
  /// per-person references gathered during parsing.
  ///
  /// If the source title or URL contains a findagrave.com memorial URL, the
  /// memorial ID is extracted and stored on the person via [findAGravePersonIds].
  static List<Source> _buildSources(
    List<Map<String, String?>> refs,
    Map<String, Map<String, String>> defs, {
    Map<String, String>? findAGravePersonIds,
    Map<String, String>? familySearchPersonIds,
  }) {
    final built = <Source>[];
    final fagPattern = RegExp(r'findagrave\.com/memorial/(\d+)');
    final fsPattern = RegExp(
      r'familysearch\.org/tree/person/details/([A-Za-z0-9-]+)',
      caseSensitive: false,
    );
    for (final ref in refs) {
      final personId = ref['personId'];
      final sourceId = ref['sourceId'];
      if (personId == null || sourceId == null) continue;
      final def = defs[sourceId];
      final title = def?['title'] ?? sourceId;

      // Detect Find A Grave memorial IDs in title or publisher field.
      for (final haystack in [title, def?['publ'] ?? '']) {
        final m = fagPattern.firstMatch(haystack);
        if (m != null && findAGravePersonIds != null) {
          findAGravePersonIds[personId] = m.group(1)!;
          break;
        }
        final fs = fsPattern.firstMatch(haystack);
        if (fs != null && familySearchPersonIds != null) {
          familySearchPersonIds[personId] = fs.group(1)!;
        }
      }

      built.add(
        Source(
          id: _uuid.v4(),
          personId: personId,
          title: title,
          type: 'GEDCOM Record',
          url: '',
          author: def?['auth'],
          publisher: def?['publ'],
          volumePage: ref['page'],
        ),
      );
    }
    return built;
  }

  Future<void> export(
    List<Person> persons,
    List<Partnership> partnerships,
    String filePath, {
    bool includeLivingData = false,
    List<LifeEvent> lifeEvents = const [],
  }) async {
    final buf = StringBuffer();
    final df = DateFormat('d MMM yyyy');

    buf.writeln('0 HEAD');
    buf.writeln('1 GEDC');
    buf.writeln('2 VERS 5.5.5');
    buf.writeln('1 CHAR UTF-8');
    buf.writeln('1 SOUR Vetviona');
    buf.writeln('2 VERS 1.0');

    // Index life events by personId for quick lookup.
    final eventsByPerson = <String, List<LifeEvent>>{};
    for (final e in lifeEvents) {
      eventsByPerson.putIfAbsent(e.personId, () => []).add(e);
    }

    for (final person in persons) {
      // A person is considered living when they have no recorded death date.
      final isLiving = person.deathDate == null;
      // When living-data is withheld, replace identifying details with a
      // generic placeholder and tag the record with RESN PRIVACY.
      final exportName = (!includeLivingData && isLiving)
          ? 'Living'
          : person.name;

      buf.writeln('0 @${person.id}@ INDI');
      if (exportName.isNotEmpty) {
        buf.writeln('1 NAME $exportName');
      }
      if (!includeLivingData && isLiving) {
        // Mark the record as restricted per GEDCOM 5.5.5 spec.
        buf.writeln('1 RESN PRIVACY');
      } else {
        if (person.gender != null && person.gender!.isNotEmpty) {
          buf.writeln('1 SEX ${person.gender![0].toUpperCase()}');
        }
        if (person.birthDate != null || person.birthPlace != null) {
          buf.writeln('1 BIRT');
          if (person.birthDate != null) {
            buf.writeln('2 DATE ${df.format(person.birthDate!).toUpperCase()}');
          }
          if (person.birthPlace != null && person.birthPlace!.isNotEmpty) {
            buf.writeln('2 PLAC ${person.birthPlace}');
          }
        }
        if (person.deathDate != null || person.deathPlace != null) {
          buf.writeln('1 DEAT');
          if (person.deathDate != null) {
            buf.writeln('2 DATE ${df.format(person.deathDate!).toUpperCase()}');
          }
          if (person.deathPlace != null && person.deathPlace!.isNotEmpty) {
            buf.writeln('2 PLAC ${person.deathPlace}');
          }
          if (person.causeOfDeath != null && person.causeOfDeath!.isNotEmpty) {
            buf.writeln('2 CAUS ${person.causeOfDeath}');
          }
        }
        if (person.burialDate != null || person.burialPlace != null) {
          buf.writeln('1 BURI');
          if (person.burialDate != null) {
            buf.writeln(
              '2 DATE ${df.format(person.burialDate!).toUpperCase()}',
            );
          }
          if (person.burialPlace != null && person.burialPlace!.isNotEmpty) {
            buf.writeln('2 PLAC ${person.burialPlace}');
          }
        }
        if (person.occupation != null && person.occupation!.isNotEmpty) {
          buf.writeln('1 OCCU ${person.occupation}');
        }
        if (person.religion != null && person.religion!.isNotEmpty) {
          buf.writeln('1 RELI ${person.religion}');
        }
        if (person.nationality != null && person.nationality!.isNotEmpty) {
          buf.writeln('1 NATI ${person.nationality}');
        }
        if (person.education != null && person.education!.isNotEmpty) {
          buf.writeln('1 EDUC ${person.education}');
        }
        if (person.aliases.isNotEmpty) {
          for (final alias in person.aliases) {
            if (alias.isNotEmpty) buf.writeln('1 _ALIAS $alias');
          }
        }
        if (person.maidenName != null && person.maidenName!.isNotEmpty) {
          buf.writeln('1 _MARN ${person.maidenName}');
        }
        if (person.notes != null && person.notes!.isNotEmpty) {
          buf.writeln('1 NOTE ${person.notes}');
        }
        // External IDs — non-standard tags recognised by WikiTree / FTM / RootsMagic.
        if (person.wikitreeId != null && person.wikitreeId!.isNotEmpty) {
          buf.writeln('1 _WIKITREEID ${person.wikitreeId}');
        }
        if (person.findAGraveId != null && person.findAGraveId!.isNotEmpty) {
          buf.writeln('1 _FINDAGRAVEID ${person.findAGraveId}');
        }
        if (person.familySearchId != null &&
            person.familySearchId!.isNotEmpty) {
          buf.writeln('1 _FAMILYSEARCHID ${person.familySearchId}');
        }
        // Life events
        for (final event in eventsByPerson[person.id] ?? []) {
          final gedTag = _titleToGedcomTag[event.title] ?? 'EVEN';
          buf.writeln('1 $gedTag');
          if (gedTag == 'EVEN') {
            buf.writeln('2 TYPE ${event.title}');
          }
          if (event.date != null) {
            buf.writeln('2 DATE ${df.format(event.date!).toUpperCase()}');
          }
          if (event.place != null && event.place!.isNotEmpty) {
            buf.writeln('2 PLAC ${event.place}');
          }
          if (event.notes != null && event.notes!.isNotEmpty) {
            buf.writeln('2 NOTE ${event.notes}');
          }
        }
      }
    }

    // Build a lookup: personId → their child IDs (from persons list)
    final childMap = {for (final p in persons) p.id: p.childIds};

    // Write FAM record for each partnership
    int famIdx = 0;
    for (final pt in partnerships) {
      final famId = 'F${famIdx++}';
      buf.writeln('0 @$famId@ FAM');
      buf.writeln('1 HUSB @${pt.person1Id}@');
      buf.writeln('1 WIFE @${pt.person2Id}@');
      if (pt.startDate != null || pt.startPlace != null) {
        buf.writeln('1 MARR');
        if (pt.startDate != null) {
          buf.writeln('2 DATE ${df.format(pt.startDate!).toUpperCase()}');
        }
        if (pt.startPlace != null && pt.startPlace!.isNotEmpty) {
          buf.writeln('2 PLAC ${pt.startPlace}');
        }
      }
      if (pt.isEnded && (pt.endDate != null || pt.endPlace != null)) {
        buf.writeln('1 DIV');
        if (pt.endDate != null) {
          buf.writeln('2 DATE ${df.format(pt.endDate!).toUpperCase()}');
        }
        if (pt.endPlace != null && pt.endPlace!.isNotEmpty) {
          buf.writeln('2 PLAC ${pt.endPlace}');
        }
      }
      // Children of this union = intersection of both partners' child lists
      final p1Children = childMap[pt.person1Id] ?? [];
      final p2Children = childMap[pt.person2Id] ?? [];
      for (final childId in p1Children.where((id) => p2Children.contains(id))) {
        buf.writeln('1 CHIL @$childId@');
      }
    }

    // Persons with children but no partnership record (single parents)
    final coveredPersonIds = partnerships
        .expand((pt) => [pt.person1Id, pt.person2Id])
        .toSet();
    for (final person in persons) {
      if (coveredPersonIds.contains(person.id)) continue;
      if (person.childIds.isEmpty) continue;
      final famId = 'F${famIdx++}';
      buf.writeln('0 @$famId@ FAM');
      buf.writeln('1 HUSB @${person.id}@');
      for (final childId in person.childIds) {
        buf.writeln('1 CHIL @$childId@');
      }
    }

    buf.writeln('0 TRLR');
    await File(filePath).writeAsString(buf.toString());
  }

  DateTime? _parseDate(String dateStr) {
    // GEDCOM uses all-caps month abbreviations (JAN, FEB, …).
    // intl's DateFormat expects title-case (Jan, Feb, …); normalise first.
    final normalized = dateStr.replaceAllMapped(
      RegExp(r'\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\b'),
      (m) => m.group(1)![0] + m.group(1)!.substring(1).toLowerCase(),
    );
    final formats = [
      DateFormat('d MMM yyyy'),
      DateFormat('MMM yyyy'),
      DateFormat('yyyy'),
    ];
    for (final fmt in formats) {
      try {
        return fmt.parse(normalized);
      } catch (_) {}
    }
    return null;
  }
}
