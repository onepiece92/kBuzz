import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/core/result.dart';
import 'package:kbuzz/core/widgets/app_toast.dart';
import 'package:kbuzz/data/ai/ticket_scanner.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:uuid/uuid.dart';

/// Scan flow: capture a photo → vision-LLM parse → review → create KOT
/// (AGENTS.md §15 milestone 5 / §8). Pushed full-screen above the tab shell.
///
/// "Scan" takes a photo and sends it to [TicketScanner] (Gemini vision) to read
/// it into a draft against the current menu. Without an API key it falls back to
/// a simulated draft; on any failure — or via "Enter manually" — the user builds
/// the ticket by hand (graceful degradation, §8). The created ticket is added to
/// the board via [DemoDataCubit.addKot].
class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DemoDataCubit, DemoDataState>(
      builder: (BuildContext context, DemoDataState state) {
        final DemoData? data = state.data;
        if (data == null || data.menu.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Scan KOT')),
            body: const _NeedsData(),
          );
        }
        return _ScanFlow(
          menu: data.menu,
          stations: data.stations,
          boardEpoch: state.generatedAt!,
        );
      },
    );
  }
}

/// Shown when there's no menu yet — scanning needs stations/menu to schedule.
class _NeedsData extends StatelessWidget {
  const _NeedsData();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.menu_book_outlined,
                size: 48, color: KBuzzColors.brandPrimary),
            const SizedBox(height: 12),
            const Text('No menu loaded',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Generate the demo data first so scanned tickets can be priced and '
              'scheduled.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.read<DemoDataCubit>().generate(),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate demo data'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFlow extends StatefulWidget {
  const _ScanFlow({
    required this.menu,
    required this.stations,
    required this.boardEpoch,
  });

  final List<Dish> menu;
  final List<Station> stations;
  final DateTime boardEpoch;

  @override
  State<_ScanFlow> createState() => _ScanFlowState();
}

enum _Step { capture, review }

class _ScanFlowState extends State<_ScanFlow> {
  final Random _rng = Random();
  _Step _step = _Step.capture;
  bool _scanning = false;
  _Draft _draft = _Draft.empty();

  String get _tableStr =>
      _draft.type == KotType.delivery ? 'D${_draft.table}' : '${_draft.table}';

  Future<void> _scan() async {
    final XFile? file = await _pickImage();
    if (!mounted || file == null) return;

    final TicketScanner scanner = context.read<TicketScanner>();
    if (!scanner.isConfigured) {
      // No AI key wired up — simulate a draft so the demo still flows.
      setState(() {
        _draft = _Draft.random(widget.menu, _rng);
        _step = _Step.review;
      });
      AppToast.show(context, 'Demo scan (no AI key) — review the draft.');
      return;
    }

    setState(() => _scanning = true);
    final Uint8List bytes = await file.readAsBytes();
    final Result<ScannedTicket> result = await scanner.scan(
      imageBytes: bytes,
      mediaType: _mediaTypeOf(file),
      menu: widget.menu,
      stations: widget.stations,
    );
    if (!mounted) return;
    setState(() => _scanning = false);
    result.when(
      ok: (ScannedTicket t) {
        setState(() {
          _draft = _Draft.fromScanned(t, widget.menu, widget.stations);
          _step = _Step.review;
        });
        AppToast.success(context, 'Scanned — review and add.');
      },
      err: (AppFailure f) {
        // Couldn't read it — drop to manual entry with the reason.
        setState(() {
          _draft = _Draft.empty();
          _step = _Step.review;
        });
        AppToast.failure(context, f);
      },
    );
  }

  Future<XFile?> _pickImage() async {
    try {
      return await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 80,
      );
    } on Object catch (_) {
      if (!mounted) return null;
      AppToast.error(context, 'Camera unavailable — enter manually.');
      return null;
    }
  }

  String _mediaTypeOf(XFile file) {
    final String name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _manual() => setState(() {
        _draft = _Draft.empty();
        _step = _Step.review;
      });

  void _submit() {
    if (_draft.lines.isEmpty) return;
    final Duration elapsed = context.read<ServiceClockCubit>().state.elapsed;
    // Off-menu (ad-hoc) dishes must join the menu so the scheduler can place them.
    final List<Dish> newDishes = <Dish>[
      for (final _DraftLine l in _draft.lines) if (l.isAdHoc) l.dish,
    ];
    final Kot kot = Kot(
      id: const Uuid().v4(),
      table: _tableStr,
      type: _draft.type,
      orderedAt: widget.boardEpoch.add(elapsed),
      lines: <OrderLine>[
        for (final _DraftLine l in _draft.lines)
          OrderLine(
            dishId: l.dish.id,
            qty: l.qty,
            cookOverrideMins:
                l.cookMins == l.dish.cookMins ? null : l.cookMins,
          ),
      ],
    );
    context.read<DemoDataCubit>().addKot(kot, newDishes: newDishes);
    AppToast.success(
      context,
      'Added $_tableStr — ${_draft.lines.length} dishes to the board.',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == _Step.capture ? 'Scan KOT' : 'Review KOT'),
        leading: _step == _Step.review
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = _Step.capture),
              )
            : null,
      ),
      body: _step == _Step.capture
          ? _CaptureStep(
              scanning: _scanning,
              tableHint: _tableStr,
              onScan: _scan,
              onManual: _manual,
            )
          : _ReviewStep(
              draft: _draft,
              menu: widget.menu,
              tableStr: _tableStr,
              onChanged: () => setState(() {}),
              onSubmit: _submit,
            ),
    );
  }
}

class _CaptureStep extends StatelessWidget {
  const _CaptureStep({
    required this.scanning,
    required this.tableHint,
    required this.onScan,
    required this.onManual,
  });

  final bool scanning;
  final String tableHint;
  final VoidCallback onScan;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: scanning
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          CircularProgressIndicator(
                              color: KBuzzColors.brandPrimary),
                          SizedBox(height: 12),
                          Text('Reading ticket…',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      )
                    : const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Position the paper KOT inside the frame',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: scanning ? null : onManual,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Enter manually'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: scanning ? null : onScan,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.draft,
    required this.menu,
    required this.tableStr,
    required this.onChanged,
    required this.onSubmit,
  });

  final _Draft draft;
  final List<Dish> menu;
  final String tableStr;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  Future<void> _pickDish(BuildContext context) async {
    final Dish? picked = await showModalBottomSheet<Dish>(
      context: context,
      backgroundColor: KBuzzColors.surface,
      builder: (BuildContext context) => ListView(
        children: <Widget>[
          for (final Dish d in menu)
            ListTile(
              leading: Text(d.emoji, style: const TextStyle(fontSize: 20)),
              title: Text(d.name),
              trailing: Text('${d.cookMins}m',
                  style: const TextStyle(color: Colors.white54)),
              onTap: () => Navigator.of(context).pop(d),
            ),
        ],
      ),
    );
    if (picked != null) {
      draft.lines.add(_DraftLine(dish: picked, qty: 1, cookMins: picked.cookMins));
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _TypeSelector(
                type: draft.type,
                onChanged: (KotType t) {
                  draft.type = t;
                  onChanged();
                },
              ),
              const SizedBox(height: 12),
              _TableRow(
                tableStr: tableStr,
                onMinus: () {
                  if (draft.table > 1) {
                    draft.table--;
                    onChanged();
                  }
                },
                onPlus: () {
                  draft.table++;
                  onChanged();
                },
              ),
              const SizedBox(height: 16),
              for (int i = 0; i < draft.lines.length; i++)
                _LineCard(
                  line: draft.lines[i],
                  onRemove: () {
                    draft.lines.removeAt(i);
                    onChanged();
                  },
                  onChanged: onChanged,
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pickDish(context),
                icon: const Icon(Icons.add),
                label: const Text('Add dish'),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: draft.lines.isEmpty ? null : onSubmit,
                child: Text(
                  draft.lines.isEmpty
                      ? 'Add a dish to continue'
                      : 'Add to board',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.type, required this.onChanged});

  final KotType type;
  final ValueChanged<KotType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<KotType>(
      segments: const <ButtonSegment<KotType>>[
        ButtonSegment<KotType>(value: KotType.dineIn, label: Text('Dine-in')),
        ButtonSegment<KotType>(value: KotType.takeaway, label: Text('Takeaway')),
        ButtonSegment<KotType>(value: KotType.delivery, label: Text('Delivery')),
      ],
      selected: <KotType>{type},
      onSelectionChanged: (Set<KotType> s) => onChanged(s.first),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.tableStr,
    required this.onMinus,
    required this.onPlus,
  });

  final String tableStr;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: KBuzzColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          const Text('Table / order #'),
          const Spacer(),
          IconButton(onPressed: onMinus, icon: const Icon(Icons.remove)),
          Text(tableStr,
              style: kMonoNumberStyle.copyWith(
                  color: Colors.white, fontSize: 16)),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add)),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.onRemove,
    required this.onChanged,
  });

  final _DraftLine line;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final Color color =
        kStationColors[line.dish.stationId] ?? KBuzzColors.brandPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KBuzzColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(line.dish.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(line.dish.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (line.isAdHoc) ...<Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: KBuzzColors.brandPrimary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'off-menu',
                    style: TextStyle(
                        color: KBuzzColors.brandPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
                color: Colors.white38,
              ),
            ],
          ),
          Row(
            children: <Widget>[
              _Stepper(
                label: 'Qty',
                value: '×${line.qty}',
                onMinus: () {
                  if (line.qty > 1) {
                    line.qty--;
                    onChanged();
                  }
                },
                onPlus: () {
                  line.qty++;
                  onChanged();
                },
              ),
              const SizedBox(width: 12),
              _Stepper(
                label: 'Cook',
                value: '${line.cookMins}m',
                onMinus: () {
                  if (line.cookMins > 1) {
                    line.cookMins--;
                    onChanged();
                  }
                },
                onPlus: () {
                  line.cookMins++;
                  onChanged();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(width: 6),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onMinus,
          icon: const Icon(Icons.remove, size: 18),
        ),
        Text(value,
            style: kMonoNumberStyle.copyWith(color: Colors.white, fontSize: 14)),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onPlus,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }
}

/// Editable draft ticket built during the scan/review flow.
class _Draft {
  _Draft({required this.type, required this.table, required this.lines});

  _Draft.empty()
      : type = KotType.dineIn,
        table = 1,
        lines = <_DraftLine>[];

  factory _Draft.random(List<Dish> menu, Random rng) {
    final KotType type = KotType.values[rng.nextInt(KotType.values.length)];
    final int table =
        type == KotType.delivery ? 20 + rng.nextInt(30) : 2 + rng.nextInt(18);
    final List<Dish> pool = <Dish>[...menu]..shuffle(rng);
    final int n = min(2 + rng.nextInt(3), pool.length); // 2–4 dishes
    return _Draft(
      type: type,
      table: table,
      lines: <_DraftLine>[
        for (final Dish d in pool.take(n))
          _DraftLine(
            dish: d,
            qty: 1 + (rng.nextDouble() < 0.2 ? 1 : 0),
            cookMins: d.cookMins,
          ),
      ],
    );
  }

  /// Build a draft from a vision-scanned ticket. Matched items bind to their menu
  /// dish (with the AI's cook-time suggestion, falling back to the menu default);
  /// off-menu items become editable **ad-hoc** dishes on a suggested station, so
  /// real-world tickets parse even when the dish isn't on the demo menu.
  factory _Draft.fromScanned(
    ScannedTicket t,
    List<Dish> menu,
    List<Station> stations,
  ) {
    final Map<String, Dish> byId = <String, Dish>{
      for (final Dish d in menu) d.id: d,
    };
    final String defaultStation =
        stations.isNotEmpty ? stations.first.id : 'grill';
    const Uuid uuid = Uuid();
    final List<_DraftLine> lines = <_DraftLine>[];
    for (final ScannedLine l in t.lines) {
      final Dish? matched = l.dishId == null ? null : byId[l.dishId];
      if (matched != null) {
        lines.add(_DraftLine(
          dish: matched,
          qty: l.qty,
          cookMins: l.cookMins ?? matched.cookMins, // AI suggestion wins
        ));
      } else if (l.name.isNotEmpty) {
        final int cook = l.cookMins ?? 10;
        lines.add(_DraftLine(
          dish: Dish(
            id: 'adhoc-${uuid.v4()}',
            name: l.name,
            emoji: '🍽️',
            stationId: l.stationId ?? defaultStation,
            cookMins: cook,
            holdable: true,
            batchable: false,
          ),
          qty: l.qty,
          cookMins: cook,
          isAdHoc: true,
        ));
      }
    }
    final int digits =
        int.tryParse(t.table.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    return _Draft(type: t.type, table: digits < 1 ? 1 : digits, lines: lines);
  }

  KotType type;
  int table;
  final List<_DraftLine> lines;
}

class _DraftLine {
  _DraftLine({
    required this.dish,
    required this.qty,
    required this.cookMins,
    this.isAdHoc = false,
  });

  final Dish dish;
  int qty;
  int cookMins;

  /// True when [dish] is a scanned off-menu item synthesised on the fly — it must
  /// be added to the menu when the ticket is created (see `_submit`).
  final bool isAdHoc;
}
