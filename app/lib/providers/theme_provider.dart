import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Vetviona Brand Palette ──────────────────────────────────────────────────

class VetvionaPalette {
  // Light mode
  static const lightPrimary   = Color(0xFF1A3C34);
  static const lightSecondary = Color(0xFF2D5A4F);
  static const lightAccent    = Color(0xFF5A9A87);
  static const lightPaper     = Color(0xFFF8F7F3);
  static const lightInk       = Color(0xFF1F1F1F);
  static const lightDust      = Color(0xFF8B8B7F);
  static const lightBrass     = Color(0xFFC9A86E);
  static const lightBurgundy  = Color(0xFF5C2D2E);
  static const lightSlate     = Color(0xFF4A5568);
  static const lightLinen     = Color(0xFFF5F3EE);

  // Dark mode
  static const darkPrimary    = Color(0xFF2D5A4F);
  static const darkSecondary  = Color(0xFF1A3C34);
  static const darkAccent     = Color(0xFF5A9A87);
  static const darkPaper      = Color(0xFF1F1F1F);
  static const darkInk        = Color(0xFFF8F7F3);
  static const darkDust       = Color(0xFF8B8B7F);
  static const darkBrass      = Color(0xFFC9A86E);
  static const darkBurgundy   = Color(0xFF8B3E40);
  static const darkSlate      = Color(0xFF6B7280);
  static const darkLinen      = Color(0xFF2D2D2D);
}

// ── Theme Provider ──────────────────────────────────────────────────────────

class ThemeProvider with ChangeNotifier {
  Color _primaryColor = VetvionaPalette.lightPrimary;
  bool _isDarkMode = false;

  Color get primaryColor => _primaryColor;
  bool get isDarkMode => _isDarkMode;

  ThemeData get theme =>
      _isDarkMode ? _buildDarkTheme() : _buildLightTheme(_primaryColor);

  // ── Light Theme ─────────────────────────────────────────────────────────

  static ThemeData _buildLightTheme(Color primary) {
    const p = VetvionaPalette.lightPrimary;
    const sec = VetvionaPalette.lightSecondary;
    const acc = VetvionaPalette.lightAccent;
    const paper = VetvionaPalette.lightPaper;
    const ink = VetvionaPalette.lightInk;
    const dust = VetvionaPalette.lightDust;
    const brass = VetvionaPalette.lightBrass;
    const burg = VetvionaPalette.lightBurgundy;
    const slate = VetvionaPalette.lightSlate;
    const linen = VetvionaPalette.lightLinen;

    // Use the user-chosen primary if they've customised it, else brand primary
    final effectivePrimary = primary == p ? p : primary;

    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: effectivePrimary,
      onPrimary: paper,
      secondary: sec,
      onSecondary: paper,
      tertiary: acc,
      onTertiary: ink,
      error: burg,
      onError: paper,
      surface: paper,
      onSurface: ink,
      surfaceContainerHighest: linen,
      outline: dust,
      outlineVariant: brass,
      shadow: slate,
    );

    return _applySharedTheme(scheme, effectivePrimary, paper, ink, dust, linen);
  }

  // ── Dark Theme ──────────────────────────────────────────────────────────

  static ThemeData _buildDarkTheme() {
    const p = VetvionaPalette.darkPrimary;
    const sec = VetvionaPalette.darkSecondary;
    const acc = VetvionaPalette.darkAccent;
    const paper = VetvionaPalette.darkPaper;
    const ink = VetvionaPalette.darkInk;
    const dust = VetvionaPalette.darkDust;
    const brass = VetvionaPalette.darkBrass;
    const burg = VetvionaPalette.darkBurgundy;
    const slate = VetvionaPalette.darkSlate;
    const linen = VetvionaPalette.darkLinen;

    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: p,
      onPrimary: ink,
      secondary: sec,
      onSecondary: ink,
      tertiary: acc,
      onTertiary: paper,
      error: burg,
      onError: ink,
      surface: paper,
      onSurface: ink,
      surfaceContainerHighest: linen,
      outline: dust,
      outlineVariant: brass,
      shadow: slate,
    );

    return _applySharedTheme(scheme, p, paper, ink, dust, linen);
  }

  // ── Shared widget theming ───────────────────────────────────────────────

  static ThemeData _applySharedTheme(
    ColorScheme scheme,
    Color primary,
    Color paper,
    Color ink,
    Color dust,
    Color linen,
  ) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: linen,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: linen,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dust.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.tertiary,
        foregroundColor: scheme.onTertiary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: linen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: dust.withOpacity(0.3),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : dust),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? primary.withOpacity(0.4)
                : dust.withOpacity(0.2)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.tertiary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.secondary,
        contentTextStyle: TextStyle(color: scheme.onSecondary),
      ),
    );
  }

  // ── Persistence ─────────────────────────────────────────────────────────

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primaryColor', color.value);
    notifyListeners();
  }

  Future<void> setDarkMode(bool dark) async {
    _isDarkMode = dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', dark);
    notifyListeners();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue =
        prefs.getInt('primaryColor') ?? VetvionaPalette.lightPrimary.value;
    _primaryColor = Color(colorValue);
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }
}
