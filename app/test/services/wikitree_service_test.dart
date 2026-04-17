import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetviona_app/models/person.dart';
import 'package:vetviona_app/services/wikitree_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

WikiTreeService _serviceWith(String body, {int statusCode = 200}) {
  final mock = MockClient((_) async => http.Response(body, statusCode));
  return WikiTreeService.withClient(mock);
}

WikiTreeProfile _profile({
  int id = 1,
  String wikiTreeId = 'Smith-1',
  String? firstName,
  String? middleName,
  String? lastName,
  DateTime? birthDate,
  String? birthPlace,
  DateTime? deathDate,
  String? deathPlace,
  String? gender,
  String? occupation,
  String? bio,
  List<String> parentWikiTreeIds = const [],
  List<String> childWikiTreeIds = const [],
  List<String> spouseWikiTreeIds = const [],
}) =>
    WikiTreeProfile(
      id: id,
      wikiTreeId: wikiTreeId,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      birthDate: birthDate,
      birthPlace: birthPlace,
      deathDate: deathDate,
      deathPlace: deathPlace,
      gender: gender,
      occupation: occupation,
      bio: bio,
      parentWikiTreeIds: parentWikiTreeIds,
      childWikiTreeIds: childWikiTreeIds,
      spouseWikiTreeIds: spouseWikiTreeIds,
    );

Person _person({
  String id = 'p1',
  String name = '',
  String? gender,
  DateTime? birthDate,
  String? birthPlace,
  DateTime? deathDate,
  String? deathPlace,
  String? occupation,
  String? notes,
  String? wikitreeId,
}) =>
    Person(
      id: id,
      name: name,
      gender: gender,
      birthDate: birthDate,
      birthPlace: birthPlace,
      deathDate: deathDate,
      deathPlace: deathPlace,
      occupation: occupation,
      notes: notes,
      wikitreeId: wikitreeId,
      parentIds: [],
      childIds: [],
      parentRelTypes: {},
      photoPaths: [],
      sourceIds: [],
      isPrivate: false,
      syncMedical: false,
      preferredSourceIds: {},
      aliases: [],
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── WikiTreeProfile.fromJson ───────────────────────────────────────────────

  group('WikiTreeProfile.fromJson', () {
    test('parses all standard fields', () {
      final json = {
        'Id': 42,
        'Name': 'Churchill-4',
        'FirstName': 'Winston',
        'MiddleName': 'Leonard',
        'LastName': 'Churchill',
        'BirthDate': '1874-11-30',
        'BirthLocation': 'Blenheim Palace, Oxfordshire',
        'DeathDate': '1965-01-24',
        'DeathLocation': 'London, England',
        'Gender': 'Male',
        'Occupation': 'Statesman',
        'Bio': 'Famous Prime Minister.',
        'Father': null,
        'Mother': null,
        'Children': null,
        'Spouses': null,
      };
      final p = WikiTreeProfile.fromJson(json);
      expect(p.id, 42);
      expect(p.wikiTreeId, 'Churchill-4');
      expect(p.firstName, 'Winston');
      expect(p.middleName, 'Leonard');
      expect(p.lastName, 'Churchill');
      expect(p.birthDate, DateTime(1874, 11, 30));
      expect(p.birthPlace, 'Blenheim Palace, Oxfordshire');
      expect(p.deathDate, DateTime(1965, 1, 24));
      expect(p.deathPlace, 'London, England');
      expect(p.gender, 'Male');
      expect(p.occupation, 'Statesman');
      expect(p.bio, 'Famous Prime Minister.');
    });

    test('parses Father/Mother as Maps with Name keys', () {
      final json = {
        'Id': 1,
        'Name': 'Smith-1',
        'Father': {'Id': 10, 'Name': 'Smith-10'},
        'Mother': {'Id': 20, 'Name': 'Jones-5'},
      };
      final p = WikiTreeProfile.fromJson(json);
      expect(p.parentWikiTreeIds, ['Smith-10', 'Jones-5']);
    });

    test('parses Children as List of Maps', () {
      final json = {
        'Id': 1,
        'Name': 'Smith-1',
        'Children': [
          {'Id': 2, 'Name': 'Smith-2'},
          {'Id': 3, 'Name': 'Smith-3'},
        ],
      };
      final p = WikiTreeProfile.fromJson(json);
      expect(p.childWikiTreeIds, ['Smith-2', 'Smith-3']);
    });

    test('parses Children as Map of Maps (object variant)', () {
      final json = {
        'Id': 1,
        'Name': 'Smith-1',
        'Children': {
          '2': {'Id': 2, 'Name': 'Smith-2'},
          '3': {'Id': 3, 'Name': 'Smith-3'},
        },
      };
      final p = WikiTreeProfile.fromJson(json);
      expect(p.childWikiTreeIds, containsAll(['Smith-2', 'Smith-3']));
    });

    test('parses Spouses as List', () {
      final json = {
        'Id': 1,
        'Name': 'Smith-1',
        'Spouses': [
          {'Id': 5, 'Name': 'Brown-5'},
        ],
      };
      final p = WikiTreeProfile.fromJson(json);
      expect(p.spouseWikiTreeIds, ['Brown-5']);
    });

    test('parses Spouses as Map', () {
      final json = {
        'Id': 1,
        'Name': 'Smith-1',
        'Spouses': {
          '5': {'Id': 5, 'Name': 'Brown-5'},
        },
      };
      final p = WikiTreeProfile.fromJson(json);
      expect(p.spouseWikiTreeIds, ['Brown-5']);
    });

    test('uses defaults for missing/null fields', () {
      final json = <String, dynamic>{'Id': 0, 'Name': ''};
      final p = WikiTreeProfile.fromJson(json);
      expect(p.firstName, isNull);
      expect(p.middleName, isNull);
      expect(p.lastName, isNull);
      expect(p.birthDate, isNull);
      expect(p.birthPlace, isNull);
      expect(p.deathDate, isNull);
      expect(p.deathPlace, isNull);
      expect(p.gender, isNull);
      expect(p.occupation, isNull);
      expect(p.bio, isNull);
      expect(p.parentWikiTreeIds, isEmpty);
      expect(p.childWikiTreeIds, isEmpty);
      expect(p.spouseWikiTreeIds, isEmpty);
    });
  });

  // ── WikiTreeProfile.displayName ───────────────────────────────────────────

  group('WikiTreeProfile.displayName', () {
    test('joins all name parts', () {
      final p = _profile(
          wikiTreeId: 'Smith-1',
          firstName: 'John',
          middleName: 'Alan',
          lastName: 'Smith');
      expect(p.displayName, 'John Alan Smith');
    });

    test('uses only lastName when no first/middle', () {
      final p = _profile(wikiTreeId: 'Smith-1', lastName: 'Smith');
      expect(p.displayName, 'Smith');
    });

    test('falls back to wikiTreeId when no name parts', () {
      final p = _profile(wikiTreeId: 'Unknown-1');
      expect(p.displayName, 'Unknown-1');
    });
  });

  // ── WikiTreeProfile._parseWikiTreeDate ────────────────────────────────────

  group('WikiTreeProfile._parseWikiTreeDate (via fromJson)', () {
    DateTime? parse(String? raw) {
      final json = <String, dynamic>{'Id': 0, 'Name': 'X', 'BirthDate': raw};
      return WikiTreeProfile.fromJson(json).birthDate;
    }

    test("'0000-00-00' returns null", () => expect(parse('0000-00-00'), isNull));

    test("'1920-00-00' returns year-only date with month/day 1", () {
      final d = parse('1920-00-00');
      expect(d?.year, 1920);
      expect(d?.month, 1);
      expect(d?.day, 1);
    });

    test("'1874-11-30' returns full date", () {
      expect(parse('1874-11-30'), DateTime(1874, 11, 30));
    });

    test('null returns null', () => expect(parse(null), isNull));
    test("empty string returns null", () => expect(parse(''), isNull));
  });

  // ── WikiTreeService.searchPerson ──────────────────────────────────────────

  group('WikiTreeService.searchPerson', () {
    test('empty query returns [] without HTTP call', () async {
      var called = false;
      final mock = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      final svc = WikiTreeService.withClient(mock);
      final result = await svc.searchPerson('');
      expect(result, isEmpty);
      expect(called, isFalse);
    });

    test('HTTP 500 returns []', () async {
      final svc = _serviceWith('error', statusCode: 500);
      expect(await svc.searchPerson('Smith'), isEmpty);
    });

    test('valid JSON with matches parses profiles', () async {
      final body = jsonEncode({
        'response': {
          'matches': [
            {
              'person': {
                'Id': 1,
                'Name': 'Smith-1',
                'FirstName': 'John',
                'LastName': 'Smith',
              },
            },
            {
              'person': {
                'Id': 2,
                'Name': 'Smith-2',
                'FirstName': 'Jane',
                'LastName': 'Smith',
              },
            },
          ],
        },
      });
      final svc = _serviceWith(body);
      final result = await svc.searchPerson('Smith');
      expect(result.length, 2);
      expect(result[0].wikiTreeId, 'Smith-1');
      expect(result[1].firstName, 'Jane');
    });

    test('response with no matches key returns []', () async {
      final svc = _serviceWith(jsonEncode({'response': {}}));
      expect(await svc.searchPerson('Smith'), isEmpty);
    });
  });

  // ── WikiTreeService.getProfile ────────────────────────────────────────────

  group('WikiTreeService.getProfile', () {
    test('HTTP 404 returns null', () async {
      final svc = _serviceWith('not found', statusCode: 404);
      expect(await svc.getProfile('Smith-1'), isNull);
    });

    test('array-wrapped response parses profile', () async {
      final body = jsonEncode([
        {
          'Id': 5,
          'Name': 'Jones-5',
          'FirstName': 'Alan',
          'LastName': 'Jones',
        }
      ]);
      final svc = _serviceWith(body);
      final p = await svc.getProfile('Jones-5');
      expect(p?.wikiTreeId, 'Jones-5');
      expect(p?.firstName, 'Alan');
    });

    test('map response with "0" key parses profile', () async {
      final body = jsonEncode({
        '0': {
          'Id': 6,
          'Name': 'Brown-6',
          'FirstName': 'Bob',
          'LastName': 'Brown',
        },
      });
      final svc = _serviceWith(body);
      final p = await svc.getProfile('Brown-6');
      expect(p?.wikiTreeId, 'Brown-6');
    });

    test('map response with "profile" key parses profile', () async {
      final body = jsonEncode({
        'profile': {
          'Id': 7,
          'Name': 'Green-7',
          'FirstName': 'Carol',
          'LastName': 'Green',
        },
      });
      final svc = _serviceWith(body);
      final p = await svc.getProfile('Green-7');
      expect(p?.wikiTreeId, 'Green-7');
    });
  });

  // ── WikiTreeService.getAncestors ──────────────────────────────────────────

  group('WikiTreeService.getAncestors', () {
    test('HTTP 500 returns []', () async {
      final svc = _serviceWith('error', statusCode: 500);
      expect(await svc.getAncestors('Smith-1'), isEmpty);
    });

    test('nested JSON containing profiles traverses and finds them', () async {
      final body = jsonEncode({
        'ancestors': {
          '1': {
            'Id': 1,
            'Name': 'Smith-1',
            'FirstName': 'John',
            'LastName': 'Smith',
          },
          '2': {
            'Id': 2,
            'Name': 'Smith-2',
            'FirstName': 'James',
            'LastName': 'Smith',
          },
        },
      });
      final svc = _serviceWith(body);
      final result = await svc.getAncestors('Smith-1');
      expect(result.length, 2);
      final ids = result.map((p) => p.wikiTreeId).toList();
      expect(ids, containsAll(['Smith-1', 'Smith-2']));
    });
  });

  // ── WikiTreeService.exportGedcom ──────────────────────────────────────────

  group('WikiTreeService.exportGedcom', () {
    test('when not logged in returns null without HTTP call', () async {
      var called = false;
      final mock = MockClient((_) async {
        called = true;
        return http.Response('0 HEAD\n', 200);
      });
      final svc = WikiTreeService.withClient(mock);
      // Not logged in (isLoggedIn == false by default)
      final result = await svc.exportGedcom('Smith-1');
      expect(result, isNull);
      expect(called, isFalse);
    });
  });

  // ── WikiTreeService._decodeBody (via getProfile invalid JSON) ─────────────

  group('WikiTreeService._decodeBody', () {
    test('valid JSON body parses correctly (getProfile returns profile)', () async {
      final body = jsonEncode([
        {'Id': 1, 'Name': 'X-1'},
      ]);
      final svc = _serviceWith(body);
      final p = await svc.getProfile('X-1');
      expect(p, isNotNull);
    });

    test('invalid JSON body returns empty map (getProfile returns null)', () async {
      final svc = _serviceWith('not valid json {{');
      final p = await svc.getProfile('X-1');
      expect(p, isNull);
    });
  });

  // ── WikiTreeService.profileToSource ──────────────────────────────────────

  group('WikiTreeService.profileToSource', () {
    test('sets correct title, type, url, confidence', () {
      final svc = WikiTreeService.instance;
      final profile = _profile(
          wikiTreeId: 'Churchill-4',
          firstName: 'Winston',
          lastName: 'Churchill');
      final src = svc.profileToSource(profile, 'person-1');
      expect(src.title, contains('WikiTree profile'));
      expect(src.title, contains('Winston Churchill'));
      expect(src.type, 'Online Database');
      expect(src.url, 'https://www.wikitree.com/wiki/Churchill-4');
      expect(src.confidence, 'B');
    });

    test('citedFacts includes birth/death date/place when set', () {
      final svc = WikiTreeService.instance;
      final profile = _profile(
        wikiTreeId: 'Smith-1',
        birthDate: DateTime(1900, 1, 1),
        birthPlace: 'London',
        deathDate: DateTime(1970, 6, 15),
        deathPlace: 'Paris',
      );
      final src = svc.profileToSource(profile, 'person-1');
      expect(src.citedFacts, contains('Birth Date'));
      expect(src.citedFacts, contains('Birth Place'));
      expect(src.citedFacts, contains('Death Date'));
      expect(src.citedFacts, contains('Death Place'));
    });

    test('citedFacts is empty when no dates/places', () {
      final svc = WikiTreeService.instance;
      final profile = _profile(wikiTreeId: 'Smith-1');
      final src = svc.profileToSource(profile, 'person-1');
      expect(src.citedFacts, isEmpty);
    });
  });

  // ── WikiTreeService.profileToPerson ──────────────────────────────────────

  group('WikiTreeService.profileToPerson', () {
    late WikiTreeService svc;
    setUp(() => svc = WikiTreeService.instance);

    test('with no existing person creates new with wikitreeId', () {
      final profile = _profile(
        wikiTreeId: 'Smith-1',
        firstName: 'John',
        lastName: 'Smith',
        gender: 'Male',
        birthDate: DateTime(1900, 1, 1),
        birthPlace: 'London',
      );
      final person = svc.profileToPerson(profile);
      expect(person.wikitreeId, 'Smith-1');
      expect(person.name, 'John Smith');
      expect(person.gender, 'Male');
      expect(person.birthDate, DateTime(1900, 1, 1));
      expect(person.birthPlace, 'London');
    });

    test('with existing person preserves existing fields', () {
      final profile = _profile(
        wikiTreeId: 'Smith-1',
        firstName: 'John',
        lastName: 'Smith',
        birthPlace: 'London',
        deathPlace: 'Paris',
      );
      final existing = _person(
        id: 'existing-id',
        name: 'Existing Name',
        birthPlace: 'Manchester',
      );
      final person = svc.profileToPerson(profile, existing: existing);
      expect(person.id, 'existing-id');
      expect(person.name, 'Existing Name');
      expect(person.birthPlace, 'Manchester'); // preserved
      expect(person.deathPlace, 'Paris'); // taken from profile (was null)
    });

    test('with forceOverwrite=true overwrites existing fields', () {
      final profile = _profile(
        wikiTreeId: 'Smith-1',
        firstName: 'John',
        lastName: 'Smith',
        birthPlace: 'London',
        gender: 'Male',
      );
      final existing = _person(
        id: 'existing-id',
        name: 'Old Name',
        birthPlace: 'Manchester',
        gender: 'Female',
      );
      final person = svc.profileToPerson(
        profile,
        existing: existing,
        forceOverwrite: true,
      );
      expect(person.id, 'existing-id');
      expect(person.name, 'John Smith');
      expect(person.birthPlace, 'London');
      expect(person.gender, 'Male');
    });
  });

  // ── _mapGender (tested indirectly via profileToPerson) ────────────────────

  group('_mapGender (via profileToPerson)', () {
    late WikiTreeService svc;
    setUp(() => svc = WikiTreeService.instance);

    test("'Male' → 'Male'", () {
      final p = svc.profileToPerson(_profile(wikiTreeId: 'X-1', gender: 'Male'));
      expect(p.gender, 'Male');
    });

    test("'male' → 'Male'", () {
      final p = svc.profileToPerson(_profile(wikiTreeId: 'X-1', gender: 'male'));
      expect(p.gender, 'Male');
    });

    test("'Female' → 'Female'", () {
      final p = svc.profileToPerson(_profile(wikiTreeId: 'X-1', gender: 'Female'));
      expect(p.gender, 'Female');
    });

    test("'female' → 'Female'", () {
      final p = svc.profileToPerson(_profile(wikiTreeId: 'X-1', gender: 'female'));
      expect(p.gender, 'Female');
    });

    test("'other' → null", () {
      final p = svc.profileToPerson(_profile(wikiTreeId: 'X-1', gender: 'other'));
      expect(p.gender, isNull);
    });

    test('null → null', () {
      final p = svc.profileToPerson(_profile(wikiTreeId: 'X-1', gender: null));
      expect(p.gender, isNull);
    });
  });

  // ── _stripWikiMarkup (tested indirectly via profileToPerson.notes) ────────

  group('_stripWikiMarkup (via profileToPerson.notes)', () {
    late WikiTreeService svc;
    setUp(() => svc = WikiTreeService.instance);

    String? stripped(String? bio) =>
        svc.profileToPerson(_profile(wikiTreeId: 'X-1', bio: bio)).notes;

    test("strips [[link|text]] → text", () {
      expect(stripped('See [[Churchill-4|Winston Churchill]].'),
          contains('Winston Churchill'));
      expect(stripped('See [[Churchill-4|Winston Churchill]].'),
          isNot(contains('[[')));
    });

    test("strips '''bold''' → bold", () {
      expect(stripped("He was '''bold'''."), contains('bold'));
      expect(stripped("He was '''bold'''."), isNot(contains("'''")));
    });

    test("strips ''italic'' → italic", () {
      expect(stripped("He was ''great''."), contains('great'));
      expect(stripped("He was ''great''."), isNot(contains("''")));
    });

    test('truncates long bio to 2000 chars (plus ellipsis)', () {
      final longBio = 'a' * 3000;
      final result = stripped(longBio);
      expect(result!.length, lessThanOrEqualTo(2001)); // 2000 chars + '…'
    });

    test('null → null', () => expect(stripped(null), isNull));
    test('empty → null', () => expect(stripped(''), isNull));
    test('whitespace only → null', () => expect(stripped('   '), isNull));
  });
}
