import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:kbuzz/core/logger.dart';
import 'package:kbuzz/core/result.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';

/// A ticket parsed from a photo: table, type, and line items mapped to the
/// restaurant's known menu (by dish id).
class ScannedTicket {
  const ScannedTicket({
    required this.table,
    required this.type,
    required this.lines,
  });

  final String table;
  final KotType type;
  final List<ScannedLine> lines;
}

/// One parsed line. [dishId] is set when the item matched a menu id; otherwise
/// it's an off-menu item carrying its raw [name] + a suggested [stationId] so the
/// review screen can turn it into an ad-hoc dish. [cookMins] is the model's
/// advisory cook-time estimate (null if it didn't suggest one).
class ScannedLine {
  const ScannedLine({
    required this.qty,
    this.dishId,
    this.name = '',
    this.stationId,
    this.cookMins,
  });

  final int qty;
  final String? dishId;
  final String name;
  final String? stationId;
  final int? cookMins;

  /// True when this item isn't on the menu (so it becomes an ad-hoc dish).
  bool get isAdHoc => dishId == null;
}

/// Reads a photographed KOT into a [ScannedTicket] via Google Gemini **vision**
/// (`generateContent` with an inline image part + JSON response mode), mapping
/// items onto the supplied menu.
///
/// Mirrors [DemoDataGenerator]: raw HTTPS, `responseMimeType: application/json`
/// so the reply is a JSON object we validate, the key from
/// `--dart-define=GEMINI_API_KEY` (free tier at https://aistudio.google.com/apikey).
/// Never throws across the boundary — every path returns a [Result] (§12); the
/// scan screen falls back to manual entry on [Err].
class TicketScanner {
  /// Fixed-key scanner (tests / a known key).
  TicketScanner({
    required this._client,
    required String apiKey,
    this.model = _defaultModel,
  }) : _apiKey = (() => apiKey);

  /// Resolver-key scanner: `apiKey` is read **live on each scan**, so a key the
  /// user enters in Profile (persisted) takes effect without rebuilding the app.
  /// Used by DI (see `app/di.dart`).
  TicketScanner.resolved({
    required this._client,
    required this._apiKey,
    this.model = _defaultModel,
  });

  /// Builds a scanner from `--dart-define` values. [isConfigured] is false when
  /// no key was supplied, in which case the scan screen stays on manual entry.
  factory TicketScanner.fromEnvironment({http.Client? client}) {
    const String key = String.fromEnvironment('GEMINI_API_KEY');
    const String model =
        String.fromEnvironment('GEMINI_MODEL', defaultValue: _defaultModel);
    return TicketScanner(
      client: client ?? http.Client(),
      apiKey: key,
      model: model,
    );
  }

  static const String _defaultModel = 'gemini-2.0-flash';
  static const String _host = 'generativelanguage.googleapis.com';
  static const Logger _log = Logger('ticket-scan');

  final http.Client _client;
  final String Function() _apiKey;
  final String model;

  /// Whether an API key is available right now; if not, callers use manual entry.
  bool get isConfigured => _apiKey().isNotEmpty;

  /// Parse the KOT photo [imageBytes] (`image/jpeg` or `image/png`) against
  /// [menu] (+ [stations], so off-menu items get a sensible station). Returns the
  /// ticket, or an [Err] the caller surfaces as a "couldn't read it — enter
  /// manually" fallback.
  Future<Result<ScannedTicket>> scan({
    required Uint8List imageBytes,
    required String mediaType,
    required List<Dish> menu,
    List<Station> stations = const <Station>[],
  }) async {
    if (!isConfigured) {
      return const Result<ScannedTicket>.err(
        NetworkFailure('No GEMINI_API_KEY configured.'),
      );
    }
    if (menu.isEmpty) {
      return const Result<ScannedTicket>.err(
        UnknownFailure('No menu to match the ticket against.'),
      );
    }

    final String menuList =
        menu.map((Dish d) => '${d.id} — ${d.name}').join('\n');
    final String stationList =
        stations.map((Station s) => '${s.id} — ${s.name}').join('\n');
    final Uri uri = Uri.https(_host, '/v1beta/models/$model:generateContent');
    final Map<String, Object?> body = <String, Object?>{
      'systemInstruction': <String, Object?>{
        'parts': <Map<String, Object?>>[
          <String, Object?>{'text': _systemPrompt},
        ],
      },
      'contents': <Map<String, Object?>>[
        <String, Object?>{
          'role': 'user',
          'parts': <Map<String, Object?>>[
            <String, Object?>{
              'inlineData': <String, Object?>{
                'mimeType': mediaType,
                'data': base64Encode(imageBytes),
              },
            },
            <String, Object?>{
              'text': 'Menu (id — name):\n$menuList\n\n'
                  'Stations (id — name):\n$stationList\n\n'
                  'Read the Kitchen Order Ticket in the image. Record its '
                  'table/order number, the order type, and EVERY line item. For '
                  'each item: if it matches a menu item, set "dishId" to that '
                  'menu id. If it is NOT on the menu, leave "dishId" empty and '
                  'instead set "name" to the item text and "stationId" to the '
                  'most appropriate station id above. Always give "qty", and a '
                  'whole-minute "cookMins" estimate when you can.',
            },
          ],
        },
      ],
      'generationConfig': <String, Object?>{
        'responseMimeType': 'application/json',
        // Low temperature: reading a ticket is extraction, not invention.
        'temperature': 0.2,
      },
    };

    http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: <String, String>{
              'content-type': 'application/json',
              'x-goog-api-key': _apiKey(),
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } on Object catch (e, st) {
      _log.error('request failed', error: e, stackTrace: st);
      return Result<ScannedTicket>.err(
        NetworkFailure('Could not reach the AI service.', cause: e),
      );
    }

    if (res.statusCode != 200) {
      final String detail = _errorMessageFrom(_bodyAsUtf8(res));
      _log.error('HTTP ${res.statusCode}: $detail');
      return Result<ScannedTicket>.err(
        NetworkFailure('Scan failed (${res.statusCode}): $detail'),
      );
    }

    try {
      return _parse(_bodyAsUtf8(res), menu: menu, stations: stations);
    } on Object catch (e, st) {
      _log.error('parse failed', error: e, stackTrace: st);
      return Result<ScannedTicket>.err(
        UnknownFailure('Could not read the ticket.', cause: e),
      );
    }
  }

  Result<ScannedTicket> _parse(
    String responseBody, {
    required List<Dish> menu,
    required List<Station> stations,
  }) {
    final Map<String, Object?> envelope =
        jsonDecode(responseBody) as Map<String, Object?>;
    final List<Object?> candidates =
        (envelope['candidates'] as List<Object?>?) ?? const <Object?>[];
    if (candidates.isEmpty) {
      return const Result<ScannedTicket>.err(
        NetworkFailure('The AI returned no result for this image.'),
      );
    }
    final Map<String, Object?>? content =
        (candidates.first as Map<String, Object?>?)?['content']
            as Map<String, Object?>?;
    final List<Object?> parts =
        (content?['parts'] as List<Object?>?) ?? const <Object?>[];
    final String? text = parts.isEmpty
        ? null
        : (parts.first as Map<String, Object?>?)?['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      return const Result<ScannedTicket>.err(
        UnknownFailure('The AI returned no ticket.'),
      );
    }
    final Map<String, Object?> root =
        jsonDecode(_stripJsonFences(text)) as Map<String, Object?>;
    return _build(root, menu: menu, stations: stations);
  }

  /// Validate the model's JSON into a [ScannedTicket]. Lines that match a menu id
  /// become matched lines; lines that don't but carry a name are kept as off-menu
  /// (ad-hoc) lines with a validated station; only truly empty lines are dropped.
  Result<ScannedTicket> _build(
    Map<String, Object?> root, {
    required List<Dish> menu,
    required List<Station> stations,
  }) {
    final Set<String> dishIds = menu.map((Dish d) => d.id).toSet();
    final Set<String> stationIds = stations.map((Station s) => s.id).toSet();
    final List<Object?> rawLines =
        (root['lines'] as List<Object?>?) ?? const <Object?>[];
    final List<ScannedLine> lines = <ScannedLine>[];
    for (final Object? l in rawLines) {
      if (l is! Map<String, Object?>) continue;
      final int qty = _intOr(l['qty'], fallback: 1, min: 1);
      final int? cookMins = _intOrNull(l['cookMins'], min: 1);
      final String dishId = _str(l['dishId']);
      if (dishIds.contains(dishId)) {
        lines.add(ScannedLine(dishId: dishId, qty: qty, cookMins: cookMins));
        continue;
      }
      // Off-menu item: keep it as ad-hoc if it has a name (else there's nothing
      // to schedule). Validate the suggested station against the real list.
      final String name = _str(l['name']);
      if (name.isEmpty) continue;
      final String rawStation = _str(l['stationId']);
      lines.add(ScannedLine(
        qty: qty,
        name: name,
        stationId: stationIds.contains(rawStation) ? rawStation : null,
        cookMins: cookMins,
      ));
    }
    if (lines.isEmpty) {
      return const Result<ScannedTicket>.err(
        UnknownFailure('No line items recognised on the ticket.'),
      );
    }
    return Result<ScannedTicket>.ok(
      ScannedTicket(
        table: _str(root['table'], fallback: '1'),
        type: _parseType(root['type']),
        lines: lines,
      ),
    );
  }

  String _bodyAsUtf8(http.Response res) =>
      utf8.decode(res.bodyBytes, allowMalformed: true);

  String _stripJsonFences(String s) {
    String t = s.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    }
    return t.trim();
  }

  String _str(Object? v, {String fallback = ''}) =>
      v is String && v.trim().isNotEmpty ? v.trim() : fallback;

  int _intOr(Object? v, {required int fallback, int? min}) {
    int out = switch (v) {
      final int i => i,
      final num n => n.round(),
      final String s => int.tryParse(s) ?? fallback,
      _ => fallback,
    };
    if (min != null && out < min) out = min;
    return out;
  }

  /// Like [_intOr] but returns null when the model didn't supply a usable value
  /// (so callers can fall back to a dish/menu default).
  int? _intOrNull(Object? v, {int? min}) {
    final int? out = switch (v) {
      final int i => i,
      final num n => n.round(),
      final String s => int.tryParse(s),
      _ => null,
    };
    if (out == null) return null;
    return (min != null && out < min) ? min : out;
  }

  KotType _parseType(Object? v) {
    final String s = _str(v);
    for (final KotType t in KotType.values) {
      if (t.name == s) return t;
    }
    return KotType.dineIn;
  }

  String _errorMessageFrom(String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final Object? err = decoded['error'];
        if (err is Map<String, Object?> && err['message'] is String) {
          return err['message'] as String;
        }
      }
    } on Object {
      // fall through to raw body
    }
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }

  static const String _systemPrompt =
      'You read a photo of a paper Kitchen Order Ticket (KOT) — handwritten or '
      'printed — for a restaurant Kitchen Display System, and return ONE JSON '
      'object (no prose, no markdown) shaped exactly:\n'
      '{"table": str, "type": "dineIn"|"takeaway"|"delivery", "lines": ['
      '{"dishId": str (a menu id; omit when the item is not on the menu), '
      '"name": str (the item text; required when dishId is omitted), '
      '"stationId": str (a station id; set when dishId is omitted), '
      '"qty": int, "cookMins": int (estimated minutes; optional)}]}\n'
      'For each item: if it clearly matches a menu item, set "dishId" to that '
      'menu id (do not also set "name"/"stationId"). If it is NOT on the menu, '
      'omit "dishId" and instead give "name" (the item) and "stationId" (the '
      'closest station id from the provided list). Estimate "cookMins" in whole '
      'minutes whenever you reasonably can. Infer quantities (default 1), the '
      'order type, and the table/order number when visible. Never invent dish ids '
      'or station ids that are not in the provided lists.';
}
