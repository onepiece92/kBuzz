import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/profile/profile_page.dart';

/// Widget coverage for the Profile page's interactive cards — previously only
/// the AI badge ([profile_ai_badge_test]) and the cubits were tested, never the
/// page's own UI logic (key entry, obscure toggle, generate button).
void main() {
  Future<void> pumpProfile(
    WidgetTester tester, {
    required DemoDataCubit demo,
    required SettingsCubit settings,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<DemoDataCubit>.value(value: demo),
            BlocProvider<SettingsCubit>.value(value: settings),
          ],
          child: const ProfilePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Drain the success-toast's auto-dismiss timer + slide-out so no timer
  // outlives the test (flutter_test fails on pending timers).
  Future<void> flush(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'API key card: entering a key + Save persists it and flips AI features on',
      (WidgetTester tester) async {
    final DemoDataCubit demo = DemoDataCubit();
    final SettingsCubit settings = SettingsCubit(); // session-only, no key
    addTearDown(demo.close);
    addTearDown(settings.close);

    await pumpProfile(tester, demo: demo, settings: settings);

    // No key yet → the in-card indicator reads off.
    expect(find.text('AI features off'), findsOneWidget);

    // The key card sits below the fold — scroll it in before interacting.
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Surrounding whitespace must be trimmed before persisting.
    await tester.enterText(find.byType(TextField), '  sk-ant-secret  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump(); // toast inserts
    await tester.pump(const Duration(milliseconds: 350)); // slide-in

    expect(settings.state.claudeApiKey, 'sk-ant-secret');
    expect(find.text('AI features on'), findsOneWidget);
    expect(find.text('AI features off'), findsNothing);
    expect(find.textContaining('Claude key saved'), findsOneWidget);

    await flush(tester);
  });

  testWidgets('API key card: Save with a blank field clears the stored key',
      (WidgetTester tester) async {
    final DemoDataCubit demo = DemoDataCubit();
    final SettingsCubit settings = SettingsCubit()
      ..setClaudeApiKey('sk-ant-existing');
    addTearDown(demo.close);
    addTearDown(settings.close);

    await pumpProfile(tester, demo: demo, settings: settings);
    expect(find.text('AI features on'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(settings.state.claudeApiKey, isEmpty);
    expect(find.text('AI features off'), findsOneWidget);
    expect(find.textContaining('cleared'), findsOneWidget);

    await flush(tester);
  });

  testWidgets('API key card: the visibility toggle unmasks the field',
      (WidgetTester tester) async {
    final DemoDataCubit demo = DemoDataCubit();
    final SettingsCubit settings = SettingsCubit();
    addTearDown(demo.close);
    addTearDown(settings.close);

    await pumpProfile(tester, demo: demo, settings: settings);

    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();

    // The key field is obscured by default.
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);

    // Tapping the eye reveals it.
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
  });

  testWidgets('demo-data card: Generate populates the board (no AI → sample)',
      (WidgetTester tester) async {
    final DemoDataCubit demo = DemoDataCubit(); // no generator → random sample
    final SettingsCubit settings = SettingsCubit();
    addTearDown(demo.close);
    addTearDown(settings.close);

    await pumpProfile(tester, demo: demo, settings: settings);
    expect(demo.state.data, isNull);

    await tester.tap(find.text('Generate demo data'));
    await tester.pumpAndSettle();

    expect(demo.state.data, isNotNull);
    expect(demo.state.data!.kots, isNotEmpty);
  });
}
