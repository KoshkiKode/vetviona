import 'dart:io';
import 'package:intl/intl.dart';
import '../models/person.dart';

class GEDCOMParser {
  Future<List<Person>> parse(String filePath) async {
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
        // Save previous
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
        } else if (currentTag == 'MARR' && tag == 'DATE') {
          currentPerson.marriageDate = _parseDate(value);
        } else if (currentTag == 'MARR' && tag == 'PLAC') {
          currentPerson.marriagePlace = value;
        }
      }
    }

    if (currentPerson != null && currentId != null) {
      persons[currentId] = currentPerson;
    }

    // Link families
    for (final fam in families.values) {
      final husbId = fam['husb'] as String?;
      final wifeId = fam['wife'] as String?;
      final children = fam['children'] as List<String>;

      if (husbId != null && wifeId != null) {
        persons[husbId]?.spouseId = wifeId;
        persons[wifeId]?.spouseId = husbId;
      }
      for (final childId in children) {
        final child = persons[childId];
        if (child != null) {
          if (husbId != null && !child.parentIds.contains(husbId)) {
            child.parentIds.add(husbId);
          }
          if (wifeId != null && !child.parentIds.contains(wifeId)) {
            child.parentIds.add(wifeId);
          }
        }
        if (husbId != null) {
          persons[husbId]?.childIds.add(childId);
        }
        if (wifeId != null) {
          persons[wifeId]?.childIds.add(childId);
        }
      }
    }

    return persons.values.toList();
  }

  Future<void> export(List<Person> persons, String filePath) async {
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
      }
      if (person.notes != null && person.notes!.isNotEmpty) {
        buf.writeln('1 NOTE ${person.notes}');
      }
    }

    // Write family records for spouse/parent-child relationships
    final writtenFamilies = <String>{};
    for (final person in persons) {
      if (person.spouseId != null) {
        final famKey = [person.id, person.spouseId!]..sort();
        final famId = 'F${famKey.join('_')}';
        if (!writtenFamilies.contains(famId)) {
          writtenFamilies.add(famId);
          buf.writeln('0 @$famId@ FAM');
          buf.writeln('1 HUSB @${person.id}@');
          buf.writeln('1 WIFE @${person.spouseId}@');
          if (person.marriageDate != null || person.marriagePlace != null) {
            buf.writeln('1 MARR');
            if (person.marriageDate != null) {
              buf.writeln('2 DATE ${df.format(person.marriageDate!).toUpperCase()}');
            }
            if (person.marriagePlace != null && person.marriagePlace!.isNotEmpty) {
              buf.writeln('2 PLAC ${person.marriagePlace}');
            }
          }
          for (final childId in person.childIds) {
            buf.writeln('1 CHIL @$childId@');
          }
        }
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
