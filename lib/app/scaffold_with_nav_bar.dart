import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kbuzz/app/router.dart';
import 'package:kbuzz/core/announce/announcer.dart';
import 'package:kbuzz/core/widgets/app_toast.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
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
class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  /// The shell controlling which branch (tab) is shown.
  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar>
    with WidgetsBindingObserver {
  /// Guards the one-shot cold-start auto-resume so it fires at most once.
  bool _autoResumed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Catch a hydrate that already finished before this shell mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeAutoResumeRun();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Wall time kept flowing while we were backgrounded/asleep; resync the run
    // clock to the true elapsed the instant we return to the foreground.
    if (state == AppLifecycleState.resumed) {
      context.read<ServiceClockCubit>().sync();
    }
  }

  /// Auto-resume the run on a restart: if a board was RESTORED from the store
  /// (not freshly generated) and the clock isn't running yet, restore the speed
  /// and start the clock at the persisted epoch — so a device/app restart
  /// resumes at true wall time without a manual "Start service" tap. One-shot,
  /// guarded so a later generate still uses the explicit Start button.
  void _maybeAutoResumeRun() {
    if (_autoResumed) return;
    final DemoDataCubit demo = context.read<DemoDataCubit>();
    if (!demo.restoredFromStore) return;
    final ServiceClockCubit clock = context.read<ServiceClockCubit>();
    final DateTime? epoch = demo.state.generatedAt;
    if (epoch == null || clock.state.started) return;
    _autoResumed = true;
    final int? speed = demo.state.data?.speed;
    if (speed != null) clock.setSpeed(speed);
    demo.snapshotForRun(); // so Reset can rewind to the resumed board
    clock.start(epoch: epoch);
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      // Tapping the active tab returns it to its initial location.
      initialLocation: index == widget.navigationShell.currentIndex,
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
    // Speak the alert only when audio is on (Profile → Settings). Muting keeps
    // the toast above; it just silences the announcer. Fire-and-forget; the
    // announcer swallows its own errors.
    if (context.read<SettingsCubit>().state.announceEnabled) {
      context.read<Announcer>().announce(batchSpokenText(alerts));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DemoDataCubit, DemoDataState>(
      // Auto-resume the run once the restored board hydrates (if the post-frame
      // check in initState ran before hydrate completed).
      listenWhen: (DemoDataState prev, DemoDataState cur) =>
          !_autoResumed && cur.generatedAt != null,
      listener: (BuildContext context, DemoDataState _) =>
          _maybeAutoResumeRun(),
      child: BlocListener<SettingsCubit, SettingsState>(
        // Cut queued + in-flight speech the instant audio is muted (Profile →
        // Settings), so a mid-burst toggle stops talking immediately instead of
        // finishing the queue.
        listenWhen: (SettingsState prev, SettingsState cur) =>
            prev.announceEnabled && !cur.announceEnabled,
        listener: (BuildContext context, SettingsState _) =>
            context.read<Announcer>().stop(),
        child: BlocListener<SettingsCubit, SettingsState>(
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
                (prev.running && !cur.running) ||
                (prev.started && !cur.started),
            listener: (BuildContext context, ServiceClockState _) =>
                AppToast.dismiss(),
            child: BlocListener<FireAlertCubit, FireAlertState>(
              listenWhen: (FireAlertState prev, FireAlertState cur) =>
                  cur.tick != prev.tick,
              listener: (BuildContext context, FireAlertState state) =>
                  _onFireAlerts(context, state.latest),
              child: Scaffold(
                // Reserve the top inset (status bar: time/network) — the shell body
                // has no AppBar of its own, so without this the ServiceControlBar
                // (and the inner pages) would draw under it. `bottom: false` leaves
                // the bottom inset to the NavigationBar. SafeArea also strips the
                // consumed top padding for descendants, so the inner page AppBars
                // don't double-pad.
                body: SafeArea(
                  bottom: false,
                  child: Column(
                    children: <Widget>[
                      // Run controls on the board tabs only (not Profile).
                      if (widget.navigationShell.currentIndex < 3)
                        const ServiceControlBar(),
                      Expanded(child: widget.navigationShell),
                    ],
                  ),
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => const ScanRoute().push<void>(context),
                  tooltip: 'Scan KOT',
                  child: const Icon(Icons.camera_alt_outlined),
                ),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: widget.navigationShell.currentIndex,
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
        ),
      ),
    );
  }
}
