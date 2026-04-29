import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/life_event.dart';
import '../models/medical_condition.dart';
import '../models/partnership.dart';
import '../models/person.dart';
import '../models/source.dart';

/// Generates a narrative-style "Family Book" PDF and returns the raw bytes.
class PdfReportService {
  static const _pageFormat = PdfPageFormat.a4;

  // @visibleForTesting
  static String formatDate(DateTime? d) {
    if (d == null) return '';
    return DateFormat('d MMM yyyy').format(d);
  }

  // @visibleForTesting
  static String nameForId(String id, List<Person> persons) =>
      persons.where((p) => p.id == id).firstOrNull?.name ?? id;

  /// Builds a prose narrative paragraph for one person.
  // @visibleForTesting
  static String buildNarrative(
    Person p,
    List<Partnership> partnerships,
    List<LifeEvent> lifeEvents,
    List<MedicalCondition> medicalConditions,
    List<Person> allPersons,
  ) {
    final buf = StringBuffer();
    final firstName = p.name.split(' ').first;

    // Opening sentence
    buf.write('${p.name} was born');
    if (p.birthDate != null) buf.write(' on ${formatDate(p.birthDate)}');
    if (p.birthPlace != null && p.birthPlace!.isNotEmpty) {
      buf.write(' in ${p.birthPlace}');
    }
    buf.write('.');

    // Parents
    if (p.parentIds.isNotEmpty) {
      final parentNames =
          p.parentIds.map((id) => nameForId(id, allPersons)).join(' and ');
      buf.write(' $firstName is the child of $parentNames.');
    }

    // Occupation / education / religion
    if (p.occupation != null && p.occupation!.isNotEmpty) {
      buf.write(' By occupation, $firstName was a ${p.occupation}.');
    }
    if (p.education != null && p.education!.isNotEmpty) {
      buf.write(' Education: ${p.education}.');
    }
    if (p.religion != null && p.religion!.isNotEmpty) {
      buf.write(' Religion: ${p.religion}.');
    }

    // Nationality
    if (p.nationality != null && p.nationality!.isNotEmpty) {
      buf.write(' Nationality: ${p.nationality}.');
    }

    // Aliases
    if (p.aliases.isNotEmpty) {
      buf.write(' Also known as: ${p.aliases.join(', ')}.');
    }

    // Physical traits
    final traits = <String>[];
    if (p.bloodType != null) traits.add('blood type ${p.bloodType}');
    if (p.eyeColour != null) traits.add('${p.eyeColour} eyes');
    if (p.hairColour != null) traits.add('${p.hairColour} hair');
    if (p.height != null) traits.add('height ${p.height}');
    if (traits.isNotEmpty) {
      buf.write(' Physical description: ${traits.join(', ')}.');
    }

    // Partnerships
    final myPartnerships = partnerships
        .where(
            (pt) => pt.person1Id == p.id || pt.person2Id == p.id)
        .toList();
    for (final pt in myPartnerships) {
      final partnerId =
          pt.person1Id == p.id ? pt.person2Id : pt.person1Id;
      final partnerName = nameForId(partnerId, allPersons);
      buf.write(
          ' $firstName ${pt.statusLabel.toLowerCase()} $partnerName');
      if (pt.startDate != null) buf.write(' on ${formatDate(pt.startDate)}');
      if (pt.startPlace != null && pt.startPlace!.isNotEmpty) {
        buf.write(' in ${pt.startPlace}');
      }
      buf.write('.');
    }

    // Children
    if (p.childIds.isNotEmpty) {
      final childNames =
          p.childIds.map((id) => nameForId(id, allPersons)).join(', ');
      final count = p.childIds.length;
      buf.write(
          ' $firstName had $count ${count == 1 ? 'child' : 'children'}: $childNames.');
    }

    // Life events
    for (final e in lifeEvents.where((e) => e.personId == p.id)) {
      buf.write(' ${e.title}');
      if (e.date != null) buf.write(' on ${formatDate(e.date)}');
      if (e.place != null && e.place!.isNotEmpty) {
        buf.write(' in ${e.place}');
      }
      if (e.notes != null && e.notes!.isNotEmpty) {
        buf.write(' (${e.notes})');
      }
      buf.write('.');
    }

    // Medical history
    final conditions =
        medicalConditions.where((mc) => mc.personId == p.id).toList();
    if (conditions.isNotEmpty) {
      final condNames =
          conditions.map((mc) => mc.condition).join(', ');
      buf.write(' Medical history includes: $condNames.');
    }

    // Death
    if (p.deathDate != null || p.deathPlace != null) {
      buf.write(' $firstName died');
      if (p.deathDate != null) buf.write(' on ${formatDate(p.deathDate)}');
      if (p.deathPlace != null && p.deathPlace!.isNotEmpty) {
        buf.write(' in ${p.deathPlace}');
      }
      if (p.causeOfDeath != null && p.causeOfDeath!.isNotEmpty) {
        buf.write(' (cause: ${p.causeOfDeath})');
      }
      buf.write('.');
    }

    if (p.burialPlace != null && p.burialPlace!.isNotEmpty) {
      buf.write(' Buried at ${p.burialPlace}');
      if (p.burialDate != null) buf.write(' on ${formatDate(p.burialDate)}');
      buf.write('.');
    }

    if (p.notes != null && p.notes!.isNotEmpty) {
      buf.write(' Notes: ${p.notes}');
    }

    return buf.toString();
  }

  /// Returns an anonymised placeholder for [person] that keeps only the
  /// structural links (id, parentIds, childIds) and replaces the name with
  /// `'Living'`.  All personal details are cleared so that narrative name
  /// lookups resolve to `'Living'` rather than the person's real name.
  // @visibleForTesting
  static Person anonymiseLiving(Person person) => Person(
        id: person.id,
        name: 'Living',
        parentIds: person.parentIds,
        childIds: person.childIds,
      );

  /// Generates the PDF and returns the raw bytes.
  static Future<Uint8List> generate({
    required List<Person> persons,
    required List<Partnership> partnerships,
    required List<LifeEvent> lifeEvents,
    required List<MedicalCondition> medicalConditions,
    required List<Source> sources,
    required String treeName,
    bool includeLivingData = false,
  }) async {
    final pdf = pw.Document();

    // When not including full living data, replace living persons with
    // anonymised placeholders so the family book still acknowledges their
    // existence while protecting their personal details — consistent with the
    // "Generic Labels" option described in the export dialog.
    //
    // The anonymised placeholder keeps only the structural links (id,
    // parentIds, childIds) so that parent / child / partner name lookups in
    // narratives resolve to "Living" rather than the person's real name.
    final Set<String> livingIds;
    final List<Person> narrativePersons;
    if (includeLivingData) {
      livingIds = const {};
      narrativePersons = persons;
    } else {
      livingIds = {
        for (final p in persons)
          if (!p.isPrivate && p.deathDate == null) p.id,
      };
      narrativePersons = persons.map((p) {
        if (!livingIds.contains(p.id)) return p;
        return anonymiseLiving(p);
      }).toList();
    }

    // Filter: exclude private persons. Sort by birth year ascending.
    final exportPersons = narrativePersons
        .where((p) => !p.isPrivate)
        .toList()
      ..sort((a, b) {
        final ay = a.birthDate?.year ?? 9999;
        final by = b.birthDate?.year ?? 9999;
        return ay.compareTo(by);
      });

    // Cover page
    pdf.addPage(
      pw.Page(
        pageFormat: _pageFormat,
        build: (pw.Context ctx) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                treeName,
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Family History Report',
                style: pw.TextStyle(fontSize: 18),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 32),
              pw.Text(
                'Generated by Vetviona',
                style: pw.TextStyle(
                    fontSize: 12, color: PdfColors.grey600),
              ),
              pw.Text(
                DateFormat('d MMMM yyyy').format(DateTime.now()),
                style: pw.TextStyle(
                    fontSize: 12, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                '${exportPersons.length} '
                '${exportPersons.length == 1 ? "person" : "people"} included',
                style: pw.TextStyle(
                    fontSize: 12, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ),
    );

    if (exportPersons.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: _pageFormat,
          margin: const pw.EdgeInsets.all(40),
          build: (_) => pw.Center(
            child: pw.Text(
              'No people to include in this report.\n'
              'Check that there are people in the tree who are not marked as private.',
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Person pages — 6 per page with narrative paragraphs
    const perPage = 6;
    for (int start = 0;
        start < exportPersons.length;
        start += perPage) {
      final chunk =
          exportPersons.skip(start).take(perPage).toList();
      pdf.addPage(
        pw.Page(
          pageFormat: _pageFormat,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (start == 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 16),
                  child: pw.Text(
                    'People',
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold),
                  ),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: chunk.map((p) {
                    // Living persons get a brief privacy notice; deceased
                    // persons get the full narrative.  Use narrativePersons
                    // so that living relatives resolve to "Living" in name lookups.
                    final narrative = livingIds.contains(p.id)
                        ? 'Personal details withheld for privacy.'
                        : buildNarrative(
                            p,
                            partnerships,
                            lifeEvents,
                            medicalConditions,
                            narrativePersons,
                          );
                    return pw.Padding(
                      padding:
                          const pw.EdgeInsets.only(bottom: 14),
                      child: pw.Column(
                        crossAxisAlignment:
                            pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            p.name,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            narrative,
                            style:
                                const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Divider(color: PdfColors.grey300),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  '${ctx.pageNumber}',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }
}
