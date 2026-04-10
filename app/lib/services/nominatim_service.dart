import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geo_coord.dart';

/// Thin wrapper around the Nominatim OpenStreetMap geocoding API.
///
/// Nominatim usage policy: https://operations.osmfoundation.org/policies/nominatim/
/// — no bulk requests, always include a descriptive User-Agent.
class NominatimService {
  NominatimService._();
  static final NominatimService instance = NominatimService._();

  static const _baseUrl = 'https://nominatim.openstreetmap.org';
  static const _userAgent = 'Vetviona/1.0 (genealogy app; contact@vetviona.app)';

  // ── Reverse geocoding ──────────────────────────────────────────────────────

  /// Returns a [GeoCoord] with address details for the given coordinates, or
  /// `null` if the request fails or the location is unknown.
  Future<GeoCoord?> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/reverse'
        '?lat=$lat&lon=$lng'
        '&format=json'
        '&addressdetails=1',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseResult(data, lat, lng);
    } catch (_) {
      return null;
    }
  }

  // ── Forward geocoding (search) ─────────────────────────────────────────────

  /// Searches for places matching [query] and returns up to 10 results.
  Future<List<GeoCoord>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri(
        scheme: 'https',
        host: 'nominatim.openstreetmap.org',
        path: '/search',
        queryParameters: {
          'q': query.trim(),
          'format': 'json',
          'addressdetails': '1',
          'limit': '10',
        },
      );
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .cast<Map<String, dynamic>>()
          .map((item) {
            final lat = double.tryParse(item['lat'] as String? ?? '') ?? 0;
            final lng = double.tryParse(item['lon'] as String? ?? '') ?? 0;
            return _parseResult(item, lat, lng);
          })
          .whereType<GeoCoord>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  GeoCoord? _parseResult(
      Map<String, dynamic> data, double lat, double lng) {
    try {
      final address = data['address'] as Map<String, dynamic>? ?? {};
      final displayName = data['display_name'] as String?;

      // Nominatim uses multiple keys for settlement level — try most-specific first.
      final city = address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String? ??
          address['hamlet'] as String? ??
          address['municipality'] as String? ??
          address['suburb'] as String?;

      final county = address['county'] as String? ??
          address['district'] as String? ??
          address['borough'] as String?;

      final state = address['state'] as String? ??
          address['region'] as String? ??
          address['province'] as String? ??
          address['state_district'] as String?;

      final country = address['country'] as String?;
      final countryCode =
          (address['country_code'] as String?)?.toUpperCase();
      final postalCode = address['postcode'] as String?;

      return GeoCoord(
        lat: lat,
        lng: lng,
        displayName: displayName,
        postalCode: postalCode,
        city: city,
        county: county,
        state: state,
        country: country,
        countryCode: countryCode,
      );
    } catch (_) {
      return null;
    }
  }
}
