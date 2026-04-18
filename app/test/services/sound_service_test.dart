// Tests for SoundService that exercise state and SharedPreferences integration
// without requiring the AudioPlayer platform channel.
//
// SoundService is a singleton — AudioPlayer instances are only created in
// init(), which is never called from tests, so _players remains empty.
// All play* methods therefore hit the `player == null → return` early exit.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetviona_app/services/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Reset SharedPreferences and restore SoundService state after every test.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Ensure soundEnabled starts at its default (true).
    await SoundService.instance.setSoundEnabled(true);
  });

  // ── soundEnabled getter ───────────────────────────────────────────────────

  group('SoundService.soundEnabled', () {
    test('initial value is true before any call to setSoundEnabled', () {
      expect(SoundService.instance.soundEnabled, isTrue);
    });

    test('returns false after setSoundEnabled(false)', () async {
      await SoundService.instance.setSoundEnabled(false);
      expect(SoundService.instance.soundEnabled, isFalse);
    });

    test('returns true after setSoundEnabled(true)', () async {
      await SoundService.instance.setSoundEnabled(false);
      await SoundService.instance.setSoundEnabled(true);
      expect(SoundService.instance.soundEnabled, isTrue);
    });
  });

  // ── setSoundEnabled — SharedPreferences persistence ───────────────────────

  group('SoundService.setSoundEnabled persistence', () {
    test('persists false to SharedPreferences', () async {
      await SoundService.instance.setSoundEnabled(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('soundEnabled'), isFalse);
    });

    test('persists true to SharedPreferences', () async {
      await SoundService.instance.setSoundEnabled(true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('soundEnabled'), isTrue);
    });
  });

  // ── play methods — no-ops when not initialized ────────────────────────────
  //
  // Because init() is never called in tests, _players is empty.
  // _play() therefore returns immediately at `if (player == null) return;`.

  group('SoundService play methods (not initialized)', () {
    test('playSyncStart completes without error', () async {
      await expectLater(SoundService.instance.playSyncStart(), completes);
    });

    test('playSyncComplete completes without error', () async {
      await expectLater(SoundService.instance.playSyncComplete(), completes);
    });

    test('playSuccess completes without error', () async {
      await expectLater(SoundService.instance.playSuccess(), completes);
    });

    test('playFailure completes without error', () async {
      await expectLater(SoundService.instance.playFailure(), completes);
    });

    test('playWarning completes without error', () async {
      await expectLater(SoundService.instance.playWarning(), completes);
    });
  });

  // ── play methods — when soundEnabled=false ────────────────────────────────
  //
  // _play() returns early at `if (!_enabled) return;` so no AudioPlayer
  // interaction happens.

  group('SoundService play methods when disabled', () {
    setUp(() async {
      await SoundService.instance.setSoundEnabled(false);
    });

    test('playSyncStart completes without error when disabled', () async {
      await expectLater(SoundService.instance.playSyncStart(), completes);
    });

    test('playFailure completes without error when disabled', () async {
      await expectLater(SoundService.instance.playFailure(), completes);
    });

    test('playSuccess completes without error when disabled', () async {
      await expectLater(SoundService.instance.playSuccess(), completes);
    });
  });

  // ── dispose — no-op when players are empty ────────────────────────────────

  group('SoundService.dispose', () {
    test('dispose completes without error when not initialized', () async {
      // Create a fresh instance via the private path is impossible (singleton),
      // but the real singleton's dispose() should be safe even if players is
      // empty (which it always is in tests since init() is never called).
      await expectLater(SoundService.instance.dispose(), completes);
    });
  });
}
