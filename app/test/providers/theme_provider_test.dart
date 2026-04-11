import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetviona_app/providers/theme_provider.dart';

void main() {
  group('VetvionaPalette', () {
    test('light and dark primaries are different colours', () {
      expect(
        VetvionaPalette.lightPrimary,
        isNot(equals(VetvionaPalette.darkPrimary)),
      );
    });

    test('light paper colour is light (high luminance)', () {
      // lightPaper = 0xFFF8F7F3 — almost white
      expect(VetvionaPalette.lightPaper.computeLuminance(), greaterThan(0.8));
    });

    test('dark paper colour is dark (low luminance)', () {
      // darkPaper = 0xFF1F1F1F — near black
      expect(VetvionaPalette.darkPaper.computeLuminance(), lessThan(0.1));
    });
  });

  group('ThemeProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('initial state', () {
      test('isDarkMode is false by default', () {
        final provider = ThemeProvider();
        expect(provider.isDarkMode, false);
      });

      test('primaryColor is the brand light primary by default', () {
        final provider = ThemeProvider();
        expect(provider.primaryColor, VetvionaPalette.lightPrimary);
      });

      test('theme is non-null on construction', () {
        final provider = ThemeProvider();
        expect(provider.theme, isNotNull);
        expect(provider.theme, isA<ThemeData>());
      });
    });

    group('setDarkMode', () {
      test('setDarkMode(true) switches isDarkMode to true', () async {
        final provider = ThemeProvider();
        await provider.setDarkMode(true);
        expect(provider.isDarkMode, true);
      });

      test('setDarkMode(false) switches isDarkMode back to false', () async {
        final provider = ThemeProvider();
        await provider.setDarkMode(true);
        await provider.setDarkMode(false);
        expect(provider.isDarkMode, false);
      });

      test('dark theme has dark brightness', () async {
        final provider = ThemeProvider();
        await provider.setDarkMode(true);
        expect(
          provider.theme.colorScheme.brightness,
          Brightness.dark,
        );
      });

      test('light theme has light brightness', () async {
        final provider = ThemeProvider();
        await provider.setDarkMode(false);
        expect(
          provider.theme.colorScheme.brightness,
          Brightness.light,
        );
      });

      test('setDarkMode persists value to SharedPreferences', () async {
        final provider = ThemeProvider();
        await provider.setDarkMode(true);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('isDarkMode'), true);
      });
    });

    group('setPrimaryColor', () {
      test('setPrimaryColor updates primaryColor', () async {
        final provider = ThemeProvider();
        const newColor = Color(0xFF123456);
        await provider.setPrimaryColor(newColor);
        expect(provider.primaryColor, newColor);
      });

      test('setPrimaryColor persists int value to SharedPreferences', () async {
        final provider = ThemeProvider();
        const newColor = Color(0xFF654321);
        await provider.setPrimaryColor(newColor);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('primaryColor'), newColor.value);
      });
    });

    group('loadTheme', () {
      test('loadTheme restores persisted dark mode setting', () async {
        SharedPreferences.setMockInitialValues({'isDarkMode': true});
        final provider = ThemeProvider();
        await provider.loadTheme();
        expect(provider.isDarkMode, true);
      });

      test('loadTheme restores persisted primary colour', () async {
        const savedColor = Color(0xFF112233);
        SharedPreferences.setMockInitialValues({
          'primaryColor': savedColor.value,
        });
        final provider = ThemeProvider();
        await provider.loadTheme();
        expect(provider.primaryColor, savedColor);
      });

      test('loadTheme defaults to light mode when no prefs exist', () async {
        SharedPreferences.setMockInitialValues({});
        final provider = ThemeProvider();
        await provider.loadTheme();
        expect(provider.isDarkMode, false);
      });

      test('loadTheme defaults to brand primary when no prefs exist', () async {
        SharedPreferences.setMockInitialValues({});
        final provider = ThemeProvider();
        await provider.loadTheme();
        expect(
          provider.primaryColor.value,
          VetvionaPalette.lightPrimary.value,
        );
      });
    });

    group('notifyListeners', () {
      test('setDarkMode triggers a change notification', () async {
        final provider = ThemeProvider();
        var notified = false;
        provider.addListener(() => notified = true);
        await provider.setDarkMode(true);
        expect(notified, true);
      });

      test('setPrimaryColor triggers a change notification', () async {
        final provider = ThemeProvider();
        var notified = false;
        provider.addListener(() => notified = true);
        await provider.setPrimaryColor(const Color(0xFFABCDEF));
        expect(notified, true);
      });

      test('loadTheme triggers a change notification', () async {
        final provider = ThemeProvider();
        var notified = false;
        provider.addListener(() => notified = true);
        await provider.loadTheme();
        expect(notified, true);
      });
    });
  });
}
