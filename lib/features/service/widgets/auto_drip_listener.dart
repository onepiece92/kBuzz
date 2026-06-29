import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

/// App-wide driver for the **auto-ticket drip** (Profile → Demo data). When
/// [SettingsState.autoDripEnabled] is on, it injects one randomized ticket every
/// [SettingsState.autoDripMins] of **run time**, so orders trickle in like a real
/// service while you watch the boards react.
///
/// It piggy-backs on the service clock instead of owning a timer: the run clock
/// already ticks ~once a wall-second while active, re-deriving `elapsed`. We drip
/// whenever `elapsed` has advanced a full interval past the last drop — which
/// means the drip automatically **respects pause** (elapsed freezes) and **run
/// speed** (faster speed ⇒ orders arrive sooner in wall time), with no extra
/// timer to leak.
///
/// Mounted once below the app providers (see `app/di.dart`) so it runs on every
/// tab, not just Profile.
class AutoDripListener extends StatefulWidget {
  const AutoDripListener({super.key, required this.child});

  final Widget child;

  @override
  State<AutoDripListener> createState() => _AutoDripListenerState();
}

class _AutoDripListenerState extends State<AutoDripListener> {
  /// Run-time of the last drip (or of when the drip was switched on). The next
  /// ticket lands once `elapsed` is one full interval past this.
  Duration _lastDrip = Duration.zero;

  void _maybeDrip() {
    final SettingsState settings = context.read<SettingsCubit>().state;
    if (!settings.autoDripEnabled) return;

    final ServiceClockState clock = context.read<ServiceClockCubit>().state;
    // Only while the run is actually advancing — a paused/stopped kitchen takes
    // no new orders.
    if (!clock.running) return;

    final DemoDataCubit demo = context.read<DemoDataCubit>();
    if (!demo.state.hasData) return;

    // Run was reset (elapsed jumped back to ~0) — re-baseline so we don't dump a
    // backlog of "missed" tickets on the next tick.
    if (clock.elapsed < _lastDrip) _lastDrip = clock.elapsed;

    final Duration interval = Duration(minutes: settings.autoDripMins);
    if (clock.elapsed - _lastDrip < interval) return;

    _lastDrip = clock.elapsed;
    demo.addRandomKot(elapsed: clock.elapsed);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <BlocListener<dynamic, dynamic>>[
        // Start the countdown from "now" when the drip is switched on, so the
        // first auto ticket is one full interval later — not an immediate burst.
        BlocListener<SettingsCubit, SettingsState>(
          listenWhen: (SettingsState p, SettingsState c) =>
              c.autoDripEnabled && !p.autoDripEnabled,
          listener: (BuildContext ctx, SettingsState _) =>
              _lastDrip = ctx.read<ServiceClockCubit>().state.elapsed,
        ),
        // The run clock ticks while active; check the drip threshold each time
        // elapsed advances (or the run starts/stops).
        BlocListener<ServiceClockCubit, ServiceClockState>(
          listenWhen: (ServiceClockState p, ServiceClockState c) =>
              c.elapsed != p.elapsed || c.running != p.running,
          listener: (BuildContext _, ServiceClockState _) => _maybeDrip(),
        ),
      ],
      child: widget.child,
    );
  }
}
