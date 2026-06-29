import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsCubit', () {
    test('defaults to 30 seconds when no prefs are injected', () {
      final SettingsCubit cubit = SettingsCubit();
      expect(
        cubit.state.fireToastDuration,
        SettingsCubit.defaultFireToastDuration,
      );
      expect(cubit.state.fireToastDuration, const Duration(seconds: 30));
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

    test('autoDrip: defaults off at 3 min, toggles + interval persist + reload',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsCubit cubit = SettingsCubit(prefs: prefs);
      expect(cubit.state.autoDripEnabled, isFalse); // off by default
      expect(cubit.state.autoDripMins, SettingsCubit.defaultAutoDripMins);
      expect(cubit.state.autoDripMins, 3);

      cubit.setAutoDripEnabled(true);
      cubit.setAutoDripMins(5);
      expect(cubit.state.autoDripEnabled, isTrue);
      expect(cubit.state.autoDripMins, 5);
      expect(prefs.getBool('autoDripEnabled'), isTrue);
      expect(prefs.getInt('autoDripMins'), 5);

      // A fresh cubit over the same store keeps the drip on at 5 min.
      final SettingsCubit reloaded = SettingsCubit(prefs: prefs);
      expect(reloaded.state.autoDripEnabled, isTrue);
      expect(reloaded.state.autoDripMins, 5);
    });

    test('setAutoDripMins floors the interval at 1 minute', () {
      final SettingsCubit cubit = SettingsCubit();
      cubit.setAutoDripMins(0);
      expect(cubit.state.autoDripMins, 1);
      cubit.setAutoDripMins(-4);
      expect(cubit.state.autoDripMins, 1);
    });

    test('autoServe: defaults ON @2min; toggle + delay persist and reload',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsCubit cubit = SettingsCubit(prefs: prefs);
      expect(cubit.state.autoServeEnabled, isTrue); // on by default now
      expect(cubit.state.autoServeDelay, const Duration(minutes: 2));

      cubit.setAutoServeEnabled(false); // toggle off (away from the default)
      cubit.setAutoServeDelay(const Duration(minutes: 5));
      expect(prefs.getBool('autoServeEnabled'), isFalse);
      expect(prefs.getInt('autoServeSeconds'), 300);

      final SettingsCubit reloaded = SettingsCubit(prefs: prefs);
      expect(reloaded.state.autoServeEnabled, isFalse);
      expect(reloaded.state.autoServeDelay, const Duration(minutes: 5));
    });

    test('railWindowMins: defaults to 30, persists, and clamps to bounds',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsCubit cubit = SettingsCubit(prefs: prefs);
      expect(cubit.state.railWindowMins, 30);

      cubit.setRailWindowMins(60);
      expect(cubit.state.railWindowMins, 60);
      expect(prefs.getInt('railWindowMins'), 60);
      expect(SettingsCubit(prefs: prefs).state.railWindowMins, 60);

      cubit.setRailWindowMins(5); // below the floor
      expect(cubit.state.railWindowMins, SettingsCubit.minRailWindowMins);
      cubit.setRailWindowMins(9999); // above the ceiling
      expect(cubit.state.railWindowMins, SettingsCubit.maxRailWindowMins);
    });

    test('themeMode defaults to light; setThemeMode persists and reloads',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsCubit cubit = SettingsCubit(prefs: prefs);
      expect(cubit.state.themeMode, ThemeMode.light); // pastel theme by default

      cubit.setThemeMode(ThemeMode.dark);
      expect(cubit.state.themeMode, ThemeMode.dark);
      expect(prefs.getInt('themeMode'), ThemeMode.dark.index);

      // A fresh cubit over the same store keeps the dark theme.
      expect(SettingsCubit(prefs: prefs).state.themeMode, ThemeMode.dark);
    });

    test('setThemeMode is a no-op when the value is unchanged', () async {
      final SettingsCubit cubit = SettingsCubit();
      int emissions = 0;
      cubit.stream.listen((_) => emissions++);

      cubit.setThemeMode(ThemeMode.light); // already the default
      await Future<void>.delayed(Duration.zero);
      expect(emissions, 0);
    });
  });
}
