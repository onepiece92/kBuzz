import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kbuzz/core/result.dart';
import 'package:kbuzz/data/ai/ticket_scanner.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';

const List<Dish> _menu = <Dish>[
  Dish(
    id: 'burger',
    name: 'Burger',
    emoji: '🍔',
    stationId: 'grill',
    cookMins: 12,
    holdable: true,
    batchable: false,
  ),
  Dish(
    id: 'fries',
    name: 'Fries',
    emoji: '🍟',
    stationId: 'fry',
    cookMins: 6,
    holdable: false,
    batchable: true,
  ),
];

const List<Station> _stations = <Station>[
  Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 2),
  Station(id: 'fry', name: 'Fry', color: 0xFFF97316, capacity: 2),
];

final Uint8List _image = Uint8List.fromList(<int>[1, 2, 3, 4]);

/// A Gemini generateContent envelope wrapping [ticket] as the model's JSON reply.
String _geminiResponse(Map<String, Object?> ticket) =>
    jsonEncode(<String, Object?>{
      'candidates': <Map<String, Object?>>[
        <String, Object?>{
          'content': <String, Object?>{
            'role': 'model',
            'parts': <Map<String, Object?>>[
              <String, Object?>{'text': jsonEncode(ticket)},
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    });

http.Response _resp(String body, [int status = 200]) => http.Response.bytes(
      utf8.encode(body),
      status,
      headers: const <String, String>{'content-type': 'application/json'},
    );

TicketScanner _scanner(MockClient client, {String apiKey = 'test-key'}) =>
    TicketScanner(client: client, apiKey: apiKey);

void main() {
  test('not configured → Err without calling the network', () async {
    bool called = false;
    final TicketScanner scanner = _scanner(
      MockClient((http.Request _) async {
        called = true;
        return _resp('{}');
      }),
      apiKey: '',
    );
    final Result<ScannedTicket> r = await scanner.scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: _menu,
    );
    expect(r.isOk, isFalse);
    expect(called, isFalse);
  });

  test('empty menu → Err', () async {
    final TicketScanner scanner = _scanner(
      MockClient((http.Request _) async => _resp('{}')),
    );
    final Result<ScannedTicket> r = await scanner.scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: const <Dish>[],
    );
    expect(r.isOk, isFalse);
  });

  test('maps the Gemini reply into a ticket; drops unknown dish ids', () async {
    // Capture the request and assert on it AFTER (asserting inside the mock
    // would be swallowed by the scanner's error handling).
    http.Request? captured;
    final MockClient client = MockClient((http.Request req) async {
      captured = req;
      return _resp(_geminiResponse(<String, Object?>{
        'table': 'D21',
        'type': 'delivery',
        'lines': <Map<String, Object?>>[
          <String, Object?>{'dishId': 'burger', 'qty': 2},
          <String, Object?>{'dishId': 'ghost', 'qty': 9}, // not on menu → dropped
          <String, Object?>{'dishId': 'fries', 'qty': 1},
        ],
      }));
    });

    final Result<ScannedTicket> r = await _scanner(client)
        .scan(imageBytes: _image, mediaType: 'image/jpeg', menu: _menu);
    final ScannedTicket ticket = r.when(
      ok: (ScannedTicket t) => t,
      err: (AppFailure f) => fail(f.message),
    );

    expect(ticket.table, 'D21');
    expect(ticket.type, KotType.delivery);
    expect(ticket.lines, hasLength(2)); // ghost dropped
    expect(ticket.lines.first.dishId, 'burger');
    expect(ticket.lines.first.qty, 2);
    expect(ticket.lines.last.dishId, 'fries');

    // The request hit Gemini's vision endpoint with the key + inline image.
    expect(captured, isNotNull);
    expect(captured!.url.toString(), contains(':generateContent'));
    expect(captured!.headers['x-goog-api-key'], 'test-key');
    final Map<String, Object?> body =
        jsonDecode(captured!.body) as Map<String, Object?>;
    final List<Object?> parts = ((body['contents']! as List<Object?>).first
        as Map<String, Object?>)['parts']! as List<Object?>;
    expect(
      parts.any((Object? p) =>
          p is Map<String, Object?> && p.containsKey('inlineData')),
      isTrue,
    );
    expect(
      (body['generationConfig']! as Map<String, Object?>)['responseMimeType'],
      'application/json',
    );
  });

  test('keeps off-menu items as ad-hoc lines and parses cookMins', () async {
    final MockClient client = MockClient((http.Request _) async {
      return _resp(_geminiResponse(<String, Object?>{
        'table': '7',
        'type': 'dineIn',
        'lines': <Map<String, Object?>>[
          // matched menu line with an AI cook-time suggestion
          <String, Object?>{'dishId': 'burger', 'qty': 1, 'cookMins': 15},
          // off-menu item with a valid station + cook → kept as ad-hoc
          <String, Object?>{
            'name': 'Lobster Bisque',
            'stationId': 'fry',
            'qty': 2,
            'cookMins': 9,
          },
          // off-menu item with an invalid station → station dropped to null
          <String, Object?>{'name': 'Mystery Special', 'stationId': 'nope', 'qty': 1},
        ],
      }));
    });

    final Result<ScannedTicket> r = await _scanner(client).scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: _menu,
      stations: _stations,
    );
    final ScannedTicket t = r.when(
      ok: (ScannedTicket x) => x,
      err: (AppFailure f) => fail(f.message),
    );

    expect(t.lines, hasLength(3));
    // matched line carries the AI cook suggestion
    expect(t.lines[0].dishId, 'burger');
    expect(t.lines[0].isAdHoc, isFalse);
    expect(t.lines[0].cookMins, 15);
    // off-menu line: ad-hoc, validated station, cook
    expect(t.lines[1].dishId, isNull);
    expect(t.lines[1].isAdHoc, isTrue);
    expect(t.lines[1].name, 'Lobster Bisque');
    expect(t.lines[1].stationId, 'fry');
    expect(t.lines[1].cookMins, 9);
    // off-menu line with a bogus station → null (the caller defaults it)
    expect(t.lines[2].stationId, isNull);
    expect(t.lines[2].name, 'Mystery Special');
    expect(t.lines[2].cookMins, isNull);
  });

  test('no recognizable lines → Err', () async {
    final TicketScanner scanner = _scanner(MockClient((http.Request _) async {
      return _resp(_geminiResponse(<String, Object?>{
        'table': '5',
        'type': 'dineIn',
        'lines': <Map<String, Object?>>[
          <String, Object?>{'dishId': 'nope', 'qty': 1},
        ],
      }));
    }));
    final Result<ScannedTicket> r = await scanner.scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: _menu,
    );
    expect(r.isOk, isFalse);
  });

  test('HTTP error status → Err', () async {
    final TicketScanner scanner = _scanner(MockClient((http.Request _) async {
      return _resp('{"error":{"message":"overloaded"}}', 503);
    }));
    final Result<ScannedTicket> r = await scanner.scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: _menu,
    );
    expect(r.isOk, isFalse);
  });
}
