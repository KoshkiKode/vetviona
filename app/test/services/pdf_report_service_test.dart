import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/life_event.dart';
import 'package:vetviona_app/models/medical_condition.dart';
import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/models/person.dart';
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
  });
}
