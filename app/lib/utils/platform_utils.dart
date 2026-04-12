import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Platform detection ─────────────────────────────────────────────────────

/// True on iOS (device or simulator).
bool get isIOS =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// True on macOS.
bool get isMacOS =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// True on any Apple platform — use to decide between Cupertino and Material
/// widgets / behaviours.
bool get isCupertino => isIOS || isMacOS;

/// True on Android.
bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// True on any traditional desktop (Windows, macOS, Linux).
bool get isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// True on a handheld mobile platform (iOS or Android).
bool get isMobile => isIOS || isAndroid;

// ── Scroll physics ─────────────────────────────────────────────────────────

/// Returns [BouncingScrollPhysics] on iOS/macOS (the platform expects elastic
/// over-scroll), and [ClampingScrollPhysics] everywhere else.
ScrollPhysics adaptiveScrollPhysics() =>
    isCupertino ? const BouncingScrollPhysics() : const ClampingScrollPhysics();

// ── System UI overlay ──────────────────────────────────────────────────────

/// A [SystemUiOverlayStyle] appropriate for a surface whose background is
/// [backgroundColor].  On dark surfaces the status-bar icons should be light;
/// on light surfaces they should be dark.
SystemUiOverlayStyle systemUiStyleFor({
  required Color backgroundColor,
  required Brightness surfaceBrightness,
}) {
  final iconsAreDark = surfaceBrightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness:
        iconsAreDark ? Brightness.light : Brightness.dark,
    // iOS uses statusBarBrightness (inverted polarity vs Android)
    statusBarBrightness:
        iconsAreDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: backgroundColor,
    systemNavigationBarIconBrightness:
        iconsAreDark ? Brightness.light : Brightness.dark,
  );
}

// ── Adaptive date picker ───────────────────────────────────────────────────

/// Shows a native-feeling date picker:
/// - **iOS / macOS**: a [CupertinoDatePicker] inside a modal bottom sheet
///   (matches the standard iOS "wheels in a sheet" pattern).
/// - **Android / desktop**: the standard Material [showDatePicker] dialog.
///
/// Returns the selected [DateTime], or `null` if the user dismisses.
Future<DateTime?> pickDateAdaptive(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  firstDate ??= DateTime(1700);
  lastDate ??= DateTime(2100);

  if (isCupertino) {
    DateTime selected = initialDate;
    final result = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final isDark = colorScheme.brightness == Brightness.dark;
        return Container(
          height: 320,
          color: isDark ? CupertinoColors.systemBackground.darkColor : CupertinoColors.systemBackground,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Toolbar row with Cancel / Done
                SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () => Navigator.of(ctx).pop(null),
                        child: const Text('Cancel'),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () => Navigator.of(ctx).pop(selected),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: initialDate,
                    minimumDate: firstDate,
                    maximumDate: lastDate,
                    onDateTimeChanged: (dt) => selected = dt,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result;
  }

  // Material fallback
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );
}
