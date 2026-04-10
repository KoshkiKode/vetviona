import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/models/place.dart';

void main() {
  group('Place', () {
    group('isValidFor', () {
      test('no bounds: always valid', () {
        const p = Place(
          continent: 'Europe',
          name: 'London',
          modernCountry: 'United Kingdom',
          historicalContext: '',
        );
        expect(p.isValidFor(null), true);
        expect(p.isValidFor(DateTime(1000)), true);
        expect(p.isValidFor(DateTime(2100)), true);
      });

      test('validFrom: date before boundary is invalid', () {
        const p = Place(
          continent: 'Europe',
          name: 'Berlin',
          modernCountry: 'Germany',
          historicalContext: '',
          validFrom: '1990-01-01',
        );
        expect(p.isValidFor(DateTime(1989, 12, 31)), false);
        expect(p.isValidFor(DateTime(1990, 1, 1)), true);
        expect(p.isValidFor(DateTime(2000)), true);
      });

      test('validTo: date after boundary is invalid', () {
        const p = Place(
          continent: 'Europe',
          name: 'Constantinople',
          modernCountry: 'Turkey',
          historicalContext: '',
          validTo: '1453-05-29',
        );
        expect(p.isValidFor(DateTime(1400)), true);
        expect(p.isValidFor(DateTime(1453, 5, 28)), true);
        expect(p.isValidFor(DateTime(1453, 5, 30)), false);
        expect(p.isValidFor(DateTime(2000)), false);
      });

      test('both bounds: inside range is valid', () {
        const p = Place(
          continent: 'Europe',
          name: 'Test',
          modernCountry: 'X',
          historicalContext: '',
          validFrom: '2000-01-01',
          validTo: '2020-12-31',
        );
        expect(p.isValidFor(DateTime(1999, 12, 31)), false);
        expect(p.isValidFor(DateTime(2010, 6, 15)), true);
        expect(p.isValidFor(DateTime(2021, 1, 1)), false);
      });

      test('null date with bounds: returns true', () {
        const p = Place(
          continent: 'Europe',
          name: 'Test',
          modernCountry: 'X',
          historicalContext: '',
          validFrom: '2000-01-01',
          validTo: '2010-01-01',
        );
        expect(p.isValidFor(null), true);
      });
    });

    group('matches', () {
      const paris = Place(
        continent: 'Europe',
        name: 'Paris',
        modernCountry: 'France',
        state: 'Île-de-France',
        nativeTribes: 'Parisii',
        historicalContext: 'Capital of France',
      );

      test('empty query always matches', () {
        expect(paris.matches(''), true);
      });

      test('matches city name (case-insensitive)', () {
        expect(paris.matches('paris'), true);
        expect(paris.matches('PARIS'), true);
        expect(paris.matches('Par'), true);
      });

      test('matches country (case-insensitive)', () {
        expect(paris.matches('france'), true);
        expect(paris.matches('FRANCE'), true);
      });

      test('matches continent', () {
        expect(paris.matches('europe'), true);
      });

      test('matches state', () {
        expect(paris.matches('île-de-france'), true);
      });

      test('no match for unrelated query', () {
        expect(paris.matches('Berlin'), false);
        expect(paris.matches('zzz'), false);
      });
    });

    group('relevanceFor', () {
      const paris = Place(
        continent: 'Europe',
        name: 'Paris',
        modernCountry: 'France',
        state: 'Île-de-France',
        historicalContext: '',
      );

      test('exact city name match → 0', () {
        expect(paris.relevanceFor('paris'), 0);
      });

      test('city name prefix → 1', () {
        expect(paris.relevanceFor('par'), 1);
      });

      test('country prefix → 2', () {
        expect(paris.relevanceFor('franc'), 2);
      });

      test('state prefix → 3', () {
        expect(paris.relevanceFor('île'), 3);
      });

      test('substring in name → 4', () {
        expect(paris.relevanceFor('aris'), 4);
      });

      test('no match → 5', () {
        expect(paris.relevanceFor('berlin'), 5);
      });

      test('empty query → 0', () {
        expect(paris.relevanceFor(''), 0);
      });
    });

    group('getFullName', () {
      test('name and country only', () {
        const p = Place(
          continent: 'Europe',
          name: 'London',
          modernCountry: 'United Kingdom',
          historicalContext: '',
        );
        expect(p.getFullName(null), 'London, United Kingdom');
      });

      test('includes county, subState, state, ssr when present', () {
        const p = Place(
          continent: 'Americas',
          name: 'Austin',
          modernCountry: 'United States',
          state: 'Texas',
          county: 'Travis County',
          subState: 'Central Texas',
          ssr: 'Region IV',
          historicalContext: '',
        );
        final name = p.getFullName(null);
        expect(name, contains('Austin'));
        expect(name, contains('Travis County'));
        expect(name, contains('Central Texas'));
        expect(name, contains('Texas'));
        expect(name, contains('Region IV'));
        expect(name, contains('United States'));
      });

      test('omits empty optional fields', () {
        const p = Place(
          continent: 'Asia',
          name: 'Tokyo',
          modernCountry: 'Japan',
          state: '',
          county: '',
          historicalContext: '',
        );
        final name = p.getFullName(null);
        // Empty state/county should not create stray commas
        expect(name.contains(', ,'), false);
        expect(name, 'Tokyo, Japan');
      });
    });

    group('getHistoricalInfo', () {
      const cusco = Place(
        continent: 'Americas',
        name: 'Cusco',
        modernCountry: 'Peru',
        historicalContext: 'Former Inca capital',
        colonizer: 'Spain',
        nativeTribes: 'Quechua people',
        romanizedNative: 'Quechua',
      );

      test('level 0: only historicalContext', () {
        final info = cusco.getHistoricalInfo(null, 0, 'Cusco');
        expect(info, 'Former Inca capital');
        expect(info, isNot(contains('Spain')));
        expect(info, isNot(contains('Quechua')));
      });

      test('level 1: adds colonizer info', () {
        final info = cusco.getHistoricalInfo(null, 1, 'Cusco');
        expect(info, contains('Former Inca capital'));
        expect(info, contains('Spain'));
        expect(info, isNot(contains('Quechua')));
      });

      test('level 2: adds both colonizer and native peoples', () {
        final info = cusco.getHistoricalInfo(null, 2, 'Cusco');
        expect(info, contains('Former Inca capital'));
        expect(info, contains('Spain'));
        expect(info, contains('Quechua'));
      });

      test('no colonizer info when colonizer is null', () {
        const p = Place(
          continent: 'Europe',
          name: 'Oslo',
          modernCountry: 'Norway',
          historicalContext: 'Nordic capital',
        );
        final info = p.getHistoricalInfo(null, 2, 'Oslo');
        expect(info, 'Nordic capital');
      });
    });

    group('fromJson / toJson', () {
      test('roundtrip preserves all fields', () {
        const original = Place(
          continent: 'Europe',
          name: 'Rome',
          modernCountry: 'Italy',
          iso3: 'ITA',
          state: 'Lazio',
          county: 'Rome Metro',
          subState: 'Central Italy',
          ssr: 'Mediterranean',
          historicalContext: 'Ancient capital',
          colonizer: null,
          nativeTribes: 'Latins',
          romanizedNative: 'Latini',
          validFrom: '0001-01-01',
          validTo: '2100-01-01',
        );
        final json = original.toJson();
        final restored = Place.fromJson(json);

        expect(restored.continent, original.continent);
        expect(restored.name, original.name);
        expect(restored.modernCountry, original.modernCountry);
        expect(restored.iso3, original.iso3);
        expect(restored.state, original.state);
        expect(restored.county, original.county);
        expect(restored.subState, original.subState);
        expect(restored.ssr, original.ssr);
        expect(restored.historicalContext, original.historicalContext);
        expect(restored.nativeTribes, original.nativeTribes);
        expect(restored.romanizedNative, original.romanizedNative);
        expect(restored.validFrom, original.validFrom);
        expect(restored.validTo, original.validTo);
      });

      test('fromJson missing optional fields produce nulls', () {
        final json = <String, dynamic>{
          'name': 'TestCity',
          'modernCountry': 'TestLand',
        };
        final p = Place.fromJson(json);
        expect(p.continent, '');
        expect(p.historicalContext, '');
        expect(p.iso3, isNull);
        expect(p.state, isNull);
        expect(p.validFrom, isNull);
        expect(p.validTo, isNull);
      });
    });
  });
}
