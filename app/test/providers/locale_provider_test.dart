import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetviona_app/providers/locale_provider.dart';

void main() {
  group('LocaleProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts with null locale', () {
      final provider = LocaleProvider();
      expect(provider.locale, isNull);
    });

    test('setLocale updates locale and persists language tag', () async {
      final provider = LocaleProvider();

      await provider.setLocale(const Locale('en', 'US'));

      expect(provider.locale, const Locale('en', 'US'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'en-US');
    });

    test('setLocale notifies listeners once', () async {
      final provider = LocaleProvider();
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setLocale(const Locale('de'));

      expect(notifyCount, 1);
    });

    test('loadLocale keeps locale null when no saved value exists', () async {
      final provider = LocaleProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.loadLocale();

      expect(provider.locale, isNull);
      expect(notified, isFalse);
    });

    test('loadLocale restores language-only locale', () async {
      SharedPreferences.setMockInitialValues({'locale': 'fr'});
      final provider = LocaleProvider();

      await provider.loadLocale();

      expect(provider.locale, const Locale('fr'));
    });

    test('loadLocale restores language+country locale', () async {
      SharedPreferences.setMockInitialValues({'locale': 'pt-BR'});
      final provider = LocaleProvider();

      await provider.loadLocale();

      expect(provider.locale, const Locale('pt', 'BR'));
    });

    test('loadLocale ignores extra tag parts after the second segment', () async {
      SharedPreferences.setMockInitialValues({'locale': 'zh-Hant-TW'});
      final provider = LocaleProvider();

      await provider.loadLocale();

      expect(provider.locale, const Locale('zh', 'Hant'));
    });

    test('loadLocale notifies listeners when saved locale exists', () async {
      SharedPreferences.setMockInitialValues({'locale': 'it-IT'});
      final provider = LocaleProvider();
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.loadLocale();

      expect(provider.locale, const Locale('it', 'IT'));
      expect(notifyCount, 1);
    });
  });
}
