import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/board/board_widgets.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

/// Queue — the flat "fire next" feed across all tickets, in real scheduler fire
/// order (AGENTS.md §10).
///
/// Once a cook is served (all its tickets retained past [BoardConfig.retainMins])
/// it drops off — there's nothing left to fire. A batched cook stays until every
/// table it serves is served (see [dishServed]).
class QueuePage extends StatelessWidget {
  const QueuePage({super.key, this.config = const BoardConfig()});

  /// Board tunables (retain window). Injectable so tests can shrink it.
  final BoardConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fire next')),
      body: BlocBuilder<DemoDataCubit, DemoDataState>(
        builder: (BuildContext context, DemoDataState state) {
          if (state.data == null) {
            return const BoardEmptyState(
              icon: Icons.local_fire_department_outlined,
              title: 'Fire order',
            );
          }
          final BoardData board = BoardData.from(
            state.data!,
            now: state.generatedAt!,
            fireImmediately:
                context.watch<SettingsCubit>().state.fireImmediately,
          );
          final Bottleneck? bottleneck = board.schedule.bottleneck;
          // Re-filter every tick so served cooks fall off the queue live.
          return BlocBuilder<ServiceClockCubit, ServiceClockState>(
            builder: (BuildContext context, ServiceClockState clock) {
              final List<ScheduledDish> fireOrder = board.fireOrder
                  .where((ScheduledDish d) => !dishServed(
                        d,
                        board.statusForKot,
                        clock.elapsedMins,
                        started: clock.started,
                        retainMins: config.retainMins,
                      ))
                  .toList(growable: false);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  if (bottleneck != null)
                    BottleneckBanner(
                      stationName: board.stationOf(bottleneck.stationId)?.name ??
                          bottleneck.stationId,
                      lateMins: bottleneck.lateMins,
                    ),
                  for (int i = 0; i < fireOrder.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child:
                          _FireRow(rank: i + 1, dish: fireOrder[i], board: board),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _FireRow extends StatelessWidget {
  const _FireRow({
    required this.rank,
    required this.dish,
    required this.board,
  });

  final int rank;
  final ScheduledDish dish;
  final BoardData board;

  @override
  Widget build(BuildContext context) {
    final station = board.stationOf(dish.stationId);
    final Color? color = station == null ? null : Color(station.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: KBuzzColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: kMonoNumberStyle.copyWith(
                color: KBuzzColors.brandPrimary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ScheduledDishRow(
              dish: dish,
              stationColor: color,
              stationName: station?.name,
              showTables: true,
            ),
          ),
        ],
      ),
    );
  }
}
