import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/life_event.dart';
import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/models/source.dart';
import 'package:vetviona_app/services/gedcom_parser.dart';

void main() {
  late Directory tempDir;
  late GEDCOMParser parser;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vetviona_gedcom_test_');
    parser = GEDCOMParser();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  // Write GEDCOM content to a temp file and return its path.
  Future<String> writeGedcom(String content) async {
    final file = File('${tempDir.path}/test.ged');
    await file.writeAsString(content);
    return file.path;
  }

  group('GEDCOMParser.parse', () {
    test('empty GEDCOM (just HEAD and TRLR) produces no records', () async {
      final path = await writeGedcom('0 HEAD\n0 TRLR\n');
      final result = await parser.parse(path);
      expect(result.persons, isEmpty);
      expect(result.partnerships, isEmpty);
    });

    test('single person with NAME and SEX', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME John /Doe/
1 SEX M
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.persons.length, 1);
      expect(result.persons.first.name, 'John Doe');
      expect(result.persons.first.gender, 'M');
    });

    test('name with slashes stripped', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Alice /Smith/
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.persons.first.name, 'Alice Smith');
    });

    test('person with birth date and place', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Alice
1 BIRT
2 DATE 15 MAY 1900
2 PLAC London, England
0 TRLR
''');
      final result = await parser.parse(path);
      final alice = result.persons.first;
      expect(alice.birthDate?.year, 1900);
      expect(alice.birthDate?.month, 5);
      expect(alice.birthDate?.day, 15);
      expect(alice.birthPlace, 'London, England');
    });

    test('person with death date and place', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Bob
1 DEAT
2 DATE 20 JUN 1980
2 PLAC Paris, France
0 TRLR
''');
      final result = await parser.parse(path);
      final bob = result.persons.first;
      expect(bob.deathDate?.year, 1980);
      expect(bob.deathDate?.month, 6);
      expect(bob.deathPlace, 'Paris, France');
    });

    test('family record creates partnership', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME John
0 @I2@ INDI
1 NAME Jane
0 @F1@ FAM
1 HUSB @I1@
1 WIFE @I2@
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.persons.length, 2);
      expect(result.partnerships.length, 1);
      expect(result.partnerships.first.person1Id, 'I1');
      expect(result.partnerships.first.person2Id, 'I2');
    });

    test('family with children sets parent/child links', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Father
0 @I2@ INDI
1 NAME Mother
0 @I3@ INDI
1 NAME Child
0 @F1@ FAM
1 HUSB @I1@
1 WIFE @I2@
1 CHIL @I3@
0 TRLR
''');
      final result = await parser.parse(path);
      final child = result.persons.firstWhere((p) => p.name == 'Child');
      expect(child.parentIds, containsAll(['I1', 'I2']));

      final father = result.persons.firstWhere((p) => p.name == 'Father');
      expect(father.childIds, contains('I3'));

      final mother = result.persons.firstWhere((p) => p.name == 'Mother');
      expect(mother.childIds, contains('I3'));
    });

    test('family with marriage date and place', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME John
0 @I2@ INDI
1 NAME Jane
0 @F1@ FAM
1 HUSB @I1@
1 WIFE @I2@
1 MARR
2 DATE 10 JUN 2000
2 PLAC New York, USA
0 TRLR
''');
      final result = await parser.parse(path);
      final pt = result.partnerships.first;
      expect(pt.startDate?.year, 2000);
      expect(pt.startDate?.month, 6);
      expect(pt.startPlace, 'New York, USA');
    });

    test('family with divorce sets ended status and date', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME John
0 @I2@ INDI
1 NAME Jane
0 @F1@ FAM
1 HUSB @I1@
1 WIFE @I2@
1 DIV
2 DATE 15 MAR 2010
2 PLAC Los Angeles, USA
0 TRLR
''');
      final result = await parser.parse(path);
      final pt = result.partnerships.first;
      expect(pt.status, 'divorced');
      expect(pt.endDate?.year, 2010);
      expect(pt.endPlace, 'Los Angeles, USA');
    });

    test('multiple families parsed independently', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Person1
0 @I2@ INDI
1 NAME Person2
0 @I3@ INDI
1 NAME Person3
0 @I4@ INDI
1 NAME Person4
0 @F1@ FAM
1 HUSB @I1@
1 WIFE @I2@
0 @F2@ FAM
1 HUSB @I3@
1 WIFE @I4@
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.persons.length, 4);
      expect(result.partnerships.length, 2);
    });

    test('year-only date parses correctly', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME OldPerson
1 BIRT
2 DATE 1850
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.persons.first.birthDate?.year, 1850);
    });

    test('month+year date parses correctly', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME MidPerson
1 BIRT
2 DATE JAN 1920
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.persons.first.birthDate?.year, 1920);
      expect(result.persons.first.birthDate?.month, 1);
    });

    test('duplicate parent links not added', () async {
      // Two families referencing the same child.
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Father
0 @I2@ INDI
1 NAME Mother
0 @I3@ INDI
1 NAME Child
0 @F1@ FAM
1 HUSB @I1@
1 WIFE @I2@
1 CHIL @I3@
0 @F2@ FAM
1 HUSB @I1@
1 WIFE @I2@
1 CHIL @I3@
0 TRLR
''');
      final result = await parser.parse(path);
      final child = result.persons.firstWhere((p) => p.name == 'Child');
      // Each parent should appear exactly once
      expect(child.parentIds.where((id) => id == 'I1').length, 1);
      expect(child.parentIds.where((id) => id == 'I2').length, 1);
    });
  });

  group('GEDCOMParser.export', () {
    test('exports HEAD and TRLR markers', () async {
      final path = '${tempDir.path}/out.ged';
      await parser.export([], [], path);
      final content = await File(path).readAsString();
      expect(content, contains('0 HEAD'));
      expect(content, contains('0 TRLR'));
    });

    test('exports person with INDI tag', () async {
      final persons = [
        Person(id: 'P1', name: 'Alice Test', gender: 'F'),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('@P1@ INDI'));
      expect(content, contains('1 NAME Alice Test'));
      expect(content, contains('1 SEX F'));
    });

    test('exports birth date and place', () async {
      final persons = [
        Person(
          id: 'P1',
          name: 'Alice',
          birthDate: DateTime(1980, 3, 15),
          birthPlace: 'Boston',
        ),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('1 BIRT'));
      expect(content, contains('2 DATE'));
      expect(content, contains('MAR'));
      expect(content, contains('1980'));
      expect(content, contains('2 PLAC Boston'));
    });

    test('exports death date and place', () async {
      final persons = [
        Person(
          id: 'P1',
          name: 'Bob',
          deathDate: DateTime(2010, 7, 4),
          deathPlace: 'Chicago',
        ),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, [], path);
      final content = await File(path).readAsString();
      expect(content, contains('1 DEAT'));
      expect(content, contains('2 PLAC Chicago'));
    });

    test('exports partnership as FAM record', () async {
      final persons = [
        Person(id: 'P1', name: 'Alice'),
        Person(id: 'P2', name: 'Bob'),
      ];
      final partnerships = [
        Partnership(id: 'F1', person1Id: 'P1', person2Id: 'P2'),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, partnerships, path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('FAM'));
      expect(content, contains('1 HUSB @P1@'));
      expect(content, contains('1 WIFE @P2@'));
    });

    test('exports children in FAM record', () async {
      final persons = [
        Person(id: 'P1', name: 'Alice', childIds: ['P3']),
        Person(id: 'P2', name: 'Bob', childIds: ['P3']),
        Person(id: 'P3', name: 'Child', parentIds: ['P1', 'P2']),
      ];
      final partnerships = [
        Partnership(id: 'F1', person1Id: 'P1', person2Id: 'P2'),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, partnerships, path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('1 CHIL @P3@'));
    });

    test('exports marriage date', () async {
      final persons = [
        Person(id: 'P1', name: 'Alice'),
        Person(id: 'P2', name: 'Bob'),
      ];
      final partnerships = [
        Partnership(
          id: 'F1',
          person1Id: 'P1',
          person2Id: 'P2',
          startDate: DateTime(2000, 1, 1),
          startPlace: 'London',
        ),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, partnerships, path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('1 MARR'));
      expect(content, contains('2 PLAC London'));
    });

    test('exports divorce tag for ended partnership', () async {
      final persons = [
        Person(id: 'P1', name: 'Alice'),
        Person(id: 'P2', name: 'Bob'),
      ];
      final partnerships = [
        Partnership(
          id: 'F1',
          person1Id: 'P1',
          person2Id: 'P2',
          status: 'divorced',
          endDate: DateTime(2015, 6, 1),
          endPlace: 'Paris',
        ),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, partnerships, path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('1 DIV'));
      expect(content, contains('2 PLAC Paris'));
    });

    test('exports notes', () async {
      final persons = [
        Person(id: 'P1', name: 'Alice', notes: 'Emigrated in 1920'),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('1 NOTE Emigrated in 1920'));
    });

    test('single parent with children generates a FAM record', () async {
      final persons = [
        Person(id: 'P1', name: 'SingleParent', childIds: ['P2']),
        Person(id: 'P2', name: 'Child', parentIds: ['P1']),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('FAM'));
      expect(content, contains('1 HUSB @P1@'));
      expect(content, contains('1 CHIL @P2@'));
    });

    test('export/import roundtrip preserves person count', () async {
      final persons = List.generate(
        50,
        (i) => Person(id: 'P$i', name: 'Person $i', gender: i.isEven ? 'M' : 'F'),
      );
      final path = '${tempDir.path}/rt.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final result = await parser.parse(path);
      expect(result.persons.length, 50);
    });

    test('large export (100 people) completes in reasonable time', () async {
      final persons = List.generate(
        100,
        (i) => Person(
          id: 'P$i',
          name: 'Person $i',
          parentIds: i > 0 ? ['P${i - 1}'] : [],
          childIds: i < 99 ? ['P${i + 1}'] : [],
        ),
      );
      final path = '${tempDir.path}/large.ged';
      final sw = Stopwatch()..start();
      await parser.export(persons, [], path, includeLivingData: true);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(5000));

      final result = await parser.parse(path);
      expect(result.persons.length, 100);
    });

    test('living person exported as generic when includeLivingData is false',
        () async {
      final persons = [
        Person(
          id: 'P1',
          name: 'Alice Living',
          gender: 'F',
          birthDate: DateTime(1990, 5, 1),
          birthPlace: 'London',
          notes: 'Some private notes',
        ),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, [], path);
      final content = await File(path).readAsString();
      expect(content, contains('@P1@ INDI'));
      expect(content, contains('1 NAME Living'));
      expect(content, contains('1 RESN PRIVACY'));
      expect(content, isNot(contains('Alice Living')));
      expect(content, isNot(contains('1 SEX')));
      expect(content, isNot(contains('1 BIRT')));
      expect(content, isNot(contains('1 NOTE')));
    });

    test('deceased person exported with full data even when includeLivingData is false',
        () async {
      final persons = [
        Person(
          id: 'P1',
          name: 'Bob Deceased',
          gender: 'M',
          birthDate: DateTime(1920, 1, 1),
          deathDate: DateTime(2000, 12, 31),
          notes: 'Historical figure',
        ),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, [], path);
      final content = await File(path).readAsString();
      expect(content, contains('1 NAME Bob Deceased'));
      expect(content, contains('1 SEX M'));
      expect(content, contains('1 BIRT'));
      expect(content, contains('1 DEAT'));
      expect(content, contains('1 NOTE Historical figure'));
      expect(content, isNot(contains('1 RESN PRIVACY')));
    });

    test('exports occupation as OCCU tag', () async {
      final persons = [
        Person(
          id: 'P1',
          name: 'Alice',
          deathDate: DateTime(1990),
          occupation: 'Doctor',
        ),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('1 OCCU Doctor'));
    });

    test('exports religion as RELI tag', () async {
      final persons = [
        Person(
          id: 'P1',
          name: 'Alice',
          deathDate: DateTime(1990),
          religion: 'Lutheran',
        ),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('1 RELI Lutheran'));
    });

    test('exports cause of death as CAUS under DEAT', () async {
      final persons = [
        Person(
          id: 'P1',
          name: 'Bob',
          deathDate: DateTime(1980, 5, 10),
          causeOfDeath: 'pneumonia',
        ),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('1 DEAT'));
      expect(content, contains('2 CAUS pneumonia'));
    });

    test('exports burial date and place as BURI', () async {
      final persons = [
        Person(
          id: 'P1',
          name: 'Alice',
          deathDate: DateTime(1970),
          burialDate: DateTime(1970, 3, 20),
          burialPlace: 'Green Lawn Cemetery',
        ),
      ];
      final path = '${tempDir.path}/out.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('1 BURI'));
      expect(content, contains('2 PLAC Green Lawn Cemetery'));
    });

    test('exports known life events with correct GEDCOM tags', () async {
      final persons = [
        Person(id: 'P1', name: 'Alice', deathDate: DateTime(2000)),
      ];
      final lifeEvents = [
        LifeEvent(id: 'e1', personId: 'P1', title: 'Immigration',
            date: DateTime(1920, 4, 1), place: 'New York'),
        LifeEvent(id: 'e2', personId: 'P1', title: 'Graduation',
            date: DateTime(1935)),
        LifeEvent(id: 'e3', personId: 'P1', title: 'Census',
            place: 'Boston'),
      ];
      final path = '${tempDir.path}/out_events.ged';
      await parser.export(persons, [], path,
          includeLivingData: true, lifeEvents: lifeEvents);
      final content = await File(path).readAsString();
      expect(content, contains('1 IMMI'));
      expect(content, contains('2 PLAC New York'));
      expect(content, contains('1 GRAD'));
      expect(content, contains('1 CENS'));
      expect(content, contains('2 PLAC Boston'));
    });

    test('exports unknown life event title as EVEN with TYPE', () async {
      final persons = [
        Person(id: 'P1', name: 'Alice', deathDate: DateTime(2000)),
      ];
      final lifeEvents = [
        LifeEvent(id: 'e1', personId: 'P1', title: 'Award Ceremony',
            date: DateTime(1965)),
      ];
      final path = '${tempDir.path}/out_even.ged';
      await parser.export(persons, [], path,
          includeLivingData: true, lifeEvents: lifeEvents);
      final content = await File(path).readAsString();
      expect(content, contains('1 EVEN'));
      expect(content, contains('2 TYPE Award Ceremony'));
    });

    test('exports life event notes as level-2 NOTE', () async {
      final persons = [
        Person(id: 'P1', name: 'Alice', deathDate: DateTime(2000)),
      ];
      final lifeEvents = [
        LifeEvent(
          id: 'e1',
          personId: 'P1',
          title: 'Baptism',
          notes: 'Baptised in St. Mary church',
        ),
      ];
      final path = '${tempDir.path}/out_note.ged';
      await parser.export(persons, [], path,
          includeLivingData: true, lifeEvents: lifeEvents);
      final content = await File(path).readAsString();
      expect(content, contains('1 BAPM'));
      expect(content, contains('2 NOTE Baptised in St. Mary church'));
    });

    test(
        'life events for living person are not exported when includeLivingData is false',
        () async {
      final persons = [Person(id: 'P1', name: 'Alice')];
      final lifeEvents = [
        LifeEvent(id: 'e1', personId: 'P1', title: 'Immigration'),
      ];
      final path = '${tempDir.path}/out_living_events.ged';
      await parser.export(persons, [], path,
          includeLivingData: false, lifeEvents: lifeEvents);
      final content = await File(path).readAsString();
      expect(content, isNot(contains('1 IMMI')));
    });
  });

  group('GEDCOMParser.parse — extended fields', () {
    test('OCCU tag parses to occupation', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Alice
1 OCCU Farmer
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.persons.first.occupation, 'Farmer');
    });

    test('RELI tag parses to religion', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Bob
1 RELI Buddhist
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.persons.first.religion, 'Buddhist');
    });

    test('BURI date and place parse to burialDate and burialPlace', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Alice
1 BURI
2 DATE 10 MAR 1950
2 PLAC Green Hill Cemetery
0 TRLR
''');
      final result = await parser.parse(path);
      final alice = result.persons.first;
      expect(alice.burialDate?.year, 1950);
      expect(alice.burialDate?.month, 3);
      expect(alice.burialDate?.day, 10);
      expect(alice.burialPlace, 'Green Hill Cemetery');
    });

    test('CAUS under DEAT parses to causeOfDeath', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Bob
1 DEAT
2 DATE 5 JUN 1970
2 CAUS tuberculosis
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.persons.first.causeOfDeath, 'tuberculosis');
    });

    test('IMMI tag creates an Immigration LifeEvent', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Alice
1 IMMI
2 DATE 12 APR 1910
2 PLAC Ellis Island, New York
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(1));
      final ev = result.lifeEvents.first;
      expect(ev.title, 'Immigration');
      expect(ev.date?.year, 1910);
      expect(ev.place, 'Ellis Island, New York');
    });

    test('BAPM tag creates a Baptism LifeEvent', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Maria
1 BAPM
2 DATE 3 JAN 1880
2 PLAC Vienna, Austria
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(1));
      expect(result.lifeEvents.first.title, 'Baptism');
      expect(result.lifeEvents.first.place, 'Vienna, Austria');
    });

    test('multiple life event tags for one person are all captured', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Alice
1 IMMI
2 DATE 1 JAN 1900
1 EMIG
2 DATE 15 JUN 1920
1 GRAD
2 DATE 5 MAY 1925
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(3));
      final titles = result.lifeEvents.map((e) => e.title).toSet();
      expect(titles, containsAll(['Immigration', 'Emigration', 'Graduation']));
    });

    test('EVEN tag with TYPE creates LifeEvent with custom title', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Alice
1 EVEN
2 TYPE Military Decoration
2 DATE 8 MAY 1945
2 PLAC Berlin
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(1));
      expect(result.lifeEvents.first.title, 'Military Decoration');
      expect(result.lifeEvents.first.place, 'Berlin');
    });

    test('EVEN tag without TYPE falls back to "Event"', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Alice
1 EVEN
2 DATE 1 JAN 1950
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(1));
      expect(result.lifeEvents.first.title, 'Event');
    });

    test('NOTE at level 2 within a life event is stored as notes', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Bob
1 CENS
2 DATE 1880
2 NOTE Found in national census registry
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents.first.notes, 'Found in national census registry');
    });

    test('CENS tag creates Census life event', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Alice
1 CENS
2 DATE 1901
2 PLAC London
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents.first.title, 'Census');
    });

    test('export/import roundtrip with life events preserves event count',
        () async {
      final persons = [
        Person(id: 'P1', name: 'Alice', deathDate: DateTime(2000)),
      ];
      final lifeEvents = [
        LifeEvent(id: 'e1', personId: 'P1', title: 'Immigration',
            date: DateTime(1920)),
        LifeEvent(id: 'e2', personId: 'P1', title: 'Graduation',
            date: DateTime(1930)),
      ];
      final path = '${tempDir.path}/rt_events.ged';
      await parser.export(persons, [], path,
          includeLivingData: true, lifeEvents: lifeEvents);
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(2));
    });
  });

  // ── GEDCOMParser.parse — SOUR records ─────────────────────────────────────
  group('GEDCOMParser.parse — SOUR records', () {
    test('SOUR record with TITL produces a source for the referencing person',
        () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Jane /Doe/
1 SOUR @S1@
0 @S1@ SOUR
1 TITL Birth Certificate
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.sources, hasLength(1));
      expect(result.sources.first.title, 'Birth Certificate');
      expect(result.sources.first.personId, 'I1');
    });

    test('SOUR record with AUTH is stored as author on the source', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Alice /Smith/
1 SOUR @S1@
0 @S1@ SOUR
1 TITL Parish Register
1 AUTH Rev. Thomas Brown
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.sources, hasLength(1));
      expect(result.sources.first.author, 'Rev. Thomas Brown');
    });

    test('SOUR record with PUBL is stored as publisher on the source',
        () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Bob /Jones/
1 SOUR @S1@
0 @S1@ SOUR
1 TITL Census Record
1 PUBL National Archives
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.sources, hasLength(1));
      expect(result.sources.first.publisher, 'National Archives');
    });

    test('multiple persons referencing the same source each get their own Source object',
        () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Alice /Smith/
1 SOUR @S1@
0 @I2@ INDI
1 NAME Bob /Smith/
1 SOUR @S1@
0 @S1@ SOUR
1 TITL Family Bible
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.sources, hasLength(2));
      expect(result.sources.every((s) => s.title == 'Family Bible'), true);
      expect(result.sources.map((s) => s.personId).toSet(),
          containsAll(['I1', 'I2']));
    });

    test('SOUR reference without a matching definition falls back to source id as title',
        () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Carol /White/
1 SOUR @S99@
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.sources, hasLength(1));
      expect(result.sources.first.title, 'S99');
    });

    test('INDI record with no SOUR reference produces no sources', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Dave /Gray/
0 @S1@ SOUR
1 TITL Unused Source
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.sources, isEmpty);
    });

    test('SOUR source type is set to GEDCOM Record', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Eve /Black/
1 SOUR @S1@
0 @S1@ SOUR
1 TITL Death Record
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.sources.first.type, 'GEDCOM Record');
    });

    test('result.sources list is empty when GEDCOM has no SOUR records',
        () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Frank /Hill/
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.sources, isEmpty);
    });
  });

  // ── GEDCOMParser.parse — additional life event tags ────────────────────────
  group('GEDCOMParser.parse — additional life event tags', () {
    test('CHR tag creates Christening LifeEvent', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Maria
1 CHR
2 DATE 5 FEB 1890
2 PLAC Prague, Bohemia
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(1));
      expect(result.lifeEvents.first.title, 'Christening');
      expect(result.lifeEvents.first.date?.year, 1890);
      expect(result.lifeEvents.first.place, 'Prague, Bohemia');
    });

    test('CONF tag creates Confirmation LifeEvent', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Hans
1 CONF
2 DATE 20 APR 1906
2 PLAC Vienna, Austria
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(1));
      expect(result.lifeEvents.first.title, 'Confirmation');
      expect(result.lifeEvents.first.date?.year, 1906);
    });

    test('NATU tag creates Naturalization LifeEvent', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Olga
1 NATU
2 DATE 12 SEP 1945
2 PLAC New York, USA
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(1));
      expect(result.lifeEvents.first.title, 'Naturalization');
      expect(result.lifeEvents.first.place, 'New York, USA');
    });

    test('MILI tag creates Military Service LifeEvent', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME John
1 MILI
2 DATE 1 JUN 1944
2 PLAC Normandy, France
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(1));
      expect(result.lifeEvents.first.title, 'Military Service');
      expect(result.lifeEvents.first.date?.year, 1944);
    });

    test('RESI tag creates Residence LifeEvent', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Peter
1 RESI
2 DATE 1930
2 PLAC Chicago, Illinois
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(1));
      expect(result.lifeEvents.first.title, 'Residence');
      expect(result.lifeEvents.first.place, 'Chicago, Illinois');
    });

    test('EMIG tag creates Emigration LifeEvent', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Anna
1 EMIG
2 DATE 15 MAR 1912
2 PLAC Hamburg, Germany
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(1));
      expect(result.lifeEvents.first.title, 'Emigration');
      expect(result.lifeEvents.first.date?.year, 1912);
      expect(result.lifeEvents.first.place, 'Hamburg, Germany');
    });

    test('GRAD tag creates Graduation LifeEvent', () async {
      final path = await writeGedcom('''
0 HEAD
0 @I1@ INDI
1 NAME Thomas
1 GRAD
2 DATE 1 JUN 1955
2 PLAC Oxford, England
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(1));
      expect(result.lifeEvents.first.title, 'Graduation');
      expect(result.lifeEvents.first.date?.year, 1955);
      expect(result.lifeEvents.first.place, 'Oxford, England');
    });
  });

  group('GEDCOMParser.export — additional life event tags', () {
    test('exports Emigration as EMIG tag', () async {
      final persons = [
        Person(id: 'P1', name: 'Anna', deathDate: DateTime(1980)),
      ];
      final lifeEvents = [
        LifeEvent(
          id: 'e1',
          personId: 'P1',
          title: 'Emigration',
          date: DateTime(1912, 3, 15),
          place: 'Hamburg, Germany',
        ),
      ];
      final path = '${tempDir.path}/out_emig.ged';
      await parser.export(persons, [], path,
          includeLivingData: true, lifeEvents: lifeEvents);
      final content = await File(path).readAsString();
      expect(content, contains('1 EMIG'));
      expect(content, contains('2 PLAC Hamburg, Germany'));
    });

    test('exports Graduation as GRAD tag', () async {
      final persons = [
        Person(id: 'P1', name: 'Thomas', deathDate: DateTime(2010)),
      ];
      final lifeEvents = [
        LifeEvent(
          id: 'e1',
          personId: 'P1',
          title: 'Graduation',
          date: DateTime(1955, 6, 1),
          place: 'Oxford, England',
        ),
      ];
      final path = '${tempDir.path}/out_grad.ged';
      await parser.export(persons, [], path,
          includeLivingData: true, lifeEvents: lifeEvents);
      final content = await File(path).readAsString();
      expect(content, contains('1 GRAD'));
      expect(content, contains('2 PLAC Oxford, England'));
    });

    test('EMIG export/import roundtrip preserves Emigration event', () async {
      final persons = [
        Person(id: 'P1', name: 'Anna', deathDate: DateTime(1980)),
      ];
      final lifeEvents = [
        LifeEvent(
          id: 'e1',
          personId: 'P1',
          title: 'Emigration',
          date: DateTime(1912, 3, 15),
          place: 'Hamburg, Germany',
        ),
      ];
      final path = '${tempDir.path}/roundtrip_emig.ged';
      await parser.export(persons, [], path,
          includeLivingData: true, lifeEvents: lifeEvents);
      final result = await parser.parse(path);
      expect(result.lifeEvents, hasLength(1));
      expect(result.lifeEvents.first.title, 'Emigration');
      expect(result.lifeEvents.first.place, 'Hamburg, Germany');
    });
  });

  group('GEDCOMParser — WikiTree & Find A Grave external IDs', () {
    test('_WIKITREEID tag parses to wikitreeId', () async {
      final path = await writeGedcom('''
0 HEAD
1 GEDC
2 VERS 5.5.1
0 @I1@ INDI
1 NAME Winston /Churchill/
1 _WIKITREEID Churchill-4
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.persons, hasLength(1));
      expect(result.persons.first.wikitreeId, 'Churchill-4');
    });

    test('_WT_USER tag also parses to wikitreeId', () async {
      final path = await writeGedcom('''
0 HEAD
1 GEDC
2 VERS 5.5.1
0 @I1@ INDI
1 NAME Ada /Lovelace/
1 _WT_USER Lovelace-1
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.persons.first.wikitreeId, 'Lovelace-1');
    });

    test('_FINDAGRAVEID tag parses to findAGraveId', () async {
      final path = await writeGedcom('''
0 HEAD
1 GEDC
2 VERS 5.5.1
0 @I1@ INDI
1 NAME Jane /Smith/
1 _FINDAGRAVEID 1836
0 TRLR
''');
      final result = await parser.parse(path);
      expect(result.persons, hasLength(1));
      expect(result.persons.first.findAGraveId, '1836');
    });

    test('export writes _WIKITREEID for person with wikitreeId', () async {
      final persons = [
        Person(
          id: 'P1',
          name: 'Winston Churchill',
          deathDate: DateTime(1965),
          wikitreeId: 'Churchill-4',
        ),
      ];
      final path = '${tempDir.path}/wikitree_export.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('1 _WIKITREEID Churchill-4'));
    });

    test('export writes _FINDAGRAVEID for person with findAGraveId', () async {
      final persons = [
        Person(
          id: 'P1',
          name: 'Jane Smith',
          deathDate: DateTime(1901),
          findAGraveId: '1836',
        ),
      ];
      final path = '${tempDir.path}/findagrave_export.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, contains('1 _FINDAGRAVEID 1836'));
    });

    test('export/import roundtrip preserves wikitreeId and findAGraveId',
        () async {
      final persons = [
        Person(
          id: 'P1',
          name: 'Marie Curie',
          deathDate: DateTime(1934, 7, 4),
          wikitreeId: 'Curie-7',
          findAGraveId: '5555',
        ),
      ];
      final path = '${tempDir.path}/roundtrip_ids.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final result = await parser.parse(path);
      expect(result.persons, hasLength(1));
      expect(result.persons.first.wikitreeId, 'Curie-7');
      expect(result.persons.first.findAGraveId, '5555');
    });

    test('person without wikitreeId does not emit _WIKITREEID tag', () async {
      final persons = [
        Person(id: 'P1', name: 'No ID', deathDate: DateTime(1900)),
      ];
      final path = '${tempDir.path}/no_ids.ged';
      await parser.export(persons, [], path, includeLivingData: true);
      final content = await File(path).readAsString();
      expect(content, isNot(contains('_WIKITREEID')));
      expect(content, isNot(contains('_FINDAGRAVEID')));
    });
  });
}
