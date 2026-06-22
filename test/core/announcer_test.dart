import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/announce/announcer.dart';

/// A [TtsEngine] whose `speak` stays "in flight" until the test completes it,
/// so we can observe how [SystemAnnouncer] paces and bounds its queue.
class _FakeTts implements TtsEngine {
  final List<String> spoken = <String>[];
  final List<Completer<void>> _inFlight = <Completer<void>>[];
  bool? awaitSet;

  @override
  Future<void> awaitCompletion(bool value) async => awaitSet = value;

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    final Completer<void> c = Completer<void>();
    _inFlight.add(c);
    return c.future;
  }

  /// Finish the oldest still-speaking utterance.
  void finish() => _inFlight.removeAt(0).complete();
  int get inFlight => _inFlight.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('configures the engine to await speech completion', () async {
    final _FakeTts tts = _FakeTts();
    SystemAnnouncer(engine: tts);
    await pumpEventQueue();
    expect(tts.awaitSet, isTrue);
  });

  test('queues utterances: the next waits for the current to finish', () async {
    final _FakeTts tts = _FakeTts();
    final SystemAnnouncer ann = SystemAnnouncer(engine: tts);

    unawaited(ann.announce('one'));
    unawaited(ann.announce('two'));
    await pumpEventQueue();

    // Only the first has started; the second is held, not interrupting it.
    expect(tts.spoken, <String>['one']);
    expect(tts.inFlight, 1);

    tts.finish(); // 'one' completes
    await pumpEventQueue();

    // Now the second begins.
    expect(tts.spoken, <String>['one', 'two']);
    tts.finish();
    await pumpEventQueue();
  });

  test('drops the oldest pending line when the queue overflows', () async {
    final _FakeTts tts = _FakeTts();
    final SystemAnnouncer ann = SystemAnnouncer(engine: tts, maxQueued: 2);

    unawaited(ann.announce('a')); // starts speaking immediately
    await pumpEventQueue();
    expect(tts.spoken, <String>['a']);

    // While 'a' is in flight, pile on more than maxQueued pending lines.
    unawaited(ann.announce('b'));
    unawaited(ann.announce('c'));
    unawaited(ann.announce('d'));
    unawaited(ann.announce('e'));
    await pumpEventQueue();

    // 'b' and 'c' are dropped (oldest); 'd' and 'e' survive.
    tts.finish(); // 'a' done -> 'd' next
    await pumpEventQueue();
    expect(tts.spoken, <String>['a', 'd']);

    tts.finish(); // 'd' done -> 'e'
    await pumpEventQueue();
    expect(tts.spoken, <String>['a', 'd', 'e']);

    tts.finish();
    await pumpEventQueue();
  });
}
