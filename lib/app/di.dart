import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:kbuzz/core/announce/announcer.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/core/logger.dart';
import 'package:kbuzz/data/ai/demo_data_generator.dart';
import 'package:kbuzz/data/ai/ticket_scanner.dart';
import 'package:kbuzz/data/db/database.dart';
import 'package:kbuzz/data/repositories/kitchen_repository.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/fire_alert_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Root dependency-injection wiring.
///
/// kBuzz uses bloc for state, so DI goes through bloc's
/// [MultiRepositoryProvider] (shared services) and, later,
/// [MultiBlocProvider] (feature cubits/blocs) — not Riverpod. Widgets read
/// shared dependencies with `context.read<T>()` and never construct them inline
/// (AGENTS.md §9, adapted for bloc).
///
/// As the data layer lands, register repositories (Drift-backed) and the sync
/// engine here, and wrap feature blocs around [child].
class AppProviders extends StatelessWidget {
  const AppProviders({
    super.key,
    this.database,
    this.announcer,
    this.prefs,
    required this.child,
  });

  /// The Drift database to use. Injected on-disk by `main`; defaults to an
  /// in-memory database so widget tests run without `path_provider`.
  final AppDatabase? database;

  /// Fire-alert announcer. Injected (`SystemAnnouncer`) by `main`; defaults to
  /// [NoopAnnouncer] so tests stay silent.
  final Announcer? announcer;

  /// Persisted settings store. Injected by `main`; when null (tests/CI) the
  /// [SettingsCubit] keeps preferences in memory for the session only.
  final SharedPreferences? prefs;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The effective Claude key, read **live** on each scan/generate: the in-app
    // key (Profile → Settings, persisted) wins; the build-time
    // `--dart-define=ANTHROPIC_API_KEY` is the fallback. One key drives both the
    // ticket scanner and the AI demo-data generator.
    String claudeKey() {
      final String? stored = prefs?.getString(SettingsCubit.claudeApiKeyPref);
      return (stored != null && stored.isNotEmpty)
          ? stored
          : const String.fromEnvironment('ANTHROPIC_API_KEY');
    }

    return MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<Clock>(create: (_) => const SystemClock()),
        RepositoryProvider<Logger>(create: (_) => const Logger('app')),
        // Drift source of truth + repository. On-disk in the app (injected),
        // in-memory by default so tests don't need path_provider.
        RepositoryProvider<AppDatabase>(
          create: (_) => database ?? AppDatabase.memory(),
        ),
        RepositoryProvider<KitchenRepository>(
          create: (BuildContext context) =>
              KitchenRepository(context.read<AppDatabase>()),
        ),
        // Live AI demo-data generator (Claude). Reads the effective key live via
        // claudeKey() (in-app Profile key, else --dart-define); without either,
        // isConfigured is false and the cubit falls back to the sample.
        RepositoryProvider<DemoDataGenerator>(
          create: (_) =>
              DemoDataGenerator.resolved(client: http.Client(), apiKey: claudeKey),
        ),
        // Vision-LLM ticket scanner for the scan flow (opt-in via the key).
        RepositoryProvider<TicketScanner>(
          create: (_) =>
              TicketScanner.resolved(client: http.Client(), apiKey: claudeKey),
        ),
        // Fire-alert audio. On-device TTS+chime in the app (injected by main);
        // a silent no-op by default so tests/CI don't hit platform channels.
        RepositoryProvider<Announcer>(
          create: (_) => announcer ?? const NoopAnnouncer(),
        ),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<StateStreamableSource<Object?>>>[
          // App-wide so future boards can read the same generated demo data.
          BlocProvider<DemoDataCubit>(
            create: (BuildContext context) => DemoDataCubit(
              clock: context.read<Clock>(),
              repository: context.read<KitchenRepository>(),
              generator: context.read<DemoDataGenerator>(),
            ),
          ),
          // App-wide run clock shared by all three boards (drives live status).
          BlocProvider<ServiceClockCubit>(
            create: (BuildContext context) => ServiceClockCubit(),
          ),
          // App-wide user preferences (fire-toast hold time, cook-timing policy,
          // …), persisted via the injected SharedPreferences (session-only when
          // none is injected). Declared before FireAlertCubit, which reads it.
          BlocProvider<SettingsCubit>(
            create: (BuildContext context) => SettingsCubit(prefs: prefs),
          ),
          // Detects fire-next crossings off the clock + schedule; the nav shell
          // listens and presents (toast + announce). Uses the cook-timing setting
          // so alerts fire at the same times the boards show.
          BlocProvider<FireAlertCubit>(
            create: (BuildContext context) => FireAlertCubit(
              data: context.read<DemoDataCubit>(),
              clock: context.read<ServiceClockCubit>(),
              settings: context.read<SettingsCubit>(),
            ),
          ),
        ],
        child: child,
      ),
    );
  }
}
