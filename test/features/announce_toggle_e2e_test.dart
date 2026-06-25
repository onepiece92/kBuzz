import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kbuzz/app/scaffold_with_nav_bar.dart';
import 'package:kbuzz/core/announce/announcer.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/data/ai/demo_data_generator.dart';
import 'package:kbuzz/data/db/database.dart';
import 'package:kbuzz/data/repositories/kitchen_repository.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/profile/profile_page.dart';
import 'package:kbuzz/features/service/cubit/fire_alert_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

/// Records what the shell asked to be spoken, so the test can assert the
/// "Read fires aloud" toggle gates audio (and only audio — the toast still shows).
class _RecordingAnnouncer implements Announcer {
  final List<String> spoken = <String>[];
  int chimes = 0;

  @override
  Future<void> announce(String text) async => spoken.add(text);

  @override
  Future<void> chime() async => chimes++;
}

/// A real [FireAlertCubit] with a hook to push a fire on demand (mirrors the
/// fire-toast e2e harness).
class _DrivableFireAlertCubit extends FireAlertCubit {
  _DrivableFireAlertCubit({required super.data, required super.clock});

  void drive(List<FireAlert> alerts) =>
      emit(FireAlertState(latest: alerts, tick: state.tick + 1));
}

void main() {
  Future<
      ({
        SettingsCubit settings,
        _DrivableFireAlertCubit fire,
        _RecordingAnnouncer announcer,
      })> pumpShell(WidgetTester tester) async {
    final AppDatabase db = AppDatabase.memory();
    final KitchenRepository repo = KitchenRepository(db);
    final DemoDataCubit demo = DemoDataCubit(
      clock: const SystemClock(),
      repository: repo,
      generator: DemoDataGenerator.fromEnvironment(),
    );
    final ServiceClockCubit clock = ServiceClockCubit();
    final _DrivableFireAlertCubit fire =
        _DrivableFireAlertCubit(data: demo, clock: clock);
    final SettingsCubit settings = SettingsCubit();
    final _RecordingAnnouncer announcer = _RecordingAnnouncer();

    addTearDown(() async {
      await fire.close();
      await clock.close();
      await demo.close();
      await settings.close();
      await db.close();
    });

    final GoRouter router = GoRouter(
      initialLocation: '/profile',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (_, _, StatefulNavigationShell shell) =>
              ScaffoldWithNavBar(navigationShell: shell),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(path: '/stations', builder: (_, _) => const Scaffold()),
            ]),
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(path: '/queue', builder: (_, _) => const Scaffold()),
            ]),
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(path: '/tickets', builder: (_, _) => const Scaffold()),
            ]),
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
            ]),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      RepositoryProvider<Announcer>.value(
        value: announcer,
        child: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<DemoDataCubit>.value(value: demo),
            BlocProvider<ServiceClockCubit>.value(value: clock),
            BlocProvider<FireAlertCubit>.value(value: fire),
            BlocProvider<SettingsCubit>.value(value: settings),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (settings: settings, fire: fire, announcer: announcer);
  }

  void driveOneFire(_DrivableFireAlertCubit fire) => fire.drive(
        const <FireAlert>[
          FireAlert(
            stationId: 'grill',
            stationName: 'Grill',
            dishName: 'Burger',
            qty: 2,
          ),
        ],
      );

  testWidgets(
      'muting "Read fires aloud" silences the announcer but keeps the toast',
      (WidgetTester tester) async {
    final (
      :SettingsCubit settings,
      :_DrivableFireAlertCubit fire,
      :_RecordingAnnouncer announcer,
    ) = await pumpShell(tester);

    // Audio is on by default → a fire is both shown and spoken.
    expect(settings.state.announceEnabled, isTrue);
    driveOneFire(fire);
    await tester.pump(); // listener inserts the toast + calls announce
    await tester.pump(const Duration(milliseconds: 300)); // slide-in
    expect(find.text('FIRE NOW'), findsOneWidget);
    expect(announcer.spoken, hasLength(1));
    expect(announcer.spoken.single, contains('Burger'));

    // Mute via the real Profile switch.
    await tester.ensureVisible(find.text('Read fires aloud'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(settings.state.announceEnabled, isFalse);

    // A second fire still raises the toast, but nothing new is spoken.
    driveOneFire(fire);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FIRE NOW'), findsOneWidget);
    expect(announcer.spoken, hasLength(1)); // unchanged → muted

    // Drain the fire toast's auto-dismiss timer so none outlives the test.
    await tester.pump(const Duration(minutes: 4));
    await tester.pumpAndSettle();
  });
}
