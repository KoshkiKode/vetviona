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

/// Master list combining all regional place data.
/// Organised: continent → country → state → county → city.
/// Historical entries carry [validTo] ISO-8601 dates for date-aware filtering.
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
];
