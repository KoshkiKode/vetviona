class Place {
  final String name;
  final String modernCountry;
  final String? state;
  final String? county;
  final String? subState;
  final String? ssr;
  final String historicalContext;
  final String? colonizer;
  final String? nativeTribes;
  final String? romanizedNative;
  final DateTime? validFrom;

  const Place({
    required this.name,
    required this.modernCountry,
    this.state,
    this.county,
    this.subState,
    this.ssr,
    required this.historicalContext,
    this.colonizer,
    this.nativeTribes,
    this.romanizedNative,
    this.validFrom,
  });

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
        if (date.year < 1923) countryName = 'Ottoman Empire';
        else if (date.year < 330) countryName = 'Roman Empire';
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
