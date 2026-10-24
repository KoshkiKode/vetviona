import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/services/gedcom_text.dart';

Uint8List _ascii(String s) => Uint8List.fromList(latin1.encode(s));

Uint8List _utf16(String s, {required bool littleEndian, bool bom = true}) {
  final bytes = <int>[];
  if (bom) bytes.addAll(littleEndian ? [0xFF, 0xFE] : [0xFE, 0xFF]);
  for (final unit in s.codeUnits) {
    final hi = unit >> 8;
    final lo = unit & 0xFF;
    bytes.addAll(littleEndian ? [lo, hi] : [hi, lo]);
  }
  return Uint8List.fromList(bytes);
}

/// Reassembles a value from wrapped lines, as the importer does with CONC.
String _unwrap(String wrapped) {
  final buffer = StringBuffer();
  final lines = wrapped.split('\n')..removeWhere((l) => l.isEmpty);
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (i == 0) {
      buffer.write(line.substring(line.indexOf(' ', line.indexOf(' ') + 1) + 1));
    } else {
      buffer.write(line.substring(line.indexOf(' CONC ') + 6));
    }
  }
  return buffer.toString();
}

void main() {
  group('GedcomDecoder', () {
    test('UTF-8 with a byte-order mark drops the mark', () {
      final bytes = Uint8List.fromList([
        0xEF, 0xBB, 0xBF,
        ...utf8.encode('0 HEAD\n1 CHAR UTF-8\n1 NAME Jos\u00e9 /Doe/\n'),
      ]);
      final decoded = GedcomDecoder.decode(bytes);
      expect(decoded.encoding, 'UTF-8');
      expect(decoded.text.startsWith('0 HEAD'), isTrue);
      expect(decoded.text, contains('José /Doe/'));
      expect(decoded.warnings, isEmpty);
    });

    test('UTF-16 little-endian with BOM', () {
      final decoded = GedcomDecoder.decode(
        _utf16('0 HEAD\n1 NAME Zo\u00eb /Doe/\n', littleEndian: true),
      );
      expect(decoded.encoding, 'UTF-16LE');
      expect(decoded.text, contains('Zoë /Doe/'));
    });

    test('UTF-16 big-endian with BOM', () {
      final decoded = GedcomDecoder.decode(
        _utf16('0 HEAD\n1 NAME Zo\u00eb /Doe/\n', littleEndian: false),
      );
      expect(decoded.encoding, 'UTF-16BE');
      expect(decoded.text, contains('Zoë /Doe/'));
    });

    test('UTF-16 without a BOM is detected and flagged', () {
      final decoded = GedcomDecoder.decode(
        _utf16('0 HEAD\n1 CHAR UNICODE\n1 NAME Zo\u00eb /Doe/\n',
            littleEndian: true, bom: false),
      );
      expect(decoded.encoding, 'UTF-16LE');
      expect(decoded.text, contains('Zoë /Doe/'));
      expect(decoded.warnings.single, contains('No byte-order mark'));
    });

    test('surrogate pairs (emoji) survive UTF-16', () {
      final decoded = GedcomDecoder.decode(
        _utf16('1 NOTE \u{1F600}\n', littleEndian: false),
      );
      expect(decoded.text, contains('\u{1F600}'));
    });

    test('CHAR ANSI reads Windows-1252 bytes correctly', () {
      final bytes = Uint8List.fromList([
        ..._ascii('0 HEAD\n1 CHAR ANSI\n1 NAME Jos'),
        0xE9, // é in Windows-1252
        ..._ascii(' /Doe/ \x80\n'), // € in Windows-1252
      ]);
      final decoded = GedcomDecoder.decode(bytes);
      expect(decoded.encoding, 'Windows-1252');
      expect(decoded.text, contains('José /Doe/ €'));
      expect(decoded.warnings, isEmpty);
    });

    test('invalid UTF-8 falls back to Windows-1252 with a warning', () {
      final bytes = Uint8List.fromList([..._ascii('1 NAME Jos'), 0xE9, 0x0A]);
      final decoded = GedcomDecoder.decode(bytes);
      expect(decoded.encoding, 'Windows-1252');
      expect(decoded.text, contains('José'));
      expect(decoded.warnings.single, contains('Invalid UTF-8'));
    });

    test('ANSEL is read with an explicit warning', () {
      final decoded = GedcomDecoder.decode(
        _ascii('0 HEAD\n1 CHAR ANSEL\n1 NAME Test\n'),
      );
      expect(decoded.warnings.single, contains('ANSEL'));
    });

    test('plain ASCII without a CHAR line is accepted silently', () {
      final decoded = GedcomDecoder.decode(_ascii('0 HEAD\n1 NAME Test\n'));
      expect(decoded.encoding, 'UTF-8');
      expect(decoded.warnings, isEmpty);
    });
  });

  group('GedcomLineWrapper', () {
    test('short lines are left alone', () {
      const text = '0 HEAD\n1 GEDC\n2 VERS 5.5.1\n0 TRLR\n';
      expect(GedcomLineWrapper.wrap(text), text);
    });

    test('every line stays within 255 UTF-8 bytes', () {
      final value = 'é' * 400;
      final wrapped = GedcomLineWrapper.wrap('1 NOTE $value\n');
      for (final line in wrapped.split('\n').where((l) => l.isNotEmpty)) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(255));
      }
    });

    test('continuation lines reconstruct the original value exactly', () {
      final value = List.generate(120, (i) => 'word$i').join(' ');
      final wrapped = GedcomLineWrapper.wrap('1 NOTE $value\n');
      expect(wrapped, contains('2 CONC '));
      expect(_unwrap(wrapped), value);
    });

    test('chunks never end with a space (the importer trims line ends)', () {
      final value = ('abc ' * 200).trimRight();
      final wrapped = GedcomLineWrapper.wrap('1 NOTE $value\n');
      for (final line in wrapped.split('\n').where((l) => l.isNotEmpty)) {
        expect(line.endsWith(' '), isFalse);
      }
    });

    test('multi-byte characters are never split', () {
      final value = '\u{1F600}' * 150;
      final wrapped = GedcomLineWrapper.wrap('1 NOTE $value\n');
      expect(_unwrap(wrapped), value);
      for (final line in wrapped.split('\n').where((l) => l.isNotEmpty)) {
        expect(() => utf8.decode(utf8.encode(line)), returnsNormally);
      }
    });
  });
}
