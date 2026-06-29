import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/core/result.dart';

/// The single, app-wide way to show a transient toast message.
///
/// **All toasts pop up at the TOP of the screen** (below the status bar), never
/// the bottom. Do **not** use `ScaffoldMessenger`/`SnackBar` — those anchor to
/// the bottom and bypass this convention (AGENTS.md §12). Use [AppToast.show]
/// (or [success] / [error] / [failure]) for normal messages, and [fire] for the
/// bold "fire next" alert (§10.5).
///
/// It renders into the **root** overlay, so toasts float above the tab shell,
/// full-screen routes (e.g. scan), and dialogs alike. Toasts **stack**: a new one
/// appears *below* the ones already showing — including [fire] alerts — each on
/// its own auto-dismiss timer; when one closes the rest move up. A burst is
/// capped (oldest dropped) so the stack can't grow without bound.
abstract final class AppToast {
  /// The live stack, oldest first (top) → newest last (bottom).
  static final List<_ToastModel> _models = <_ToastModel>[];

  /// Per-toast controllers, registered by each [_AppToastView] while mounted
  /// (keyed by model id), so [dismiss] / [retime] / the fire content-swap can
  /// reach a specific toast.
  static final Map<int, _ToastHandle> _handles = <int, _ToastHandle>{};

  /// The single overlay entry that renders the whole stack.
  static OverlayEntry? _entry;

  static int _nextId = 0;

  /// Cap on simultaneous toasts; older non-fire toasts are dropped past this so
  /// a burst can't grow the stack without bound.
  static const int _maxVisible = 4;

  /// Animate out **every** visible toast (e.g. the run was paused or reset).
  /// A no-op when nothing is showing.
  static void dismiss() {
    for (final _ToastHandle h in _handles.values.toList()) {
      h.close();
    }
  }

  /// Reschedule the visible **fire** toast's auto-dismiss to [hold] from now —
  /// used when the fire-toast display time is changed live (Profile → Settings).
  /// A no-op when no fire toast is up; never touches normal toasts.
  static void retime(Duration hold) {
    for (final _ToastModel m in _models) {
      if (m.retimeable) _handles[m.id]?.retime(hold);
    }
  }

  /// Show [message] as a top toast of the given [type].
  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? note,
  }) {
    final KdsColors c = KdsColors.of(context);
    final Color accent = type.accentOf(c);
    _insert(
      context,
      accent: accent,
      duration: duration,
      child: _MessageContent(
        icon: type.icon,
        message: message,
        accent: accent,
        note: note,
      ),
    );
  }

  /// Convenience: a green success toast. [note] is an optional second line.
  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? note,
  }) => show(
    context,
    message,
    type: AppToastType.success,
    duration: duration,
    note: note,
  );

  /// Convenience: a red error toast. [note] is an optional second line.
  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? note,
  }) => show(
    context,
    message,
    type: AppToastType.error,
    duration: duration,
    note: note,
  );

  /// Convenience: surface an [AppFailure]'s user-safe message as an error toast.
  static void failure(
    BuildContext context,
    AppFailure failure, {
    Duration duration = const Duration(seconds: 4),
    String? note,
  }) => error(context, failure.message, duration: duration, note: note);

  /// The bold **"fire next"** alert (§10.5): big mono qty + dish + station per
  /// item, brand-orange accent, held for [duration] (the Profile hold time).
  /// Itemises the whole same-tick batch so simultaneous multi-station fires are
  /// all shown in one toast (the list scrolls if it outgrows the screen).
  /// Tappable anywhere — or via the corner ✕ — to dismiss. A later fire **stacks**
  /// as its own toast with its own countdown. Pairs with the spoken [Announcer]
  /// announcement. Still a top toast.
  static void fire(
    BuildContext context, {
    required List<FireToastItem> items,
    Duration duration = const Duration(minutes: 3),
    String? note,
  }) {
    if (items.isEmpty) return;
    // Each fire batch is its OWN stacked toast with its OWN expire timer (the
    // Profile hold time), so a later fire never inherits an earlier one's
    // leftover countdown — they stack and each counts down independently. A dense
    // rush is bounded by the stack cap (oldest dropped).
    _insert(
      context,
      accent: KdsColors.of(context).brand,
      duration: duration,
      showClose: true,
      retimeable: true,
      child: _FireContent(items: items, note: note),
    );
  }

  /// Append a toast to the bottom of the stack.
  static void _insert(
    BuildContext context, {
    required Color accent,
    required Duration duration,
    required Widget child,
    bool showClose = false,
    bool retimeable = false,
  }) {
    _ensureEntry(context);
    _models.add(
      _ToastModel(
        id: _nextId++,
        accent: accent,
        duration: duration,
        child: child,
        showClose: showClose,
        retimeable: retimeable,
      ),
    );
    // Keep the most recent [_maxVisible]; drop the oldest so a burst (e.g. a
    // dense fire rush) can't grow the stack without bound. Removing a model
    // disposes its view, cancelling its timer.
    while (_models.length > _maxVisible) {
      _models.removeAt(0);
    }
    _entry!.markNeedsBuild();
  }

  /// Lazily create the one overlay entry that renders the stack; reused until the
  /// stack empties. Root overlay so toasts clear the nav shell / routes / dialogs.
  static void _ensureEntry(BuildContext context) {
    if (_entry != null) return;
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    final OverlayEntry entry = OverlayEntry(builder: _buildStack);
    _entry = entry;
    overlay.insert(entry);
  }

  /// Remove a dismissed toast (after its exit animation) and tear the overlay
  /// down once the stack is empty.
  static void _remove(int id) {
    _models.removeWhere((_ToastModel m) => m.id == id);
    _handles.remove(id);
    if (_models.isEmpty) {
      _entry?.remove();
      _entry = null;
    } else {
      _entry?.markNeedsBuild();
    }
  }

  /// Build the stacked toasts: a top-anchored column, oldest first. Re-runs on
  /// every [OverlayEntry.markNeedsBuild]; the [ValueKey]s preserve each toast's
  /// animation + timer state across rebuilds.
  static Widget _buildStack(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpaceMd, kSpaceSm, kSpaceMd, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final _ToastModel m in _models)
                _AppToastView(
                  key: ValueKey<int>(m.id),
                  model: m,
                  onDismissed: () => _remove(m.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Severity of a toast — drives its accent colour and leading icon.
enum AppToastType {
  info(Icons.info_outline),
  success(Icons.check_circle_outline),
  error(Icons.error_outline);

  const AppToastType(this.icon);

  final IconData icon;

  /// Resolve this severity's theme-aware accent colour. An enum constant can't
  /// hold a [KdsColors] field, so the colour is mapped from the active set here.
  Color accentOf(KdsColors c) => switch (this) {
    AppToastType.info => c.brand,
    AppToastType.success => c.success,
    AppToastType.error => c.danger,
  };
}

/// One stacked toast's data. [child] is mutable so a newer fire can swap its
/// content in place; [retimeable] marks the single fire toast (it registers
/// retime + content-swap and is preserved when the stack is capped).
class _ToastModel {
  _ToastModel({
    required this.id,
    required this.accent,
    required this.duration,
    required this.child,
    required this.showClose,
    required this.retimeable,
  });

  final int id;
  final Color accent;
  final Duration duration;
  final Widget child;
  final bool showClose;

  /// Marks the fire toast: it registers [retime] (so a live hold-time change
  /// reschedules it) — the [AppToast.retime] target.
  final bool retimeable;
}

/// Live controls for one mounted toast, registered in [AppToast._handles] by its
/// [_AppToastView] so the static API can reach a specific toast in the stack.
class _ToastHandle {
  _ToastHandle({required this.close, required this.retime});

  final VoidCallback close;
  final void Function(Duration hold) retime;
}

/// The animated toast surface: slides down from the top edge, holds, then slides
/// back up and removes itself via [onDismissed]. One per entry in the stack;
/// positioning/spacing is owned by [AppToast._buildStack].
class _AppToastView extends StatefulWidget {
  const _AppToastView({
    super.key,
    required this.model,
    required this.onDismissed,
  });

  final _ToastModel model;
  final VoidCallback onDismissed;

  @override
  State<_AppToastView> createState() => _AppToastViewState();
}

class _AppToastViewState extends State<_AppToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final Animation<Offset> _offset =
      Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      );

  Timer? _dismissTimer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // Register this toast's live controls (ids are unique + never reused).
    AppToast._handles[widget.model.id] = _ToastHandle(
      close: _close,
      retime: _retime,
    );
    _controller.forward();
    _scheduleDismiss(widget.model.duration);
  }

  /// (Re)arm the auto-dismiss to fire [hold] from now (plus the slide
  /// animation), cancelling any prior timer.
  void _scheduleDismiss(Duration hold) {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(
      hold + (_controller.duration ?? Duration.zero),
      _close,
    );
  }

  /// Live re-time from a settings change: keep this toast up for [hold] more,
  /// measured from now. Ignored once it has started closing.
  void _retime(Duration hold) {
    if (!mounted || _closing) return;
    _scheduleDismiss(hold);
  }

  Future<void> _close() async {
    // Guard re-entry: tap-anywhere and the ✕ button can both fire _close.
    if (!mounted || _closing) return;
    _closing = true;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    AppToast._handles.remove(widget.model.id);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _controller,
        // Gap below each card so stacked toasts read as separate.
        child: Padding(
          padding: const EdgeInsets.only(bottom: kSpaceSm),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _close,
                  child: Stack(
                    children: <Widget>[
                      Container(
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(kRadiusLg),
                          border: Border(
                            left: BorderSide(
                              color: widget.model.accent,
                              width: 4,
                            ),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: c.scrim,
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: widget.model.child,
                      ),
                      if (widget.model.showClose)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: IconButton(
                            onPressed: _close,
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            splashRadius: 20,
                            color: c.textSecondary,
                            tooltip: 'Dismiss',
                            icon: const Icon(Icons.close),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard one-line toast content: leading icon + message.
class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.icon,
    required this.message,
    required this.accent,
    this.note,
  });

  final IconData icon;
  final String message;
  final Color accent;

  /// Optional smaller second line under [message] (extra detail / hint).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    final String? note = this.note;
    final bool hasNote = note != null && note.isNotEmpty;
    return Row(
      crossAxisAlignment: hasNote
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: <Widget>[
        Icon(icon, color: accent, size: 22),
        const SizedBox(width: kSpaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                message,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: kFontMd,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (note != null && note.isNotEmpty) ...<Widget>[
                const SizedBox(height: kSpaceXs),
                Text(
                  note,
                  style: TextStyle(color: c.textSecondary, fontSize: kFontSm),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One cook to fire, as rendered in an [AppToast.fire] batch. Lives in `core/`
/// (a primitive view-model) so the toast stays decoupled from the service-layer
/// `FireAlert` — the caller maps its alerts onto these.
@immutable
class FireToastItem {
  const FireToastItem({
    required this.dishName,
    required this.stationName,
    this.qty = 1,
    this.emoji,
  });

  final String dishName;
  final String stationName;
  final int qty;
  final String? emoji;
}

/// Bold "fire next" content: a header ("FIRE NOW", with a count when several
/// fire at once) over one [_FireRow] per item. The list scrolls if a big batch
/// outgrows ~70% of the screen, so it never overflows.
class _FireContent extends StatelessWidget {
  const _FireContent({required this.items, this.note});

  final List<FireToastItem> items;

  /// Optional smaller note line under the header.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    final double maxListHeight = MediaQuery.sizeOf(context).height * 0.7;
    final String? note = this.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          // Keep the header clear of the corner ✕.
          padding: const EdgeInsets.only(right: kSpaceXl),
          child: Text(
            items.length > 1 ? 'FIRE NOW · ${items.length}' : 'FIRE NOW',
            style: TextStyle(
              color: c.brand,
              fontSize: kFontXs,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        if (note != null && note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: kSpaceXs, right: kSpaceXl),
            child: Text(
              note,
              style: TextStyle(color: c.textSecondary, fontSize: kFontSm),
            ),
          ),
        const SizedBox(height: kSpaceSm),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxListHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0)
                    Divider(height: 14, thickness: 1, color: c.hairline),
                  _FireRow(item: items[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single line in the fire toast: emoji + big mono "qty× dish", station under.
class _FireRow extends StatelessWidget {
  const _FireRow({required this.item});

  final FireToastItem item;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(item.emoji ?? '🔥', style: const TextStyle(fontSize: kFontXxl)),
        const SizedBox(width: kSpaceLg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                item.qty > 1 ? '${item.qty}× ${item.dishName}' : item.dishName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: kMonoNumberStyle.copyWith(
                  color: c.textPrimary,
                  fontSize: kFontXl,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                item.stationName,
                style: TextStyle(color: c.textSecondary, fontSize: kFontMd),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
