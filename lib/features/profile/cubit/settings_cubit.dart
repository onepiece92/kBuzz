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

/// The presets offered for the fire toast hold time. The 3-minute option is the
/// default and matches [SettingsCubit.defaultFireToastDuration].
const List<FireToastPreset> kFireToastPresets = <FireToastPreset>[
  FireToastPreset('10s', Duration(seconds: 10)),
  FireToastPreset('30s', Duration(seconds: 30)),
  FireToastPreset('1 min', Duration(minutes: 1)),
  FireToastPreset('3 min', Duration(minutes: 3)),
  FireToastPreset('5 min', Duration(minutes: 5)),
  FireToastPreset('Until dismissed', Duration(days: 1)),
];

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
    this.themeMode = ThemeMode.dark,
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

  /// Active theme. Defaults to [ThemeMode.dark] (the neon KDS board);
  /// [ThemeMode.light] is the pastel theme and [ThemeMode.system] follows the OS.
  final ThemeMode themeMode;

  /// Whether AI features have a key to use (in-app key or build-time fallback).
  bool get aiConfigured => claudeApiKey.isNotEmpty || kEnvClaudeKey.isNotEmpty;

  SettingsState copyWith({
    Duration? fireToastDuration,
    String? claudeApiKey,
    bool? announceEnabled,
    bool? fireImmediately,
    ThemeMode? themeMode,
  }) =>
      SettingsState(
        fireToastDuration: fireToastDuration ?? this.fireToastDuration,
        claudeApiKey: claudeApiKey ?? this.claudeApiKey,
        announceEnabled: announceEnabled ?? this.announceEnabled,
        fireImmediately: fireImmediately ?? this.fireImmediately,
        themeMode: themeMode ?? this.themeMode,
      );

  @override
  List<Object?> get props => <Object?>[
        fireToastDuration,
        claudeApiKey,
        announceEnabled,
        fireImmediately,
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
        themeMode: _readThemeMode(prefs),
      ));

  final SharedPreferences? _prefs;

  static const String _fireToastKey = 'fireToastSeconds';
  static const String _announceKey = 'announceEnabled';
  static const String _fireImmediatelyKey = 'fireImmediately';
  static const String _themeModeKey = 'themeMode';

  /// SharedPreferences key for the in-app Claude API key. The DI-wired ticket
  /// scanner and demo-data generator read this same key (see `app/di.dart`), so a
  /// key saved in Profile powers both flows.
  static const String claudeApiKeyPref = 'claudeApiKey';

  /// The factory default (also the pre-injection fallback): keep the prior 3-min
  /// behaviour.
  static const Duration defaultFireToastDuration = Duration(minutes: 3);

  static Duration _readFireToast(SharedPreferences? prefs) {
    final int? seconds = prefs?.getInt(_fireToastKey);
    return seconds == null
        ? defaultFireToastDuration
        : Duration(seconds: seconds);
  }

  static ThemeMode _readThemeMode(SharedPreferences? prefs) {
    final int? i = prefs?.getInt(_themeModeKey);
    return (i != null && i >= 0 && i < ThemeMode.values.length)
        ? ThemeMode.values[i]
        : ThemeMode.dark;
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
}
