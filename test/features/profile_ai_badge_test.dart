import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/profile/profile_page.dart';

/// The demo-data card's AI badge must react to the Claude key — saving a key in
/// Profile (a SettingsCubit emit, not a DemoDataCubit one) has to flip it on.
void main() {
  testWidgets('AI badge flips on when a Claude key is set', (
    WidgetTester tester,
  ) async {
    final DemoDataCubit demo = DemoDataCubit();
    final SettingsCubit settings = SettingsCubit(); // session-only, no key
    addTearDown(demo.close);
    addTearDown(settings.close);

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

    // No key yet → badge is off.
    expect(find.text('AI OFF'), findsOneWidget);
    expect(find.textContaining('AI ·'), findsNothing);

    // Saving a key (SettingsCubit emit) must flip the badge — this is the
    // regression: it used to stay 'AI OFF' until a DemoDataCubit emit.
    settings.setClaudeApiKey('sk-ant-test-key');
    await tester.pumpAndSettle();

    expect(find.text('AI OFF'), findsNothing);
    expect(find.textContaining('AI ·'), findsOneWidget);

    // Clearing it flips it back off.
    settings.setClaudeApiKey('');
    await tester.pumpAndSettle();
    expect(find.text('AI OFF'), findsOneWidget);
  });
}
