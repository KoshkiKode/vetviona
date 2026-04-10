import 'dart:io';
import 'package:intl/intl.dart';
import '../models/partnership.dart';
import '../models/person.dart';

/// Return value from [GEDCOMParser.parse].
class GedcomResult {
  final List<Person> persons;
  final List<Partnership> partnerships;
  const GedcomResult({required this.persons, required this.partnerships});
}

class GEDCOMParser {
  Future<GedcomResult> parse(String filePath) async {
    final file = File(filePath);
    final lines = await file.readAsLines();
    final persons = <String, Person>{};
    final families = <String, Map<String, dynamic>>{};

    String? currentId;
    String? currentTag;
    Person? currentPerson;
    Map<String, dynamic>? currentFamily;

    for (final line in lines) {
      final parts = line.trim().split(' ');
      if (parts.isEmpty) continue;
      final level = int.tryParse(parts[0]) ?? -1;
      if (level < 0) continue;
      final tag = parts.length > 1 ? parts[1] : '';
      final value = parts.length > 2 ? parts.sublist(2).join(' ') : '';

      if (level == 0) {
        if (currentPerson != null && currentId != null) {
          persons[currentId] = currentPerson;
        }
        currentPerson = null;
        currentFamily = null;
        currentTag = null;
        currentId = null;

        if (value == 'INDI') {
          currentId = tag.replaceAll('@', '');
          currentPerson = Person(id: currentId, name: '');
        } else if (value == 'FAM') {
          final famId = tag.replaceAll('@', '');
          families[famId] = {'children': <String>[]};
          currentFamily = families[famId];
          currentId = famId;
        }
      } else if (level == 1 && currentPerson != null) {
        currentTag = tag;
        if (tag == 'NAME') {
          currentPerson.name = value.replaceAll('/', '').trim();
        } else if (tag == 'SEX') {
          currentPerson.gender = value;
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
      persons[currentId] = currentPerson;
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

    return GedcomResult(
      persons: persons.values.toList(),
      partnerships: builtPartnerships,
    );
  }

  Future<void> export(
      List<Person> persons, List<Partnership> partnerships, String filePath) async {
    final buf = StringBuffer();
    final df = DateFormat('d MMM yyyy');

    buf.writeln('0 HEAD');
    buf.writeln('1 GEDC');
    buf.writeln('2 VERS 5.5.5');
    buf.writeln('1 CHAR UTF-8');
    buf.writeln('1 SOUR Vetviona');
    buf.writeln('2 VERS 1.0');

    for (final person in persons) {
      buf.writeln('0 @${person.id}@ INDI');
      if (person.name.isNotEmpty) {
        buf.writeln('1 NAME ${person.name}');
      }
      if (person.gender != null && person.gender!.isNotEmpty) {
        buf.writeln('1 SEX ${person.gender![0].toUpperCase()}');
      }
      if (person.birthDate != null || person.birthPlace != null) {
        buf.writeln('1 BIRT');
        if (person.birthDate != null) {
          buf.writeln(
              '2 DATE ${df.format(person.birthDate!).toUpperCase()}');
        }
        if (person.birthPlace != null && person.birthPlace!.isNotEmpty) {
          buf.writeln('2 PLAC ${person.birthPlace}');
        }
      }
      if (person.deathDate != null || person.deathPlace != null) {
        buf.writeln('1 DEAT');
        if (person.deathDate != null) {
          buf.writeln(
              '2 DATE ${df.format(person.deathDate!).toUpperCase()}');
        }
        if (person.deathPlace != null && person.deathPlace!.isNotEmpty) {
          buf.writeln('2 PLAC ${person.deathPlace}');
        }
      }
      if (person.notes != null && person.notes!.isNotEmpty) {
        buf.writeln('1 NOTE ${person.notes}');
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
      for (final childId
          in p1Children.where((id) => p2Children.contains(id))) {
        buf.writeln('1 CHIL @$childId@');
      }
    }

    // Persons with children but no partnership record (single parents)
    final coveredPersonIds =
        partnerships.expand((pt) => [pt.person1Id, pt.person2Id]).toSet();
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
    final formats = [
      DateFormat('d MMM yyyy'),
      DateFormat('MMM yyyy'),
      DateFormat('yyyy'),
    ];
    for (final fmt in formats) {
      try {
        return fmt.parse(dateStr);
      } catch (_) {}
    }
    return null;
  }
}
