import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/board/board_widgets.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/fired_cooks_cubit.dart';
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
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            <Widget>[
              SliverAppBar(
                title: const Text('Fire next'),
                floating: true,
                snap: true,
                forceElevated: innerBoxIsScrolled,
              ),
            ],
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
              fireImmediately: context
                  .watch<SettingsCubit>()
                  .state
                  .fireImmediately,
              // Optional: present app-wide (DI), absent in lean widget tests →
              // empty pins (no pinning, identical schedule).
              pinnedFireMins:
                  context.watch<FiredCooksCubit?>()?.state.pinnedFireMins ??
                      const <String, int>{},
            );
            final Bottleneck? bottleneck = board.schedule.bottleneck;
            // Re-filter every tick so served cooks fall off the queue live.
            return BlocBuilder<ServiceClockCubit, ServiceClockState>(
              builder: (BuildContext context, ServiceClockState clock) {
                final List<ScheduledDish> fireOrder = board.fireOrder
                    .where(
                      (ScheduledDish d) {
                        // Served + retained cooks have left the board entirely.
                        if (dishServed(
                          d,
                          board.statusForKot,
                          clock.elapsedMins,
                          started: clock.started,
                          retainMins: config.retainMins,
                        )) {
                          return false;
                        }
                        // "Fire next" is the upcoming/in-progress feed — once a
                        // cook has finished cooking it's no longer something to
                        // fire, so it drops off (it's now the expo's to serve).
                        if (clock.started && clock.elapsedMins >= d.finishAt) {
                          return false;
                        }
                        return true;
                      },
                    )
                    .toList(growable: false);
                return ListView(
                  padding: const EdgeInsets.all(kSpaceLg),
                  children: <Widget>[
                    if (bottleneck != null)
                      BottleneckBanner(
                        stationName:
                            board.stationOf(bottleneck.stationId)?.name ??
                            bottleneck.stationId,
                        lateMins: bottleneck.lateMins,
                      ),
                    for (int i = 0; i < fireOrder.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: kSpaceSm),
                        child: _FireRow(
                          rank: i + 1,
                          dish: fireOrder[i],
                          board: board,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FireRow extends StatelessWidget {
  const _FireRow({required this.rank, required this.dish, required this.board});

  final int rank;
  final ScheduledDish dish;
  final BoardData board;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    final station = board.stationOf(dish.stationId);
    final Color? color = station == null ? null : Color(station.color);
    // Ticket-colour stripe so a cook reads as its order — same colour the
    // Stations rail paints this ticket's bar (first table for a batched cook).
    final Color tColor = dish.members.isEmpty
        ? (color ?? c.textFaint)
        : ticketColor(dish.members.first.kotId);
    return TicketStripeCard(
      ticketColor: tColor,
      padding: const EdgeInsets.symmetric(
        horizontal: kSpaceMd,
        vertical: kSpaceMd,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: kMonoNumberStyle.copyWith(
                color: c.brand,
                fontSize: kFontMd,
              ),
            ),
          ),
          const SizedBox(width: kSpaceSm),
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
