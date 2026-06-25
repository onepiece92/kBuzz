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

/// A Claude Messages envelope wrapping [ticket] as the model's JSON reply.
String _claudeResponse(Map<String, Object?> ticket) =>
    jsonEncode(<String, Object?>{
      'role': 'assistant',
      'stop_reason': 'end_turn',
      'content': <Map<String, Object?>>[
        <String, Object?>{'type': 'text', 'text': jsonEncode(ticket)},
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

  test('empty menu AND no stations → Err', () async {
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

  test('empty menu but stations given → every item is ad-hoc (no-data scan)',
      () async {
    final TicketScanner scanner = _scanner(MockClient((http.Request _) async {
      return _resp(_claudeResponse(<String, Object?>{
        'table': '7',
        'type': 'dineIn',
        'lines': <Map<String, Object?>>[
          <String, Object?>{
            'name': 'Mystery Stew',
            'stationId': 'fry',
            'qty': 2,
            'cookMins': 9,
          },
        ],
      }));
    }));
    final Result<ScannedTicket> r = await scanner.scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: const <Dish>[], // nothing to match against …
      stations: _stations, // … but stations to assign ad-hoc items to
    );
    final ScannedTicket t = r.when(
      ok: (ScannedTicket x) => x,
      err: (AppFailure f) => fail(f.message),
    );
    expect(t.lines, hasLength(1));
    expect(t.lines.single.isAdHoc, isTrue);
    expect(t.lines.single.dishId, isNull);
    expect(t.lines.single.name, 'Mystery Stew');
    expect(t.lines.single.stationId, 'fry');
  });

  test('maps the Claude reply into a ticket; drops unknown dish ids', () async {
    // Capture the request and assert on it AFTER (asserting inside the mock
    // would be swallowed by the scanner's error handling).
    http.Request? captured;
    final MockClient client = MockClient((http.Request req) async {
      captured = req;
      return _resp(_claudeResponse(<String, Object?>{
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

    // The request hit Claude's Messages endpoint with the key + image block.
    expect(captured, isNotNull);
    expect(captured!.url.toString(), contains('/v1/messages'));
    expect(captured!.headers['x-api-key'], 'test-key');
    expect(captured!.headers['anthropic-version'], isNotEmpty);
    final Map<String, Object?> body =
        jsonDecode(captured!.body) as Map<String, Object?>;
    expect(body['model'], isNotNull);
    final List<Object?> content = ((body['messages']! as List<Object?>).first
        as Map<String, Object?>)['content']! as List<Object?>;
    expect(
      content.any((Object? c) =>
          c is Map<String, Object?> && c['type'] == 'image'),
      isTrue,
    );
  });

  test('keeps off-menu items as ad-hoc lines and parses cookMins', () async {
    final MockClient client = MockClient((http.Request _) async {
      return _resp(_claudeResponse(<String, Object?>{
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
      return _resp(_claudeResponse(<String, Object?>{
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

  test('401 → Err pointing the user at the key', () async {
    final TicketScanner scanner = _scanner(MockClient((http.Request _) async {
      return _resp('{"error":{"message":"invalid x-api-key"}}', 401);
    }));
    final Result<ScannedTicket> r = await scanner.scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: _menu,
    );
    r.when(
      ok: (_) => fail('a 401 must not produce a ticket'),
      err: (AppFailure f) => expect(f.message.toLowerCase(), contains('key')),
    );
  });

  test('network exception → Err (no crash escapes scan)', () async {
    final TicketScanner scanner = _scanner(MockClient((http.Request _) async {
      throw Exception('connection reset');
    }));
    final Result<ScannedTicket> r = await scanner.scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: _menu,
    );
    expect(r.isOk, isFalse);
  });

  test('non-JSON body → Err (not a thrown FormatException)', () async {
    final TicketScanner scanner = _scanner(
      MockClient((http.Request _) async => _resp('totally not json')),
    );
    final Result<ScannedTicket> r = await scanner.scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: _menu,
    );
    expect(r.isOk, isFalse);
  });

  test('envelope decodes to a JSON array, not an object → Err (shape guard)',
      () async {
    final TicketScanner scanner =
        _scanner(MockClient((http.Request _) async => _resp('[1, 2, 3]')));
    final Result<ScannedTicket> r = await scanner.scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: _menu,
    );
    expect(r.isOk, isFalse);
  });

  test('model text decodes to a list, not an object → Err (inner shape guard)',
      () async {
    // A valid Claude envelope whose text block is a JSON array rather than the
    // expected ticket object — the inner `is! Map` guard must catch it cleanly.
    final String envelope = jsonEncode(<String, Object?>{
      'content': <Map<String, Object?>>[
        <String, Object?>{'type': 'text', 'text': '[1, 2, 3]'},
      ],
    });
    final TicketScanner scanner =
        _scanner(MockClient((http.Request _) async => _resp(envelope)));
    final Result<ScannedTicket> r = await scanner.scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: _menu,
    );
    expect(r.isOk, isFalse);
  });

  test('caps an over-long ad-hoc line name at 80 chars', () async {
    final String longName = 'A' * 200;
    final TicketScanner scanner = _scanner(MockClient((http.Request _) async {
      return _resp(_claudeResponse(<String, Object?>{
        'table': '5',
        'type': 'dineIn',
        'lines': <Map<String, Object?>>[
          <String, Object?>{'name': longName, 'stationId': 'fry', 'qty': 1},
        ],
      }));
    }));
    final ScannedTicket t = (await scanner.scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: _menu,
      stations: _stations,
    ))
        .when(ok: (ScannedTicket x) => x, err: (AppFailure f) => fail(f.message));
    expect(t.lines.single.name, hasLength(80));
  });

  test('caps an over-long table label at 16 chars', () async {
    final TicketScanner scanner = _scanner(MockClient((http.Request _) async {
      return _resp(_claudeResponse(<String, Object?>{
        'table': 'T' * 50,
        'type': 'dineIn',
        'lines': <Map<String, Object?>>[
          <String, Object?>{'dishId': 'burger', 'qty': 1},
        ],
      }));
    }));
    final ScannedTicket t = (await scanner.scan(
      imageBytes: _image,
      mediaType: 'image/jpeg',
      menu: _menu,
    ))
        .when(ok: (ScannedTicket x) => x, err: (AppFailure f) => fail(f.message));
    expect(t.table, hasLength(16));
  });
}
