import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsCubit', () {
    test('defaults to 3 minutes when no prefs are injected', () {
      final SettingsCubit cubit = SettingsCubit();
      expect(
        cubit.state.fireToastDuration,
        SettingsCubit.defaultFireToastDuration,
      );
      expect(cubit.state.fireToastDuration, const Duration(minutes: 3));
    });

    test('setFireToastDuration updates the state', () {
      final SettingsCubit cubit = SettingsCubit();
      final List<Duration> emitted = <Duration>[];
      cubit.stream.listen((SettingsState s) => emitted.add(s.fireToastDuration));

      cubit.setFireToastDuration(const Duration(seconds: 30));
      expect(cubit.state.fireToastDuration, const Duration(seconds: 30));
    });

    test('setting the same value does not emit again', () async {
      final SettingsCubit cubit = SettingsCubit();
      int emissions = 0;
      cubit.stream.listen((_) => emissions++);

      cubit.setFireToastDuration(SettingsCubit.defaultFireToastDuration);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, 0); // already at the default — no-op
    });

    test('persists to prefs and a fresh cubit reads it back', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final SettingsCubit cubit = SettingsCubit(prefs: prefs);
      expect(
        cubit.state.fireToastDuration,
        SettingsCubit.defaultFireToastDuration,
      );

      cubit.setFireToastDuration(const Duration(minutes: 5));
      expect(prefs.getInt('fireToastSeconds'), 300);

      // A new cubit over the same store reflects the persisted choice.
      final SettingsCubit reloaded = SettingsCubit(prefs: prefs);
      expect(reloaded.state.fireToastDuration, const Duration(minutes: 5));
    });

    test('every preset is selectable and round-trips through the cubit', () {
      final SettingsCubit cubit = SettingsCubit();
      for (final FireToastPreset preset in kFireToastPresets) {
        cubit.setFireToastDuration(preset.duration);
        expect(cubit.state.fireToastDuration, preset.duration);
      }
    });

    test('gemini key: trims, persists, flips aiConfigured, reloads', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsCubit cubit = SettingsCubit(prefs: prefs);
      expect(cubit.state.geminiApiKey, '');
      expect(cubit.state.aiConfigured, isFalse); // no key, no --dart-define

      cubit.setGeminiApiKey('  AIza-test-key  ');
      expect(cubit.state.geminiApiKey, 'AIza-test-key'); // trimmed
      expect(cubit.state.aiConfigured, isTrue);
      expect(prefs.getString(SettingsCubit.geminiApiKeyPref), 'AIza-test-key');

      // A fresh cubit over the same store reflects the persisted key — the same
      // store the DI-wired scanner + demo generator read, so both pick it up.
      expect(SettingsCubit(prefs: prefs).state.geminiApiKey, 'AIza-test-key');
    });

    test('clearing the gemini key removes it from prefs', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SettingsCubit.geminiApiKeyPref: 'AIza-old',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsCubit cubit = SettingsCubit(prefs: prefs);
      expect(cubit.state.geminiApiKey, 'AIza-old');

      cubit.setGeminiApiKey('');
      expect(cubit.state.geminiApiKey, '');
      expect(prefs.getString(SettingsCubit.geminiApiKeyPref), isNull);
    });
  });
}
