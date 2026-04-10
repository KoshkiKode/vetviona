import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/partnership.dart';
import 'package:vetviona_app/models/person.dart';
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
  });
}
