import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kbuzz/core/logger.dart';
import 'package:kbuzz/core/result.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';

/// Generates a *fresh* demo dataset on every call by asking Google Gemini to
/// invent a plausible restaurant: stations, a themed menu and a live ticket
/// rush. Replaces the deterministic [buildDemoData] when an API key is wired up.
///
/// Gemini is used because Google AI Studio offers a free tier — get a key at
/// https://aistudio.google.com/apikey and pass it at build time via
/// `--dart-define=GEMINI_API_KEY=...` (see [DemoDataGenerator.fromEnvironment]).
/// Without a key [isConfigured] is false and the cubit keeps using the sample.
///
/// Flutter has no official Gemini SDK, so this talks to the Generative Language
/// REST API (`models/{model}:generateContent`) over raw HTTPS via `package:http`,
/// asking for `responseMimeType: application/json` so the reply is a JSON object
/// we validate. Never throws across the layer boundary: every path returns a
/// [Result] (AGENTS.md §12); the cubit falls back to [buildDemoData] on [Err].
class DemoDataGenerator {
  /// Fixed-key generator (tests / a known key).
  DemoDataGenerator({
    required this._client,
    required String apiKey,
    this.model = _defaultModel,
  }) : _apiKey = (() => apiKey);

  /// Resolver-key generator: `apiKey` is read **live on each generate**, so a key
  /// the user enters in Profile (persisted) takes effect without rebuilding the
  /// app. Used by DI (see `app/di.dart`).
  DemoDataGenerator.resolved({
    required this._client,
    required this._apiKey,
    this.model = _defaultModel,
  });

  /// Builds a generator from `--dart-define` values. [isConfigured] is false
  /// when no `GEMINI_API_KEY` was supplied.
  factory DemoDataGenerator.fromEnvironment({http.Client? client}) {
    const String key = String.fromEnvironment('GEMINI_API_KEY');
    const String model =
        String.fromEnvironment('GEMINI_MODEL', defaultValue: _defaultModel);
    return DemoDataGenerator(
      client: client ?? http.Client(),
      apiKey: key,
      model: model,
    );
  }

  /// Fast, capable, free-tier-eligible default. Override with `GEMINI_MODEL`.
  static const String _defaultModel = 'gemini-2.0-flash';
  static const String _host = 'generativelanguage.googleapis.com';
  static const Logger _log = Logger('demo-gen');

  final http.Client _client;
  final String Function() _apiKey;
  final String model;

  /// Whether an API key is available right now; if not, callers should fall back.
  bool get isConfigured => _apiKey().isNotEmpty;

  /// Short provider name for the UI.
  String get providerLabel => 'Gemini';

  /// Ask Gemini for a brand-new dataset, anchored to [now].
  Future<Result<DemoData>> generate({required DateTime now}) async {
    if (!isConfigured) {
      return const Result<DemoData>.err(
        NetworkFailure('No GEMINI_API_KEY configured.'),
      );
    }

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
            <String, Object?>{'text': _userPrompt},
          ],
        },
      ],
      'generationConfig': <String, Object?>{
        'responseMimeType': 'application/json',
        // High temperature so each tap yields a noticeably different rush.
        'temperature': 1.2,
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
      _log.error('gemini request failed', error: e, stackTrace: st);
      return Result<DemoData>.err(
        NetworkFailure('Could not reach the AI service.', cause: e),
      );
    }

    if (res.statusCode != 200) {
      final String detail = _errorMessageFrom(_bodyAsUtf8(res));
      _log.error('gemini HTTP ${res.statusCode}: $detail');
      return Result<DemoData>.err(NetworkFailure(_statusMessage(res.statusCode)));
    }

    try {
      final Map<String, Object?> envelope =
          jsonDecode(_bodyAsUtf8(res)) as Map<String, Object?>;
      final List<Object?> candidates =
          (envelope['candidates'] as List<Object?>?) ?? const <Object?>[];
      if (candidates.isEmpty) {
        return const Result<DemoData>.err(
          UnknownFailure('The AI did not return usable data.'),
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
        return const Result<DemoData>.err(
          UnknownFailure('The AI did not return usable data.'),
        );
      }
      final Map<String, Object?> root =
          jsonDecode(_stripJsonFences(text)) as Map<String, Object?>;
      return _validateDataset(root, now: now);
    } on Object catch (e, st) {
      _log.error('gemini parse failed', error: e, stackTrace: st);
      return Result<DemoData>.err(
        UnknownFailure('The AI did not return usable data.', cause: e),
      );
    }
  }

  /// A short, plain-language message for a non-200 status. The full technical
  /// detail is logged (above) — the user just needs to know what to do.
  String _statusMessage(int status) => switch (status) {
        429 => 'AI hit its free usage limit. Try again later.',
        500 || 503 => 'The AI service is busy right now.',
        401 || 403 => 'AI key was not accepted — check it in Profile.',
        _ => 'The AI service had a problem.',
      };
}

/* ================================================================== */
/*  Validation + helpers                                              */
/* ================================================================== */

/// Map + validate Gemini's JSON into domain entities, dropping anything that
/// would break the scheduler (dishes on unknown stations, lines on unknown
/// dishes, empty tickets) rather than failing the whole batch.
Result<DemoData> _validateDataset(
  Map<String, Object?> root, {
  required DateTime now,
}) {
  final List<Object?> rawStations =
      (root['stations'] as List<Object?>?) ?? const <Object?>[];
  final List<Object?> rawMenu =
      (root['menu'] as List<Object?>?) ?? const <Object?>[];
  final List<Object?> rawKots =
      (root['kots'] as List<Object?>?) ?? const <Object?>[];

  // Stations — unique ids, capacity >= 1, parseable colour.
  final List<Station> stations = <Station>[];
  final Set<String> stationIds = <String>{};
  for (final Object? s in rawStations) {
    if (s is! Map<String, Object?>) continue;
    final String id = _str(s['id']);
    final String name = _str(s['name']);
    if (id.isEmpty || name.isEmpty || !stationIds.add(id)) continue;
    stations.add(Station(
      id: id,
      name: name,
      color: _parseColor(s['color']),
      capacity: _intOr(s['capacity'], fallback: 1, min: 1),
    ));
  }
  if (stations.isEmpty) {
    return const Result<DemoData>.err(
      UnknownFailure('AI produced no usable stations.'),
    );
  }

  // Menu — unique ids, station must exist.
  final List<Dish> menu = <Dish>[];
  final Set<String> dishIds = <String>{};
  for (final Object? m in rawMenu) {
    if (m is! Map<String, Object?>) continue;
    final String id = _str(m['id']);
    final String stationId = _str(m['stationId']);
    // Skip dishes with no id, a duplicate id, or an unknown station.
    if (id.isEmpty || dishIds.contains(id) || !stationIds.contains(stationId)) {
      continue;
    }
    dishIds.add(id);
    menu.add(Dish(
      id: id,
      name: _str(m['name'], fallback: id),
      emoji: _str(m['emoji'], fallback: '🍽️'),
      stationId: stationId,
      cookMins: _intOr(m['cookMins'], fallback: 8, min: 1),
      holdable: m['holdable'] == true,
      batchable: m['batchable'] == true,
    ));
  }
  if (menu.isEmpty) {
    return const Result<DemoData>.err(
      UnknownFailure('AI produced no dishes on valid stations.'),
    );
  }

  // Tickets — drop lines on unknown dishes; drop empty tickets.
  final List<Kot> kots = <Kot>[];
  int seq = 0;
  for (final Object? k in rawKots) {
    if (k is! Map<String, Object?>) continue;
    final List<Object?> rawLines =
        (k['lines'] as List<Object?>?) ?? const <Object?>[];
    final List<OrderLine> lines = <OrderLine>[];
    for (final Object? l in rawLines) {
      if (l is! Map<String, Object?>) continue;
      final String dishId = _str(l['dishId']);
      if (!dishIds.contains(dishId)) continue;
      lines.add(
        OrderLine(dishId: dishId, qty: _intOr(l['qty'], fallback: 1, min: 1)),
      );
    }
    if (lines.isEmpty) continue;
    final int minsAgo = _intOr(k['orderedMinsAgo'], fallback: 0, min: 0);
    kots.add(Kot(
      id: 'ai-kot-${++seq}',
      table: _str(k['table'], fallback: '$seq'),
      type: _parseType(k['type']),
      orderedAt: now.subtract(Duration(minutes: minsAgo)),
      lines: lines,
    ));
  }
  if (kots.isEmpty) {
    return const Result<DemoData>.err(
      UnknownFailure('AI produced no tickets we could schedule.'),
    );
  }

  return Result<DemoData>.ok(
    DemoData(stations: stations, menu: menu, kots: kots),
  );
}

/// Decode a response body as UTF-8 from its raw bytes.
///
/// `http`'s `Response.body` getter falls back to **latin1** when the response
/// has no `charset` (Gemini sends `application/json` without one), which mangles
/// multi-byte UTF-8 — e.g. dish emoji. Reading the bytes as UTF-8 ourselves
/// keeps emoji and accents intact.
String _bodyAsUtf8(http.Response res) =>
    utf8.decode(res.bodyBytes, allowMalformed: true);

/// Strip a leading ```json / ``` fence the model may add despite a JSON mime type.
String _stripJsonFences(String s) {
  String t = s.trim();
  if (t.startsWith('```')) {
    t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
    if (t.endsWith('```')) t = t.substring(0, t.length - 3);
  }
  return t.trim();
}

/// Best-effort error text from Gemini's JSON error envelope.
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

/// Accepts `#RRGGBB`, `#AARRGGBB`, `0xFFRRGGBB` or bare hex; returns an opaque
/// ARGB int. Falls back to slate-500 when unparseable.
int _parseColor(Object? v) {
  const int fallback = 0xFF64748B;
  if (v is int) return v == 0 ? fallback : (0xFF000000 | v);
  if (v is! String) return fallback;
  String hex = v.trim().replaceAll('#', '').replaceAll('0x', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return fallback;
  final int? parsed = int.tryParse(hex, radix: 16);
  return parsed ?? fallback;
}

KotType _parseType(Object? v) {
  final String s = _str(v);
  for (final KotType t in KotType.values) {
    if (t.name == s) return t;
  }
  return KotType.dineIn;
}

/// System prompt — describes the exact JSON object Gemini must return.
const String _systemPrompt =
    'You design demo data for a Kitchen Display System (KDS). Invent a '
    'realistic, varied single restaurant and a snapshot of its current dinner '
    'rush, and return it as ONE JSON object (no prose, no markdown) with exactly '
    'these keys:\n'
    '{\n'
    '  "stations": [{"id": str, "name": str, "color": "#RRGGBB", "capacity": int}],\n'
    '  "menu": [{"id": str, "name": str, "emoji": str, "stationId": str, '
    '"cookMins": int, "holdable": bool, "batchable": bool}],\n'
    '  "kots": [{"table": str, "type": "dineIn"|"takeaway"|"delivery", '
    '"orderedMinsAgo": int, "lines": [{"dishId": str, "qty": int}]}]\n'
    '}\n'
    'Rules: 6-9 stations, each a distinct cooking line with a distinct hex colour '
    'and capacity 1-3; 10-16 menu dishes spread across the stations with '
    'believable cook times (2-18 min), holdable/batchable flags and a fitting '
    'emoji; 4-7 tickets, each with 1-4 line items, a mix of '
    'dineIn/takeaway/delivery, orderedMinsAgo 0-8. Every menu dish stationId MUST '
    'match a station id; every line dishId MUST match a menu id. Use short '
    'lowercase-slug ids. Make each generation feel different: vary the cuisine '
    'theme, station mix, dish names and the tickets.';

/// User turn — nudges variety so each tap differs.
const String _userPrompt =
    'Generate a fresh restaurant and its current rush now. Surprise me with the '
    'cuisine and dishes — make it different from a generic sample.';
