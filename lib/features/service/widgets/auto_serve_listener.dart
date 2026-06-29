import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/fired_cooks_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

/// App-wide driver for **auto serve-all** (Profile → Settings). When
/// [SettingsState.autoServeEnabled] is on, a ticket whose every item has been
/// ready (cooked) for [SettingsState.autoServeDelay] is automatically served +
/// closed (moved to the Done section) — keeping the Tickets board clean without
/// manual taps.
///
/// Like the auto-drip, it piggy-backs on the service clock (no own timer): the
/// run clock ticks ~once a wall-second while active, so on each tick we rebuild
/// the schedule, check which active tickets have been ready past the delay, and
/// serve+close them. This respects pause (elapsed freezes) and run speed.
///
/// Mounted once below the app providers (see `app/di.dart`).
class AutoServeListener extends StatefulWidget {
  const AutoServeListener({super.key, required this.child});

  final Widget child;

  @override
  State<AutoServeListener> createState() => _AutoServeListenerState();
}

class _AutoServeListenerState extends State<AutoServeListener> {
  void _maybeServe() {
    final SettingsState settings = context.read<SettingsCubit>().state;
    if (!settings.autoServeEnabled) return;

    final ServiceClockState clock = context.read<ServiceClockCubit>().state;
    // Only while the run is advancing — a paused/stopped kitchen serves nothing.
    if (!clock.running) return;

    final DemoDataCubit demo = context.read<DemoDataCubit>();
    final DateTime? epoch = demo.state.generatedAt;
    final DemoData? data = demo.state.data;
    if (data == null || epoch == null) return;

    // Same schedule the boards show, so plate times line up exactly (including
    // pinned already-fired cooks).
    final BoardData board = BoardData.from(
      data,
      now: epoch,
      fireImmediately: settings.fireImmediately,
      pinnedFireMins:
          context.read<FiredCooksCubit?>()?.state.pinnedFireMins ??
              const <String, int>{},
    );

    final double elapsed = clock.elapsedMins;
    final double delayMins = settings.autoServeDelay.inSeconds / 60.0;

    for (final Kot kot in board.data.kots) {
      if (kot.status == TicketState.done) continue; // already closed
      final TicketStatus status = board.statusOf(kot);
      if (status.dishes.isEmpty) continue; // nothing cooking (served/void)
      // All items have been ready (cooked to plate) for the full grace period.
      if (elapsed >= status.plateMins + delayMins) {
        demo.serveAll(kot.id);
        demo.markTicketDone(kot.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ServiceClockCubit, ServiceClockState>(
      // Re-check whenever the run advances (or starts/stops).
      listenWhen: (ServiceClockState p, ServiceClockState c) =>
          c.elapsed != p.elapsed || c.running != p.running,
      listener: (BuildContext _, ServiceClockState _) => _maybeServe(),
      child: widget.child,
    );
  }
}
