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

/// Settings panel. Currently the fire-toast hold time — how long a "fire next"
/// alert stays on screen (it also clears on a newer fire or a pause/reset).
class _SettingsCard extends StatelessWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return Card(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.local_fire_department, size: 18, color: c.brand),
                const SizedBox(width: kSpaceSm),
                const Text(
                  'Fire toast display time',
                  style: TextStyle(
                    fontSize: kFontLg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpaceXs),
            Text(
              'How long a “fire next” alert stays on screen before it '
              'auto-dismisses. It also clears when a newer fire arrives or the '
              'run is paused.',
              style: TextStyle(color: c.textMuted, fontSize: kFontMd),
            ),
            const SizedBox(height: kSpaceLg),
            BlocBuilder<SettingsCubit, SettingsState>(
              builder: (BuildContext context, SettingsState state) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final FireToastPreset preset in kFireToastPresets)
                      _PresetChip(
                        preset: preset,
                        selected: state.fireToastDuration == preset.duration,
                        onTap: () => context
                            .read<SettingsCubit>()
                            .setFireToastDuration(preset.duration),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: kSpaceSm),
            Divider(color: c.hairline, height: 1),
            const SizedBox(height: kSpaceXs),
            BlocBuilder<SettingsCubit, SettingsState>(
              builder: (BuildContext context, SettingsState state) => Row(
                children: <Widget>[
                  Icon(
                    state.announceEnabled ? Icons.volume_up : Icons.volume_off,
                    size: 18,
                    color: c.brand,
                  ),
                  const SizedBox(width: kSpaceSm),
                  const Expanded(
                    child: Text(
                      'Read fires aloud',
                      style: TextStyle(
                        fontSize: kFontMd,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch(
                    key: const Key('announceToggle'),
                    value: state.announceEnabled,
                    onChanged: (bool v) =>
                        context.read<SettingsCubit>().setAnnounceEnabled(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kSpaceSm),
            Divider(color: c.hairline, height: 1),
            const SizedBox(height: kSpaceXs),
            BlocBuilder<SettingsCubit, SettingsState>(
              builder: (BuildContext context, SettingsState state) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.timer_outlined, size: 18, color: c.brand),
                      const SizedBox(width: kSpaceSm),
                      const Expanded(
                        child: Text(
                          'Start cooking immediately',
                          style: TextStyle(
                            fontSize: kFontMd,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch(
                        key: const Key('fireImmediatelyToggle'),
                        value: state.fireImmediately,
                        onChanged: (bool v) =>
                            context.read<SettingsCubit>().setFireImmediately(v),
                      ),
                    ],
                  ),
                  Text(
                    state.fireImmediately
                        ? 'Every dish fires as soon as its station is free — '
                              'stations start right away.'
                        : 'Just-in-time: each dish starts so it’s ready exactly '
                              'when due, so a station may sit idle first.',
                    style: TextStyle(color: c.textMuted, fontSize: kFontSm),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kSpaceSm),
            Divider(color: c.hairline, height: 1),
            const SizedBox(height: kSpaceXs),
            Row(
              children: <Widget>[
                Icon(Icons.palette_outlined, size: 18, color: c.brand),
                const SizedBox(width: kSpaceSm),
                const Expanded(
                  child: Text(
                    'Theme',
                    style: TextStyle(
                      fontSize: kFontMd,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpaceSm),
            BlocBuilder<SettingsCubit, SettingsState>(
              builder: (BuildContext context, SettingsState state) {
                final SettingsCubit cubit = context.read<SettingsCubit>();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _ThemeChip(
                      label: 'System',
                      selected: state.themeMode == ThemeMode.system,
                      onTap: () => cubit.setThemeMode(ThemeMode.system),
                    ),
                    _ThemeChip(
                      label: 'Light',
                      selected: state.themeMode == ThemeMode.light,
                      onTap: () => cubit.setThemeMode(ThemeMode.light),
                    ),
                    _ThemeChip(
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
      ),
    );
  }
}

/// A selectable preset chip for the fire-toast hold time.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final FireToastPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return ChoiceChip(
      label: Text(preset.label),
      selected: selected,
      showCheckmark: false,
      backgroundColor: c.board,
      selectedColor: c.brand,
      side: BorderSide(color: selected ? c.brand : c.hairlineStrong),
      labelStyle: TextStyle(
        color: selected ? Colors.white : c.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

/// A selectable theme-mode chip (System / Light / Dark), styled like
/// [_PresetChip].
class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
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
        color: selected ? Colors.white : c.textSecondary,
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
  bool _obscure = true;

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
    return Card(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.key, size: 18, color: c.brand),
                const SizedBox(width: kSpaceSm),
                const Text(
                  'Claude API key',
                  style: TextStyle(
                    fontSize: kFontLg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpaceXs),
            Text(
              'Powers scanning a ticket photo and AI demo-data generation. '
              'Stored on this device only; leave blank to use manual entry and '
              'the built-in sample.',
              style: TextStyle(color: c.textMuted, fontSize: kFontMd),
            ),
            const SizedBox(height: kSpaceMd),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'sk-ant-…',
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  tooltip: _obscure ? 'Show' : 'Hide',
                ),
              ),
            ),
            const SizedBox(height: kSpaceMd),
            Row(
              children: <Widget>[
                BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (BuildContext context, SettingsState state) => Row(
                    children: <Widget>[
                      Icon(
                        state.aiConfigured
                            ? Icons.check_circle
                            : Icons.info_outline,
                        size: 16,
                        color: state.aiConfigured ? c.expoReady : c.textFaint,
                      ),
                      const SizedBox(width: kSpaceSm),
                      Text(
                        state.aiConfigured
                            ? 'AI features on'
                            : 'AI features off',
                        style: TextStyle(
                          color: state.aiConfigured ? c.expoReady : c.textMuted,
                          fontSize: kFontMd,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: _getKey, child: const Text('Get a key')),
                const SizedBox(width: kSpaceXs),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The "generate demo data" panel: a button plus a live summary of whatever the
/// [DemoDataCubit] currently holds.
class _DemoDataCard extends StatelessWidget {
  const _DemoDataCard();

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
    return Card(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  'Demo data',
                  style: TextStyle(
                    fontSize: kFontLg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _AiBadge(enabled: aiEnabled, provider: provider),
              ],
            ),
            const SizedBox(height: kSpaceXs),
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
                                    AppToast.show(
                                      context,
                                      'Demo data cleared.',
                                    );
                                  },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ],
                    ),
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
      ),
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
          spacing: 8,
          runSpacing: 8,
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
              Text(
                'Table ${kot.table}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: kSpaceSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpaceSm,
                  vertical: kSpaceXs,
                ),
                decoration: BoxDecoration(
                  color: KBuzzColors.brandSecondary,
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: Text(
                  kot.type.label,
                  style: const TextStyle(
                    fontSize: kFontXs,
                    color: Colors.white,
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
/// needed, so it works on simulators/desktop. Needs a Claude key + demo data.
class _ScanTestCard extends StatelessWidget {
  const _ScanTestCard();

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return Card(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.document_scanner_outlined, size: 18, color: c.brand),
                const SizedBox(width: kSpaceSm),
                const Text(
                  'Scan a ticket image',
                  style: TextStyle(
                    fontSize: kFontLg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpaceXs),
            Text(
              'Drag & drop a saved KOT / receipt image onto a test page — for '
              'desktop / macOS. Needs a Claude key (above) and generated demo '
              'data to match against.',
              style: TextStyle(color: c.textMuted, fontSize: kFontMd),
            ),
            const SizedBox(height: kSpaceMd),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext _) =>
                            const ScanPage(dropMode: true),
                      ),
                    ),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Open drop-to-scan page'),
              ),
            ),
          ],
        ),
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
