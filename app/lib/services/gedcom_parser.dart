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

    for (final line in lines) {
      final parts = line.split(' ');
      final level = int.parse(parts[0]);
      final tag = parts.length > 1 ? parts[1] : '';
      final value = parts.length > 2 ? parts.sublist(2).join(' ') : '';

      if (level == 0 && tag.startsWith('@') && tag.endsWith('@')) {
        if (currentPerson != null) {
          persons[currentId!] = currentPerson;
        }
        currentId = tag;
        if (value == 'INDI') {
          currentPerson = Person(id: tag, name: '');
        } else if (value == 'FAM') {
          families[tag] = {};
          currentPerson = null;
        }
      } else if (level == 1 && currentPerson != null) {
        if (tag == 'NAME') {
          currentPerson.name = value.replaceAll('/', '');
        } else if (tag == 'BIRT') {
          currentTag = 'BIRT';
        } else if (tag == 'DEAT') {
          currentTag = 'DEAT';
        } else if (tag == 'SEX') {
          currentPerson.gender = value;
        } else if (tag == 'FAMC') {
          // Family as child
          // For simplicity, assume one family
        } else if (tag == 'FAMS') {
          // Family as spouse
        }
      } else if (level == 2 && currentTag == 'BIRT' && tag == 'DATE') {
        currentPerson!.birthDate = _parseDate(value);
      } else if (level == 2 && currentTag == 'BIRT' && tag == 'PLAC') {
        currentPerson!.birthPlace = value;
      } else if (level == 2 && currentTag == 'DEAT' && tag == 'DATE') {
        currentPerson!.deathDate = _parseDate(value);
      } else if (level == 2 && currentTag == 'DEAT' && tag == 'PLAC') {
        currentPerson!.deathPlace = value;
      }
    }

    if (currentPerson != null) {
      persons[currentId!] = currentPerson;
    }

    // Link families (simplified)
    // This is basic, real GEDCOM has more complexity

    return persons.values.toList();
  }

  DateTime? _parseDate(String dateStr) {
    try {
      // Simple parsing, GEDCOM dates can be complex
      final formats = [DateFormat('d MMM yyyy'), DateFormat('MMM yyyy'), DateFormat('yyyy')];
      for (final format in formats) {
        try {
          return format.parse(dateStr);
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }
}
