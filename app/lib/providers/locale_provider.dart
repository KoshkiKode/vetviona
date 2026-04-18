import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.toLanguageTag());
  }

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final tag = prefs.getString('locale');
    if (tag != null) {
      final parts = tag.split('-');
      _locale = Locale(parts[0], parts.length > 1 ? parts[1] : null);
      notifyListeners();
    }
  }
}
