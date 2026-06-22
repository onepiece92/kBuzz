import 'package:equatable/equatable.dart';
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

/// Compile-time Gemini key fallback (`--dart-define=GEMINI_API_KEY=…`). Used when
/// the user hasn't entered a key in Profile, so existing build-time keys keep
/// working and an in-app key simply overrides it.
const String kEnvGeminiKey = String.fromEnvironment('GEMINI_API_KEY');

/// User-tunable app settings.
class SettingsState extends Equatable {
  const SettingsState({
    required this.fireToastDuration,
    required this.geminiApiKey,
  });

  /// How long a fire-next toast stays on screen before auto-dismissing.
  final Duration fireToastDuration;

  /// User-supplied Google Gemini API key. Drives **both** the ticket scanner
  /// (scan parse) and the AI demo-data generator. Empty here = use the build-time
  /// [kEnvGeminiKey] if present, else AI is off (manual entry / the sample).
  final String geminiApiKey;

  /// Whether AI features have a key to use (in-app key or build-time fallback).
  bool get aiConfigured => geminiApiKey.isNotEmpty || kEnvGeminiKey.isNotEmpty;

  SettingsState copyWith({Duration? fireToastDuration, String? geminiApiKey}) =>
      SettingsState(
        fireToastDuration: fireToastDuration ?? this.fireToastDuration,
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      );

  @override
  List<Object?> get props => <Object?>[fireToastDuration, geminiApiKey];
}

/// Holds app preferences and persists them. Backed by [SharedPreferences] when
/// one is injected (by `main`); with none (tests/CI) it's session-only, mirroring
/// how the rest of the app injects real services and defaults to no-ops.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({SharedPreferences? prefs})
    : _prefs = prefs,
      super(SettingsState(
        fireToastDuration: _readFireToast(prefs),
        geminiApiKey: prefs?.getString(geminiApiKeyPref) ?? '',
      ));

  final SharedPreferences? _prefs;

  static const String _fireToastKey = 'fireToastSeconds';

  /// SharedPreferences key for the in-app Gemini API key. The DI-wired ticket
  /// scanner and demo-data generator read this same key (see `app/di.dart`), so a
  /// key saved in Profile powers both flows.
  static const String geminiApiKeyPref = 'geminiApiKey';

  /// The factory default (also the pre-injection fallback): keep the prior 3-min
  /// behaviour.
  static const Duration defaultFireToastDuration = Duration(minutes: 3);

  static Duration _readFireToast(SharedPreferences? prefs) {
    final int? seconds = prefs?.getInt(_fireToastKey);
    return seconds == null
        ? defaultFireToastDuration
        : Duration(seconds: seconds);
  }

  /// Set (and persist) the fire-toast hold time. Takes effect on the next fire.
  void setFireToastDuration(Duration duration) {
    if (duration == state.fireToastDuration) return;
    emit(state.copyWith(fireToastDuration: duration));
    _prefs?.setInt(_fireToastKey, duration.inSeconds);
  }

  /// Set (and persist) the in-app Gemini API key. Empty clears it (AI reverts to
  /// the build-time key if any, else off). Takes effect on the next scan/generate
  /// — both read the key live from the same store.
  void setGeminiApiKey(String key) {
    final String k = key.trim();
    if (k == state.geminiApiKey) return;
    emit(state.copyWith(geminiApiKey: k));
    if (k.isEmpty) {
      _prefs?.remove(geminiApiKeyPref);
    } else {
      _prefs?.setString(geminiApiKeyPref, k);
    }
  }
}
