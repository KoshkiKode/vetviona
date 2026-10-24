/// Structured genealogical dates: GEDCOM 5.5.1 date phrases plus tolerant
/// parsing of common free text. Pure Dart, so it can be tested and shared with
/// exporters without touching the database.
///
/// Years before 1 AD are negative and there is no year 0: `-1` is 1 B.C.
enum GenCalendar {
  gregorian('GREGORIAN'),
  julian('JULIAN'),
  hebrew('HEBREW'),
  french('FRENCH R'),
  islamic('ISLAMIC');

  const GenCalendar(this.gedcomName);

  /// The name used inside a GEDCOM calendar escape (`@#DJULIAN@`).
  final String gedcomName;
}

enum GenDateQualifier {
  exact,
  about,
  calculated,
  estimated,
  before,
  after,
  between,
  from,
  to,
  fromTo,
  interpreted,
}

const int _unboundedLow = -(1 << 53);
const int _unboundedHigh = 1 << 53;
const List<String> _monthAbbr = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];
const List<int> _daysPerMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

bool _isLeapYear(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

int _daysInMonth(int year, int month) =>
    month == 2 && _isLeapYear(year) ? 29 : _daysPerMonth[month - 1];

int _yearOfKey(int key) => (key / 10000).floor();

final RegExp _calendarEscape = RegExp(
  r'@#D(GREGORIAN|JULIAN|HEBREW|FRENCH R|ISLAMIC)@\s*',
  caseSensitive: false,
);
final RegExp _interpreted = RegExp(r'^INT\s+(.+?)\s*\((.*)\)$', caseSensitive: false);
final RegExp _between = RegExp(r'^BET(?:WEEN)?\s+(.+?)\s+AND\s+(.+)$', caseSensitive: false);
final RegExp _fromTo = RegExp(r'^FROM\s+(.+?)\s+TO\s+(.+)$', caseSensitive: false);
final RegExp _from = RegExp(r'^FROM\s+(.+)$', caseSensitive: false);
final RegExp _to = RegExp(r'^TO\s+(.+)$', caseSensitive: false);
final RegExp _calculated = RegExp(r'^CALC?\.?\s+(.+)$', caseSensitive: false);
final RegExp _estimated = RegExp(r'^(?:EST|ESTIMATED)\.?\s+(.+)$', caseSensitive: false);
final RegExp _about = RegExp(
  r'^(?:ABT\.?|ABOUT|CIRCA|CA\.|C\.)\s*(.+)$',
  caseSensitive: false,
);
final RegExp _before = RegExp(r'^(?:BEF\.?|BEFORE)\s+(.+)$', caseSensitive: false);
final RegExp _after = RegExp(r'^(?:AFT\.?|AFTER)\s+(.+)$', caseSensitive: false);
final RegExp _range = RegExp(r'^(.+?)\s*[-\u2013]\s*(.+)$');
final RegExp _bce = RegExp(r'\s*(?:B\.?\s?C\.?|BCE)$', caseSensitive: false);

/// A calendar point: a year, optionally refined by month and day.
class GenPoint {
  const GenPoint(this.year, {this.month, this.day});

  final int year;
  final int? month;
  final int? day;

  /// Sort key for the first instant this point can denote (yyyymmdd style).
  int get earliestKey => year * 10000 + (month ?? 1) * 100 + (day ?? 1);

  /// Sort key for the last instant this point can denote.
  int get latestKey {
    final m = month ?? 12;
    final d = day ?? _daysInMonth(year, m);
    return year * 10000 + m * 100 + d;
  }

  /// GEDCOM spelling, e.g. `12 JAN 1900`, `JAN 1900`, `1000 B.C.`.
  String get gedcom {
    final buffer = StringBuffer();
    if (day != null) buffer.write('$day ');
    if (month != null) buffer.write('${_monthAbbr[month! - 1]} ');
    buffer.write(year < 0 ? '${-year} B.C.' : '$year');
    return buffer.toString();
  }

  /// Readable spelling, e.g. `12 Jan 1900`, `1000 BC`.
  String get display {
    final buffer = StringBuffer();
    if (day != null) buffer.write('$day ');
    if (month != null) {
      final abbr = _monthAbbr[month! - 1];
      buffer.write('${abbr[0]}${abbr.substring(1).toLowerCase()} ');
    }
    buffer.write(year < 0 ? '${-year} BC' : '$year');
    return buffer.toString();
  }
}

/// A genealogical date. Build with [GenDate.parse] or the named constructors.
class GenDate implements Comparable<GenDate> {
  const GenDate._(
    this.qualifier, {
    this.start,
    this.end,
    this.calendar = GenCalendar.gregorian,
    this.phrase,
  });

  /// An exact date, e.g. `GenDate.exact(GenPoint(1900, month: 1, day: 12))`.
  factory GenDate.exact(
    GenPoint point, {
    GenCalendar calendar = GenCalendar.gregorian,
  }) =>
      GenDate._(GenDateQualifier.exact, start: point, calendar: calendar);

  /// A date with a qualifier. [end] is only used for ranges.
  factory GenDate.qualified(
    GenDateQualifier qualifier,
    GenPoint start, {
    GenPoint? end,
  }) =>
      GenDate._(qualifier, start: start, end: end);

  /// Text that could not be parsed into a structured date. It is kept verbatim.
  factory GenDate.phrase(String text) =>
      GenDate._(GenDateQualifier.interpreted, phrase: text);

  final GenDateQualifier qualifier;

  /// The main date (lower bound for ranges), or null for phrase-only dates.
  final GenPoint? start;

  /// The upper bound for [GenDateQualifier.between] and [GenDateQualifier.fromTo].
  final GenPoint? end;

  final GenCalendar calendar;

  /// Original or interpreted wording, kept so no information is lost.
  final String? phrase;

  /// The date is only known as text.
  bool get isPhraseOnly => start == null;

  /// Lowest sort key this date can cover.
  int get lowKey {
    final s = start;
    if (s == null) return _unboundedHigh;
    return switch (qualifier) {
      GenDateQualifier.before || GenDateQualifier.to => _unboundedLow,
      _ => s.earliestKey,
    };
  }

  /// Highest sort key this date can cover.
  int get highKey {
    final s = start;
    if (s == null) return _unboundedHigh;
    return switch (qualifier) {
      GenDateQualifier.after || GenDateQualifier.from => _unboundedHigh,
      GenDateQualifier.between || GenDateQualifier.fromTo =>
        (end ?? s).latestKey,
      _ => s.latestKey,
    };
  }

  /// True when the two dates can refer to the same moment. Unknown dates never
  /// overlap anything.
  bool overlaps(GenDate other) {
    if (isPhraseOnly || other.isPhraseOnly) return false;
    return lowKey <= other.highKey && other.lowKey <= highKey;
  }

  /// Plausible age range in whole years between [birth] and [death], or null if
  /// either date is unknown or unbounded.
  static ({int min, int max})? ageBetween(GenDate birth, GenDate death) {
    if (birth.isPhraseOnly || death.isPhraseOnly) return null;
    for (final d in [birth, death]) {
      if (d.lowKey == _unboundedLow || d.highKey == _unboundedHigh) return null;
    }
    return (
      min: _yearOfKey(death.lowKey) - _yearOfKey(birth.highKey),
      max: _yearOfKey(death.highKey) - _yearOfKey(birth.lowKey),
    );
  }

  /// Parses [input]. Returns null only for blank input; anything unrecognised
  /// is kept as a phrase-only date rather than dropped.
  static GenDate? parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    var calendar = GenCalendar.gregorian;
    var body = trimmed;
    final escape = _calendarEscape.firstMatch(body);
    if (escape != null) {
      final name = escape.group(1)!.toUpperCase();
      calendar = GenCalendar.values.firstWhere(
        (c) => c.gedcomName == name,
        orElse: () => GenCalendar.gregorian,
      );
      body = body.replaceAll(_calendarEscape, '').trim();
    }

    return _parseBody(body, calendar) ??
        GenDate._(GenDateQualifier.interpreted, phrase: trimmed);
  }

  static GenDate? _parseBody(String body, GenCalendar calendar) {
    final interpreted = _interpreted.firstMatch(body);
    if (interpreted != null) {
      return GenDate._(
        GenDateQualifier.interpreted,
        start: _parsePoint(interpreted.group(1)!),
        calendar: calendar,
        phrase: interpreted.group(2)!.trim(),
      );
    }
    final between = _between.firstMatch(body);
    if (between != null) {
      return _pair(GenDateQualifier.between, between, calendar);
    }
    final fromTo = _fromTo.firstMatch(body);
    if (fromTo != null) {
      return _pair(GenDateQualifier.fromTo, fromTo, calendar);
    }
    final from = _from.firstMatch(body);
    if (from != null) return _single(GenDateQualifier.from, from.group(1)!, calendar);
    final to = _to.firstMatch(body);
    if (to != null) return _single(GenDateQualifier.to, to.group(1)!, calendar);
    final calc = _calculated.firstMatch(body);
    if (calc != null) {
      return _single(GenDateQualifier.calculated, calc.group(1)!, calendar);
    }
    final est = _estimated.firstMatch(body);
    if (est != null) {
      return _single(GenDateQualifier.estimated, est.group(1)!, calendar);
    }
    final about = _about.firstMatch(body);
    if (about != null) return _single(GenDateQualifier.about, about.group(1)!, calendar);
    final before = _before.firstMatch(body);
    if (before != null) {
      return _single(GenDateQualifier.before, before.group(1)!, calendar);
    }
    final after = _after.firstMatch(body);
    if (after != null) return _single(GenDateQualifier.after, after.group(1)!, calendar);

    final range = _range.firstMatch(body);
    if (range != null) {
      final a = _parsePoint(range.group(1)!);
      final b = _parsePoint(range.group(2)!);
      if (a != null && b != null) {
        return GenDate._(GenDateQualifier.between, start: a, end: b, calendar: calendar);
      }
    }

    final point = _parsePoint(body);
    return point == null
        ? null
        : GenDate._(GenDateQualifier.exact, start: point, calendar: calendar);
  }

  static GenDate? _single(GenDateQualifier q, String text, GenCalendar calendar) {
    final point = _parsePoint(text);
    return point == null ? null : GenDate._(q, start: point, calendar: calendar);
  }

  static GenDate? _pair(GenDateQualifier q, RegExpMatch m, GenCalendar calendar) {
    final a = _parsePoint(m.group(1)!);
    final b = _parsePoint(m.group(2)!);
    if (a == null || b == null) return null;
    return GenDate._(q, start: a, end: b, calendar: calendar);
  }

  static GenPoint? _parsePoint(String text) {
    var s = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    var isBce = false;
    final bce = _bce.firstMatch(s);
    if (bce != null) {
      isBce = true;
      s = s.substring(0, bce.start).trim();
    }

    final parts = s.isEmpty ? <String>[] : s.split(' ');
    int? day;
    int? month;
    final String yearText;
    switch (parts.length) {
      case 1:
        yearText = parts[0];
      case 2:
        month = _monthNumber(parts[0]);
        if (month == null) return null;
        yearText = parts[1];
      case 3:
        day = int.tryParse(parts[0]);
        month = _monthNumber(parts[1]);
        if (day == null || month == null) return null;
        yearText = parts[2];
      default:
        return null;
    }

    final number = int.tryParse(yearText);
    if (number == null || number == 0 || number.abs() > 99999) return null;
    final year = isBce ? -number.abs() : number;
    if (day != null && (day < 1 || day > _daysInMonth(year, month!))) {
      return null;
    }
    return GenPoint(year, month: month, day: day);
  }

  static int? _monthNumber(String text) {
    final key = text.toUpperCase().replaceAll('.', '');
    if (key == 'SEPT') return 9;
    if (key.length != 3) return null;
    final index = _monthAbbr.indexOf(key);
    return index < 0 ? null : index + 1;
  }

  /// GEDCOM 5.5.1 spelling, e.g. `ABT 1850`, `BET 1890 AND 1900`.
  String toGedcom() {
    final s = start;
    if (s == null) return phrase ?? '';
    final escape = calendar == GenCalendar.gregorian
        ? ''
        : '@#D${calendar.gedcomName}@ ';
    String pt(GenPoint x) => '$escape${x.gedcom}';
    return switch (qualifier) {
      GenDateQualifier.exact => pt(s),
      GenDateQualifier.about => 'ABT ${pt(s)}',
      GenDateQualifier.calculated => 'CAL ${pt(s)}',
      GenDateQualifier.estimated => 'EST ${pt(s)}',
      GenDateQualifier.before => 'BEF ${pt(s)}',
      GenDateQualifier.after => 'AFT ${pt(s)}',
      GenDateQualifier.between => 'BET ${pt(s)} AND ${pt(end ?? s)}',
      GenDateQualifier.from => 'FROM ${pt(s)}',
      GenDateQualifier.to => 'TO ${pt(s)}',
      GenDateQualifier.fromTo => 'FROM ${pt(s)} TO ${pt(end ?? s)}',
      GenDateQualifier.interpreted => 'INT ${pt(s)} (${phrase ?? ''})',
    };
  }

  /// Readable English, e.g. `about 1850`, `between 1890 and 1900`.
  String format() {
    final s = start;
    if (s == null) return phrase ?? '';
    final cal = calendar == GenCalendar.gregorian
        ? ''
        : '${calendar.name[0].toUpperCase()}${calendar.name.substring(1)} ';
    String pt(GenPoint x) => '$cal${x.display}';
    return switch (qualifier) {
      GenDateQualifier.exact => pt(s),
      GenDateQualifier.about => 'about ${pt(s)}',
      GenDateQualifier.calculated => 'calculated ${pt(s)}',
      GenDateQualifier.estimated => 'estimated ${pt(s)}',
      GenDateQualifier.before => 'before ${pt(s)}',
      GenDateQualifier.after => 'after ${pt(s)}',
      GenDateQualifier.between => 'between ${pt(s)} and ${(end ?? s).display}',
      GenDateQualifier.from => 'from ${pt(s)}',
      GenDateQualifier.to => 'to ${pt(s)}',
      GenDateQualifier.fromTo => 'from ${pt(s)} to ${(end ?? s).display}',
      GenDateQualifier.interpreted =>
        (phrase == null || phrase!.isEmpty) ? pt(s) : '${pt(s)} ($phrase)',
    };
  }

  /// Orders by earliest possible date, then latest. Phrase-only dates sort last.
  @override
  int compareTo(GenDate other) {
    final low = lowKey.compareTo(other.lowKey);
    return low != 0 ? low : highKey.compareTo(other.highKey);
  }

  @override
  String toString() => format();
}
