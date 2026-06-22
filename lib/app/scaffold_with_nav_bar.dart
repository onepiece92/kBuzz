import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kbuzz/app/router.dart';
import 'package:kbuzz/core/announce/announcer.dart';
import 'package:kbuzz/core/widgets/app_toast.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/fire_alert_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:kbuzz/features/service/widgets/service_control_bar.dart';

/// The persistent app shell: a [NavigationBar] over the three board branches,
/// plus a brand-coloured action that pushes [ScanRoute] full-screen
/// (mirrors the prototype's "camera KOT" button).
///
/// Each branch keeps its own navigation stack via
/// [StatefulShellRoute.indexedStack].
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  /// The shell controlling which branch (tab) is shown.
  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab returns it to its initial location.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Present each new fire alert kitchen-wide: a bold top toast + spoken
  /// announcement. The toast **itemises the whole same-tick batch** (one row per
  /// station, scrolling if it covers the page) and the announcement speaks it in
  /// one utterance — so simultaneous multi-station fires are never lost.
  void _onFireAlerts(BuildContext context, List<FireAlert> alerts) {
    if (alerts.isEmpty) return;
    AppToast.fire(
      context,
      items: <FireToastItem>[
        for (final FireAlert a in alerts)
          FireToastItem(
            dishName: a.dishName,
            stationName: a.stationName,
            qty: a.qty,
            emoji: a.emoji,
          ),
      ],
      // Honour the user's configured hold time (Profile → Settings).
      duration: context.read<SettingsCubit>().state.fireToastDuration,
    );
    // Fire-and-forget; the announcer swallows its own errors.
    context.read<Announcer>().announce(batchSpokenText(alerts));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, SettingsState>(
      // Re-time a fire toast that's already on screen when the hold time is
      // changed live (Profile → Settings), so the visible toast adopts it.
      listenWhen: (SettingsState prev, SettingsState cur) =>
          prev.fireToastDuration != cur.fireToastDuration,
      listener: (BuildContext context, SettingsState state) =>
          AppToast.retime(state.fireToastDuration),
      child: BlocListener<ServiceClockCubit, ServiceClockState>(
        // Clear any lingering fire toast when the run pauses or resets — it
        // would otherwise hang around referring to a stopped run.
        listenWhen: (ServiceClockState prev, ServiceClockState cur) =>
            (prev.running && !cur.running) || (prev.started && !cur.started),
        listener: (BuildContext context, ServiceClockState _) =>
            AppToast.dismiss(),
        child: BlocListener<FireAlertCubit, FireAlertState>(
          listenWhen: (FireAlertState prev, FireAlertState cur) =>
              cur.tick != prev.tick,
          listener: (BuildContext context, FireAlertState state) =>
              _onFireAlerts(context, state.latest),
          child: Scaffold(
            body: Column(
              children: <Widget>[
                // Run controls on the board tabs only (not Profile).
                if (navigationShell.currentIndex < 3) const ServiceControlBar(),
                Expanded(child: navigationShell),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => const ScanRoute().push<void>(context),
              tooltip: 'Scan KOT',
              child: const Icon(Icons.camera_alt_outlined),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _goBranch,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.view_week_outlined),
                  selectedIcon: Icon(Icons.view_week),
                  label: 'Stations',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_fire_department_outlined),
                  selectedIcon: Icon(Icons.local_fire_department),
                  label: 'Fire next',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Tickets',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
