import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kbuzz/core/result.dart';
import 'package:kbuzz/data/ai/demo_data_generator.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';

/// The dataset the model returns (before validation). Includes records that MUST
/// be dropped: a dish on a missing station, a line on that dish, and a ticket
/// whose only line is invalid.
Map<String, Object?> _input() => <String, Object?>{
      'stations': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'grill',
          'name': 'Grill',
          'color': '#EF4444',
          'capacity': 2,
        },
        <String, Object?>{
          'id': 'wok',
          'name': 'Wok',
          'color': '0xFFF59E0B',
          'capacity': 1,
        },
      ],
      'menu': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'sekuwa',
          'name': 'Buff Sekuwa',
          'emoji': '🍢',
          'stationId': 'grill',
          'cookMins': 16,
          'holdable': true,
          'batchable': false,
        },
        <String, Object?>{
          'id': 'ghost',
          'name': 'Ghost Dish',
          'emoji': '👻',
          'stationId': 'nonexistent',
          'cookMins': 5,
          'holdable': false,
          'batchable': false,
        },
      ],
      'kots': <Map<String, Object?>>[
        <String, Object?>{
          'table': '5',
          'type': 'dineIn',
          'orderedMinsAgo': 2,
          'lines': <Map<String, Object?>>[
            <String, Object?>{'dishId': 'sekuwa', 'qty': 2, 'note': 'extra spicy'},
            <String, Object?>{'dishId': 'ghost', 'qty': 1},
          ],
        },
        <String, Object?>{
          'table': 'D21',
          'type': 'delivery',
          'orderedMinsAgo': 0,
          'lines': <Map<String, Object?>>[
            <String, Object?>{'dishId': 'ghost', 'qty': 1},
          ],
        },
      ],
    };

/// A Claude Messages envelope wrapping [text] as the model's reply.
String _claudeEnvelope(String text) => jsonEncode(<String, Object?>{
      'role': 'assistant',
      'stop_reason': 'end_turn',
      'content': <Map<String, Object?>>[
        <String, Object?>{'type': 'text', 'text': text},
      ],
    });

/// Build a response from UTF-8 bytes (so emoji survive the round-trip).
/// `http.Response(String, …)` would latin1-encode and throw on emoji.
http.Response _resp(String body, [int status = 200]) => http.Response.bytes(
      utf8.encode(body),
      status,
      headers: const <String, String>{'content-type': 'application/json'},
    );

DemoData _ok(Result<DemoData> r) {
  if (r is Err<DemoData>) {
    fail('expected Ok, got Err: ${r.failure.message}');
  }
  return (r as Ok<DemoData>).value;
}

void _expectValidated(DemoData data, DateTime now) {
  // Stations: both kept; hex and 0x colours both parse to opaque ARGB.
  expect(data.stations.map((Station s) => s.id), <String>['grill', 'wok']);
  expect(data.stations[1].color, 0xFFF59E0B);
  // Menu: the dish on the unknown station is dropped.
  expect(data.menu.map((Dish d) => d.id), <String>['sekuwa']);
  // Tickets: only the ticket with a valid line survives; bad line dropped.
  expect(data.kots.length, 1);
  final Kot kot = data.kots.single;
  expect(kot.id, 'ai-kot-1');
  expect(kot.table, '5');
  expect(kot.type, KotType.dineIn);
  expect(kot.lines.single.dishId, 'sekuwa');
  expect(kot.lines.single.qty, 2);
  expect(kot.lines.single.note, 'extra spicy'); // special instruction parsed
  expect(kot.orderedAt, now.subtract(const Duration(minutes: 2)));
}

void main() {
  final DateTime now = DateTime.utc(2026, 6, 21, 12);

  test('isConfigured is false without a key, and generate() fails fast',
      () async {
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((_) async => _resp('', 500)),
      apiKey: '',
    );
    expect(gen.isConfigured, isFalse);
    expect(gen.providerLabel, 'Claude');
    expect((await gen.generate(now: now)).isOk, isFalse);
  });

  test('fromEnvironment is unconfigured under flutter test (no dart-define)', () {
    final DemoDataGenerator gen = DemoDataGenerator.fromEnvironment(
      client: MockClient((_) async => _resp('', 500)),
    );
    expect(gen.isConfigured, isFalse);
  });

  test('parses the Messages reply and enforces referential integrity', () async {
    late http.Request captured;
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((http.Request req) async {
        captured = req;
        return _resp(_claudeEnvelope(jsonEncode(_input())));
      }),
      apiKey: 'g-test',
      model: 'claude-opus-4-8',
    );

    _expectValidated(_ok(await gen.generate(now: now)), now);

    // Hits the Messages endpoint with the key header + the chosen model in body.
    expect(captured.url.path, contains('/v1/messages'));
    expect(captured.headers['x-api-key'], 'g-test');
    expect(captured.headers['anthropic-version'], isNotEmpty);
    final Map<String, Object?> body =
        jsonDecode(captured.body) as Map<String, Object?>;
    expect(body['model'], 'claude-opus-4-8');
  });

  test('tolerates a ```json fenced body', () async {
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((_) async =>
          _resp(_claudeEnvelope('```json\n${jsonEncode(_input())}\n```'))),
      apiKey: 'g-test',
    );
    _expectValidated(_ok(await gen.generate(now: now)), now);
  });

  test('maps a non-200 into a short, plain-language failure (no API jargon)',
      () async {
    Future<AppFailure> failureFor(int status) async {
      final DemoDataGenerator gen = DemoDataGenerator(
        client: MockClient((_) async => _resp(
              jsonEncode(<String, Object?>{
                'error': <String, Object?>{
                  'code': status,
                  'message': 'API key not valid',
                  'status': 'PERMISSION_DENIED',
                },
              }),
              status,
            )),
        apiKey: 'g-bad',
      );
      return (await gen.generate(now: now) as Err<DemoData>).failure;
    }

    // 429 → quota wording; 403 → key/Profile guidance; neither leaks raw jargon.
    final AppFailure quota = await failureFor(429);
    expect(quota, isA<NetworkFailure>());
    expect(quota.message.toLowerCase(), contains('limit'));

    final AppFailure key = await failureFor(403);
    expect(key.message, contains('Profile'));

    expect(key.message, isNot(contains('PERMISSION_DENIED')));
    expect(key.message, isNot(contains('API key not valid')));
  });

  test('fails cleanly when the dataset has no schedulable tickets', () async {
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((_) async => _resp(_claudeEnvelope(jsonEncode(
            <String, Object?>{
              'stations': <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'grill',
                  'name': 'Grill',
                  'color': '#EF4444',
                  'capacity': 1,
                },
              ],
              'menu': <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'sekuwa',
                  'name': 'Buff Sekuwa',
                  'emoji': '🍢',
                  'stationId': 'grill',
                  'cookMins': 16,
                  'holdable': true,
                  'batchable': false,
                },
              ],
              'kots': <Map<String, Object?>>[],
            },
          )))),
      apiKey: 'g-test',
    );
    expect((await gen.generate(now: now)).isOk, isFalse);
  });

  test('non-JSON body → Err (not a thrown FormatException)', () async {
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((_) async => _resp('not json at all')),
      apiKey: 'g-test',
    );
    expect((await gen.generate(now: now)).isOk, isFalse);
  });

  test('model text decodes to a list, not an object → Err (shape guard)',
      () async {
    // Valid envelope, but the model's text is a JSON array — the `is! Map`
    // guard must turn this into a clean Err, not a caught TypeError.
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((_) async => _resp(_claudeEnvelope('[1, 2, 3]'))),
      apiKey: 'g-test',
    );
    expect((await gen.generate(now: now)).isOk, isFalse);
  });

  test('caps pathological note (80) and emoji (8) lengths from the model',
      () async {
    final String longNote = 'x' * 200;
    final String emojiRun = '🔥' * 50; // 50 code points
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((_) async => _resp(_claudeEnvelope(jsonEncode(
            <String, Object?>{
              'stations': <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'grill',
                  'name': 'Grill',
                  'color': '#EF4444',
                  'capacity': 2,
                },
              ],
              'menu': <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'sek',
                  'name': 'Sek',
                  'emoji': emojiRun,
                  'stationId': 'grill',
                  'cookMins': 10,
                  'holdable': true,
                  'batchable': false,
                },
              ],
              'kots': <Map<String, Object?>>[
                <String, Object?>{
                  'table': '5',
                  'type': 'dineIn',
                  'orderedMinsAgo': 1,
                  'lines': <Map<String, Object?>>[
                    <String, Object?>{
                      'dishId': 'sek',
                      'qty': 1,
                      'note': longNote,
                    },
                  ],
                },
              ],
            },
          )))),
      apiKey: 'g-test',
    );
    final DemoData data = _ok(await gen.generate(now: now));
    // Emoji clamped by code point (no split surrogate); note clamped to 80.
    expect(data.menu.single.emoji.runes.length, 8);
    expect(data.kots.single.lines.single.note, hasLength(80));
  });

  test(
      'station coherence: a hot dish on a cold station is repointed to a hot '
      'station; a salad with a hot word stays put', () async {
    final Map<String, Object?> input = <String, Object?>{
      'stations': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'grill', 'name': 'Grill', 'color': '#EF4444', 'capacity': 2,
        },
        <String, Object?>{
          'id': 'fry', 'name': 'Fryer', 'color': '#F97316', 'capacity': 2,
        },
        <String, Object?>{
          'id': 'cold', 'name': 'Cold & Sides', 'color': '#10B981',
          'capacity': 3,
        },
      ],
      'menu': <Map<String, Object?>>[
        // Mismatch: a fried item parked on the cold line → moves to the Fryer.
        <String, Object?>{
          'id': 'calamari', 'name': 'Fried Calamari', 'emoji': '🦑',
          'stationId': 'cold', 'cookMins': 6, 'holdable': false,
          'batchable': false,
        },
        // Legit cold salad that carries a hot word → vetoed, must NOT move.
        <String, Object?>{
          'id': 'gcs', 'name': 'Grilled Chicken Salad', 'emoji': '🥗',
          'stationId': 'cold', 'cookMins': 4, 'holdable': false,
          'batchable': false,
        },
        // Already coherent → unchanged.
        <String, Object?>{
          'id': 'steak', 'name': 'Grilled Ribeye', 'emoji': '🥩',
          'stationId': 'grill', 'cookMins': 14, 'holdable': true,
          'batchable': false,
        },
      ],
      'kots': <Map<String, Object?>>[
        <String, Object?>{
          'table': '5', 'type': 'dineIn', 'orderedMinsAgo': 1,
          'lines': <Map<String, Object?>>[
            <String, Object?>{'dishId': 'calamari', 'qty': 1},
          ],
        },
      ],
    };
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((_) async => _resp(_claudeEnvelope(jsonEncode(input)))),
      apiKey: 'g-test',
    );
    final DemoData data = _ok(await gen.generate(now: now));
    Dish byId(String id) => data.menu.firstWhere((Dish d) => d.id == id);

    expect(byId('calamari').stationId, 'fry'); // off cold → fits the fryer
    expect(byId('gcs').stationId, 'cold'); // salad veto → stays
    expect(byId('steak').stationId, 'grill'); // coherent → unchanged
  });

  test('station coherence: with no hot station, a misplaced dish is left as-is',
      () async {
    final Map<String, Object?> input = <String, Object?>{
      'stations': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'cold', 'name': 'Cold Bar', 'color': '#10B981', 'capacity': 2,
        },
        <String, Object?>{
          'id': 'bar', 'name': 'Bar', 'color': '#14B8A6', 'capacity': 2,
        },
      ],
      'menu': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'wings', 'name': 'Buffalo Wings', 'emoji': '🍗',
          'stationId': 'cold', 'cookMins': 8, 'holdable': false,
          'batchable': false,
        },
      ],
      'kots': <Map<String, Object?>>[
        <String, Object?>{
          'table': '7', 'type': 'dineIn', 'orderedMinsAgo': 0,
          'lines': <Map<String, Object?>>[
            <String, Object?>{'dishId': 'wings', 'qty': 1},
          ],
        },
      ],
    };
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((_) async => _resp(_claudeEnvelope(jsonEncode(input)))),
      apiKey: 'g-test',
    );
    final DemoData data = _ok(await gen.generate(now: now));
    expect(data.menu.single.stationId, 'cold'); // nowhere hot to move it
  });
}
