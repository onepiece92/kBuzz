import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kbuzz/core/result.dart';
import 'package:kbuzz/data/ai/demo_data_generator.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';

/// The dataset Gemini returns (before validation). Includes records that MUST be
/// dropped: a dish on a missing station, a line on that dish, and a ticket whose
/// only line is invalid.
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
            <String, Object?>{'dishId': 'sekuwa', 'qty': 2},
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

/// A Gemini generateContent envelope wrapping [text] as the model's reply.
String _geminiEnvelope(String text) => jsonEncode(<String, Object?>{
      'candidates': <Map<String, Object?>>[
        <String, Object?>{
          'content': <String, Object?>{
            'role': 'model',
            'parts': <Map<String, Object?>>[
              <String, Object?>{'text': text},
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    });

/// Build a response from UTF-8 bytes (mirrors how Gemini sends emoji).
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
    expect(gen.providerLabel, 'Gemini');
    expect((await gen.generate(now: now)).isOk, isFalse);
  });

  test('fromEnvironment is unconfigured under flutter test (no dart-define)', () {
    final DemoDataGenerator gen = DemoDataGenerator.fromEnvironment(
      client: MockClient((_) async => _resp('', 500)),
    );
    expect(gen.isConfigured, isFalse);
  });

  test('parses generateContent and enforces referential integrity', () async {
    late http.Request captured;
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((http.Request req) async {
        captured = req;
        return _resp(_geminiEnvelope(jsonEncode(_input())));
      }),
      apiKey: 'g-test',
      model: 'gemini-2.0-flash',
    );

    _expectValidated(_ok(await gen.generate(now: now)), now);

    // Hits the right model endpoint with the key header + JSON mime config.
    expect(captured.url.path, contains('gemini-2.0-flash:generateContent'));
    expect(captured.headers['x-goog-api-key'], 'g-test');
    final Map<String, Object?> body =
        jsonDecode(captured.body) as Map<String, Object?>;
    expect(
      (body['generationConfig']! as Map<String, Object?>)['responseMimeType'],
      'application/json',
    );
  });

  test('tolerates a ```json fenced body', () async {
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((_) async =>
          _resp(_geminiEnvelope('```json\n${jsonEncode(_input())}\n```'))),
      apiKey: 'g-test',
    );
    _expectValidated(_ok(await gen.generate(now: now)), now);
  });

  test('maps a non-200 into a NetworkFailure with the API message', () async {
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((_) async => _resp(
            jsonEncode(<String, Object?>{
              'error': <String, Object?>{
                'code': 400,
                'message': 'API key not valid',
                'status': 'INVALID_ARGUMENT',
              },
            }),
            400,
          )),
      apiKey: 'g-bad',
    );
    final AppFailure failure =
        (await gen.generate(now: now) as Err<DemoData>).failure;
    expect(failure, isA<NetworkFailure>());
    expect(failure.message, contains('API key not valid'));
  });

  test('fails cleanly when the dataset has no schedulable tickets', () async {
    final DemoDataGenerator gen = DemoDataGenerator(
      client: MockClient((_) async => _resp(_geminiEnvelope(jsonEncode(
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
}
