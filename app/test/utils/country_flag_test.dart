import 'package:flutter_test/flutter_test.dart';
import 'package:vetviona_app/utils/country_flag.dart';

void main() {
  group('countryFlagEmojiFromIso3', () {
    test('returns globe for null/empty inputs', () {
      expect(countryFlagEmojiFromIso3(null), '🌐');
      expect(countryFlagEmojiFromIso3(''), '🌐');
      expect(countryFlagEmojiFromIso3('   '), '🌐');
    });

    test('returns globe for unsupported historical codes', () {
      expect(countryFlagEmojiFromIso3('SUN'), '🌐');
      expect(countryFlagEmojiFromIso3('YUG'), '🌐');
      expect(countryFlagEmojiFromIso3('OTT'), '🌐');
    });

    test('returns globe for unknown or malformed alpha-3 values', () {
      expect(countryFlagEmojiFromIso3('ZZZ'), '🌐');
      expect(countryFlagEmojiFromIso3('12!'), '🌐');
      expect(countryFlagEmojiFromIso3('US'), '🌐');
    });

    test('converts known ISO3 values to flags', () {
      expect(countryFlagEmojiFromIso3('USA'), '🇺🇸');
      expect(countryFlagEmojiFromIso3('GBR'), '🇬🇧');
      expect(countryFlagEmojiFromIso3('JPN'), '🇯🇵');
      expect(countryFlagEmojiFromIso3('UKR'), '🇺🇦');
    });

    test('normalizes case and surrounding spaces', () {
      expect(countryFlagEmojiFromIso3(' usa '), '🇺🇸');
      expect(countryFlagEmojiFromIso3('gBr'), '🇬🇧');
    });
  });
}
