import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kbuzz/core/logger.dart';
import 'package:kbuzz/core/result.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';

/// Generates a *fresh* demo dataset on every call by asking Anthropic's Claude
/// to invent a plausible restaurant: stations, a themed menu and a live ticket
/// rush. Replaces the deterministic [buildDemoData] when an API key is wired up.
///
/// Get a key at https://console.anthropic.com/settings/keys and enter it in
/// Profile → Settings (persisted), or pass it at build time via
/// `--dart-define=ANTHROPIC_API_KEY=...` (see [DemoDataGenerator.fromEnvironment]).
/// Without a key [isConfigured] is false and the cubit keeps using the sample.
///
/// Flutter has no official Anthropic SDK, so this talks to the Messages API
/// (`/v1/messages`) over raw HTTPS via `package:http`; the system prompt pins a
/// strict JSON shape so the reply is a JSON object we validate. Never throws
/// across the layer boundary: every path returns a [Result] (AGENTS.md §12); the
/// cubit falls back to [buildDemoData] on [Err].
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
  /// when no `ANTHROPIC_API_KEY` was supplied.
  factory DemoDataGenerator.fromEnvironment({http.Client? client}) {
    const String key = String.fromEnvironment('ANTHROPIC_API_KEY');
    const String model =
        String.fromEnvironment('ANTHROPIC_MODEL', defaultValue: _defaultModel);
    return DemoDataGenerator(
      client: client ?? http.Client(),
      apiKey: key,
      model: model,
    );
  }

  /// Default Claude model. Override with `--dart-define=ANTHROPIC_MODEL=…`
  /// (e.g. `claude-haiku-4-5` for a cheaper, faster generator).
  static const String _defaultModel = 'claude-opus-4-8';
  static const String _host = 'api.anthropic.com';
  static const String _apiVersion = '2023-06-01';
  static const int _maxTokens = 8192;
  static const Logger _log = Logger('demo-gen');

  final http.Client _client;
  final String Function() _apiKey;
  final String model;

  /// Whether an API key is available right now; if not, callers should fall back.
  bool get isConfigured => _apiKey().isNotEmpty;

  /// Short provider name for the UI.
  String get providerLabel => 'Claude';

  /// Ask Claude for a brand-new dataset, anchored to [now].
  Future<Result<DemoData>> generate({required DateTime now}) async {
    if (!isConfigured) {
      return const Result<DemoData>.err(
        NetworkFailure('No Anthropic API key configured.'),
      );
    }

    final Uri uri = Uri.https(_host, '/v1/messages');
    final Map<String, Object?> body = <String, Object?>{
      'model': model,
      'max_tokens': _maxTokens,
      'system': _systemPrompt,
      'messages': <Map<String, Object?>>[
        <String, Object?>{'role': 'user', 'content': _userPrompt},
      ],
    };

    http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: <String, String>{
              'content-type': 'application/json',
              'x-api-key': _apiKey(),
              'anthropic-version': _apiVersion,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } on Object catch (e, st) {
      _log.error('claude request failed', error: e, stackTrace: st);
      return Result<DemoData>.err(
        NetworkFailure('Could not reach the AI service.', cause: e),
      );
    }

    if (res.statusCode != 200) {
      final String detail = _errorMessageFrom(_bodyAsUtf8(res));
      _log.error('claude HTTP ${res.statusCode}: $detail');
      return Result<DemoData>.err(NetworkFailure(_statusMessage(res.statusCode)));
    }

    try {
      final Object? envelope = jsonDecode(_bodyAsUtf8(res));
      if (envelope is! Map<String, Object?>) {
        return const Result<DemoData>.err(
          UnknownFailure('The AI did not return usable data.'),
        );
      }
      final String? text = _firstText(envelope);
      if (text == null || text.trim().isEmpty) {
        return const Result<DemoData>.err(
          UnknownFailure('The AI did not return usable data.'),
        );
      }
      final Object? root = jsonDecode(_stripJsonFences(text));
      if (root is! Map<String, Object?>) {
        return const Result<DemoData>.err(
          UnknownFailure('The AI did not return usable data.'),
        );
      }
      return _validateDataset(root, now: now);
    } on Object catch (e, st) {
      _log.error('claude parse failed', error: e, stackTrace: st);
      return Result<DemoData>.err(
        UnknownFailure('The AI did not return usable data.', cause: e),
      );
    }
  }

  /// A short, plain-language message for a non-200 status. The full technical
  /// detail is logged (above) — the user just needs to know what to do.
  String _statusMessage(int status) => switch (status) {
        429 => 'AI hit its usage limit. Try again later.',
        500 || 503 || 529 => 'The AI service is busy right now.',
        401 || 403 => 'AI key was not accepted — check it in Profile.',
        _ => 'The AI service had a problem.',
      };
}

/// The first `text` block from a Claude Messages response `content` array.
/// Skips any non-text blocks (e.g. thinking) and returns null if there's none.
String? _firstText(Map<String, Object?> envelope) {
  final List<Object?> content =
      (envelope['content'] as List<Object?>?) ?? const <Object?>[];
  for (final Object? block in content) {
    if (block is Map<String, Object?> &&
        block['type'] == 'text' &&
        block['text'] is String) {
      return block['text'] as String;
    }
  }
  return null;
}

/* ================================================================== */
/*  Validation + helpers                                              */
/* ================================================================== */

/// Map + validate the model's JSON into domain entities, dropping anything that
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
    final String name = _str(s['name'], maxLen: 40);
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
      name: _str(m['name'], fallback: id, maxLen: 80),
      emoji: _str(m['emoji'], fallback: '🍽️', maxLen: 8),
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
      final String note = _str(l['note'], maxLen: 80);
      lines.add(
        OrderLine(
          dishId: dishId,
          qty: _intOr(l['qty'], fallback: 1, min: 1),
          note: note.isEmpty ? null : note,
        ),
      );
    }
    if (lines.isEmpty) continue;
    final int minsAgo = _intOr(k['orderedMinsAgo'], fallback: 0, min: 0);
    kots.add(Kot(
      id: 'ai-kot-${++seq}',
      table: _str(k['table'], fallback: '$seq', maxLen: 16),
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
/// has no `charset`, which mangles multi-byte UTF-8 — e.g. dish emoji. Reading
/// the bytes as UTF-8 ourselves keeps emoji and accents intact.
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

/// Best-effort error text from the API's JSON error envelope.
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

String _str(Object? v, {String fallback = '', int? maxLen}) {
  if (v is! String) return fallback;
  final String s = v.trim();
  if (s.isEmpty) return fallback;
  if (maxLen == null) return s;
  // Clamp by code point (rune) so the cap never splits a surrogate pair into
  // invalid UTF-16 — defends the UI/TTS against a pathological model response
  // with an enormous name/note/emoji.
  final List<int> runes = s.runes.toList();
  return runes.length <= maxLen ? s : String.fromCharCodes(runes.take(maxLen));
}

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

/// System prompt — describes the exact JSON object the model must return.
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
    '"orderedMinsAgo": int, "lines": [{"dishId": str, "qty": int, '
    '"note": str (optional special instruction)}]}]\n'
    '}\n'
    'Rules: 6-9 stations, each a distinct cooking line with a distinct hex colour '
    'and capacity 1-3; 10-16 menu dishes spread across the stations with '
    'believable cook times (2-18 min), holdable/batchable flags and a fitting '
    'emoji; 4-7 tickets, each with 1-4 line items and orderedMinsAgo 0-8. '
    'Weight each ticket "type" heavily toward dineIn: about 80% dineIn, ~10% '
    'delivery, ~10% takeaway — i.e. the large majority are dineIn, with only the '
    'occasional delivery or takeaway across the batch. Give roughly a third of the '
    'line items a short "note" — a realistic kitchen instruction like "no salt", '
    '"extra spicy", "well done", "allergy: nuts", "sauce on the side" (omit it '
    'on the rest). Every menu dish stationId MUST match a station id; every line '
    'dishId MUST match a menu id. Use short lowercase-slug ids.\n'
    'CUISINE: The restaurant serves food popular in the United States. Pick a '
    'different mainstream American style each generation — e.g. classic American '
    'diner, burger & grill, BBQ smokehouse, Tex-Mex, Southern comfort, '
    'steakhouse, seafood shack, New York pizza / Italian-American, or all-day '
    'brunch. Use dish names a typical US diner would instantly recognise '
    '(cheeseburger, buffalo wings, mac & cheese, BBQ ribs, clam chowder, Caesar '
    'salad, fried chicken, pancakes, club sandwich, apple pie, etc.). Vary the '
    'American style, station mix, dish names, tickets and notes each time so no '
    'two generations feel the same — but do NOT use Indian, Nepali, or other '
    'South-Asian cuisines.';

/// User turn — nudges variety so each tap differs, anchored to US cuisine.
const String _userPrompt =
    'Generate a fresh American restaurant and its current dinner rush now. Pick a '
    'different US-popular style than a generic sample (diner, BBQ, burgers, '
    'Tex-Mex, steakhouse, seafood, pizza, brunch…) with dishes American diners '
    'know well.';
