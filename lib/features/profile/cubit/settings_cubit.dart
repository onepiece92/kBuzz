import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A selectable fire-toast hold time shown in Profile → Settings. [duration] is
/// what [AppToast.fire] is given; [days: 1] stands in for "until dismissed" — by
/// then a newer fire or a pause/reset will have cleared the toast anyway.
class FireToastPreset extends Equatable {
  const FireToastPreset(this.label, this.duration);

  final String label;
  final Duration duration;

  @override
  List<Object?> get props => <Object?>[label, duration];
}

/// The presets offered for the fire toast hold time. The 30-second option is the
/// default and matches [SettingsCubit.defaultFireToastDuration].
const List<FireToastPreset> kFireToastPresets = <FireToastPreset>[
  FireToastPreset('10s', Duration(seconds: 10)),
  FireToastPreset('30s', Duration(seconds: 30)),
  FireToastPreset('1 min', Duration(minutes: 1)),
  FireToastPreset('3 min', Duration(minutes: 3)),
  FireToastPreset('5 min', Duration(minutes: 5)),
  FireToastPreset('Until dismissed', Duration(days: 1)),
];

/// Grace periods offered for **auto serve-all** (Profile → Settings): how long
/// after a ticket's items are all ready before it auto-serves + closes. `Now`
/// fires the instant it's ready. Reuses [FireToastPreset] (label + duration).
const List<FireToastPreset> kAutoServePresets = <FireToastPreset>[
  FireToastPreset('Now', Duration.zero),
  FireToastPreset('1 min', Duration(minutes: 1)),
  FireToastPreset('2 min', Duration(minutes: 2)),
  FireToastPreset('5 min', Duration(minutes: 5)),
  FireToastPreset('10 min', Duration(minutes: 10)),
];

/// Selectable Stations-rail time windows (minutes shown at once before it
/// scrolls), tunable by an admin in Profile → Settings.
const List<int> kRailWindowPresets = <int>[30, 45, 60, 90, 120];

/// Compile-time Claude key fallback (`--dart-define=ANTHROPIC_API_KEY=…`). Used
/// when the user hasn't entered a key in Profile, so existing build-time keys
/// keep working and an in-app key simply overrides it.
const String kEnvClaudeKey = String.fromEnvironment('ANTHROPIC_API_KEY');

/// User-tunable app settings.
class SettingsState extends Equatable {
  const SettingsState({
    required this.fireToastDuration,
    required this.claudeApiKey,
    this.announceEnabled = true,
    this.fireImmediately = false,
    this.autoDripEnabled = false,
    this.autoDripMins = SettingsCubit.defaultAutoDripMins,
    this.autoServeEnabled = true,
    this.autoServeDelay = SettingsCubit.defaultAutoServeDelay,
    this.railWindowMins = SettingsCubit.defaultRailWindowMins,
    this.themeMode = ThemeMode.light,
  });

  /// How long a fire-next toast stays on screen before auto-dismissing.
  final Duration fireToastDuration;

  /// User-supplied Anthropic (Claude) API key. Drives **both** the ticket
  /// scanner (scan parse) and the AI demo-data generator. Empty here = use the
  /// build-time [kEnvClaudeKey] if present, else AI is off (manual entry / the
  /// sample).
  final String claudeApiKey;

  /// Whether fire alerts are spoken aloud. On by default; turning it off mutes
  /// the [Announcer] (TTS + chime) while the on-screen fire toast still shows.
  final bool announceEnabled;

  /// Cook-timing policy. `false` (default) ⇒ **just-in-time**: each dish is
  /// back-scheduled to be ready right at its due time (stations may sit idle
  /// first). `true` ⇒ **start immediately**: every dish fires as soon as capacity
  /// allows, so the station starts now. Drives [BoardData.from]'s scheduler config.
  final bool fireImmediately;

  /// Whether to **auto-add** a randomized ticket every [autoDripMins] of run
  /// time — simulates real-world orders trickling in while the service runs.
  /// Off by default; only drips while the run clock is active and a board exists.
  final bool autoDripEnabled;

  /// How many minutes of **run time** between auto-added tickets (see
  /// [autoDripEnabled]). Floored at 1. Measured in service-clock minutes, so it
  /// respects the run speed (faster speed ⇒ orders arrive sooner in wall time).
  final int autoDripMins;

  /// Whether to **auto serve-all + close** a ticket once all its items have been
  /// ready for [autoServeDelay] — keeps the Tickets board clean without manual
  /// taps. Off by default; only runs while the run clock is active.
  final bool autoServeEnabled;

  /// Grace period after a ticket is all-ready before it auto-serves (see
  /// [autoServeEnabled]). Measured in service-clock minutes (respects run speed).
  final Duration autoServeDelay;

  /// Stations-rail time window — minutes shown at once before the Gantt scrolls.
  /// Admin-tunable; smaller = bigger bars / less on screen. Floored sensibly.
  final int railWindowMins;

  /// Active theme. Defaults to [ThemeMode.light] (the pastel theme);
  /// [ThemeMode.dark] is the neon KDS board and [ThemeMode.system] follows the OS.
  final ThemeMode themeMode;

  /// Whether AI features have a key to use (in-app key or build-time fallback).
  bool get aiConfigured => claudeApiKey.isNotEmpty || kEnvClaudeKey.isNotEmpty;

  SettingsState copyWith({
    Duration? fireToastDuration,
    String? claudeApiKey,
    bool? announceEnabled,
    bool? fireImmediately,
    bool? autoDripEnabled,
    int? autoDripMins,
    bool? autoServeEnabled,
    Duration? autoServeDelay,
    int? railWindowMins,
    ThemeMode? themeMode,
  }) =>
      SettingsState(
        fireToastDuration: fireToastDuration ?? this.fireToastDuration,
        claudeApiKey: claudeApiKey ?? this.claudeApiKey,
        announceEnabled: announceEnabled ?? this.announceEnabled,
        fireImmediately: fireImmediately ?? this.fireImmediately,
        autoDripEnabled: autoDripEnabled ?? this.autoDripEnabled,
        autoDripMins: autoDripMins ?? this.autoDripMins,
        autoServeEnabled: autoServeEnabled ?? this.autoServeEnabled,
        autoServeDelay: autoServeDelay ?? this.autoServeDelay,
        railWindowMins: railWindowMins ?? this.railWindowMins,
        themeMode: themeMode ?? this.themeMode,
      );

  @override
  List<Object?> get props => <Object?>[
        fireToastDuration,
        claudeApiKey,
        announceEnabled,
        fireImmediately,
        autoDripEnabled,
        autoDripMins,
        autoServeEnabled,
        autoServeDelay,
        railWindowMins,
        themeMode,
      ];
}

/// Holds app preferences and persists them. Backed by [SharedPreferences] when
/// one is injected (by `main`); with none (tests/CI) it's session-only, mirroring
/// how the rest of the app injects real services and defaults to no-ops.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({SharedPreferences? prefs})
    : _prefs = prefs,
      super(SettingsState(
        fireToastDuration: _readFireToast(prefs),
        claudeApiKey: prefs?.getString(claudeApiKeyPref) ?? '',
        announceEnabled: prefs?.getBool(_announceKey) ?? true,
        fireImmediately: prefs?.getBool(_fireImmediatelyKey) ?? false,
        autoDripEnabled: prefs?.getBool(_autoDripEnabledKey) ?? false,
        autoDripMins: _readAutoDripMins(prefs),
        autoServeEnabled: prefs?.getBool(_autoServeEnabledKey) ?? true,
        autoServeDelay: _readAutoServeDelay(prefs),
        railWindowMins: _readRailWindowMins(prefs),
        themeMode: _readThemeMode(prefs),
      ));

  final SharedPreferences? _prefs;

  static const String _fireToastKey = 'fireToastSeconds';
  static const String _announceKey = 'announceEnabled';
  static const String _fireImmediatelyKey = 'fireImmediately';
  static const String _autoDripEnabledKey = 'autoDripEnabled';
  static const String _autoDripMinsKey = 'autoDripMins';
  static const String _autoServeEnabledKey = 'autoServeEnabled';
  static const String _autoServeSecondsKey = 'autoServeSeconds';
  static const String _railWindowMinsKey = 'railWindowMins';
  static const String _themeModeKey = 'themeMode';

  /// Default minutes of run time between auto-added tickets.
  static const int defaultAutoDripMins = 3;

  /// Default grace period before auto serve-all fires once a ticket is ready.
  static const Duration defaultAutoServeDelay = Duration(minutes: 2);

  /// Default Stations-rail window (minutes shown before it scrolls).
  static const int defaultRailWindowMins = 30;

  /// Bounds the admin-set rail window so the Gantt stays usable.
  static const int minRailWindowMins = 15;
  static const int maxRailWindowMins = 240;

  /// SharedPreferences key for the in-app Claude API key. The DI-wired ticket
  /// scanner and demo-data generator read this same key (see `app/di.dart`), so a
  /// key saved in Profile powers both flows.
  static const String claudeApiKeyPref = 'claudeApiKey';

  /// The factory default (also the pre-injection fallback): a brief 30-second
  /// hold before the fire toast auto-dismisses.
  static const Duration defaultFireToastDuration = Duration(seconds: 30);

  static Duration _readFireToast(SharedPreferences? prefs) {
    final int? seconds = prefs?.getInt(_fireToastKey);
    return seconds == null
        ? defaultFireToastDuration
        : Duration(seconds: seconds);
  }

  static int _readAutoDripMins(SharedPreferences? prefs) {
    final int? m = prefs?.getInt(_autoDripMinsKey);
    return (m == null || m < 1) ? defaultAutoDripMins : m;
  }

  static Duration _readAutoServeDelay(SharedPreferences? prefs) {
    final int? s = prefs?.getInt(_autoServeSecondsKey);
    return (s == null || s < 0) ? defaultAutoServeDelay : Duration(seconds: s);
  }

  static int _readRailWindowMins(SharedPreferences? prefs) {
    final int? m = prefs?.getInt(_railWindowMinsKey);
    if (m == null) return defaultRailWindowMins;
    return m.clamp(minRailWindowMins, maxRailWindowMins);
  }

  static ThemeMode _readThemeMode(SharedPreferences? prefs) {
    final int? i = prefs?.getInt(_themeModeKey);
    return (i != null && i >= 0 && i < ThemeMode.values.length)
        ? ThemeMode.values[i]
        : ThemeMode.light;
  }

  /// Set (and persist) the active theme. Takes effect immediately — the root
  /// [MaterialApp] rebuilds on this state and swaps the neon/pastel palettes.
  void setThemeMode(ThemeMode mode) {
    if (mode == state.themeMode) return;
    emit(state.copyWith(themeMode: mode));
    _prefs?.setInt(_themeModeKey, mode.index);
  }

  /// Set (and persist) the fire-toast hold time. Takes effect on the next fire.
  void setFireToastDuration(Duration duration) {
    if (duration == state.fireToastDuration) return;
    emit(state.copyWith(fireToastDuration: duration));
    _prefs?.setInt(_fireToastKey, duration.inSeconds);
  }

  /// Set (and persist) the cook-timing policy. The boards re-run the scheduler
  /// off this, so the change is visible immediately (see [BoardData.from]).
  void setFireImmediately(bool value) {
    if (value == state.fireImmediately) return;
    emit(state.copyWith(fireImmediately: value));
    _prefs?.setBool(_fireImmediatelyKey, value);
  }

  /// Set (and persist) the in-app Claude API key. Empty clears it (AI reverts to
  /// the build-time key if any, else off). Takes effect on the next scan/generate
  /// — both read the key live from the same store.
  void setClaudeApiKey(String key) {
    final String k = key.trim();
    if (k == state.claudeApiKey) return;
    emit(state.copyWith(claudeApiKey: k));
    if (k.isEmpty) {
      _prefs?.remove(claudeApiKeyPref);
    } else {
      _prefs?.setString(claudeApiKeyPref, k);
    }
  }

  /// Toggle (and persist) whether fire alerts are spoken aloud. Muting keeps the
  /// on-screen fire toast — only the audio (TTS + chime) stops.
  void setAnnounceEnabled(bool enabled) {
    if (enabled == state.announceEnabled) return;
    emit(state.copyWith(announceEnabled: enabled));
    _prefs?.setBool(_announceKey, enabled);
  }

  /// Toggle (and persist) the auto-ticket drip. When on, a new randomized ticket
  /// is added every [SettingsState.autoDripMins] of run time (see the drip
  /// listener wired in `app/di.dart`).
  void setAutoDripEnabled(bool enabled) {
    if (enabled == state.autoDripEnabled) return;
    emit(state.copyWith(autoDripEnabled: enabled));
    _prefs?.setBool(_autoDripEnabledKey, enabled);
  }

  /// Set (and persist) the auto-drip interval in run minutes (floored at 1).
  void setAutoDripMins(int mins) {
    final int m = mins < 1 ? 1 : mins;
    if (m == state.autoDripMins) return;
    emit(state.copyWith(autoDripMins: m));
    _prefs?.setInt(_autoDripMinsKey, m);
  }

  /// Toggle (and persist) auto serve-all. When on, a ticket that's been all-ready
  /// for [SettingsState.autoServeDelay] is served + closed automatically (see the
  /// auto-serve listener wired in `app/di.dart`).
  void setAutoServeEnabled(bool enabled) {
    if (enabled == state.autoServeEnabled) return;
    emit(state.copyWith(autoServeEnabled: enabled));
    _prefs?.setBool(_autoServeEnabledKey, enabled);
  }

  /// Set (and persist) the auto serve-all grace period (clamped ≥ 0).
  void setAutoServeDelay(Duration delay) {
    final Duration d = delay.isNegative ? Duration.zero : delay;
    if (d == state.autoServeDelay) return;
    emit(state.copyWith(autoServeDelay: d));
    _prefs?.setInt(_autoServeSecondsKey, d.inSeconds);
  }

  /// Set (and persist) the Stations-rail time window in minutes (admin-tunable,
  /// clamped to [minRailWindowMins]–[maxRailWindowMins]). The rail re-scales live.
  void setRailWindowMins(int mins) {
    final int m = mins.clamp(minRailWindowMins, maxRailWindowMins);
    if (m == state.railWindowMins) return;
    emit(state.copyWith(railWindowMins: m));
    _prefs?.setInt(_railWindowMinsKey, m);
  }
}
