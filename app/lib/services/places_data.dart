import '../models/place.dart';
import 'places_africa.dart';
import 'places_americas.dart';
import 'places_asia.dart';
import 'places_europe.dart';
import 'places_historical.dart';
import 'places_oceania.dart';
import 'places_subdivisions_africa.dart';
import 'places_subdivisions_americas.dart';
import 'places_subdivisions_asia.dart';
import 'places_subdivisions_europe.dart';
import 'places_subdivisions_oceania.dart';
import 'places_l2_africa.dart';
import 'places_l2_americas.dart';
import 'places_l2_asia.dart';
import 'places_l2_europe.dart';
import 'places_l2_oceania.dart';

/// Master list combining all regional place data.
/// Organised: continent → country → state → county → city.
/// Historical entries carry [validTo] ISO-8601 dates for date-aware filtering.
///
/// Layers:
///   1. Curated cities/towns with historical context
///   2. ISO 3166-2 level-1 administrative subdivisions (states, provinces…)
///   3. ISO 3166-2 level-2 subdivisions + all US counties (FIPS)
///
/// A fourth layer – 32,444 GeoNames cities – is available through
/// [GeonamesService] which queries a bundled SQLite database at runtime.
const List<Place> allPlaces = [
  ...placesAfrica,
  ...placesAmericas,
  ...placesAsia,
  ...placesEurope,
  ...placesHistorical,
  ...placesOceania,
  ...placesSubdivisionsAfrica,
  ...placesSubdivisionsAmericas,
  ...placesSubdivisionsAsia,
  ...placesSubdivisionsEurope,
  ...placesSubdivisionsOceania,
  ...placesL2Africa,
  ...placesL2Americas,
  ...placesL2Asia,
  ...placesL2Europe,
  ...placesL2Oceania,
];
