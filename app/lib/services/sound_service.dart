import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plays short CC0 UI sounds for sync, success, failure, and warning events.
///
/// All audio files are procedurally generated sine-wave tones (public domain).
/// Sounds are gated by a user-controlled preference (`soundEnabled`).
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  bool _enabled = true;
  bool get soundEnabled => _enabled;

  // One player per sound so overlapping calls don't cancel each other.
  final _players = <_Sound, AudioPlayer>{};

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('soundEnabled') ?? true;

    for (final s in _Sound.values) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(0.85);
      _players[s] = player;
    }
  }

  Future<void> setSoundEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', value);
  }

  // ── Public play methods ───────────────────────────────────────────────────

  Future<void> playSyncStart() => _play(_Sound.syncStart);
  Future<void> playSyncComplete() => _play(_Sound.syncComplete);
  Future<void> playSuccess() => _play(_Sound.success);
  Future<void> playFailure() => _play(_Sound.failure);
  Future<void> playWarning() => _play(_Sound.warning);

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _play(_Sound sound) async {
    if (!_enabled) return;
    final player = _players[sound];
    if (player == null) return;
    try {
      await player.stop();
      await player.play(AssetSource(sound.assetPath));
    } catch (_) {
      // Audio is non-critical; swallow errors silently.
    }
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}

enum _Sound {
  syncStart('sounds/sync_start.wav'),
  syncComplete('sounds/sync_complete.wav'),
  success('sounds/success.wav'),
  failure('sounds/failure.wav'),
  warning('sounds/warning.wav');

  const _Sound(this.assetPath);
  final String assetPath;
}
