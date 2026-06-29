import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/core/widgets/app_toast.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/scan/scan_page.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:url_launcher/url_launcher.dart';

/// Profile / settings tab.
///
/// Hosts the **Generate demo data** testing aid (seeds the prototype's sample
/// data into the in-memory [DemoDataCubit]) and a **Settings** section for
/// user-tunable preferences such as the fire-toast hold time (AGENTS.md §15).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            <Widget>[
              SliverAppBar(
                title: const Text('Profile'),
                floating: true,
                snap: true,
                forceElevated: innerBoxIsScrolled,
              ),
            ],
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(kSpaceLg),
            children: const <Widget>[
              _SettingsCard(),
              SizedBox(height: kSpaceLg),
              _DemoDataCard(),
              SizedBox(height: kSpaceLg),
              _ApiKeyCard(),
              SizedBox(height: kSpaceLg),
              _ScanTestCard(),
              SizedBox(height: kSpaceLg),
              _SponsorsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A collapsible Profile card: an [ExpansionTile] inside a surface [Card] with a
/// brand icon, a bold title, an optional header widget (e.g. the AI badge), and a
/// body revealed on tap. Keeps the Profile page short — each section opens only
/// when needed (the long demo-data summary stays tucked away by default).
class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.icon,
    required this.title,
    required this.child,
    this.headerTrailing,
    this.initiallyExpanded = false,
    this.maintainState = false,
  });

  final IconData icon;
  final String title;
  final Widget child;

  /// Shown in the header to the right of the title, before the expand chevron
  /// (e.g. the demo card's AI badge) — visible whether open or closed.
  final Widget? headerTrailing;
  final bool initiallyExpanded;

  /// Keep [child] alive while collapsed (use for sections holding input state,
  /// e.g. the API-key field, so typed text survives a collapse).
  final bool maintainState;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return Card(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // ExpansionTile draws default divider lines when expanded; hide them.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          maintainState: maintainState,
          tilePadding: const EdgeInsets.symmetric(horizontal: kSpaceLg),
          childrenPadding: const EdgeInsets.fromLTRB(
            kSpaceLg,
            kSpaceSm,
            kSpaceLg,
            kSpaceLg,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: c.brand,
          collapsedIconColor: c.textMuted,
          leading: Icon(icon, size: 20, color: c.brand),
          title: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: kFontLg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (headerTrailing != null) ...<Widget>[
                headerTrailing!,
                const SizedBox(width: kSpaceSm),
              ],
            ],
          ),
          children: <Widget>[child],
        ),
      ),
    );
  }
}

/// Settings panel: fire-toast hold time, audio, cook-timing, auto-serve, rail
/// width and theme, grouped under Alerts / Service / Display. Collapsed by
/// default — like every Profile section — so the page opens compact on each
/// app start / refresh; tap to expand.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return _CollapsibleSection(
      icon: Icons.tune,
      title: 'Settings',
      initiallyExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _GroupLabel('Alerts'),
          const SizedBox(height: kSpaceSm),
          _SettingHeader(
            icon: Icons.local_fire_department,
            title: 'Fire toast display time',
          ),
          const SizedBox(height: kSpaceXs),
          Text(
            'How long a “fire next” alert stays on screen before it '
            'auto-dismisses. It also clears when a newer fire arrives or the '
            'run is paused.',
            style: TextStyle(color: c.textMuted, fontSize: kFontSm),
          ),
          const SizedBox(height: kSpaceSm),
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (BuildContext context, SettingsState state) {
              return Wrap(
                spacing: kSpaceSm,
                runSpacing: kSpaceSm,
                children: <Widget>[
                  for (final FireToastPreset preset in kFireToastPresets)
                    _SettingChip(
                      label: preset.label,
                      selected: state.fireToastDuration == preset.duration,
                      onTap: () => context
                          .read<SettingsCubit>()
                          .setFireToastDuration(preset.duration),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: kSpaceXs),
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (BuildContext context, SettingsState state) => SwitchListTile(
              key: const Key('announceToggle'),
              contentPadding: EdgeInsets.zero,
              isThreeLine: true,
              value: state.announceEnabled,
              onChanged: context.read<SettingsCubit>().setAnnounceEnabled,
              secondary: Icon(
                state.announceEnabled ? Icons.volume_up : Icons.volume_off,
                size: 18,
                color: c.brand,
              ),
              title: const Text(
                'Read fires aloud',
                style: TextStyle(
                  fontSize: kFontMd,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Speak each fire alert aloud — the on-screen toast still shows '
                'when this is off.',
                style: TextStyle(color: c.textMuted, fontSize: kFontSm),
              ),
            ),
          ),
          const SizedBox(height: kSpaceLg),
          Divider(color: c.hairline, height: 1),
          const SizedBox(height: kSpaceSm),
          const _GroupLabel('Service'),
          const SizedBox(height: kSpaceXs),
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (BuildContext context, SettingsState state) =>
                SwitchListTile(
                  key: const Key('fireImmediatelyToggle'),
                  contentPadding: EdgeInsets.zero,
                  isThreeLine: true,
                  value: state.fireImmediately,
                  onChanged: context.read<SettingsCubit>().setFireImmediately,
                  secondary: Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: c.brand,
                  ),
                  title: const Text(
                    'Start cooking immediately',
                    style: TextStyle(
                      fontSize: kFontMd,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    state.fireImmediately
                        ? 'Every dish fires as soon as its station is free — '
                              'stations start right away.'
                        : 'Just-in-time: each dish starts so it’s ready exactly '
                              'when due, so a station may sit idle first.',
                    style: TextStyle(color: c.textMuted, fontSize: kFontSm),
                  ),
                ),
          ),
          const SizedBox(height: kSpaceXs),
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (BuildContext context, SettingsState state) {
              final SettingsCubit cubit = context.read<SettingsCubit>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SwitchListTile(
                    key: const Key('autoServeToggle'),
                    contentPadding: EdgeInsets.zero,
                    isThreeLine: true,
                    value: state.autoServeEnabled,
                    onChanged: cubit.setAutoServeEnabled,
                    secondary: Icon(Icons.task_alt, size: 18, color: c.brand),
                    title: const Text(
                      'Auto serve & close ready tickets',
                      style: TextStyle(
                        fontSize: kFontMd,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Once every item on a ticket has been ready for the '
                      'delay below, it’s served and moved to Done '
                      'automatically — so the Tickets board stays clean.',
                      style: TextStyle(color: c.textMuted, fontSize: kFontSm),
                    ),
                  ),
                  if (state.autoServeEnabled) ...<Widget>[
                    const SizedBox(height: kSpaceXs),
                    Text(
                      'Delay after ready',
                      style: TextStyle(color: c.textMuted, fontSize: kFontSm),
                    ),
                    const SizedBox(height: kSpaceXs),
                    Wrap(
                      spacing: kSpaceSm,
                      runSpacing: kSpaceSm,
                      children: <Widget>[
                        for (final FireToastPreset p in kAutoServePresets)
                          _SettingChip(
                            label: p.label,
                            selected: state.autoServeDelay == p.duration,
                            onTap: () => cubit.setAutoServeDelay(p.duration),
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: kSpaceLg),
          Divider(color: c.hairline, height: 1),
          const SizedBox(height: kSpaceSm),
          const _GroupLabel('Display'),
          const SizedBox(height: kSpaceXs),
          _SettingHeader(
            icon: Icons.view_timeline_outlined,
            title: 'Stations timeline width',
          ),
          const SizedBox(height: kSpaceXs),
          Text(
            'How much time the Stations rail shows at once before it '
            'scrolls. Smaller = bigger, easier-to-read bars.',
            style: TextStyle(color: c.textMuted, fontSize: kFontSm),
          ),
          const SizedBox(height: kSpaceSm),
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (BuildContext context, SettingsState state) {
              final SettingsCubit cubit = context.read<SettingsCubit>();
              return Wrap(
                spacing: kSpaceSm,
                runSpacing: kSpaceSm,
                children: <Widget>[
                  for (final int m in kRailWindowPresets)
                    _SettingChip(
                      label: '$m min',
                      selected: state.railWindowMins == m,
                      onTap: () => cubit.setRailWindowMins(m),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: kSpaceMd),
          _SettingHeader(icon: Icons.palette_outlined, title: 'Theme'),
          const SizedBox(height: kSpaceSm),
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (BuildContext context, SettingsState state) {
              final SettingsCubit cubit = context.read<SettingsCubit>();
              return Wrap(
                spacing: kSpaceSm,
                runSpacing: kSpaceSm,
                children: <Widget>[
                  _SettingChip(
                    label: 'System',
                    selected: state.themeMode == ThemeMode.system,
                    onTap: () => cubit.setThemeMode(ThemeMode.system),
                  ),
                  _SettingChip(
                    label: 'Light',
                    selected: state.themeMode == ThemeMode.light,
                    onTap: () => cubit.setThemeMode(ThemeMode.light),
                  ),
                  _SettingChip(
                    label: 'Dark',
                    selected: state.themeMode == ThemeMode.dark,
                    onTap: () => cubit.setThemeMode(ThemeMode.dark),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A small muted section label that groups related settings within a card
/// (e.g. "Alerts", "Service", "Display").
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: c.textFaint,
        fontSize: kFontXs,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// An icon + title row used as the header for a non-toggle setting (one whose
/// control is a chip row below it), matching the [SwitchListTile] toggles' look.
class _SettingHeader extends StatelessWidget {
  const _SettingHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: c.brand),
        const SizedBox(width: kSpaceSm),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: kFontMd,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A selectable settings chip — one shared style for every preset/option picker
/// in Profile (fire-toast time, auto-serve delay, rail width, theme, drip rate).
class _SettingChip extends StatelessWidget {
  const _SettingChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      backgroundColor: c.board,
      selectedColor: c.brand,
      side: BorderSide(color: selected ? c.brand : c.hairlineStrong),
      labelStyle: TextStyle(
        // Dark ink on the orange fill — white misses WCAG AA on the brand.
        color: selected ? c.onBrand : c.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

/// Lets the user paste an Anthropic (Claude) API key. Persisted via
/// [SettingsCubit] and read live by **both** the ticket scanner (scan parse) and
/// the AI demo-data generator (see `app/di.dart`) — so one key powers both.
/// Stored on-device only; the build-time `--dart-define=ANTHROPIC_API_KEY` is the
/// fallback.
class _ApiKeyCard extends StatefulWidget {
  const _ApiKeyCard();

  @override
  State<_ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends State<_ApiKeyCard> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = context.read<SettingsCubit>().state.claudeApiKey;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final String key = _controller.text.trim();
    context.read<SettingsCubit>().setClaudeApiKey(key);
    FocusScope.of(context).unfocus();
    AppToast.success(
      context,
      key.isEmpty
          ? 'Claude key cleared — scan & AI demo use manual / sample.'
          : 'Claude key saved — scanning and AI demo data are on.',
    );
  }

  Future<void> _getKey() async {
    final Uri url = Uri.parse('https://console.anthropic.com/settings/keys');
    final bool ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) AppToast.error(context, 'Could not open the browser.');
  }

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return _CollapsibleSection(
      icon: Icons.key,
      title: 'Claude API key',
      maintainState: true, // keep typed text if the section is collapsed
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Powers scanning a ticket photo and AI demo-data generation. '
            'Stored on this device only; leave blank to use manual entry and '
            'the built-in sample.',
            style: TextStyle(color: c.textMuted, fontSize: kFontMd),
          ),
          const SizedBox(height: kSpaceMd),
          TextField(
            controller: _controller,
            // Always masked — the key is write-only from the UI (no reveal).
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              hintText: 'sk-ant-…',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: kSpaceMd),
          Row(
            children: <Widget>[
              Expanded(
                child: BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (BuildContext context, SettingsState state) => Row(
                    children: <Widget>[
                      Icon(
                        state.aiConfigured
                            ? Icons.check_circle
                            : Icons.info_outline,
                        size: 16,
                        color: state.aiConfigured ? c.success : c.textFaint,
                      ),
                      const SizedBox(width: kSpaceSm),
                      Flexible(
                        child: Text(
                          state.aiConfigured
                              ? 'AI features on'
                              : 'AI features off',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: state.aiConfigured ? c.success : c.textMuted,
                            fontSize: kFontMd,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: kSpaceXs),
              TextButton(onPressed: _getKey, child: const Text('Get a key')),
              const SizedBox(width: kSpaceXs),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}

/// The "generate demo data" panel: a button plus a live summary of whatever the
/// [DemoDataCubit] currently holds.
class _DemoDataCard extends StatelessWidget {
  const _DemoDataCard();

  /// Drop **one** fresh ticket onto the live board — simulates a new order
  /// arriving mid-service. Ordered at the current run time (board epoch + the
  /// service clock's elapsed) so it appears at the now-line, just like a KOT that
  /// just came in. No-op when there's no board yet.
  void _addTicket(BuildContext context) {
    final DemoDataCubit cubit = context.read<DemoDataCubit>();
    final Duration elapsed = context.read<ServiceClockCubit>().state.elapsed;
    final Kot? kot = cubit.addRandomKot(elapsed: elapsed);
    if (kot == null || !context.mounted) return;
    final int items = kot.lines.fold<int>(
      0,
      (int sum, OrderLine l) => sum + l.qty,
    );
    AppToast.success(
      context,
      'New ticket — #${kot.table}, $items ${items == 1 ? 'dish' : 'dishes'}.',
      note: 'Added to the live board at the current time.',
    );
  }

  Future<void> _generate(BuildContext context) async {
    final DemoDataCubit cubit = context.read<DemoDataCubit>();
    await cubit.generate();
    if (!context.mounted) return;
    final DemoDataState state = cubit.state;
    final DemoData? data = state.data;
    if (data == null) return;
    final String summary =
        '${data.kots.length} tickets, '
        '${data.totalDishes} dishes, ${data.stations.length} stations.';
    if (state.error != null) {
      // Short, plain-language reason; full technical detail stays in the logs.
      AppToast.error(
        context,
        '${state.error} Showing a sample instead.',
        duration: const Duration(seconds: 5),
      );
    } else {
      AppToast.success(
        context,
        '${cubit.aiEnabled ? '${cubit.aiProvider} generated' : 'Demo data generated'} — '
        '$summary',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings so the AI badge flips the moment a key is saved/cleared:
    // the in-app Claude key drives the generator, and SettingsState.aiConfigured
    // is the same live truth (in-app key or build-time fallback).
    final bool aiEnabled = context.watch<SettingsCubit>().state.aiConfigured;
    final String provider = context.read<DemoDataCubit>().aiProvider;
    final KdsColors c = KdsColors.of(context);
    return _CollapsibleSection(
      icon: Icons.science_outlined,
      title: 'Demo data',
      headerTrailing: _AiBadge(enabled: aiEnabled, provider: provider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            aiEnabled
                ? 'Generate a brand-new restaurant and dinner rush with '
                      '$provider — a different menu and tickets every time.'
                : 'Seed the prototype sample rush so you can test the boards. '
                      'For a fresh AI dataset every time, add a Claude key '
                      'in the “Claude API key” section below.',
            style: TextStyle(color: c.textMuted, fontSize: kFontMd),
          ),
          const SizedBox(height: kSpaceLg),
          BlocBuilder<DemoDataCubit, DemoDataState>(
            builder: (BuildContext context, DemoDataState state) {
              final bool busy = state.generating;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy ? null : () => _generate(context),
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(
                            busy
                                ? (aiEnabled
                                      ? 'Generating with AI…'
                                      : 'Generating…')
                                : state.hasData
                                ? 'Regenerate demo data'
                                : 'Generate demo data',
                          ),
                        ),
                      ),
                      if (state.hasData) ...<Widget>[
                        const SizedBox(width: kSpaceSm),
                        IconButton(
                          tooltip: 'Clear demo data',
                          onPressed: busy
                              ? null
                              : () {
                                  context.read<DemoDataCubit>().clear();
                                  AppToast.show(context, 'Demo data cleared.');
                                },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ],
                  ),
                  // A "new order just came in" drip: adds one ticket at the
                  // current run time so you can watch the boards react live,
                  // like a real service. Only meaningful once a board exists.
                  if (state.hasData) ...<Widget>[
                    const SizedBox(height: kSpaceSm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () => _addTicket(context),
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Add a ticket'),
                      ),
                    ),
                    const _AutoDripControl(),
                  ],
                  if (state.data != null) ...<Widget>[
                    const SizedBox(height: kSpaceLg),
                    _DemoSummary(data: state.data!),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The interval presets offered for the auto-ticket drip, in run minutes.
const List<int> _kAutoDripMinutes = <int>[1, 2, 3, 5, 10];

/// Toggle + interval picker for the auto-ticket drip (Profile → Demo data). When
/// on, [AutoDripListener] adds one randomized ticket every N minutes of run time.
class _AutoDripControl extends StatelessWidget {
  const _AutoDripControl();

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    final SettingsState s = context.watch<SettingsCubit>().state;
    final SettingsCubit settings = context.read<SettingsCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SwitchListTile(
          key: const Key('autoDripToggle'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: s.autoDripEnabled,
          onChanged: settings.setAutoDripEnabled,
          title: const Text(
            'Auto-add tickets',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: kFontMd),
          ),
          subtitle: Text(
            'A new order every ${s.autoDripMins} min of run time, while the '
            'run is playing.',
            style: TextStyle(color: c.textMuted, fontSize: kFontSm),
          ),
        ),
        if (s.autoDripEnabled) ...<Widget>[
          const SizedBox(height: kSpaceXs),
          Text(
            'Every',
            style: TextStyle(color: c.textMuted, fontSize: kFontSm),
          ),
          const SizedBox(height: kSpaceXs),
          Wrap(
            spacing: kSpaceSm,
            runSpacing: kSpaceSm,
            children: <Widget>[
              for (final int m in _kAutoDripMinutes)
                _SettingChip(
                  label: m == 1 ? '1 min' : '$m min',
                  selected: s.autoDripMins == m,
                  onTap: () => settings.setAutoDripMins(m),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// At-a-glance indicator of whether live AI generation is wired up. Green "AI ·
/// Claude" when a Claude key is set (in-app via the key card, or build-time
/// `--dart-define`); amber "AI OFF" when none (the button then produces the
/// fixed sample).
class _AiBadge extends StatelessWidget {
  const _AiBadge({required this.enabled, required this.provider});

  final bool enabled;
  final String provider;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    final Color color = enabled ? c.success : c.slackCook;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpaceSm,
        vertical: kSpaceXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            enabled ? Icons.auto_awesome : Icons.cloud_off,
            size: 12,
            color: color,
          ),
          const SizedBox(width: kSpaceXs),
          Text(
            enabled ? 'AI · $provider' : 'AI OFF',
            style: TextStyle(
              color: color,
              fontSize: kFontXs,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact, scrollable summary of the generated demo data.
class _DemoSummary extends StatelessWidget {
  const _DemoSummary({required this.data});

  final DemoData data;

  @override
  Widget build(BuildContext context) {
    final Map<String, Dish> menuById = <String, Dish>{
      for (final Dish d in data.menu) d.id: d,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: kSpaceSm,
          runSpacing: kSpaceSm,
          children: <Widget>[
            _StatChip(label: 'Tickets', value: '${data.kots.length}'),
            _StatChip(label: 'Dishes', value: '${data.totalDishes}'),
            _StatChip(label: 'Menu', value: '${data.menu.length}'),
            _StatChip(label: 'Stations', value: '${data.stations.length}'),
          ],
        ),
        const SizedBox(height: kSpaceLg),
        const Text('Tickets', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: kSpaceSm),
        for (final Kot kot in data.kots)
          Padding(
            padding: const EdgeInsets.only(bottom: kSpaceSm),
            child: _KotTile(kot: kot, menuById: menuById),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpaceMd,
        vertical: kSpaceSm,
      ),
      decoration: BoxDecoration(
        color: c.board,
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: kMonoNumberStyle.copyWith(color: c.brand, fontSize: kFontLg),
          ),
          const SizedBox(width: kSpaceSm),
          Text(label, style: TextStyle(color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _KotTile extends StatelessWidget {
  const _KotTile({required this.kot, required this.menuById});

  final Kot kot;
  final Map<String, Dish> menuById;

  @override
  Widget build(BuildContext context) {
    final String items = kot.lines
        .map((OrderLine l) {
          final Dish? dish = menuById[l.dishId];
          final String name = dish?.name ?? l.dishId;
          final String emoji = dish == null ? '' : '${dish.emoji} ';
          return l.qty > 1 ? '$emoji$name ×${l.qty}' : '$emoji$name';
        })
        .join(' · ');

    final KdsColors c = KdsColors.of(context);
    return Container(
      padding: const EdgeInsets.all(kSpaceMd),
      decoration: BoxDecoration(
        color: c.board,
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  // Dine-in orders sit at a table; takeaway/delivery don't.
                  kot.type == KotType.dineIn
                      ? 'Table ${kot.table}'
                      : 'Order ${kot.table}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: kSpaceSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpaceSm,
                  vertical: kSpaceXs,
                ),
                decoration: BoxDecoration(
                  color: c.brand.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                // Brand-tinted fill with a muted-text label: a same-hue brand
                // foreground fails contrast on the light theme's pale tint, so
                // use textSecondary, which stays legible (>4.5:1) in both themes.
                child: Text(
                  kot.type.label,
                  style: TextStyle(
                    fontSize: kFontXs,
                    fontWeight: FontWeight.w700,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpaceXs),
          Text(items, style: TextStyle(color: c.textSecondary)),
        ],
      ),
    );
  }
}

/// One sponsor: a display [label] and the [url] its banner opens.
class _Sponsor {
  const _Sponsor(this.label, this.url);

  final String label;
  final String url;
}

/// The sponsors shown in the Profile carousel.
const List<_Sponsor> _kSponsors = <_Sponsor>[
  _Sponsor('Brand Builder Pvt Ltd', 'https://brandbuilder.com.np/'),
  _Sponsor('Rebuzz POS & Ordering', 'https://rebuzzpos.com/'),
  _Sponsor('Vcardly - Online Biz Card', 'https://vcardly.link/'),
  _Sponsor('Resume AI', 'https://cvai.dev/'),
];

/// Testing aid: upload a saved KOT/receipt photo and run it through the **real**
/// scan flow (Claude parse → review → add to the board, ad-hoc dishes and all).
/// Opens the scan screen with the gallery picker already triggered — no camera
/// needed, so it works on simulators/desktop. Needs a Claude key; demo data is
/// optional (the scan can bootstrap a board on its own).
class _ScanTestCard extends StatelessWidget {
  const _ScanTestCard();

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return _CollapsibleSection(
      icon: Icons.document_scanner_outlined,
      title: 'Scan a ticket image',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Drag & drop a saved KOT / receipt image onto a test page — for '
            'desktop / macOS. Needs a Claude key (above); demo data is '
            'optional — with none, it builds a board from the scan.',
            style: TextStyle(color: c.textMuted, fontSize: kFontMd),
          ),
          const SizedBox(height: kSpaceMd),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext _) => const ScanPage(dropMode: true),
                ),
              ),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Open drop-to-scan page'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Auto-advancing, swipeable sponsor carousel with dot indicators. Each banner
/// opens its sponsor's site in the external browser; failures surface a toast.
class _SponsorsCard extends StatefulWidget {
  const _SponsorsCard();

  @override
  State<_SponsorsCard> createState() => _SponsorsCardState();
}

class _SponsorsCardState extends State<_SponsorsCard> {
  // Start deep in a virtual range so the carousel can loop both ways smoothly;
  // the real sponsor is index % _kSponsors.length.
  static const int _initialPage = 10000;
  late final PageController _controller = PageController(
    initialPage: _initialPage,
    viewportFraction: 0.92,
  );
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(_Sponsor sponsor) async {
    bool ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(sponsor.url),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      ok = false;
    }
    if (!mounted || ok) return;
    AppToast.error(context, 'Could not open ${sponsor.label}');
  }

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    // Sponsors stay always-visible (not a collapsible section) so the banner is
    // never hidden behind a dropdown.
    return Card(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Sponsors',
              style: TextStyle(fontSize: kFontLg, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: kSpaceXs),
            Text(
              'Proudly supported by — tap to visit.',
              style: TextStyle(color: c.textMuted, fontSize: kFontMd),
            ),
            const SizedBox(height: kSpaceLg),
            SizedBox(
              height: 86,
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (int page) =>
                    setState(() => _index = page % _kSponsors.length),
                itemBuilder: (BuildContext context, int page) {
                  final _Sponsor sponsor = _kSponsors[page % _kSponsors.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kSpaceXs),
                    child: _SponsorBanner(
                      sponsor: sponsor,
                      onTap: () => _open(sponsor),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: kSpaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < _kSponsors.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: kSpaceXs),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index ? c.brand : c.hairlineStrong,
                      borderRadius: BorderRadius.circular(kRadiusSm),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single tappable sponsor banner (brand gradient, label + domain).
class _SponsorBanner extends StatelessWidget {
  const _SponsorBanner({required this.sponsor, required this.onTap});

  final _Sponsor sponsor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String host = Uri.parse(sponsor.url).host.replaceFirst('www.', '');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusLg),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                KBuzzColors.brandSecondary,
                KBuzzColors.brandPrimary,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(kRadiusLg),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: kSpaceLg,
            vertical: kSpaceLg,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      sponsor.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: kFontMd,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: kSpaceXs),
                    Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: kFontSm,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: kSpaceSm),
              const Icon(Icons.open_in_new, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
