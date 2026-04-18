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

    // Use the modernCountry directly — the Place data model already encodes
    // the correct country/empire via validFrom/validTo for each historical era.
    parts.add(modernCountry);
    return parts.join(', ');
  }

  String getHistoricalInfo(
    DateTime? date,
    int colonizationLevel,
    String fullName,
  ) {
    final lines = <String>[];
    if (historicalContext.trim().isNotEmpty) {
      lines.add(historicalContext.trim());
    }
    if (colonizationLevel >= 1 &&
        colonizer != null &&
        colonizer!.trim().isNotEmpty) {
      lines.add('Colonized by: ${colonizer!.trim()}');
    }
    if (colonizationLevel >= 2 &&
        nativeTribes != null &&
        nativeTribes!.trim().isNotEmpty) {
      var nativeLine = 'Indigenous peoples: ${nativeTribes!.trim()}';
      final nativeVariant = romanizedNative?.trim();
      if (nativeVariant != null &&
          nativeVariant.isNotEmpty &&
          nativeVariant.toLowerCase() != nativeTribes!.trim().toLowerCase()) {
        nativeLine = '$nativeLine ($nativeVariant)';
      }
      lines.add(nativeLine);
    }
    return lines.isEmpty
        ? 'No historical context available.'
        : lines.join('\n');
  }
}
