import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetviona_app/services/nominatim_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

NominatimService _serviceWith(String body, {int statusCode = 200}) {
  final client = MockClient((_) async => http.Response(body, statusCode));
  return NominatimService.withClient(client);
}

Map<String, dynamic> _addressResponse({
  double lat = 51.5074,
  double lng = -0.1278,
  String? displayName,
  String? city,
  String? town,
  String? village,
  String? county,
  String? state,
  String? country,
  String? countryCode,
  String? postcode,
}) =>
    {
      'display_name': displayName ?? '$city, $country',
      'address': {
        if (city != null) 'city': city,
        if (town != null) 'town': town,
        if (village != null) 'village': village,
        if (county != null) 'county': county,
        if (state != null) 'state': state,
        if (country != null) 'country': country,
        if (countryCode != null) 'country_code': countryCode,
        if (postcode != null) 'postcode': postcode,
      },
    };

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── search — empty / blank query ─────────────────────────────────────────────
  group('NominatimService.search empty query', () {
    test('returns empty list for empty string without HTTP call', () async {
      // This mock client would throw if called, proving no HTTP is made.
      var called = false;
      final client = MockClient((_) async {
        called = true;
        throw Exception('HTTP should not be called');
      });
      final svc = NominatimService.withClient(client);

      final results = await svc.search('');
      expect(results, isEmpty);
      expect(called, isFalse);
    });

    test('returns empty list for whitespace-only query', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        throw Exception('HTTP should not be called');
      });
      final svc = NominatimService.withClient(client);

      final results = await svc.search('   ');
      expect(results, isEmpty);
      expect(called, isFalse);
    });
  });

  // ── search — HTTP errors ──────────────────────────────────────────────────────
  group('NominatimService.search HTTP errors', () {
    test('returns empty list on non-200 status', () async {
      final svc = _serviceWith('Not found', statusCode: 404);
      final results = await svc.search('Paris');
      expect(results, isEmpty);
    });

    test('returns empty list on 500 error', () async {
      final svc = _serviceWith('Server error', statusCode: 500);
      final results = await svc.search('London');
      expect(results, isEmpty);
    });
  });

  // ── search — successful response ──────────────────────────────────────────────
  group('NominatimService.search success', () {
    test('returns one result for single-item response', () async {
      final body = jsonEncode([
        {
          ..._addressResponse(
            lat: 48.8566,
            lng: 2.3522,
            displayName: 'Paris, Île-de-France, France',
            city: 'Paris',
            state: 'Île-de-France',
            country: 'France',
            countryCode: 'fr',
            postcode: '75001',
          ),
          'lat': '48.8566',
          'lon': '2.3522',
        }
      ]);
      final svc = _serviceWith(body);
      final results = await svc.search('Paris');

      expect(results, hasLength(1));
      expect(results.first.lat, closeTo(48.8566, 0.001));
      expect(results.first.lng, closeTo(2.3522, 0.001));
      expect(results.first.city, 'Paris');
      expect(results.first.country, 'France');
      expect(results.first.countryCode, 'FR'); // uppercased
    });

    test('returns multiple results', () async {
      final body = jsonEncode([
        {'lat': '51.5074', 'lon': '-0.1278', 'display_name': 'London', 'address': {}},
        {'lat': '52.4797', 'lon': '-1.8980', 'display_name': 'Birmingham', 'address': {}},
      ]);
      final svc = _serviceWith(body);
      final results = await svc.search('England');
      expect(results, hasLength(2));
    });

    test('handles item with missing lat/lon gracefully', () async {
      // lat/lon parse falls back to 0.0 when not parseable
      final body = jsonEncode([
        {'lat': 'bad', 'lon': 'bad', 'display_name': 'Unknown', 'address': {}},
      ]);
      final svc = _serviceWith(body);
      final results = await svc.search('anything');
      // Should return the item (lat/lng default to 0)
      expect(results, hasLength(1));
      expect(results.first.lat, 0.0);
      expect(results.first.lng, 0.0);
    });
  });

  // ── reverseGeocode — HTTP errors ─────────────────────────────────────────────
  group('NominatimService.reverseGeocode HTTP errors', () {
    test('returns null on non-200 status', () async {
      final svc = _serviceWith('forbidden', statusCode: 403);
      expect(await svc.reverseGeocode(51.5, -0.1), isNull);
    });

    test('returns null on 500 server error', () async {
      final svc = _serviceWith('error', statusCode: 500);
      expect(await svc.reverseGeocode(0, 0), isNull);
    });
  });

  // ── reverseGeocode — successful response ─────────────────────────────────────
  group('NominatimService.reverseGeocode success', () {
    test('parses city from "city" key', () async {
      final body = jsonEncode(_addressResponse(
        lat: 51.5074,
        lng: -0.1278,
        city: 'London',
        state: 'England',
        country: 'United Kingdom',
        countryCode: 'gb',
      ));
      final svc = _serviceWith(body);
      final coord = await svc.reverseGeocode(51.5074, -0.1278);

      expect(coord, isNotNull);
      expect(coord!.lat, 51.5074);
      expect(coord.lng, -0.1278);
      expect(coord.city, 'London');
      expect(coord.state, 'England');
      expect(coord.country, 'United Kingdom');
      expect(coord.countryCode, 'GB'); // uppercased
    });

    test('falls back to "town" when no "city" key', () async {
      final body = jsonEncode(
        _addressResponse(
          lat: 52.0,
          lng: 1.0,
          town: 'Ipswich',
          country: 'United Kingdom',
          countryCode: 'gb',
        ),
      );
      final svc = _serviceWith(body);
      final coord = await svc.reverseGeocode(52.0, 1.0);
      expect(coord!.city, 'Ipswich');
    });

    test('falls back to "village" when no city or town', () async {
      final body = jsonEncode(
        _addressResponse(
          lat: 53.0,
          lng: 2.0,
          village: 'Little Snoring',
          country: 'United Kingdom',
        ),
      );
      final svc = _serviceWith(body);
      final coord = await svc.reverseGeocode(53.0, 2.0);
      expect(coord!.city, 'Little Snoring');
    });

    test('parses postal code', () async {
      final body = jsonEncode(_addressResponse(
        lat: 48.8566,
        lng: 2.3522,
        city: 'Paris',
        country: 'France',
        countryCode: 'fr',
        postcode: '75001',
      ));
      final svc = _serviceWith(body);
      final coord = await svc.reverseGeocode(48.8566, 2.3522);
      expect(coord!.postalCode, '75001');
    });

    test('parses county', () async {
      final body = jsonEncode(_addressResponse(
        lat: 51.0,
        lng: 0.0,
        city: 'Maidstone',
        county: 'Kent',
        country: 'United Kingdom',
      ));
      final svc = _serviceWith(body);
      final coord = await svc.reverseGeocode(51.0, 0.0);
      expect(coord!.county, 'Kent');
    });

    test('displayName is populated from response', () async {
      const display = 'London, Greater London, England, United Kingdom';
      final body = jsonEncode({
        'display_name': display,
        'address': {'city': 'London', 'country': 'United Kingdom'},
      });
      final svc = _serviceWith(body);
      final coord = await svc.reverseGeocode(51.5074, -0.1278);
      expect(coord!.displayName, display);
    });

    test('country code is uppercased', () async {
      final body = jsonEncode(_addressResponse(
        lat: 52.0,
        lng: 21.0,
        city: 'Warsaw',
        country: 'Poland',
        countryCode: 'pl',
      ));
      final svc = _serviceWith(body);
      final coord = await svc.reverseGeocode(52.0, 21.0);
      expect(coord!.countryCode, 'PL');
    });
  });
}
