import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/life_event.dart';
import 'package:vetviona_app/models/medical_condition.dart';
import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/models/source.dart';
import 'package:vetviona_app/services/pdf_report_service.dart';

void main() {
  // ── formatDate ──────────────────────────────────────────────────────────────

  group('PdfReportService.formatDate', () {
    test('null returns empty string', () {
      expect(PdfReportService.formatDate(null), '');
    });

    test('2000-01-15 → 15 Jan 2000', () {
      expect(PdfReportService.formatDate(DateTime(2000, 1, 15)), '15 Jan 2000');
    });

    test('1850-12-31 → 31 Dec 1850', () {
      expect(PdfReportService.formatDate(DateTime(1850, 12, 31)), '31 Dec 1850');
    });
  });

  // ── nameForId ───────────────────────────────────────────────────────────────

  group('PdfReportService.nameForId', () {
    final persons = [
      Person(id: 'p1', name: 'Alice Smith'),
      Person(id: 'p2', name: 'Bob Jones'),
    ];

    test('found → returns name', () {
      expect(PdfReportService.nameForId('p1', persons), 'Alice Smith');
    });

    test('not found → returns id itself', () {
      expect(PdfReportService.nameForId('unknown', persons), 'unknown');
    });
  });

  // ── buildNarrative ──────────────────────────────────────────────────────────

  group('PdfReportService.buildNarrative', () {
    test('person with no optional fields starts with name', () {
      final person = Person(id: 'x', name: 'John Doe');
      final result = PdfReportService.buildNarrative(person, [], [], [], []);
      expect(result, startsWith('John Doe'));
    });

    test('person with ALL optional fields set', () {
      final parent1 = Person(id: 'p1', name: 'Father Dad');
      final parent2 = Person(id: 'p2', name: 'Mother Mom');
      final child1 = Person(id: 'c1', name: 'Child One');
      final child2 = Person(id: 'c2', name: 'Child Two');
      final allPersons = [parent1, parent2, child1, child2];

      final person = Person(
        id: 'main',
        name: 'Test Person',
        birthDate: DateTime(1950, 6, 15),
        birthPlace: 'London',
        deathDate: DateTime(2020, 3, 10),
        deathPlace: 'Manchester',
        causeOfDeath: 'Natural causes',
        burialPlace: 'Highgate Cemetery',
        burialDate: DateTime(2020, 3, 15),
        occupation: 'Engineer',
        education: 'BSc Engineering',
        religion: 'Anglican',
        nationality: 'British',
        aliases: ['AKA', 'Nickname'],
        bloodType: 'A+',
        eyeColour: 'Blue',
        hairColour: 'Brown',
        height: '180cm',
        parentIds: ['p1', 'p2'],
        childIds: ['c1', 'c2'],
        notes: 'Interesting life.',
      );

      final result = PdfReportService.buildNarrative(
          person, [], [], [], allPersons);

      expect(result, contains('Test Person was born'));
      expect(result, contains('15 Jun 1950'));
      expect(result, contains('London'));
      expect(result, contains('Father Dad'));
      expect(result, contains('Mother Mom'));
      expect(result, contains('Engineer'));
      expect(result, contains('BSc Engineering'));
      expect(result, contains('Anglican'));
      expect(result, contains('British'));
      expect(result, contains('AKA'));
      expect(result, contains('Nickname'));
      expect(result, contains('A+'));
      expect(result, contains('Blue'));
      expect(result, contains('Brown'));
      expect(result, contains('180cm'));
      expect(result, contains('Child One'));
      expect(result, contains('Child Two'));
      expect(result, contains('Manchester'));
      expect(result, contains('Natural causes'));
      expect(result, contains('Highgate Cemetery'));
      expect(result, contains('15 Mar 2020'));
      expect(result, contains('Interesting life.'));
    });

    test('with partnership — partner name appears in narrative', () {
      final partner = Person(id: 'partner1', name: 'Jane Partner');
      final person = Person(id: 'main', name: 'John Main');
      final allPersons = [person, partner];

      final partnership = Partnership(
        id: 'pt1',
        person1Id: 'main',
        person2Id: 'partner1',
        status: 'married',
        startDate: DateTime(1980, 5, 20),
        startPlace: 'Brighton',
      );

      final result = PdfReportService.buildNarrative(
          person, [partnership], [], [], allPersons);

      expect(result, contains('Jane Partner'));
      expect(result, contains('married'));
      expect(result, contains('20 May 1980'));
      expect(result, contains('Brighton'));
    });

    test('with life events — event details appear in narrative', () {
      final person = Person(id: 'main', name: 'John Main');
      final event = LifeEvent(
        id: 'e1',
        personId: 'main',
        title: 'Graduation',
        date: DateTime(1972, 7, 1),
        place: 'Oxford',
        notes: 'First class honours',
      );

      final result = PdfReportService.buildNarrative(
          person, [], [event], [], [person]);

      expect(result, contains('Graduation'));
      expect(result, contains('1 Jul 1972'));
      expect(result, contains('Oxford'));
      expect(result, contains('First class honours'));
    });

    test('with medical conditions — condition appears in narrative', () {
      final person = Person(id: 'main', name: 'John Main');
      final condition = MedicalCondition(
        id: 'mc1',
        personId: 'main',
        condition: 'Hypertension',
        category: 'Cardiovascular',
      );

      final result = PdfReportService.buildNarrative(
          person, [], [], [condition], [person]);

      expect(result, contains('Hypertension'));
    });

    test('empty birthPlace — no "in" clause after birth', () {
      final person = Person(
        id: 'main',
        name: 'No Place',
        birthDate: DateTime(1900, 1, 1),
        birthPlace: '',
      );

      final result = PdfReportService.buildNarrative(
          person, [], [], [], [person]);

      // Should contain date but not " in " before the period
      expect(result, contains('1 Jan 1900'));
      // The narrative should not have " in  " (empty place)
      expect(result, isNot(contains(' in .')));
    });

    test('only burialPlace (no burialDate) — burial sentence no date', () {
      final person = Person(
        id: 'main',
        name: 'Buried Person',
        burialPlace: 'City Cemetery',
      );

      final result = PdfReportService.buildNarrative(
          person, [], [], [], [person]);

      expect(result, contains('City Cemetery'));
      expect(result, contains('Buried at City Cemetery.'));
    });

    test('partnership where person is person2 — partner id is person1Id', () {
      final person = Person(id: 'main', name: 'Alice Main');
      final partner = Person(id: 'partner1', name: 'Bob Partner');
      final allPersons = [person, partner];

      final partnership = Partnership(
        id: 'pt1',
        person1Id: 'partner1',
        person2Id: 'main',  // person is person2
        status: 'married',
        startDate: DateTime(1975, 8, 10),
      );

      final result = PdfReportService.buildNarrative(
          person, [partnership], [], [], allPersons);

      expect(result, contains('Bob Partner'));
    });

    test('partnership with no startDate or startPlace — just name and status', () {
      final person = Person(id: 'main', name: 'Alice Main');
      final partner = Person(id: 'partner1', name: 'Bob Partner');

      final partnership = Partnership(
        id: 'pt1',
        person1Id: 'main',
        person2Id: 'partner1',
        status: 'divorced',
      );

      final result = PdfReportService.buildNarrative(
          person, [partnership], [], [], [person, partner]);

      expect(result, contains('Bob Partner'));
      expect(result, contains('divorced'));
    });

    test('single child — uses singular "child"', () {
      final child = Person(id: 'c1', name: 'Only Child');
      final person = Person(
        id: 'main',
        name: 'John Main',
        childIds: ['c1'],
      );

      final result = PdfReportService.buildNarrative(
          person, [], [], [], [person, child]);

      expect(result, contains('had 1 child:'));
    });

    test('life event without date and without place', () {
      final person = Person(id: 'main', name: 'John Main');
      final event = LifeEvent(
        id: 'e1',
        personId: 'main',
        title: 'Baptism',
      );

      final result = PdfReportService.buildNarrative(
          person, [], [event], [], [person]);

      expect(result, contains('Baptism'));
      expect(result, isNot(contains(' on ')));
      expect(result, isNot(contains(' in ')));
    });

    test('life event for different person is filtered out', () {
      final person = Person(id: 'main', name: 'John Main');
      final event = LifeEvent(
        id: 'e1',
        personId: 'other-person',  // different person
        title: 'Secret Event',
      );

      final result = PdfReportService.buildNarrative(
          person, [], [event], [], [person]);

      expect(result, isNot(contains('Secret Event')));
    });

    test('medical condition for different person is filtered out', () {
      final person = Person(id: 'main', name: 'John Main');
      final condition = MedicalCondition(
        id: 'mc1',
        personId: 'other-person',  // different person
        condition: 'Other Disease',
        category: 'Other',
      );

      final result = PdfReportService.buildNarrative(
          person, [], [], [condition], [person]);

      expect(result, isNot(contains('Other Disease')));
    });

    test('death with only deathPlace (no deathDate)', () {
      final person = Person(
        id: 'main',
        name: 'John Main',
        deathPlace: 'Paris',
      );

      final result = PdfReportService.buildNarrative(
          person, [], [], [], [person]);

      expect(result, contains('died'));
      expect(result, contains('Paris'));
    });

    test('death with only deathDate (no deathPlace)', () {
      final person = Person(
        id: 'main',
        name: 'John Main',
        deathDate: DateTime(1999, 12, 31),
      );

      final result = PdfReportService.buildNarrative(
          person, [], [], [], [person]);

      expect(result, contains('died'));
      expect(result, contains('31 Dec 1999'));
    });

    test('multiple medical conditions joined with comma', () {
      final person = Person(id: 'main', name: 'John Main');
      final conditions = [
        MedicalCondition(id: 'mc1', personId: 'main', condition: 'Diabetes', category: 'Metabolic'),
        MedicalCondition(id: 'mc2', personId: 'main', condition: 'Arthritis', category: 'Musculoskeletal'),
      ];

      final result = PdfReportService.buildNarrative(
          person, [], [], conditions, [person]);

      expect(result, contains('Diabetes'));
      expect(result, contains('Arthritis'));
      expect(result, contains('Medical history includes:'));
    });
  });

  // ── PdfReportService.generate — privacy / "Generic Labels" behaviour ────────

  group('PdfReportService.generate — Generic Labels privacy', () {
    final deceased = Person(
      id: 'dec1',
      name: 'Alice Anderson',
      deathDate: DateTime(2000, 1, 1),
      childIds: ['liv1'],
    );
    final living = Person(
      id: 'liv1',
      name: 'Bob Anderson',
      parentIds: ['dec1'],
    );

    test(
        'includeLivingData=false includes living person (not excluded entirely)',
        () async {
      final bytes = await PdfReportService.generate(
        persons: [deceased, living],
        partnerships: [],
        lifeEvents: [],
        medicalConditions: [],
        sources: [],
        treeName: 'Test',
        includeLivingData: false,
      );
      // Both deceased and living persons are included (living shows as "Living")
      // so the PDF should be at least as large as with an all-deceased tree.
      expect(bytes.length, greaterThan(200));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('includeLivingData=true produces a valid PDF', () async {
      final bytes = await PdfReportService.generate(
        persons: [deceased, living],
        partnerships: [],
        lifeEvents: [],
        medicalConditions: [],
        sources: [],
        treeName: 'Test',
        includeLivingData: true,
      );
      expect(bytes.length, greaterThan(200));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test(
        'living-only tree with includeLivingData=false produces a valid PDF',
        () async {
      // All people are living — previously would have produced an empty report
      // (excluded entirely).  Now they are included anonymised as "Living".
      final bytes = await PdfReportService.generate(
        persons: [living],
        partnerships: [],
        lifeEvents: [],
        medicalConditions: [],
        sources: [],
        treeName: 'Test',
        includeLivingData: false,
      );
      expect(bytes.length, greaterThan(200));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('all-private tree produces a valid PDF without crashing', () async {
      final priv = Person(id: 'p1', name: 'Private Person', isPrivate: true);
      final bytes = await PdfReportService.generate(
        persons: [priv],
        partnerships: [],
        lifeEvents: [],
        medicalConditions: [],
        sources: [],
        treeName: 'Test',
      );
      expect(bytes.length, greaterThan(200));
    });

    test(
        'buildNarrative uses anonymised allPersons: living parent shows as "Living"',
        () {
      // A deceased person whose parent is living — the narrative should
      // reference "Living" rather than the real name when using the
      // anonymised persons list (as generate() does internally).
      final parent = Person(id: 'par1', name: 'Bob Living');
      final child = Person(
        id: 'chi1',
        name: 'Alice Deceased',
        deathDate: DateTime(2020, 1, 1),
        parentIds: ['par1'],
      );
      // Use the shared anonymiseLiving helper (same as generate() uses).
      final anonParent = PdfReportService.anonymiseLiving(parent);
      final allPersons = [child, anonParent];
      final narrative =
          PdfReportService.buildNarrative(child, [], [], [], allPersons);
      expect(narrative, contains('Living'));
      expect(narrative, isNot(contains('Bob Living')));
    });
  });
}
