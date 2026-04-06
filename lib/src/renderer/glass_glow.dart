import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';
import '../../utils/glass_spring.dart';

/// {@template glass_glow}
/// If placed as a descendant of a [GlassGlowLayer], this widget will
/// send touch updates to that layer to create a glow effect.
/// {@endtemplate}
class GlassGlow extends StatelessWidget {
  /// {@macro glass_glow}
  const GlassGlow({
    required this.child,
    this.glowColor = Colors.white24,
    this.glowRadius = 1,
    this.hitTestBehavior = HitTestBehavior.opaque,
    super.key,
  });

  /// The radius of the glow effect relative to the layer's shortest side.
  ///
  /// A value of 0.8 means the glow radius will be 80% of the shortest
  /// dimension (width or height) of the [GlassGlowLayer].
  ///
  /// Defaults to 1.
  final double glowRadius;

  /// The color of the glow effect.
  ///
  /// The glow will have this colors opacity at the center, and will fade out
  /// to fully transparent at the edge of the glow.
  final Color glowColor;

  /// The hit test behavior of this gesture listener.
  ///
  /// Defaults to [HitTestBehavior.opaque].
  final HitTestBehavior hitTestBehavior;

  /// The child that will be painted above the glow effect.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: hitTestBehavior,
      onPointerDown: (event) => _handlePointer(context, event),
      onPointerMove: (event) => _handlePointer(context, event),
      onPointerUp: (event) => _removeTouch(context),
      onPointerCancel: (event) => _removeTouch(context),
      child: child,
    );
  }

  void _handlePointer(BuildContext context, PointerEvent event) {
    final layerState = GlassGlowLayer.maybeOf(context);
    if (layerState == null) return;

    // GlassGlowLayer may be at a different level than GlassGlow — e.g. a
    // toolbar GlassGlowLayer wrapping three buttons, each with their own
    // GlassGlow. event.localPosition is relative to this GlassGlow widget,
    // not relative to the GlassGlowLayer. We must convert via global space.
    final myBox = context.findRenderObject() as RenderBox?;
    final layerBox = layerState.context.findRenderObject() as RenderBox?;

    final Offset pos;
    if (myBox != null &&
        layerBox != null &&
        myBox.attached &&
        layerBox.attached) {
      // local-in-GlassGlow → global screen → local-in-GlassGlowLayer
      pos = layerBox.globalToLocal(myBox.localToGlobal(event.localPosition));
    } else {
      // Fallback for tests or during layout (same-level case is also correct).
      pos = event.localPosition;
    }

    layerState.updateTouch(pos, radius: glowRadius, color: glowColor);
  }

  void _removeTouch(BuildContext context) {
    GlassGlowLayer.maybeOf(context)?.removeTouch();
  }
}

/// {@template glass_glow}
/// Represents a layer that can paint a glowing effect below its child.
///
/// Any child [GlassGlow] will send touch updates to this layer to
/// update the glow effect.
///
/// This is similar to how an `InkWell` works with a `Material` widget.
/// {@endtemplate}
class GlassGlowLayer extends StatefulWidget {
  /// {@macro glass_glow}
  const GlassGlowLayer({
    required this.child,
    super.key,
  });

  /// The child that will be painted above the glow effect.
  final Widget child;

  @override
  State<GlassGlowLayer> createState() => GlassGlowLayerState();

  @internal
  // ignore: public_member_api_docs
  static GlassGlowLayerState? maybeOf(BuildContext context) {
    if (!context.mounted) return null;
    return context.findAncestorStateOfType<GlassGlowLayerState>();
  }
}

@internal
class GlassGlowLayerState extends State<GlassGlowLayer>
    with TickerProviderStateMixin {
  late final _offsetController = OffsetSpringController(
    vsync: this,
    spring: GlassSpring.smooth(duration: const Duration(seconds: 1)),
    initialValue: Offset.zero,
  );

  late final _alphaController = SingleSpringController(
    vsync: this,
    spring: GlassSpring.smooth(),
    initialValue: 0,
    lowerBound: 0,
    upperBound: 1,
  );

  late final _radiusController = SingleSpringController(
    vsync: this,
    spring: GlassSpring.smooth(),
    initialValue: 10,
  );

  bool _dragging = false;
  double _baseRadius = 0;
  Color _baseColor = const Color.fromARGB(0, 0, 0, 0);

  @override
  void dispose() {
    _offsetController.dispose();
    _alphaController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void updateTouch(
    Offset offset, {
    required double radius,
    required Color color,
  }) {
    setState(() {
      _baseRadius = radius;
      _baseColor = color;
    });

    if (!_dragging) {
      _dragging = true;
      // Snap to the exact touch point immediately so the glow appears right
      // where the finger lands — not at Offset.zero drifting over. Alpha then
      // fades in at the correct position instead of mid-spring.
      _offsetController.value = offset;
      _alphaController.spring = GlassSpring.interactive();
      _radiusController.spring = GlassSpring.interactive();
      _alphaController.animateTo(1, fromVelocity: 0);
      _radiusController.animateTo(1, fromVelocity: 0);
    }

    _offsetController.animateTo(offset);
  }

  void removeTouch() {
    if (!_dragging) return;
    _alphaController.spring = GlassSpring.smooth();
    _radiusController.spring = GlassSpring.smooth();
    _dragging = false;
    _offsetController.animateTo(Offset.zero);
    _radiusController.animateTo(10);
    _alphaController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _offsetController,
        _alphaController,
        _radiusController,
      ]),
      builder: (context, child) {
        return _RenderGlassGlowLayerWidget(
          glowRadius: _baseRadius * _radiusController.value,
          glowColor: _baseColor.withValues(
            alpha: _baseColor.a * _alphaController.value,
          ),
          glowOffset: _offsetController.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _RenderGlassGlowLayerWidget extends SingleChildRenderObjectWidget {
  const _RenderGlassGlowLayerWidget({
    required this.glowRadius,
    required this.glowColor,
    required this.glowOffset,
    required super.child,
  });

  final double glowRadius;
  final Color glowColor;
  final Offset glowOffset;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderGlassGlowLayer(
      glowRadius: glowRadius,
      glowColor: glowColor,
      glowOffset: glowOffset,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGlassGlowLayer renderObject,
  ) {
    renderObject
      ..glowRadius = glowRadius
      ..glowColor = glowColor
      ..glowOffset = glowOffset;
  }
}

class _RenderGlassGlowLayer extends RenderProxyBox {
  _RenderGlassGlowLayer({
    required double glowRadius,
    required Color glowColor,
    required Offset glowOffset,
  })  : _glowRadius = glowRadius,
        _glowColor = glowColor,
        _glowOffset = glowOffset;

  double _glowRadius;
  double get glowRadius => _glowRadius;
  set glowRadius(double value) {
    if (_glowRadius == value) return;
    _glowRadius = value;
    markNeedsPaint();
  }

  Color _glowColor;
  Color get glowColor => _glowColor;
  set glowColor(Color value) {
    if (_glowColor == value) return;
    _glowColor = value;
    markNeedsPaint();
  }

  Offset _glowOffset;
  Offset get glowOffset => _glowOffset;
  set glowOffset(Offset value) {
    if (_glowOffset == value) return;
    _glowOffset = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_glowColor.a == 0 || _glowRadius <= 0) {
      super.paint(context, offset);
      return;
    }

    final glowPosition = offset + _glowOffset;
    // Geometric mean of width and height so the spotlight scales proportionally
    // to the button area — not just the short side. For a 56x56 circle this is
    // identical to shortestSide; for a 300x56 wide pill it gives ~130px instead
    // of 56px, covering the glass surface correctly like iOS 26.
    final radius = _glowRadius * math.sqrt(size.width * size.height);

    // RadialGradient.createShader() bakes the center position into the shader
    // via the Rect passed to it — caching across position changes is incorrect.
    // Per-frame creation is cheap for a simple radial gradient (uniform-only).
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [_glowColor, _glowColor.withValues(alpha: 0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: glowPosition, radius: radius))
      ..blendMode = BlendMode.plus;

    // No canvas save/restore needed — we don't modify canvas state.
    context.canvas.drawCircle(glowPosition, radius, paint);
    super.paint(context, offset);
  }
}
