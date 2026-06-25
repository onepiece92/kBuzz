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
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const <Widget>[
            _SettingsCard(),
            SizedBox(height: 16),
            _DemoDataCard(),
            SizedBox(height: 16),
            _ApiKeyCard(),
            SizedBox(height: 16),
            _ScanTestCard(),
            SizedBox(height: 16),
            _SponsorsCard(),
          ],
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
    return Card(
      color: KBuzzColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons.local_fire_department,
                  size: 18,
                  color: KBuzzColors.brandPrimary,
                ),
                SizedBox(width: 8),
                Text(
                  'Fire toast display time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'How long a “fire next” alert stays on screen before it '
              'auto-dismisses. It also clears when a newer fire arrives or the '
              'run is paused.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 8),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 4),
            BlocBuilder<SettingsCubit, SettingsState>(
              builder: (BuildContext context, SettingsState state) => Row(
                children: <Widget>[
                  Icon(
                    state.announceEnabled
                        ? Icons.volume_up
                        : Icons.volume_off,
                    size: 18,
                    color: KBuzzColors.brandPrimary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Read fires aloud',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Switch(
                    value: state.announceEnabled,
                    onChanged: (bool v) =>
                        context.read<SettingsCubit>().setAnnounceEnabled(v),
                  ),
                ],
              ),
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
    return ChoiceChip(
      label: Text(preset.label),
      selected: selected,
      showCheckmark: false,
      backgroundColor: KBuzzColors.board,
      selectedColor: KBuzzColors.brandPrimary,
      side: BorderSide(
        color: selected ? KBuzzColors.brandPrimary : Colors.white24,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
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
    return Card(
      color: KBuzzColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.key, size: 18, color: KBuzzColors.brandPrimary),
                SizedBox(width: 8),
                Text(
                  'Claude API key',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Powers scanning a ticket photo and AI demo-data generation. '
              'Stored on this device only; leave blank to use manual entry and '
              'the built-in sample.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
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
                      size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  tooltip: _obscure ? 'Show' : 'Hide',
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                        color: state.aiConfigured
                            ? const Color(0xFF34D399)
                            : Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state.aiConfigured ? 'AI features on' : 'AI features off',
                        style: TextStyle(
                          color: state.aiConfigured
                              ? const Color(0xFF34D399)
                              : Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: _getKey, child: const Text('Get a key')),
                const SizedBox(width: 4),
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
    return Card(
      color: KBuzzColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  'Demo data',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                _AiBadge(enabled: aiEnabled, provider: provider),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              aiEnabled
                  ? 'Generate a brand-new restaurant and dinner rush with '
                        '$provider — a different menu and tickets every time.'
                  : 'Seed the prototype sample rush so you can test the boards. '
                        'For a fresh AI dataset every time, add a Claude key '
                        'in the “Claude API key” section below.',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
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
                          const SizedBox(width: 8),
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
                      const SizedBox(height: 16),
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
    final Color color = enabled
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            enabled ? Icons.auto_awesome : Icons.cloud_off,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            enabled ? 'AI · $provider' : 'AI OFF',
            style: TextStyle(
              color: color,
              fontSize: 11,
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
        const SizedBox(height: 16),
        const Text('Tickets', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final Kot kot in data.kots)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: KBuzzColors.board,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: kMonoNumberStyle.copyWith(
              color: KBuzzColors.brandPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70)),
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KBuzzColors.board,
        borderRadius: BorderRadius.circular(10),
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: KBuzzColors.brandSecondary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  kot.type.label,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(items, style: const TextStyle(color: Colors.white70)),
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
    return Card(
      color: KBuzzColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.document_scanner_outlined,
                    size: 18, color: KBuzzColors.brandPrimary),
                SizedBox(width: 8),
                Text(
                  'Scan a ticket image',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Drag & drop a saved KOT / receipt image onto a test page — for '
              'desktop / macOS. Needs a Claude key (above) and generated demo '
              'data to match against.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context, rootNavigator: true).push(
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
  late final PageController _controller =
      PageController(initialPage: _initialPage, viewportFraction: 0.92);
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
    return Card(
      color: KBuzzColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Sponsors',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Proudly supported by — tap to visit.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 86,
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (int page) =>
                    setState(() => _index = page % _kSponsors.length),
                itemBuilder: (BuildContext context, int page) {
                  final _Sponsor sponsor = _kSponsors[page % _kSponsors.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _SponsorBanner(
                      sponsor: sponsor,
                      onTap: () => _open(sponsor),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < _kSponsors.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? KBuzzColors.brandPrimary
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
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
    final String host =
        Uri.parse(sponsor.url).host.replaceFirst('www.', '');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
