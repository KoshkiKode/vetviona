import 'dart:convert';

/// Geographic coordinates with reverse-geocoded political boundaries and
/// postal code.  Stored as a JSON blob in the persons table columns
/// `birthCoord`, `deathCoord`, and `burialCoord`.
class GeoCoord {
  final double lat;
  final double lng;

  /// Full display name returned by Nominatim (may be very long).
  final String? displayName;

  /// Postal / ZIP code for the location.
  final String? postalCode;

  /// City, town, village, or municipality name.
  final String? city;

  /// County, district, or equivalent sub-state unit.
  final String? county;

  /// State, province, or region.
  final String? state;

  /// Country name.
  final String? country;

  /// ISO 3166-1 alpha-2 country code (upper-case), e.g. "US", "DE", "UA".
  final String? countryCode;

  const GeoCoord({
    required this.lat,
    required this.lng,
    this.displayName,
    this.postalCode,
    this.city,
    this.county,
    this.state,
    this.country,
    this.countryCode,
  });

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (displayName != null) 'displayName': displayName,
        if (postalCode != null) 'postalCode': postalCode,
        if (city != null) 'city': city,
        if (county != null) 'county': county,
        if (state != null) 'state': state,
        if (country != null) 'country': country,
        if (countryCode != null) 'countryCode': countryCode,
      };

  factory GeoCoord.fromJson(Map<String, dynamic> json) => GeoCoord(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        displayName: json['displayName'] as String?,
        postalCode: json['postalCode'] as String?,
        city: json['city'] as String?,
        county: json['county'] as String?,
        state: json['state'] as String?,
        country: json['country'] as String?,
        countryCode: json['countryCode'] as String?,
      );

  /// Serialises to a JSON string for database storage.
  String toDbString() => jsonEncode(toJson());

  /// Deserialises from a database JSON string; returns `null` on failure.
  static GeoCoord? fromDbString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return GeoCoord.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Display helpers ────────────────────────────────────────────────────────

  /// Short human-readable label (city, state, country).
  String get shortLabel {
    final parts = <String>[
      if (city != null && city!.isNotEmpty) city!,
      if (state != null && state!.isNotEmpty) state!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// Full political hierarchy string (city → county → state → country).
  String get politicalBoundaries {
    final parts = <String>[
      if (city != null && city!.isNotEmpty) city!,
      if (county != null && county!.isNotEmpty) county!,
      if (state != null && state!.isNotEmpty) state!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    return parts.join(', ');
  }

  /// Formatted coordinate pair, e.g. "55.7558°N, 37.6173°E".
  String get coordinateLabel {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(4)}°$latDir, '
        '${lng.abs().toStringAsFixed(4)}°$lngDir';
  }
}
