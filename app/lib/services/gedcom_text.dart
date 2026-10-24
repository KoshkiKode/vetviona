import 'dart:convert';
import 'dart:typed_data';

/// Text decoded from a GEDCOM file, together with how it was decoded.
class GedcomText {
  const GedcomText({
    required this.text,
    required this.encoding,
    this.warnings = const [],
  });

  final String text;

  /// The character set actually used, e.g. `UTF-8`, `UTF-16LE`, `Windows-1252`.
  final String encoding;

  /// Non-fatal problems found while decoding (guessed encodings, bad bytes).
  final List<String> warnings;
}

/// Decodes GEDCOM bytes using the byte-order mark, UTF-16 byte patterns and
/// the `1 CHAR` header value.
///
/// Supported: UTF-8 (with or without BOM), UTF-16 LE/BE, `UNICODE`,
/// `ASCII`/`ANSI` (read as Windows-1252). `ANSEL` is read as Windows-1252 with
/// a warning because its diacritic table is not implemented. Malformed UTF-8
/// falls back to Windows-1252 with a warning.
class GedcomDecoder {
  GedcomDecoder._();

  static GedcomText decode(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return _decodeUtf8(bytes, 3);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return GedcomText(
        text: _decodeUtf16(bytes, 2, littleEndian: true),
        encoding: 'UTF-16LE',
      );
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return GedcomText(
        text: _decodeUtf16(bytes, 2, littleEndian: false),
        encoding: 'UTF-16BE',
      );
    }

    final utf16LittleEndian = _guessUtf16LittleEndian(bytes);
    if (utf16LittleEndian != null) {
      return GedcomText(
        text: _decodeUtf16(bytes, 0, littleEndian: utf16LittleEndian),
        encoding: utf16LittleEndian ? 'UTF-16LE' : 'UTF-16BE',
        warnings: const [
          'No byte-order mark: UTF-16 was detected from the byte pattern.',
        ],
      );
    }

    final declared = _declaredCharset(bytes);
    switch (declared) {
      case 'UTF-8':
      case 'UTF8':
        return _decodeUtf8(bytes, 0);
      case 'UNICODE':
        return _decodeUtf8(
          bytes,
          0,
          extra: 'CHAR UNICODE without a UTF-16 pattern; read as UTF-8.',
        );
      case 'ASCII':
      case 'ANSI':
        return _decodeCp1252(bytes);
      case 'ANSEL':
        return _decodeCp1252(
          bytes,
          extra: 'ANSEL diacritics are not fully supported; '
              'some characters may be approximated.',
        );
      case null:
        return _decodeUtf8(bytes, 0);
      default:
        return _decodeUtf8(
          bytes,
          0,
          extra: "Unrecognised CHAR '$declared'; read as UTF-8.",
        );
    }
  }

  static String? _declaredCharset(Uint8List bytes) {
    final head = latin1.decode(
      bytes.length <= 8192 ? bytes : Uint8List.sublistView(bytes, 0, 8192),
      allowInvalid: true,
    );
    final match = RegExp(
      r'^\s*1\s+CHAR\s+(\S+)',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(head);
    return match?.group(1)?.toUpperCase();
  }

  /// Returns true for little-endian, false for big-endian, null if the bytes do
  /// not look like UTF-16 text (GEDCOM is ASCII-heavy, so NUL bytes are rare).
  static bool? _guessUtf16LittleEndian(Uint8List bytes) {
    final sample = bytes.length < 400 ? bytes.length : 400;
    if (sample < 4) return null;
    var evenZeros = 0;
    var oddZeros = 0;
    for (var i = 0; i < sample; i++) {
      if (bytes[i] != 0) continue;
      if (i.isEven) {
        evenZeros++;
      } else {
        oddZeros++;
      }
    }
    final half = sample / 2;
    if (oddZeros > half * 0.6 && evenZeros < sample * 0.05) return true;
    if (evenZeros > half * 0.6 && oddZeros < sample * 0.05) return false;
    return null;
  }

  static GedcomText _decodeUtf8(Uint8List bytes, int offset, {String? extra}) {
    final view = Uint8List.sublistView(bytes, offset);
    try {
      return GedcomText(
        text: utf8.decode(view),
        encoding: 'UTF-8',
        warnings: [?extra],
      );
    } on FormatException {
      final fallback = _decodeCp1252(view);
      return GedcomText(
        text: fallback.text,
        encoding: 'Windows-1252',
        warnings: [
          ?extra,
          'Invalid UTF-8 bytes; the file was read as Windows-1252.',
        ],
      );
    }
  }

  static GedcomText _decodeCp1252(Uint8List bytes, {String? extra}) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80 || b >= 0xA0) {
        buffer.writeCharCode(b);
      } else {
        buffer.writeCharCode(_cp1252High[b] ?? b);
      }
    }
    return GedcomText(
      text: buffer.toString(),
      encoding: 'Windows-1252',
      warnings: [?extra],
    );
  }

  static String _decodeUtf16(
    Uint8List bytes,
    int offset, {
    required bool littleEndian,
  }) {
    int unitAt(int index) => littleEndian
        ? bytes[index] | (bytes[index + 1] << 8)
        : (bytes[index] << 8) | bytes[index + 1];

    final buffer = StringBuffer();
    var i = offset;
    while (i + 1 < bytes.length) {
      final unit = unitAt(i);
      i += 2;
      if (unit >= 0xD800 && unit <= 0xDBFF && i + 1 < bytes.length) {
        final low = unitAt(i);
        if (low >= 0xDC00 && low <= 0xDFFF) {
          buffer.writeCharCode(0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00));
          i += 2;
          continue;
        }
      }
      buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }

  /// Windows-1252 code points for bytes 0x80-0x9F (the rest map to Latin-1).
  static const Map<int, int> _cp1252High = {
    0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026,
    0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160,
    0x8B: 0x2039, 0x8C: 0x0152, 0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019,
    0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
    0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153,
    0x9E: 0x017E, 0x9F: 0x0178,
  };
}

/// Writes GEDCOM text with every line at most [maxBytes] UTF-8 bytes long, the
/// GEDCOM 5.5.1 limit. Longer values are split into `CONC` continuation lines
/// (`n+1 CONC`) at code-point boundaries and never end a piece in a space, so
/// the importer (which trims line ends) reconstructs the original value.
class GedcomLineWrapper {
  GedcomLineWrapper._();

  static String wrap(String text, {int maxBytes = 255}) {
    final out = StringBuffer();
    final lines = text.split('\n');
    final count =
        lines.isNotEmpty && lines.last.isEmpty ? lines.length - 1 : lines.length;
    for (var i = 0; i < count; i++) {
      var line = lines[i];
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      for (final part in _wrapLine(line, maxBytes)) {
        out
          ..write(part)
          ..write('\n');
      }
    }
    return out.toString();
  }

  static List<String> _wrapLine(String line, int maxBytes) {
    if (utf8.encode(line).length <= maxBytes) return [line];
    final match = RegExp(r'^(\d+) (\S+)(?: (.*))?$').firstMatch(line);
    if (match == null) return [line];

    final level = int.parse(match.group(1)!);
    var prefix = '$level ${match.group(2)} ';
    var rest = match.group(3) ?? '';
    final pieces = <String>[];
    while (true) {
      final cut = _cutPoint(rest, maxBytes - utf8.encode(prefix).length);
      pieces.add('$prefix${rest.substring(0, cut)}');
      rest = rest.substring(cut);
      if (rest.isEmpty) break;
      prefix = '${level + 1} CONC ';
    }
    return pieces;
  }

  static int _cutPoint(String s, int budget) {
    var bytes = 0;
    var i = 0;
    while (i < s.length) {
      final width = _unitWidth(s, i);
      final size = utf8.encode(s.substring(i, i + width)).length;
      if (bytes + size > budget) break;
      bytes += size;
      i += width;
    }
    if (i > 0 && i < s.length && s[i - 1] == ' ') i -= 1;
    if (i == 0 && s.isNotEmpty) i = _unitWidth(s, 0);
    return i;
  }

  static int _unitWidth(String s, int i) {
    final unit = s.codeUnitAt(i);
    return unit >= 0xD800 && unit <= 0xDBFF && i + 1 < s.length ? 2 : 1;
  }
}
