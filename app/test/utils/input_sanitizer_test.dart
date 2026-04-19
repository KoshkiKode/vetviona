import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/utils/input_sanitizer.dart';

void main() {
  group('InputSanitizer.sanitize', () {
    test('returns null for null input', () {
      expect(InputSanitizer.sanitize(null), isNull);
    });

    test('returns empty string unchanged', () {
      expect(InputSanitizer.sanitize(''), '');
    });

    test('passes through normal printable ASCII', () {
      const s = 'Alice Smith 1990 – genealogy notes!';
      expect(InputSanitizer.sanitize(s), s);
    });

    test('passes through unicode text', () {
      const s = 'Ångström Üniversitesi 日本語 🎉';
      expect(InputSanitizer.sanitize(s), s);
    });

    test('removes null byte (U+0000)', () {
      expect(InputSanitizer.sanitize('hello\x00world'), 'helloworld');
    });

    test('removes C0 control chars other than TAB, LF, CR', () {
      expect(InputSanitizer.sanitize('a\x01b\x07c\x0Bd\x1Fe'), 'abcde');
    });

    test('preserves TAB (U+0009)', () {
      expect(InputSanitizer.sanitize('a\tb'), 'a\tb');
    });

    test('preserves LF (U+000A)', () {
      expect(InputSanitizer.sanitize('a\nb'), 'a\nb');
    });

    test('preserves CR (U+000D)', () {
      expect(InputSanitizer.sanitize('a\rb'), 'a\rb');
    });

    test('removes DEL (U+007F)', () {
      expect(InputSanitizer.sanitize('a\x7Fb'), 'ab');
    });

    test('removes C1 controls (U+0080–U+009F)', () {
      expect(InputSanitizer.sanitize('a\x80b\x9Fc'), 'abc');
    });

    test('truncates to maxLength', () {
      final long = 'x' * 600;
      final result = InputSanitizer.sanitize(long,
          maxLength: InputSanitizer.maxShortField);
      expect(result!.length, InputSanitizer.maxShortField);
    });

    test('does not truncate when length equals maxLength', () {
      final exact = 'a' * InputSanitizer.maxShortField;
      expect(InputSanitizer.sanitize(exact)!.length,
          InputSanitizer.maxShortField);
    });

    test('combined: strips controls AND truncates', () {
      final withControls = 'a\x00b\x01${'c' * 600}';
      final result = InputSanitizer.sanitize(withControls)!;
      expect(result.contains('\x00'), isFalse);
      expect(result.contains('\x01'), isFalse);
      expect(result.length, InputSanitizer.maxShortField);
    });
  });

  group('InputSanitizer.sanitizeRequired', () {
    test('returns empty string for null input', () {
      expect(InputSanitizer.sanitizeRequired(null), '');
    });

    test('returns sanitized non-null text', () {
      expect(InputSanitizer.sanitizeRequired('hello\x00'), 'hello');
    });
  });

  group('InputSanitizer convenience wrappers', () {
    test('name() strips controls from person name', () {
      expect(InputSanitizer.name('Alice\x00 \x01Smith'), 'Alice Smith');
    });

    test('shortField() returns null for null', () {
      expect(InputSanitizer.shortField(null), isNull);
    });

    test('mediumField() allows up to maxMediumField chars', () {
      final long = 'n' * (InputSanitizer.maxMediumField + 100);
      final result = InputSanitizer.mediumField(long)!;
      expect(result.length, InputSanitizer.maxMediumField);
    });

    test('authField() sanitizes and returns required string', () {
      expect(InputSanitizer.authField('admin\x00pass'), 'adminpass');
    });

    test('authField() returns empty string for null', () {
      expect(InputSanitizer.authField(null), '');
    });

    test('authField() truncates to maxAuthField', () {
      final long = 'p' * (InputSanitizer.maxAuthField + 100);
      expect(InputSanitizer.authField(long).length, InputSanitizer.maxAuthField);
    });

    test('shortField() returns sanitized value for non-null input', () {
      expect(InputSanitizer.shortField('hello\x00world'), 'helloworld');
    });

    test('mediumField() returns sanitized non-null value', () {
      expect(InputSanitizer.mediumField('note\x01content'), 'notecontent');
    });

    test('mediumField() returns null for null input', () {
      expect(InputSanitizer.mediumField(null), isNull);
    });
  });
}
