import 'package:flutter/material.dart' show ThemeMode;
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

    test('fireImmediately: defaults off, toggles, persists, reloads', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final SettingsCubit cubit = SettingsCubit(prefs: prefs);
      expect(cubit.state.fireImmediately, isFalse); // just-in-time by default

      cubit.setFireImmediately(true);
      expect(cubit.state.fireImmediately, isTrue);
      expect(prefs.getBool('fireImmediately'), isTrue);

      final SettingsCubit reloaded = SettingsCubit(prefs: prefs);
      expect(reloaded.state.fireImmediately, isTrue);
    });

    test('every preset is selectable and round-trips through the cubit', () {
      final SettingsCubit cubit = SettingsCubit();
      for (final FireToastPreset preset in kFireToastPresets) {
        cubit.setFireToastDuration(preset.duration);
        expect(cubit.state.fireToastDuration, preset.duration);
      }
    });

    test('claude key: trims, persists, flips aiConfigured, reloads', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsCubit cubit = SettingsCubit(prefs: prefs);
      expect(cubit.state.claudeApiKey, '');
      expect(cubit.state.aiConfigured, isFalse); // no key, no --dart-define

      cubit.setClaudeApiKey('  sk-ant-test-key  ');
      expect(cubit.state.claudeApiKey, 'sk-ant-test-key'); // trimmed
      expect(cubit.state.aiConfigured, isTrue);
      expect(prefs.getString(SettingsCubit.claudeApiKeyPref), 'sk-ant-test-key');

      // A fresh cubit over the same store reflects the persisted key — the same
      // store the DI-wired scanner + demo generator read, so both pick it up.
      expect(SettingsCubit(prefs: prefs).state.claudeApiKey, 'sk-ant-test-key');
    });

    test('clearing the claude key removes it from prefs', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SettingsCubit.claudeApiKeyPref: 'sk-ant-old',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsCubit cubit = SettingsCubit(prefs: prefs);
      expect(cubit.state.claudeApiKey, 'sk-ant-old');

      cubit.setClaudeApiKey('');
      expect(cubit.state.claudeApiKey, '');
      expect(prefs.getString(SettingsCubit.claudeApiKeyPref), isNull);
    });

    test('announceEnabled defaults on; toggling persists and reloads', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsCubit cubit = SettingsCubit(prefs: prefs);
      expect(cubit.state.announceEnabled, isTrue); // on by default

      cubit.setAnnounceEnabled(false);
      expect(cubit.state.announceEnabled, isFalse);
      expect(prefs.getBool('announceEnabled'), isFalse);

      // A fresh cubit over the same store stays muted.
      expect(SettingsCubit(prefs: prefs).state.announceEnabled, isFalse);
    });

    test('setAnnounceEnabled is a no-op when the value is unchanged', () async {
      final SettingsCubit cubit = SettingsCubit();
      int emissions = 0;
      cubit.stream.listen((_) => emissions++);

      cubit.setAnnounceEnabled(true); // already the default
      await Future<void>.delayed(Duration.zero);
      expect(emissions, 0);
    });

    test('themeMode defaults to dark; setThemeMode persists and reloads',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsCubit cubit = SettingsCubit(prefs: prefs);
      expect(cubit.state.themeMode, ThemeMode.dark); // neon board by default

      cubit.setThemeMode(ThemeMode.light);
      expect(cubit.state.themeMode, ThemeMode.light);
      expect(prefs.getInt('themeMode'), ThemeMode.light.index);

      // A fresh cubit over the same store keeps the light theme.
      expect(SettingsCubit(prefs: prefs).state.themeMode, ThemeMode.light);
    });

    test('setThemeMode is a no-op when the value is unchanged', () async {
      final SettingsCubit cubit = SettingsCubit();
      int emissions = 0;
      cubit.stream.listen((_) => emissions++);

      cubit.setThemeMode(ThemeMode.dark); // already the default
      await Future<void>.delayed(Duration.zero);
      expect(emissions, 0);
    });
  });
}
