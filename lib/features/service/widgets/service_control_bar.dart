import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

/// The run controls shown above the boards: *Start service* before a run, then
/// elapsed time + play/pause/reset + a speed toggle (mirrors the prototype
/// footer). Reads the app-wide [ServiceClockCubit].
class ServiceControlBar extends StatelessWidget {
  const ServiceControlBar({super.key});

  /// Format an elapsed [Duration] as the run timer: `0:00`, `5:30`, `1:02:09`
  /// (`h:mm:ss` only once it passes an hour). Clamps negatives to `0:00`.
  static String formatElapsed(Duration d) {
    final Duration e = d.isNegative ? Duration.zero : d;
    final int h = e.inHours;
    final int m = e.inMinutes.remainder(60);
    final String ss = e.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  }

  /// Reset = fresh start on the same restaurant: clear every ticket, reset all
  /// station capacities to their defaults (keeping the stations + menu), and
  /// zero the clock. Confirms first since it discards the run's progress.
  Future<void> _confirmReset(BuildContext context) async {
    final ServiceClockCubit clock = context.read<ServiceClockCubit>();
    final DemoDataCubit demo = context.read<DemoDataCubit>();
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Reset service?'),
            content: const Text(
              'Clears all tickets and resets every station to its default '
              'capacity for a fresh start — keeps the restaurant (stations and '
              'menu) and zeroes the clock.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Reset'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) {
      demo.clearForFreshStart(); // wipe tickets + reset station capacities
      clock.reset(); // zero the clock back to not-started
    }
  }

  @override
  Widget build(BuildContext context) {
    final ServiceClockCubit cubit = context.read<ServiceClockCubit>();
    return BlocBuilder<ServiceClockCubit, ServiceClockState>(
      builder: (BuildContext context, ServiceClockState state) {
        final KdsColors c = KdsColors.of(context);
        return Container(
          color: c.surface,
          padding: const EdgeInsets.symmetric(horizontal: kSpaceMd, vertical: kSpaceSm),
          child: Row(
            children: <Widget>[
              if (!state.started)
                Expanded(
                  child: FilledButton.icon(
                    // Snapshot the board as the run's start state (so Reset can
                    // rewind to it), then anchor elapsed=0 at the board epoch so
                    // live status lines up with the schedule's `now`.
                    onPressed: () {
                      final DemoDataCubit demo = context.read<DemoDataCubit>();
                      demo.snapshotForRun();
                      cubit.start(epoch: demo.state.generatedAt);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: c.success,
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start service'),
                  ),
                )
              else ...<Widget>[
                _ClockReadout(state: state),
                const SizedBox(width: kSpaceSm),
                IconButton(
                  tooltip: state.running ? 'Pause' : 'Resume',
                  onPressed: cubit.toggle,
                  icon: Icon(state.running ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  tooltip: 'Reset',
                  onPressed: () => _confirmReset(context),
                  icon: const Icon(Icons.replay),
                ),
                const Spacer(),
              ],
              _SpeedToggle(speed: state.speed, onChanged: cubit.setSpeed),
            ],
          ),
        );
      },
    );
  }
}

/// The service clock readout — a **live elapsed timer** for the run (session
/// time since *Start*), formatted `m:ss` (or `h:mm:ss` past an hour). It counts
/// kitchen-time, so a demo fast-forward speeds it up, and it reads `0:00` at the
/// start of a run and right after a reset.
class _ClockReadout extends StatelessWidget {
  const _ClockReadout({required this.state});

  final ServiceClockState state;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return Text(
      ServiceControlBar.formatElapsed(state.elapsed),
      style: kMonoNumberStyle.copyWith(
        color: c.brand,
        fontSize: kFontLg,
      ),
    );
  }
}

class _SpeedToggle extends StatelessWidget {
  const _SpeedToggle({required this.speed, required this.onChanged});

  final int speed;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.board,
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      padding: const EdgeInsets.all(kSpaceXs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final int s in ServiceClockCubit.speeds)
            GestureDetector(
              onTap: () => onChanged(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: kSpaceMd, vertical: kSpaceXs),
                decoration: BoxDecoration(
                  color: s == speed
                      ? c.brand
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: Text(
                  '${s}x',
                  style: kMonoNumberStyle.copyWith(
                    color: s == speed ? Colors.white : c.textMuted,
                    fontSize: kFontSm,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
