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
/// It renders into the **root** overlay, so a toast floats above the tab shell,
/// full-screen routes (e.g. scan), and dialogs alike. Only one toast is visible
/// at a time — showing a new one replaces the current.
abstract final class AppToast {
  /// The currently-visible toast, if any. Replaced on each insert.
  static OverlayEntry? _current;

  /// Animated-close of the visible toast, registered by [_AppToastView] while
  /// it's on screen. Lets [dismiss] slide it out the same way the ✕ does.
  static VoidCallback? _activeClose;

  /// Animate out the active toast, if any (e.g. the run was paused or reset).
  /// A no-op when nothing is showing. Distinct from the private [_dismiss],
  /// which removes instantly (no exit animation) for the replacement path.
  static void dismiss() => _activeClose?.call();

  /// Re-time hook of the active *fire* toast — registered by [_AppToastView]
  /// only when it opted in (the [fire] toast). Lets [retime] reschedule the
  /// auto-dismiss when the hold time changes while one is on screen.
  static void Function(Duration hold)? _activeRetime;

  /// Reschedule the active fire toast's auto-dismiss to [hold] from now — used
  /// when the fire-toast display time is changed live (Profile → Settings). A
  /// no-op when nothing is showing or the visible toast isn't a fire toast.
  static void retime(Duration hold) => _activeRetime?.call(hold);

  /// Content-swap hook of the active *fire* toast — registered by [_AppToastView]
  /// only for the fire toast. Lets a newer fire replace the visible content
  /// **without** restarting the auto-dismiss, so the display time is a hard cap
  /// from first appearance (not re-armed by every fire). Returns false if the
  /// toast is gone/closing, so [fire] opens a fresh one instead.
  static bool Function(Widget child)? _activeSetContent;

  /// Show [message] as a top toast of the given [type].
  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _insert(
      context,
      accent: type.accent,
      duration: duration,
      child: _MessageContent(
        icon: type.icon,
        message: message,
        accent: type.accent,
      ),
    );
  }

  /// Convenience: a green success toast.
  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) => show(context, message, type: AppToastType.success, duration: duration);

  /// Convenience: a red error toast.
  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) => show(context, message, type: AppToastType.error, duration: duration);

  /// Convenience: surface an [AppFailure]'s user-safe message as an error toast.
  static void failure(
    BuildContext context,
    AppFailure failure, {
    Duration duration = const Duration(seconds: 4),
  }) => error(context, failure.message, duration: duration);

  /// The bold **"fire next"** alert (§10.5): big mono qty + dish + station per
  /// item, brand-orange accent, held 3 minutes (or until dismissed/replaced).
  /// Itemises the whole same-tick batch so simultaneous multi-station fires are
  /// all shown (the list scrolls if it outgrows the screen). Tappable anywhere —
  /// or via the corner ✕ — to dismiss. A newer fire replaces it. Pairs with the
  /// spoken [Announcer] announcement. Still a top toast.
  static void fire(
    BuildContext context, {
    required List<FireToastItem> items,
    Duration duration = const Duration(minutes: 3),
  }) {
    if (items.isEmpty) return;
    // If a fire toast is already up, swap in the newest batch but keep its
    // running countdown — so the display time caps total visibility instead of
    // restarting on every fire (which, under the fast service clock, kept it up
    // until the rush ended). Falls through to a fresh toast once it has closed.
    final bool Function(Widget)? swap = _activeSetContent;
    if (swap != null && swap(_FireContent(items: items))) return;
    _insert(
      context,
      accent: KBuzzColors.brandPrimary,
      duration: duration,
      showClose: true,
      retimeable: true,
      child: _FireContent(items: items),
    );
  }

  static void _insert(
    BuildContext context, {
    required Color accent,
    required Duration duration,
    required Widget child,
    bool showClose = false,
    bool retimeable = false,
  }) {
    // Root overlay so the toast clears the nav shell / full-screen routes / dialogs.
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    _dismiss();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext context) => _AppToastView(
        accent: accent,
        duration: duration,
        showClose: showClose,
        retimeable: retimeable,
        // Only remove if this entry is still the active one — a newer toast may
        // have replaced it before its timer fired.
        onDismissed: () {
          if (_current == entry) _current = null;
          entry.remove();
        },
        child: child,
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }

  /// Immediately remove the active toast (if any), no exit animation.
  static void _dismiss() {
    _current?.remove();
    _current = null;
  }
}

/// Severity of a toast — drives its accent colour and leading icon.
enum AppToastType {
  info(KBuzzColors.brandPrimary, Icons.info_outline),
  success(Color(0xFF10B981), Icons.check_circle_outline),
  error(Color(0xFFEF4444), Icons.error_outline);

  const AppToastType(this.accent, this.icon);

  final Color accent;
  final IconData icon;
}

/// The animated toast surface: slides down from the top edge, holds, then slides
/// back up and removes itself via [onDismissed]. Renders [child] inside the
/// shared chrome (rounded card, accent stripe, tap-to-dismiss).
class _AppToastView extends StatefulWidget {
  const _AppToastView({
    required this.accent,
    required this.duration,
    required this.onDismissed,
    required this.child,
    this.showClose = false,
    this.retimeable = false,
  });

  final Color accent;
  final Duration duration;
  final VoidCallback onDismissed;
  final Widget child;

  /// Whether to overlay a tap-target ✕ in the top-right corner.
  final bool showClose;

  /// Whether this toast registers [AppToast._activeRetime], letting a live hold
  /// change reschedule its auto-dismiss (the fire toast opts in).
  final bool retimeable;

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
  late Widget _child;

  @override
  void initState() {
    super.initState();
    _child = widget.child;
    AppToast._activeClose = _close; // so AppToast.dismiss() can animate us out
    if (widget.retimeable) {
      AppToast._activeRetime = _retime;
      AppToast._activeSetContent = _setContent;
    }
    _controller.forward();
    _scheduleDismiss(widget.duration);
  }

  /// (Re)arm the auto-dismiss to fire [hold] from now (plus the slide
  /// animation), cancelling any prior timer.
  void _scheduleDismiss(Duration hold) {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(hold + _controller.duration!, _close);
  }

  /// Live re-time from a settings change: keep this toast up for [hold] more,
  /// measured from now. Ignored once it has started closing.
  void _retime(Duration hold) {
    if (!mounted || _closing) return;
    _scheduleDismiss(hold);
  }

  /// Swap the toast's content in place, leaving the auto-dismiss timer running —
  /// a newer fire updates the visible toast without extending it. Returns false
  /// if this toast is gone/closing, so the caller opens a fresh one instead.
  bool _setContent(Widget child) {
    if (!mounted || _closing) return false;
    setState(() => _child = child);
    return true;
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
    if (AppToast._activeClose == _close) AppToast._activeClose = null;
    if (AppToast._activeRetime == _retime) AppToast._activeRetime = null;
    if (AppToast._activeSetContent == _setContent) {
      AppToast._activeSetContent = null;
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _offset,
          child: FadeTransition(
            opacity: _controller,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
                              color: KBuzzColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                  color: widget.accent,
                                  width: 4,
                                ),
                              ),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: _child,
                          ),
                          if (widget.showClose)
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
                                color: Colors.white60,
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
  });

  final IconData icon;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: accent, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
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
  const _FireContent({required this.items});

  final List<FireToastItem> items;

  @override
  Widget build(BuildContext context) {
    final double maxListHeight = MediaQuery.sizeOf(context).height * 0.7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          // Keep the header clear of the corner ✕.
          padding: const EdgeInsets.only(right: 28),
          child: Text(
            items.length > 1 ? 'FIRE NOW · ${items.length}' : 'FIRE NOW',
            style: const TextStyle(
              color: KBuzzColors.brandPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxListHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0)
                    const Divider(
                      height: 14,
                      thickness: 1,
                      color: Colors.white12,
                    ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(item.emoji ?? '🔥', style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
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
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                item.stationName,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
