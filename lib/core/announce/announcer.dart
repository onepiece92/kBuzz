import 'package:flutter/services.dart' show SystemSound, SystemSoundType;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kbuzz/core/logger.dart';

/// Speaks/chimes the "fire next" alert so the chef hears it without looking
/// (AGENTS.md §10.5). A side-effecting platform concern, wrapped behind this
/// abstraction so it can be injected and no-op'd in tests/CI.
///
/// **On-device only — must work offline (§0.1).** Never call a cloud TTS API.
abstract class Announcer {
  Future<void> announce(String text);
  Future<void> chime();
}

/// Does nothing — the default in tests/CI and when audio is muted.
class NoopAnnouncer implements Announcer {
  const NoopAnnouncer();

  @override
  Future<void> announce(String text) async {}

  @override
  Future<void> chime() async {}
}

/// The on-device text-to-speech surface [SystemAnnouncer] drives. Wrapped behind
/// this seam so the queueing logic is unit-testable with a fake — real TTS needs
/// a device/platform channel.
abstract class TtsEngine {
  /// Make [speak] resolve only when the utterance *finishes* (not when it merely
  /// starts), so the queue can wait for one line before beginning the next.
  Future<void> awaitCompletion(bool value);

  /// Speak [text]. With [awaitCompletion] set, the future resolves when done.
  Future<void> speak(String text);
}

/// Real announcer: a short attention [chime] (the platform alert sound — no
/// bundled asset, works offline) then on-device TTS via `flutter_tts`.
///
/// Utterances are **queued, not interrupted** — each fire line finishes before
/// the next begins, so a burst (e.g. fast-forward demo speed) never garbles
/// mid-word. The queue holds at most [maxQueued] *pending* lines; on overflow
/// the **oldest pending** line is dropped (the toast still shows it) so audio
/// stays current instead of falling minutes behind.
///
/// All calls are best-effort: audio failures are logged and swallowed so a
/// missing TTS engine never breaks the run.
class SystemAnnouncer implements Announcer {
  SystemAnnouncer({TtsEngine? engine, this.maxQueued = 4})
      : _engine = engine ?? _FlutterTtsEngine() {
    // speak() should resolve on completion so the queue can pace itself.
    _engine.awaitCompletion(true);
  }

  final TtsEngine _engine;

  /// Max *pending* (not-yet-started) utterances; the oldest is dropped past this.
  final int maxQueued;

  static const Logger _log = Logger('announcer');

  /// Lines waiting their turn (FIFO). The line currently being spoken is not
  /// here — it's already been removed and is awaiting completion.
  final List<String> _pending = <String>[];
  bool _draining = false;

  @override
  Future<void> chime() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } on Object catch (e) {
      _log.warning('chime failed: $e');
    }
  }

  @override
  Future<void> announce(String text) async {
    _pending.add(text);
    while (_pending.length > maxQueued) {
      _pending.removeAt(0); // drop the oldest, keep the most recent fires
      _log.warning('speech queue full; dropped an utterance');
    }
    if (_draining) return; // an in-progress drain loop will pick this up
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final String next = _pending.removeAt(0);
        await chime();
        try {
          await _engine.speak(next); // resolves when the utterance finishes
        } on Object catch (e, st) {
          _log.error('announce failed', error: e, stackTrace: st);
        }
      }
    } finally {
      _draining = false;
    }
  }
}

/// [TtsEngine] backed by `flutter_tts` — the real, on-device implementation.
class _FlutterTtsEngine implements TtsEngine {
  _FlutterTtsEngine([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> awaitCompletion(bool value) async {
    await _tts.awaitSpeakCompletion(value);
  }

  @override
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }
}
