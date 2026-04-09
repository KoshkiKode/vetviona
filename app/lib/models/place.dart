class Place {
  final String continent;
  final String name;
  final String modernCountry;
  final String? iso3;
  final String? state;
  final String? county;
  final String? subState;
  final String? ssr;
  final String historicalContext;
  final String? colonizer;
  final String? nativeTribes;
  final String? romanizedNative;
  /// ISO-8601 string for the earliest valid date (null = no lower bound).
  final String? validFrom;
  /// ISO-8601 string for the latest valid date (null = still current).
  final String? validTo;

  const Place({
    required this.continent,
    required this.name,
    required this.modernCountry,
    this.iso3,
    this.state,
    this.county,
    this.subState,
    this.ssr,
    required this.historicalContext,
    this.colonizer,
    this.nativeTribes,
    this.romanizedNative,
    this.validFrom,
    this.validTo,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      continent: json['continent'] as String? ?? '',
      name: json['name'] as String,
      modernCountry: json['modernCountry'] as String,
      iso3: json['iso3'] as String?,
      state: json['state'] as String?,
      county: json['county'] as String?,
      subState: json['subState'] as String?,
      ssr: json['ssr'] as String?,
      historicalContext: json['historicalContext'] as String? ?? '',
      colonizer: json['colonizer'] as String?,
      nativeTribes: json['nativeTribes'] as String?,
      romanizedNative: json['romanizedNative'] as String?,
      validFrom: json['validFrom'] as String?,
      validTo: json['validTo'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'continent': continent,
        'name': name,
        'modernCountry': modernCountry,
        if (iso3 != null) 'iso3': iso3,
        if (state != null) 'state': state,
        if (county != null) 'county': county,
        if (subState != null) 'subState': subState,
        if (ssr != null) 'ssr': ssr,
        'historicalContext': historicalContext,
        if (colonizer != null) 'colonizer': colonizer,
        if (nativeTribes != null) 'nativeTribes': nativeTribes,
        if (romanizedNative != null) 'romanizedNative': romanizedNative,
        if (validFrom != null) 'validFrom': validFrom,
        if (validTo != null) 'validTo': validTo,
      };

  /// Whether this place entry is valid for the given date.
  bool isValidFor(DateTime? date) {
    if (date == null) return true;
    if (validFrom != null) {
      final from = DateTime.tryParse(validFrom!);
      if (from != null && date.isBefore(from)) return false;
    }
    if (validTo != null) {
      final to = DateTime.tryParse(validTo!);
      if (to != null && date.isAfter(to)) return false;
    }
    return true;
  }

  /// All searchable text combined for fuzzy matching.
  String get _searchableText => [
        continent,
        name,
        modernCountry,
        state ?? '',
        county ?? '',
        nativeTribes ?? '',
        romanizedNative ?? '',
      ].join(' ').toLowerCase();

  /// Returns true if any searchable field starts with or contains [query].
  bool matches(String query) {
    if (query.isEmpty) return true;
    return _searchableText.contains(query.toLowerCase());
  }

  /// Relevance score: lower is better. City-name prefix match = 0, others = 1+.
  int relevanceFor(String query) {
    if (query.isEmpty) return 0;
    final q = query.toLowerCase();
    final n = name.toLowerCase();
    if (n == q) return 0;
    if (n.startsWith(q)) return 1;
    if (modernCountry.toLowerCase().startsWith(q)) return 2;
    if ((state ?? '').toLowerCase().startsWith(q)) return 3;
    if (n.contains(q)) return 4;
    return 5;
  }

  String getFullName(DateTime? date) {
    final parts = <String>[name];
    if (county != null && county!.isNotEmpty) parts.add(county!);
    if (subState != null && subState!.isNotEmpty) parts.add(subState!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (ssr != null && ssr!.isNotEmpty) parts.add(ssr!);

    String countryName = modernCountry;
    if (date != null) {
      if (name == 'Belgrade') {
        if (date.year < 1918) countryName = 'Ottoman Empire';
        else if (date.year < 1992) countryName = 'Yugoslavia';
      } else if (name == 'Boston') {
        if (date.year < 1776) countryName = 'British America';
      } else if (name == 'New York') {
        if (date.year < 1776) countryName = 'British America';
        else if (date.year < 1788) countryName = 'New York State';
      } else if (name == 'Istanbul' || name == 'Constantinople') {
        if (date.year < 330) countryName = 'Roman Empire';
        else if (date.year < 1923) countryName = 'Ottoman Empire';
      } else if (name == 'Saint Petersburg') {
        if (date.year >= 1914 && date.year < 1924) countryName = 'Petrograd, Russia';
        else if (date.year >= 1924 && date.year < 1991) countryName = 'Leningrad, Soviet Union';
      }
    }
    parts.add(countryName);
    return parts.join(', ');
  }

  String getHistoricalInfo(DateTime? date, int colonizationLevel, String fullName) {
    final buffer = StringBuffer(historicalContext);
    if (colonizationLevel >= 1 && colonizer != null && colonizer!.isNotEmpty) {
      buffer.write('\nColonized by: $colonizer');
    }
    if (colonizationLevel >= 2 && nativeTribes != null && nativeTribes!.isNotEmpty) {
      buffer.write('\nIndigenous peoples: $nativeTribes');
      if (romanizedNative != null &&
          romanizedNative!.isNotEmpty &&
          romanizedNative != nativeTribes) {
        buffer.write(' ($romanizedNative)');
      }
    }
    return buffer.toString();
  }
}
