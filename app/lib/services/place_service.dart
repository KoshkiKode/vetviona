import '../models/place.dart';
import 'places_data.dart';

/// Provides scored search across the compiled-in place database.
/// All data lives in Dart source files — no JSON parsing, fully offline.
class PlaceService {
  PlaceService._();
  static final PlaceService instance = PlaceService._();

  List<Place>? _cache;

  /// Returns the full place list (synchronous after first call).
  Future<List<Place>> loadPlaces() async {
    _cache ??= List<Place>.unmodifiable(allPlaces);
    return _cache!;
  }

  /// Returns all places, or an empty list if not yet loaded.
  List<Place> get places => _cache ?? [];

  /// Search places with ranked results.
  /// Matches across city name, country, state, native names.
  /// Results sorted by relevance (prefix on city name first).
  /// When [eventDate] is provided, filters out places not valid for that era.
  List<Place> search(String query, {DateTime? eventDate}) {
    final all = _cache ?? [];
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) {
      if (eventDate == null) return all;
      return all.where((p) => p.isValidFor(eventDate)).toList();
    }

    final tokens = lowerQuery.split(RegExp(r'[\s,]+'));

    final matches = <Place>[];
    for (final place in all) {
      if (eventDate != null && !place.isValidFor(eventDate)) continue;
      // Every token must match at least one field
      bool allTokensMatch = true;
      for (final token in tokens) {
        if (!place.matches(token)) {
          allTokensMatch = false;
          break;
        }
      }
      if (allTokensMatch) matches.add(place);
    }

    // Sort by relevance of the first token (usually the city name)
    matches.sort((a, b) =>
        a.relevanceFor(tokens.first).compareTo(b.relevanceFor(tokens.first)));
    return matches;
  }
}
