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

/// A real [FireAlertCubit] (it still subscribes to the live clock + data) with a
/// hook to push a fire on demand, so the test drives the shell's listener exactly
/// as a scheduler crossing would — without simulating the whole clock run.
class _DrivableFireAlertCubit extends FireAlertCubit {
  _DrivableFireAlertCubit({
    required super.data,
    required super.clock,
    required super.settings,
  });

  void drive(List<FireAlert> alerts) =>
      emit(FireAlertState(latest: alerts, tick: state.tick + 1));
}

void main() {
  // Builds the genuine app shell (ScaffoldWithNavBar) over a go_router, with the
  // real ProfilePage on the Profile branch. Returns the cubits the test drives.
  Future<({SettingsCubit settings, _DrivableFireAlertCubit fire})> pumpShell(
    WidgetTester tester,
  ) async {
    final AppDatabase db = AppDatabase.memory();
    final KitchenRepository repo = KitchenRepository(db);
    final DemoDataCubit demo = DemoDataCubit(
      clock: const SystemClock(),
      repository: repo,
      generator: DemoDataGenerator.fromEnvironment(),
    );
    final ServiceClockCubit clock = ServiceClockCubit();
    final SettingsCubit settings = SettingsCubit();
    final _DrivableFireAlertCubit fire =
        _DrivableFireAlertCubit(data: demo, clock: clock, settings: settings);

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
        value: const NoopAnnouncer(),
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
    return (settings: settings, fire: fire);
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
    'picking the 10s preset makes the live fire toast dismiss at ~10s '
    '(not the 3-min default)',
    (WidgetTester tester) async {
      final (:SettingsCubit settings, :_DrivableFireAlertCubit fire) =
          await pumpShell(tester);

      // Change the setting through the real Profile UI.
      expect(find.text('Fire toast display time'), findsOneWidget);
      await tester.tap(find.text('10s'));
      await tester.pump();
      expect(settings.state.fireToastDuration, const Duration(seconds: 10));

      // A fire crosses → the shell shows the toast.
      driveOneFire(fire);
      await tester.pump(); // listener inserts the overlay
      await tester.pump(const Duration(milliseconds: 300)); // slide-in
      expect(find.text('FIRE NOW'), findsOneWidget);
      expect(find.text('2× Burger'), findsOneWidget);

      // Still on screen just before the 10s hold elapses.
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('FIRE NOW'), findsOneWidget);

      // Gone shortly after 10s — proving the chosen hold, not the 3-min default.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('FIRE NOW'), findsNothing);
    },
  );

  testWidgets(
    'picking the 1-min preset keeps the toast alive well past 10s',
    (WidgetTester tester) async {
      final (:SettingsCubit settings, :_DrivableFireAlertCubit fire) =
          await pumpShell(tester);

      await tester.tap(find.text('1 min'));
      await tester.pump();
      expect(settings.state.fireToastDuration, const Duration(minutes: 1));

      driveOneFire(fire);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('FIRE NOW'), findsOneWidget);

      // At 15s a 10s hold would already be gone; the 1-min hold keeps it up.
      await tester.pump(const Duration(seconds: 15));
      expect(find.text('FIRE NOW'), findsOneWidget);

      // Eventually it does dismiss (it's not infinite) — past the 1-min hold.
      await tester.pump(const Duration(seconds: 47));
      await tester.pumpAndSettle();
      expect(find.text('FIRE NOW'), findsNothing);
    },
  );

  testWidgets(
    'changing the hold time re-times a fire toast that is already on screen',
    (WidgetTester tester) async {
      final (:SettingsCubit settings, :_DrivableFireAlertCubit fire) =
          await pumpShell(tester);

      // Show a fire under a long (1-min) hold.
      await tester.tap(find.text('1 min'));
      await tester.pump();
      driveOneFire(fire);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('FIRE NOW'), findsOneWidget);

      // It's sat there a few seconds; now shorten the hold to 10s while it's up.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('FIRE NOW'), findsOneWidget);
      await tester.tap(find.text('10s'));
      await tester.pump();
      expect(settings.state.fireToastDuration, const Duration(seconds: 10));

      // The visible toast now re-times to ~10s *from the change*: up at +9s…
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('FIRE NOW'), findsOneWidget);

      // …and gone shortly after — far before the original 1-min would elapse.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('FIRE NOW'), findsNothing);
    },
  );
}
