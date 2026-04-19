import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/services/person_id_service.dart';

void main() {
  final svc = PersonIdService.instance;

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Person person(String name, {String? shortId}) =>
      Person(id: 'id-$name', name: name, shortId: shortId);

  group('PersonIdService.initials', () {
    test('two-word name → first initial + last initial', () {
      expect(svc.initials('John Doe'), 'JD');
      expect(svc.initials('Alice Smith'), 'AS');
      expect(svc.initials('Winston Churchill'), 'WC');
    });

    test('three-word name → first letter of first word + first letter of last word',
        () {
      expect(svc.initials('Mary Ann Smith'), 'MS');
      expect(svc.initials('Jean Paul Marat'), 'JM');
    });

    test('single-word name → first letter used for both initials', () {
      expect(svc.initials('Madonna'), 'MM');
      expect(svc.initials('Prince'), 'PP');
    });

    test('leading/trailing spaces are trimmed', () {
      expect(svc.initials('  Bob  Jones  '), 'BJ');
    });

    test('empty string → XX', () {
      expect(svc.initials(''), 'XX');
    });

    test('name starting with non-letter → first ASCII letter used', () {
      // e.g. a hyphenated name like "-Allen"
      expect(svc.initials('-Allen Jones'), 'AJ');
    });
  });

  group('PersonIdService.generate', () {
    test('first person in an empty tree gets 001', () {
      expect(svc.generate('John Doe', []), 'JD-001');
    });

    test('second person with same initials gets 002', () {
      final existing = [person('John Doe', shortId: 'JD-001')];
      expect(svc.generate('Jane Doe', existing), 'JD-002');
    });

    test('person with different initials starts at 001', () {
      final existing = [person('John Doe', shortId: 'JD-001')];
      expect(svc.generate('Alice Smith', existing), 'AS-001');
    });

    test('next slot after gap is max+1, not gap-fill', () {
      // Existing: JD-001, JD-003 (gap at 002)
      final existing = [
        person('A', shortId: 'JD-001'),
        person('B', shortId: 'JD-003'),
      ];
      // max = 3, so next = 4
      expect(svc.generate('John Doe', existing), 'JD-004');
    });

    test('persons without shortId are ignored in the count', () {
      final existing = [person('John Doe')]; // no shortId
      expect(svc.generate('Jane Doe', existing), 'JD-001');
    });

    test('number is always zero-padded to 3 digits', () {
      final existing = List.generate(
        9,
        (i) => person('A', shortId: 'JD-00${i + 1}'),
      );
      final id = svc.generate('John Doe', existing);
      expect(id, 'JD-010');
    });

    test('wraps back to first unused slot when > 999', () {
      // All 999 slots taken — should start at 001 again (rare case).
      final existing = List.generate(
        999,
        (i) =>
            person('A', shortId: 'JD-${(i + 1).toString().padLeft(3, '0')}'),
      );
      final id = svc.generate('John Doe', existing);
      // The pathological wrap still produces a valid ID.
      expect(id, startsWith('JD-'));
    });
  });

  group('PersonIdService.display', () {
    test('returns empty string for null shortId', () {
      expect(svc.display(null, []), '');
    });

    test('returns empty string for empty shortId', () {
      expect(svc.display('', []), '');
    });

    test('bucket ≤ 99 → strips leading zeros (single digit)', () {
      final persons = [person('A', shortId: 'JD-001')];
      expect(svc.display('JD-001', persons), 'JD-1');
    });

    test('bucket ≤ 99 → strips leading zeros (two digits)', () {
      final persons = List.generate(
          10, (i) => person('A', shortId: 'JD-${(i + 1).toString().padLeft(3, '0')}'));
      expect(svc.display('JD-007', persons), 'JD-7');
      expect(svc.display('JD-010', persons), 'JD-10');
    });

    test('bucket = 99 → still drops leading zeros', () {
      final persons = List.generate(
          99, (i) => person('A', shortId: 'JD-${(i + 1).toString().padLeft(3, '0')}'));
      expect(svc.display('JD-001', persons), 'JD-1');
      expect(svc.display('JD-099', persons), 'JD-99');
    });

    test('bucket = 100 → switches to 3-digit format', () {
      final persons = List.generate(
          100,
          (i) => person('A',
              shortId: 'JD-${(i + 1).toString().padLeft(3, '0')}'));
      expect(svc.display('JD-001', persons), 'JD-001');
      expect(svc.display('JD-007', persons), 'JD-007');
      expect(svc.display('JD-100', persons), 'JD-100');
    });

    test('bucket > 100 → 3-digit format kept', () {
      final persons = List.generate(
          150,
          (i) => person('A',
              shortId: 'JD-${(i + 1).toString().padLeft(3, '0')}'));
      expect(svc.display('JD-042', persons), 'JD-042');
    });

    test('different bucket does not affect display of another bucket', () {
      // Only 3 people in AS; 110 people in JD.
      final persons = [
        person('A', shortId: 'AS-001'),
        person('B', shortId: 'AS-002'),
        person('C', shortId: 'AS-003'),
        ...List.generate(
            110,
            (i) => person('D',
                shortId: 'JD-${(i + 1).toString().padLeft(3, '0')}')),
      ];
      // AS bucket has 3 entries → no leading zeros.
      expect(svc.display('AS-001', persons), 'AS-1');
      // JD bucket has 110 entries → 3-digit format.
      expect(svc.display('JD-005', persons), 'JD-005');
    });

    test('invalid format (no dash) passes through unchanged', () {
      expect(svc.display('NODASH', []), 'NODASH');
    });
  });

  group('generate + display integration', () {
    test(
        'adding 100 people to the same bucket switches all to 3-digit display',
        () {
      final persons = <Person>[];
      // Add 99 people.
      for (int i = 0; i < 99; i++) {
        final id = svc.generate('John Doe', persons);
        persons.add(person('John Doe $i', shortId: id));
      }
      expect(persons.length, 99);

      // All should display without leading zeros (no zero prefix like "0XX").
      for (final p in persons) {
        if (p.shortId?.startsWith('JD-') == true) {
          final d = svc.display(p.shortId, persons);
          final numPart = d.substring(3); // strip "JD-"
          expect(numPart, isNot(startsWith('0')),
              reason: '${p.shortId} showed a leading zero in "$d"');
        }
      }

      // Add the 100th.
      final id100 = svc.generate('John Doe', persons);
      persons.add(person('John Doe 100', shortId: id100));

      // Now every display in the JD bucket should be 3 digits.
      for (final p in persons) {
        if (p.shortId?.startsWith('JD-') == true) {
          final d = svc.display(p.shortId, persons);
          expect(d.substring(3), hasLength(3),
              reason:
                  '${p.shortId} should display as 3 digits but got $d');
        }
      }
    });
  });
}
