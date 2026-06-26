import 'package:flutter/widgets.dart';

/// Single-line text that **slides horizontally** when it's wider than the space
/// it's given, so the whole string can be read without truncation. When it fits,
/// it's a plain [Text] (no animation, no ticker). When it overflows it scrolls
/// back and forth, pausing briefly at each end.
///
/// Respects [TickerMode], so it sits still wherever animations are disabled
/// (widget tests, "reduce motion") — there it just shows the clipped start.
class MarqueeText extends StatefulWidget {
  const MarqueeText(this.text, {super.key, this.style, this.velocity = 26});

  final String text;
  final TextStyle? style;

  /// Scroll speed, logical pixels per second.
  final double velocity;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  // Hold ~12% of each half-cycle at the ends so the start/finish are readable
  // before the slide reverses.
  static const Curve _ease = Interval(0.12, 0.88, curve: Curves.easeInOut);
  late final AnimationController _controller = AnimationController(vsync: this);
  double _distance = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Reconfigure the loop for a new overflow [distance] (px). Called after
  /// layout — never mutates the controller during build.
  void _retune(double distance) {
    if (distance <= 0.5) {
      if (!_controller.isDismissed) _controller.stop();
      _distance = 0;
      return;
    }
    if ((distance - _distance).abs() < 0.5 && _controller.isAnimating) return;
    _distance = distance;
    final int travelMs = (distance / widget.velocity * 1000).round();
    // Inflate so the *travel* keeps [velocity] despite the ~24% spent holding,
    // and add a floor so a tiny overflow still pauses long enough to read.
    _controller.duration =
        Duration(milliseconds: (travelMs / 0.76).round() + 700);
    _controller.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final Text text = Text(
      widget.text,
      style: widget.style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxW = constraints.maxWidth;
        final TextPainter painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        final double distance = painter.width - maxW;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _retune(distance);
        });
        // Bound every line to exactly one text-line height — both so the
        // marquee never grabs unbounded height from a flexible parent, and so a
        // sliding line and a static one occupy the *same* height in a column.
        return SizedBox(
          height: painter.height,
          child: distance <= 0.5
              ? text
              : ClipRect(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? child) =>
                        Transform.translate(
                      offset: Offset(
                          -distance * _ease.transform(_controller.value), 0),
                      child: child,
                    ),
                    child: OverflowBox(
                      maxWidth: double.infinity,
                      alignment: Alignment.centerLeft,
                      child: text,
                    ),
                  ),
                ),
        );
      },
    );
  }
}
