import 'package:flutter/cupertino.dart';

/// A shared accessibility and focus region for interactive glass widgets.
///
/// Encapsulates:
/// - Semantic boundaries and roles.
/// - Keyboard focus traversal via [FocusableActionDetector].
/// - Space/Enter [ActivateIntent] mapping.
/// - The iOS 26-style focus ring painting (using a [ValueListenableBuilder] to
///   ensure zero GPU cost for touch users).
///
/// **State Lifting:**
/// To maintain strict zero-rebuild performance profiles in glass widgets, this
/// region does *not* own the hover/focus state. It accepts `ValueNotifier`s
/// from the parent widget and updates them, allowing the parent to feed them
/// directly into an `AnimatedBuilder` for visual feedback without full rebuilds.
class GlassFocusRegion extends StatefulWidget {
  const GlassFocusRegion({
    required this.child,
    required this.shape,
    required this.enabled,
    required this.isFocusedNotifier,
    required this.isHoveredNotifier,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.isButton = false,
    this.isSlider = false,
    this.hasTapAction = false,
    this.onKeyboardActivate,
    super.key,
  });

  /// The widget tree inside the focus region.
  final Widget child;

  /// The exact shape of the widget, used to draw the focus ring.
  final ShapeBorder shape;

  /// Whether the widget is interactive and focusable.
  final bool enabled;

  /// Externally provided focus node (from the parent's widget parameter).
  final FocusNode? focusNode;

  /// Whether to request focus immediately.
  final bool autofocus;

  /// A notifier that this region will update when keyboard focus arrives/leaves.
  final ValueNotifier<bool> isFocusedNotifier;

  /// A notifier that this region will update when mouse hover enters/exits.
  final ValueNotifier<bool> isHoveredNotifier;

  /// The semantic label for screen readers.
  final String? semanticLabel;

  /// Whether this region should announce as a button to screen readers.
  final bool isButton;

  /// Whether this region should announce as a slider to screen readers.
  final bool isSlider;

  /// Whether the control has a tap action (e.g. for accessibility tap gesture).
  final bool hasTapAction;

  /// Callback fired when the user presses Space or Enter while focused.
  final VoidCallback? onKeyboardActivate;

  @override
  State<GlassFocusRegion> createState() => _GlassFocusRegionState();
}

class _GlassFocusRegionState extends State<GlassFocusRegion> {
  // Allocated once in initState to avoid per-frame allocations.
  late final Map<Type, Action<Intent>> _actions;

  @override
  void initState() {
    super.initState();
    _actions = <Type, Action<Intent>>{
      ActivateIntent: CallbackAction<Intent>(
        onInvoke: (Intent intent) {
          widget.onKeyboardActivate?.call();
          return null;
        },
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.isButton,
      slider: widget.isSlider,
      label: widget.semanticLabel,
      enabled: widget.enabled,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        actions: _actions,
        mouseCursor:
            widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) => widget.isFocusedNotifier.value = v,
        onShowHoverHighlight: (v) => widget.isHoveredNotifier.value = v,
        child: ValueListenableBuilder<bool>(
          valueListenable: widget.isFocusedNotifier,
          builder: (context, isFocused, child) {
            if (!isFocused) return child!;
            // Focus ring: painted outside the button bounds so it never clips
            // the glass surface. Uses the same path as the button's shape.
            return Stack(
              clipBehavior: Clip.none,
              children: [
                child!,
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _GlassFocusRingPainter(
                        shape: widget.shape,
                        color: CupertinoColors.activeBlue.resolveFrom(context),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Paints an iOS 26-style keyboard focus ring around a [ShapeBorder].
///
/// Only instantiated when [FocusableActionDetector.onShowFocusHighlight]
/// fires — i.e. exclusively during hardware-keyboard Tab navigation.
/// Touch users never trigger this painter.
///
/// The ring is drawn 3 logical pixels outside the shape boundary so it
/// never clips the glass surface underneath. A secondary stroke at a lower
/// opacity and slightly larger radius provides a faint glow that keeps the
/// ring legible over any glass background.
class _GlassFocusRingPainter extends CustomPainter {
  _GlassFocusRingPainter({
    required this.shape,
    required this.color,
  });

  final ShapeBorder shape;
  final Color color;

  static const double _outset = 3.0;
  static const double _ringWidth = 2.0;
  static const double _glowWidth = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Expand the rect so the ring sits outside the shape boundary.
    final ringRect = Rect.fromLTWH(
      -_outset,
      -_outset,
      size.width + _outset * 2,
      size.height + _outset * 2,
    );
    final path = shape.getOuterPath(ringRect);

    // Outer glow — wider, lower opacity, makes the ring legible on any surface.
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _glowWidth
        ..strokeCap = StrokeCap.round,
    );

    // Inner ring — crisp, full-opacity stroke.
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GlassFocusRingPainter oldDelegate) =>
      color != oldDelegate.color || shape != oldDelegate.shape;
}
