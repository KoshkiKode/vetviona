import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool get _isCupertinoHost =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

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
  // Tonal surface containers (light)
  static const lightSurfaceContainer     = Color(0xFFEDEDE8);
  static const lightSurfaceContainerLow  = Color(0xFFF2F1EC);
  static const lightSurfaceContainerHigh = Color(0xFFE7E6E1);

  // Dark mode
  static const darkPrimary    = Color(0xFF2D5A4F);
  static const darkSecondary  = Color(0xFF1A3C34);
  static const darkAccent     = Color(0xFF5A9A87);
  static const darkPaper      = Color(0xFF121412);
  static const darkInk        = Color(0xFFF8F7F3);
  static const darkDust       = Color(0xFF8B8B7F);
  static const darkBrass      = Color(0xFFC9A86E);
  static const darkBurgundy   = Color(0xFF8B3E40);
  static const darkSlate      = Color(0xFF6B7280);
  static const darkLinen      = Color(0xFF1E2420);
  // Tonal surface containers (dark)
  static const darkSurfaceContainer     = Color(0xFF232823);
  static const darkSurfaceContainerLow  = Color(0xFF1A1E1A);
  static const darkSurfaceContainerHigh = Color(0xFF2B302B);
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
    const surfaceContainer     = VetvionaPalette.lightSurfaceContainer;
    const surfaceContainerLow  = VetvionaPalette.lightSurfaceContainerLow;
    const surfaceContainerHigh = VetvionaPalette.lightSurfaceContainerHigh;

    // Use the user-chosen primary if they've customised it, else brand primary
    final effectivePrimary = primary == p ? p : primary;

    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: effectivePrimary,
      onPrimary: paper,
      primaryContainer: acc.withOpacity(0.25),
      onPrimaryContainer: effectivePrimary,
      secondary: sec,
      onSecondary: paper,
      secondaryContainer: acc.withOpacity(0.18),
      onSecondaryContainer: sec,
      tertiary: acc,
      onTertiary: ink,
      tertiaryContainer: acc.withOpacity(0.15),
      onTertiaryContainer: effectivePrimary,
      error: burg,
      onError: paper,
      errorContainer: burg.withOpacity(0.12),
      onErrorContainer: burg,
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: slate,
      surfaceContainerLowest: paper,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: linen,
      inverseSurface: ink,
      onInverseSurface: paper,
      inversePrimary: acc,
      outline: dust,
      outlineVariant: brass.withOpacity(0.4),
      shadow: slate,
      scrim: Colors.black,
    );

    return _applySharedTheme(
      scheme, effectivePrimary, dust,
    );
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
    const surfaceContainer     = VetvionaPalette.darkSurfaceContainer;
    const surfaceContainerLow  = VetvionaPalette.darkSurfaceContainerLow;
    const surfaceContainerHigh = VetvionaPalette.darkSurfaceContainerHigh;

    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: p,
      onPrimary: ink,
      primaryContainer: p.withOpacity(0.35),
      onPrimaryContainer: acc,
      secondary: sec,
      onSecondary: ink,
      secondaryContainer: sec.withOpacity(0.4),
      onSecondaryContainer: acc,
      tertiary: acc,
      onTertiary: paper,
      tertiaryContainer: acc.withOpacity(0.2),
      onTertiaryContainer: ink,
      error: burg,
      onError: ink,
      errorContainer: burg.withOpacity(0.25),
      onErrorContainer: burg,
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: slate,
      surfaceContainerLowest: paper,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: linen,
      inverseSurface: ink,
      onInverseSurface: paper,
      inversePrimary: acc,
      outline: dust,
      outlineVariant: brass.withOpacity(0.3),
      shadow: slate,
      scrim: Colors.black,
    );

    return _applySharedTheme(scheme, p, dust);
  }

  // ── Shared widget theming ───────────────────────────────────────────────

  static ThemeData _applySharedTheme(
    ColorScheme scheme,
    Color primary,
    Color dust,
  ) {
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: primary.withOpacity(0.3),
        surfaceTintColor: primary,
        centerTitle: _isCupertinoHost,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: scheme.onPrimary),
        actionsIconTheme: IconThemeData(color: scheme.onPrimary),
        titleTextStyle: TextStyle(
          color: scheme.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
        ),
      ),

      // ── Cards ───────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: dust.withOpacity(isDark ? 0.12 : 0.15),
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: dust.withOpacity(0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        floatingLabelStyle: TextStyle(color: primary),
      ),

      // ── Buttons ─────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          elevation: 1,
          shadowColor: primary.withOpacity(0.35),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ).copyWith(
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 2;
            return 1;
          }),
          shadowColor: WidgetStatePropertyAll(primary.withOpacity(0.3)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: primary.withOpacity(0.5)),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),

      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.tertiary,
        foregroundColor: scheme.onTertiary,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 5,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
      ),

      // ── Chips ───────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.secondaryContainer,
        secondarySelectedColor: scheme.secondaryContainer,
        checkmarkColor: scheme.onSecondaryContainer,
        side: BorderSide(color: dust.withOpacity(0.2)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        labelStyle: TextStyle(color: scheme.onSurface, fontSize: 13),
      ),

      // ── Dialogs ─────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: primary,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.15),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28)),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // ── Bottom Sheet ─────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: primary,
        elevation: 2,
        showDragHandle: true,
        dragHandleColor: dust.withOpacity(0.5),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: const BoxConstraints(maxWidth: 640),
      ),

      // ── Navigation Bar (bottom nav) ──────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        surfaceTintColor: primary,
        elevation: 3,
        height: 72,
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
                color: scheme.onSecondaryContainer, size: 22);
          }
          return IconThemeData(
              color: scheme.onSurfaceVariant, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 12);
          }
          return TextStyle(
              color: scheme.onSurfaceVariant, fontSize: 12);
        }),
      ),

      // ── Navigation Drawer ─────────────────────────────────────────────────
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        surfaceTintColor: primary,
        elevation: 1,
        tileHeight: 52,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600);
          }
          return TextStyle(color: scheme.onSurface);
        }),
      ),

      // ── Drawer ───────────────────────────────────────────────────────────
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: primary,
        elevation: 1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
      ),

      // ── PopupMenu ─────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: primary,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        textStyle: TextStyle(color: scheme.onSurface, fontSize: 14),
      ),

      // ── Snack Bar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
            color: scheme.onInverseSurface, fontSize: 14),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: dust.withOpacity(isDark ? 0.15 : 0.25),
      ),

      // ── Switch ───────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : dust),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? primary.withOpacity(0.4)
                : dust.withOpacity(0.2)),
      ),

      // ── List Tiles ───────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        iconColor: scheme.tertiary,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),

      // ── Tooltip ───────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(
            color: scheme.onInverseSurface, fontSize: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Progress Indicator ─────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: dust.withOpacity(0.2),
        circularTrackColor: dust.withOpacity(0.15),
        linearMinHeight: 6,
      ),

      // ── Badge ─────────────────────────────────────────────────────────────
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        smallSize: 8,
        largeSize: 18,
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
