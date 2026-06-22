import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kbuzz/app/scaffold_with_nav_bar.dart';
import 'package:kbuzz/features/profile/profile_page.dart';
import 'package:kbuzz/features/queue/queue_page.dart';
import 'package:kbuzz/features/scan/scan_page.dart';
import 'package:kbuzz/features/stations/stations_page.dart';
import 'package:kbuzz/features/tickets/tickets_page.dart';

part 'router.g.dart';

/// Root navigator key — lets top-level routes (e.g. [ScanRoute]) render above
/// the tab shell, and gives future auth redirects a stable anchor.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app's [GoRouter], built from generated typed routes (AGENTS.md §7).
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: const StationsRoute().location,
  routes: $appRoutes,
);

/// Persistent bottom-tab shell hosting the three boards. Each branch keeps its
/// own navigation state via [StatefulShellRoute.indexedStack].
@TypedStatefulShellRoute<MainShellRouteData>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<StationsBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<StationsRoute>(path: '/stations'),
      ],
    ),
    TypedStatefulShellBranch<QueueBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<QueueRoute>(path: '/queue'),
      ],
    ),
    TypedStatefulShellBranch<TicketsBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<TicketsRoute>(path: '/tickets'),
      ],
    ),
    TypedStatefulShellBranch<ProfileBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ProfileRoute>(path: '/profile'),
      ],
    ),
  ],
)
class MainShellRouteData extends StatefulShellRouteData {
  const MainShellRouteData();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    return ScaffoldWithNavBar(navigationShell: navigationShell);
  }
}

class StationsBranchData extends StatefulShellBranchData {
  const StationsBranchData();
}

class QueueBranchData extends StatefulShellBranchData {
  const QueueBranchData();
}

class TicketsBranchData extends StatefulShellBranchData {
  const TicketsBranchData();
}

class ProfileBranchData extends StatefulShellBranchData {
  const ProfileBranchData();
}

/// `/stations` — the stations rail tab.
class StationsRoute extends GoRouteData with $StationsRoute {
  const StationsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const StationsPage();
}

/// `/queue` — the flat fire-next tab.
class QueueRoute extends GoRouteData with $QueueRoute {
  const QueueRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const QueuePage();
}

/// `/tickets` — the table-centric expo tab.
class TicketsRoute extends GoRouteData with $TicketsRoute {
  const TicketsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const TicketsPage();
}

/// `/profile` — profile/settings tab (hosts the demo-data generator for now).
class ProfileRoute extends GoRouteData with $ProfileRoute {
  const ProfileRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProfilePage();
}

/// `/scan` — full-screen scan flow pushed above the tab shell.
@TypedGoRoute<ScanRoute>(path: '/scan')
class ScanRoute extends GoRouteData with $ScanRoute {
  const ScanRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ScanPage();
}
