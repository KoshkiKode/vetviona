import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/gen_date.dart';

void _expectDate(
  GenDate? date,
  GenDateQualifier qualifier,
  int year, {
  int? month,
  int? day,
}) {
  expect(date, isNotNull);
  expect(date!.qualifier, qualifier);
  expect(date.start?.year, year);
  expect(date.start?.month, month);
  expect(date.start?.day, day);
}

void main() {
  group('GenDate.parse recognises GEDCOM date phrases', () {
    test('plain years, months and days', () {
      _expectDate(GenDate.parse('1900'), GenDateQualifier.exact, 1900);
      _expectDate(GenDate.parse('JAN 1900'), GenDateQualifier.exact, 1900, month: 1);
      _expectDate(GenDate.parse('12 JAN 1900'), GenDateQualifier.exact, 1900,
          month: 1, day: 12);
      _expectDate(GenDate.parse('12 sept 1900'), GenDateQualifier.exact, 1900,
          month: 9, day: 12);
    });

    test('qualifiers', () {
      _expectDate(GenDate.parse('ABT 1850'), GenDateQualifier.about, 1850);
      _expectDate(GenDate.parse('c. 1850'), GenDateQualifier.about, 1850);
      _expectDate(GenDate.parse('circa 1850'), GenDateQualifier.about, 1850);
      _expectDate(GenDate.parse('CAL 1850'), GenDateQualifier.calculated, 1850);
      _expectDate(GenDate.parse('EST 1850'), GenDateQualifier.estimated, 1850);
      _expectDate(GenDate.parse('BEF 12 MAR 1800'), GenDateQualifier.before, 1800,
          month: 3, day: 12);
      _expectDate(GenDate.parse('AFT 1800'), GenDateQualifier.after, 1800);
      _expectDate(GenDate.parse('FROM 1890'), GenDateQualifier.from, 1890);
      _expectDate(GenDate.parse('TO 1900'), GenDateQualifier.to, 1900);
    });

    test('ranges keep both bounds', () {
      final between = GenDate.parse('BET 1890 AND 1900')!;
      expect(between.qualifier, GenDateQualifier.between);
      expect(between.start!.year, 1890);
      expect(between.end!.year, 1900);

      final fromTo = GenDate.parse('FROM 1890 TO 1900')!;
      expect(fromTo.qualifier, GenDateQualifier.fromTo);
      expect(fromTo.end!.year, 1900);

      final dash = GenDate.parse('1850-1860')!;
      expect(dash.qualifier, GenDateQualifier.between);
      expect(dash.end!.year, 1860);
    });

    test('B.C. dates are negative years with no year zero', () {
      expect(GenDate.parse('1000 B.C.')!.start!.year, -1000);
      expect(GenDate.parse('1 BC')!.start!.year, -1);
      expect(GenDate.parse('0 AD'), isNotNull);
      expect(GenDate.parse('0 AD')!.isPhraseOnly, isTrue);
    });

    test('calendar escapes set the calendar', () {
      final julian = GenDate.parse('@#DJULIAN@ 12 JAN 1700')!;
      expect(julian.calendar, GenCalendar.julian);
      expect(julian.start!.day, 12);
      expect(GenDate.parse('ABT @#DJULIAN@ 1700')!.calendar, GenCalendar.julian);
    });

    test('interpreted phrases keep their text', () {
      final date = GenDate.parse('INT 1850 (between harvests)')!;
      expect(date.qualifier, GenDateQualifier.interpreted);
      expect(date.start!.year, 1850);
      expect(date.phrase, 'between harvests');
    });
  });

  group('GenDate.parse never drops unrecognised text', () {
    test('unknown wording is kept as a phrase', () {
      final date = GenDate.parse('sometime in the 1800s')!;
      expect(date.isPhraseOnly, isTrue);
      expect(date.toGedcom(), 'sometime in the 1800s');
      expect(date.format(), 'sometime in the 1800s');
    });

    test('impossible days are kept as phrases', () {
      expect(GenDate.parse('31 FEB 1900')!.isPhraseOnly, isTrue);
      expect(GenDate.parse('29 FEB 1900')!.isPhraseOnly, isTrue);
      expect(GenDate.parse('29 FEB 2000')!.isPhraseOnly, isFalse);
    });

    test('dual-dated years stay as phrases rather than guessing', () {
      expect(GenDate.parse('1750/51')!.isPhraseOnly, isTrue);
    });

    test('blank input has no date', () {
      expect(GenDate.parse(''), isNull);
      expect(GenDate.parse('   '), isNull);
    });
  });

  group('GenDate.toGedcom round-trips canonical forms', () {
    const canonical = [
      '1900',
      'JAN 1900',
      '12 JAN 1900',
      'ABT 1850',
      'CAL 1850',
      'EST 1850',
      'BEF 12 MAR 1800',
      'AFT 1800',
      'BET 1890 AND 1900',
      'FROM 1890 TO 1900',
      'FROM 1890',
      'TO 1900',
      'INT 1850 (between harvests)',
      '@#DJULIAN@ 12 JAN 1700',
      '1000 B.C.',
    ];
    for (final text in canonical) {
      test(text, () => expect(GenDate.parse(text)!.toGedcom(), text));
    }
  });

  group('GenDate.format is readable English', () {
    test('examples', () {
      expect(GenDate.parse('ABT 1850')!.format(), 'about 1850');
      expect(GenDate.parse('BET 1890 AND 1900')!.format(), 'between 1890 and 1900');
      expect(GenDate.parse('FROM 1890 TO 1900')!.format(), 'from 1890 to 1900');
      expect(GenDate.parse('BEF 12 MAR 1800')!.format(), 'before 12 Mar 1800');
      expect(GenDate.parse('1000 B.C.')!.format(), '1000 BC');
      expect(GenDate.parse('@#DJULIAN@ 12 JAN 1700')!.format(),
          'Julian 12 Jan 1700');
    });
  });

  group('ordering and overlap', () {
    test('sorts earliest first and phrases last', () {
      final dates = [
        GenDate.parse('sometime')!,
        GenDate.parse('AFT 1950')!,
        GenDate.parse('1900')!,
        GenDate.parse('ABT 1850')!,
        GenDate.parse('BEF 1800')!,
      ]..sort();
      expect(dates.map((d) => d.format()).toList(), [
        'before 1800',
        'about 1850',
        '1900',
        'after 1950',
        'sometime',
      ]);
    });

    test('a year overlaps the days inside it, not the neighbouring year', () {
      final year = GenDate.parse('1900')!;
      expect(year.overlaps(GenDate.parse('12 JAN 1900')!), isTrue);
      expect(year.overlaps(GenDate.parse('1901')!), isFalse);
    });

    test('unknown dates never overlap anything', () {
      expect(GenDate.parse('sometime')!.overlaps(GenDate.parse('1900')!), isFalse);
    });

    test('GenPoint key bounds cover the whole unspecified span', () {
      expect(const GenPoint(1900).earliestKey, 19000101);
      expect(const GenPoint(1900).latestKey, 19001231);
      expect(const GenPoint(2000, month: 2).latestKey, 20000229);
    });
  });

  group('GenDate.ageBetween', () {
    test('exact years give an exact age', () {
      final age = GenDate.ageBetween(
        GenDate.parse('1850')!,
        GenDate.parse('1900')!,
      );
      expect(age, (min: 50, max: 50));
    });

    test('a range of birth years widens the age range', () {
      final age = GenDate.ageBetween(
        GenDate.parse('BET 1850 AND 1855')!,
        GenDate.parse('1900')!,
      );
      expect(age, (min: 45, max: 50));
    });

    test('unbounded or unknown dates give no age', () {
      expect(GenDate.ageBetween(GenDate.parse('AFT 1850')!, GenDate.parse('1900')!),
          isNull);
      expect(GenDate.ageBetween(GenDate.parse('sometime')!, GenDate.parse('1900')!),
          isNull);
    });
  });
}
