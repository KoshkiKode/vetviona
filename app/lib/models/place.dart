  String getFullName(DateTime? date) {
    List<String> parts = [name];
    if (county != null && county!.isNotEmpty) parts.add(county!);
    if (subState != null && subState!.isNotEmpty) parts.add(subState!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (ssr != null && ssr!.isNotEmpty) parts.add(ssr!);
    String countryName = modernCountry;
    if (date != null) {
      if (name == 'Belgrade') {
        if (date.year < 1918) countryName = 'Ottoman Empire';
        else if (date.year < 1992) countryName = 'Yugoslavia';
      }
      if (name == 'Boston') {
        if (date.year < 1776) countryName = 'British America';
      }
    }
    parts.add(countryName);
    return parts.join(', ');
  }
