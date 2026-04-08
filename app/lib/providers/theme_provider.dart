import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  Color _primaryColor = Colors.blue;

  Color get primaryColor => _primaryColor;

  ThemeData get theme => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _primaryColor),
    useMaterial3: true,
  );

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primaryColor', color.value);
    notifyListeners();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('primaryColor') ?? Colors.blue.value;
    _primaryColor = Color(colorValue);
    notifyListeners();
  }
}
