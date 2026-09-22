// Copyright 2024-2025 Tim Lehmann for whynotmake.it
//
// SPDX-License-Identifier: MIT
//
// Originally from liquid_glass_renderer (whynotmake.it).
// Maintained and evolved in-tree for liquid_glass_widgets.
// See lib/src/engine/ATTRIBUTION.md for provenance and modification history.

// ignore_for_file: avoid_setters_without_getters, public_member_api_docs

import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import '../renderer/glass_materialize_scope.dart';
import '../renderer/liquid_glass_push_back_scope.dart';
import '../renderer/liquid_glass_self_scale_scope.dart';
import 'glass_glow.dart';
import 'internal/transform_tracking_repaint_boundary_mixin.dart';
import 'liquid_glass_render_scope.dart';
import 'liquid_glass_settings.dart';
import 'multi_shader_builder.dart';
import 'render_liquid_glass_geometry.dart';
import 'rendering/liquid_glass_render_object.dart';
import 'shaders.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scale-safe repaint boundary
//
// Flutter's built-in [RepaintBoundary] rasterises its subtree to a GPU texture
// whose dimensions exactly match the widget's layout size.  When an ancestor
// [Transform.scale] (e.g. from [LiquidStretch] during a press animation) tries
// to expand that texture beyond its original bounds, Impeller clips at the
// layer boundary — producing the "top-cut" artefact on nav-bar buttons.
//
// [_ScaleSafeRepaintBoundary] is a drop-in replacement that overrides
// [paintBounds] to include the [clipExpansion] insets in all four directions.
// This tells Impeller to allocate a slightly larger texture so the scale
// animation has transparent headroom to paint into.
//
// When [clipExpansion] is [EdgeInsets.zero] (the default) the behaviour is
// identical to a plain [RepaintBoundary] — zero extra GPU cost.
// ─────────────────────────────────────────────────────────────────────────────

class _ScaleSafeRepaintBoundary extends SingleChildRenderObjectWidget {
  const _ScaleSafeRepaintBoundary({
    required super.child,
    this.expansion = EdgeInsets.zero,
  });

  /// Extra space (logical pixels) to inflate [paintBounds] in each direction.
  ///
  /// Set this to the same value as [LiquidGlassLayer.clipExpansion] so the
  /// repaint-boundary texture is large enough to absorb any ancestor scale or
  /// translate transform without hard-clipping the glass content.
  final EdgeInsets expansion;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderScaleSafeRepaintBoundary(expansion: expansion);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderScaleSafeRepaintBoundary renderObject,
  ) {
    renderObject.expansion = expansion;
  }
}

class _RenderScaleSafeRepaintBoundary extends RenderProxyBox {
  _RenderScaleSafeRepaintBoundary({required EdgeInsets expansion})
      : _expansion = expansion;

  EdgeInsets _expansion;
  set expansion(EdgeInsets value) {
    if (_expansion == value) return;
    _expansion = value;
    markNeedsPaint();
  }

  /// Acts as a repaint boundary — tells Flutter to rasterise the subtree into
  /// its own GPU layer rather than painting inline into the parent.
  @override
  bool get isRepaintBoundary => true;

  /// Inflate the declared paint area by [_expansion].  This causes Impeller to
  /// allocate a texture whose pixel region includes the expansion margin, so
  /// parent [Transform.scale] animations can expand into that space without
  /// triggering a hard clip at the original layout boundary.
  @override
  Rect get paintBounds => Rect.fromLTRB(
        -_expansion.left,
        -_expansion.top,
        size.width + _expansion.right,
        size.height + _expansion.bottom,
      );
}

/// Represents a layer of multiple [LiquidGlass] shapes or
/// [LiquidGlassBlendGroup]s that have shared [LiquidGlassSettings] and will be
/// rendered together.
///
/// If you create a [LiquidGlassLayer] with one or more [LiquidGlass] or
/// [LiquidGlassBlendGroup] widgets, the liquid glass effect will be rendered
/// where this layer is.
///
/// Make sure not to stack any other widgets between the [LiquidGlassLayer] and
/// the [LiquidGlass] widgets, otherwise the liquid glass effect will be behind
/// them.
///
/// ## Example
///
/// ```dart
/// Widget build(BuildContext context) {
///   return LiquidGlassLayer(
///     child: Column(
///       children: [
///         LiquidGlass(
///           shape: LiquidRoundedSuperellipse(
///             borderRadius: 10,
///           ),
///           child: const SizedBox.square(
///             dimension: 100,
///           ),
///         ),
///         const SizedBox(height: 100),
///         LiquidGlassBlendGroup(
///          blend: 20,
///          child: Row(
///             children: [
///               LiquidGlass.grouped(
///                 shape: const LiquidOval(),
///                 child: const SizedBox.square(
///                   dimension: 100,
///                 ),
///               ),
///               LiquidGlass.grouped(
///                 shape: const LiquidRoundedSuperellipse(
///                   borderRadius: 20,
///                 ),
///                 child: const SizedBox.square(
///                   dimension: 100,
///                 ),
///               ),
///             ],
///           ),
///         ),
///       ],
///     ),
///   );
/// }
class LiquidGlassLayer extends StatefulWidget {
  /// Creates a new [LiquidGlassLayer] with the given [child] and [settings].
  const LiquidGlassLayer({
    required this.child,
    this.settings = const LiquidGlassSettings(),
    this.shadows = const <BoxShadow>[],
    this.clipExpansion = EdgeInsets.zero,
    this.captureImage,
    this.captureOriginInScreenSpace = Offset.zero,
    super.key,
  });

  /// The subtree in which you should include at least one [LiquidGlass] widget.
  ///
  /// The [LiquidGlassLayer] will automatically register all [LiquidGlass]
  /// widgets in the subtree as shapes and render them.
  final Widget child;

  /// The settings for the liquid glass effect for all shapes in this layer.
  final LiquidGlassSettings settings;

  /// The shadows to render using the merged SDF geometry.
  final List<BoxShadow> shadows;

  /// Extra space to add around the geometry bounding box before clipping the
  /// [BackdropFilterLayer] that runs the glass shader.
  ///
  /// The clip rect is normally tight to the glass shape's geometry.  Any
  /// ancestor [Transform] (e.g. jelly squash-and-stretch on an indicator)
  /// can push painted pixels outside that tight rect, producing a hard edge
  /// cutoff.  Set [clipExpansion] to a safe margin that covers the maximum
  /// expected deformation so the shader is applied over the full animated area.
  ///
  /// Defaults to [EdgeInsets.zero] — zero extra GPU cost for static glass.
  final EdgeInsets clipExpansion;

  /// Pre-captured background image to use instead of a live [BackdropFilterLayer].
  ///
  /// When non-null, the glass shader reads from this image directly (sampler
  /// slot 0) instead of letting the compositor extract the backdrop. This
  /// eliminates the Impeller compositor ordering dependency that caused the
  /// opaque-white indicator bug (#99). The image must come from a
  /// [RenderRepaintBoundary.toImageSync] call on a boundary that covers the
  /// full background region behind the glass.
  ///
  /// Defaults to null — falls through to the BackdropFilterLayer path.
  final ui.Image? captureImage;

  /// The global (screen-space) logical-pixel origin of the [RepaintBoundary]
  /// that produced [captureImage]. Used to compute `uCaptureOffset` inside
  /// the shader so `FlutterFragCoord()` fragments are correctly mapped into
  /// the capture image's coordinate space.
  ///
  /// Ignored when [captureImage] is null.
  final Offset captureOriginInScreenSpace;

  @override
  State<LiquidGlassLayer> createState() => _LiquidGlassLayerState();
}

class _LiquidGlassLayerState extends State<LiquidGlassLayer>
    with SingleTickerProviderStateMixin {
  late final GeometryRenderLink _link = GeometryRenderLink();

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [LOCAL PATCH]: a running materialize transition above this layer
    // dissolves its glass through the settings' visibility channel — the one
    // fade the backdrop pass honours. Identity (the same instance) at rest.
    final settings =
        GlassMaterializeScope.resolveSettings(context, widget.settings);

    if (!ImageFilter.isShaderFilterSupported) {
      return LiquidGlassRenderScope(
        settings: settings,
        child: InheritedGeometryRenderLink(
          link: _link,
          child: widget.child,
        ),
      );
    }

    return BackdropGroup(
      child: _ScaleSafeRepaintBoundary(
        // Inflate the RepaintBoundary texture by clipExpansion so that any
        // ancestor Transform.scale (e.g. LiquidStretch press animation) can
        // expand into the margin without hard-clipping at the original bounds.
        expansion: widget.clipExpansion,
        child: LiquidGlassRenderScope(
          settings: settings,
          child: InheritedGeometryRenderLink(
            link: _link,
            child: ShaderBuilder(
              assetKey: ShaderKeys.liquidGlassRender,
              (context, shader, child) => _TouchSpecularBridge(
                renderShader: shader,
                backdropKey: BackdropGroup.of(context)?.backdropKey,
                settings: settings,
                shadows: widget.shadows,
                link: _link,
                clipExpansion: widget.clipExpansion,
                captureImage: widget.captureImage,
                captureOriginInScreenSpace: widget.captureOriginInScreenSpace,
                selfScaled: LiquidGlassSelfScaleScope.of(context),
                pushBackActive: LiquidGlassPushBackScope.of(context),
                child: child!,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TouchSpecularBridge — zero-rebuild touch-specular wiring
//
// Subscribes to GlassGlowLayer.touchSpecularNotifierOf() and pushes position
// + intensity directly to RenderLiquidGlassLayer.setTouchSpecular().
//
// No setState. No widget rebuild. The listener fires on every spring animation
// tick (driven by GlassGlowLayerState's ListenableBuilder) and calls
// markNeedsPaint() on the render object only when values have changed.
//
// If no GlassGlowLayer ancestor exists (e.g. GlassAppBar with no GlassButton
// children), touchSpecularNotifierOf returns null and this bridge is a
// transparent passthrough with zero overhead.
// ---------------------------------------------------------------------------
class _TouchSpecularBridge extends StatefulWidget {
  const _TouchSpecularBridge({
    required this.renderShader,
    required this.backdropKey,
    required this.settings,
    required this.shadows,
    required this.link,
    required this.child,
    this.clipExpansion = EdgeInsets.zero,
    this.captureImage,
    this.captureOriginInScreenSpace = Offset.zero,
    this.selfScaled = false,
    this.pushBackActive = false,
  });

  final FragmentShader renderShader;
  final BackdropKey? backdropKey;
  final LiquidGlassSettings settings;
  final List<BoxShadow> shadows;
  final GeometryRenderLink link;
  final Widget child;
  final EdgeInsets clipExpansion;
  final ui.Image? captureImage;
  final Offset captureOriginInScreenSpace;
  final bool selfScaled;
  final bool pushBackActive;

  @override
  State<_TouchSpecularBridge> createState() => _TouchSpecularBridgeState();
}

class _TouchSpecularBridgeState extends State<_TouchSpecularBridge> {
  final _rawShapesKey = GlobalKey();
  ValueNotifier<({Offset position, double intensity})>? _notifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebindNotifier();
  }

  void _rebindNotifier() {
    final next = GlassGlowLayer.touchSpecularNotifierOf(context);
    if (next == _notifier) return;
    _notifier?.removeListener(_onTouchSpecular);
    _notifier = next;
    _notifier?.addListener(_onTouchSpecular);
  }

  void _onTouchSpecular() {
    final v = _notifier?.value;
    if (v == null) return;
    final ro = _rawShapesKey.currentContext?.findRenderObject()
        as RenderLiquidGlassLayer?;
    if (ro == null) return;

    final layerBox = GlassGlowLayer.maybeOf(context)?.context.findRenderObject()
        as RenderBox?;
    final Offset pos;
    if (layerBox != null &&
        layerBox.attached &&
        ro.attached &&
        layerBox.hasSize &&
        ro.hasSize) {
      pos = ro.globalToLocal(layerBox.localToGlobal(v.position));
    } else {
      pos = v.position;
    }
    ro.setTouchSpecular(pos, v.intensity);
  }

  @override
  void dispose() {
    _notifier?.removeListener(_onTouchSpecular);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RawShapes(
      key: _rawShapesKey,
      renderShader: widget.renderShader,
      backdropKey: widget.backdropKey,
      settings: widget.settings,
      shadows: widget.shadows,
      link: widget.link,
      clipExpansion: widget.clipExpansion,
      captureImage: widget.captureImage,
      captureOriginInScreenSpace: widget.captureOriginInScreenSpace,
      selfScaled: widget.selfScaled,
      pushBackActive: widget.pushBackActive,
      child: widget.child,
    );
  }
}

class _RawShapes extends SingleChildRenderObjectWidget {
  const _RawShapes({
    required this.renderShader,
    required this.backdropKey,
    required this.settings,
    required this.shadows,
    required Widget super.child,
    required this.link,
    super.key,
    this.clipExpansion = EdgeInsets.zero,
    this.captureImage,
    this.captureOriginInScreenSpace = Offset.zero,
    this.selfScaled = false,
    this.pushBackActive = false,
  });

  final FragmentShader renderShader;
  final BackdropKey? backdropKey;
  final LiquidGlassSettings settings;
  final List<BoxShadow> shadows;
  final GeometryRenderLink link;
  final EdgeInsets clipExpansion;
  final ui.Image? captureImage;
  final Offset captureOriginInScreenSpace;

  /// See [LiquidGlassSelfScaleScope].
  final bool selfScaled;

  /// See [LiquidGlassPushBackScope]. When `false` (the default),
  /// [RenderLiquidGlassLayer._hasScale] always returns `false` regardless of
  /// the ancestor transform — a static app-level scale (e.g.
  /// `responsive_framework`) never freezes UV coordinates.
  final bool pushBackActive;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLiquidGlassLayer(
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      renderShader: renderShader,
      backdropKey: backdropKey,
      settings: settings,
      shadows: shadows,
      link: link,
      clipExpansion: clipExpansion,
      captureImage: captureImage,
      captureOriginInScreenSpace: captureOriginInScreenSpace,
      selfScaled: selfScaled,
      pushBackActive: pushBackActive,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiquidGlassLayer renderObject,
  ) {
    renderObject
      ..link = link
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context)
      ..settings = settings
      ..shadows = shadows
      ..backdropKey = backdropKey
      ..clipExpansion = clipExpansion
      ..captureImage = captureImage
      ..captureOriginInScreenSpace = captureOriginInScreenSpace
      ..selfScaled = selfScaled
      ..pushBackActive = pushBackActive;
  }
}

class RenderLiquidGlassLayer extends LiquidGlassRenderObject
    with TransformTrackingRenderObjectMixin {
  RenderLiquidGlassLayer({
    required super.renderShader,
    required super.devicePixelRatio,
    required super.settings,
    required this.shadows,
    required super.link,
    super.backdropKey,
    super.captureImage,
    super.captureOriginInScreenSpace,
    EdgeInsets clipExpansion = EdgeInsets.zero,
    bool selfScaled = false,
    bool pushBackActive = false,
  })  : _clipExpansion = clipExpansion,
        _selfScaled = selfScaled,
        _pushBackActive = pushBackActive;

  // ── Cached blur filters ─────────────────────────────────────────────────
  // The BackdropFilterLayers' blur filters are rebuilt only when their sigma
  // or opacity changes — not on every paint frame during jelly/morph
  // animations.
  ImageFilter? _cachedBlur;
  double _cachedBlurSigma = -1;
  double _cachedBlurGamma = -1;
  ImageFilter? _cachedFrost;
  ImageFilter? _cachedFrostClampFilter;
  double _cachedFrostSigma = -1;
  double _cachedFrostOpacity = -1;
  double _cachedFrostGamma = -1;
  double _cachedFrostClamp = 0;
  double _cachedFrostDilate = 0;

  final _shaderHandle = LayerHandle<BackdropFilterLayer>();
  final _blurLayerHandle = LayerHandle<BackdropFilterLayer>();
  final _lensLayerHandle = LayerHandle<BackdropFilterLayer>();
  final _frostLayerHandle = LayerHandle<BackdropFilterLayer>();
  final _frostClampLayerHandle = LayerHandle<BackdropFilterLayer>();
  final _clipRectLayerHandle = LayerHandle<ClipRectLayer>();
  final _clipPathLayerHandle = LayerHandle<ClipPathLayer>();
  final _lensClipLayerHandle = LayerHandle<ClipRectLayer>();
  final _frostClipLayerHandle = LayerHandle<ClipPathLayer>();

  /// A Gaussian blur of [sigma], composited over the sharp backdrop at
  /// [opacity]. A colour matrix is an ImageFilter, so it composes onto the
  /// blur in the same layer.
  ///
  /// With [gamma] other than 1, the backdrop is raised to that exponent
  /// before the blur and to its reciprocal after (frost_gamma.frag on both
  /// sides), so the blur averages in a curved space: see
  /// LiquidGlassSettings.frostGamma. Falls back to a plain blur until the
  /// program is cached (LiquidGlassWidgets.initialize).
  ImageFilter _blurFilter(
    double sigma,
    double opacity,
    List<FragmentShader> shaders, {
    double gamma = 1.0,
    double offset = 0.0,
    double dilate = 0.0,
  }) {
    ImageFilter blur = ImageFilter.blur(
      tileMode: TileMode.mirror,
      sigmaX: sigma,
      sigmaY: sigma,
    );
    if (dilate != 0) {
      final radius = dilate.abs();
      blur = ImageFilter.compose(
        outer: blur,
        inner: dilate > 0
            ? ImageFilter.dilate(radiusX: radius, radiusY: radius)
            : ImageFilter.erode(radiusX: radius, radiusY: radius),
      );
    }
    if (gamma != 1.0) {
      final program = MultiShaderBuilder.cachedProgram(ShaderKeys.frostGamma);
      if (program != null) {
        // Each filter gets its own pair: a filter reads its shader's
        // uniforms when it is first drawn, so instances shared between the
        // blur and frost filters would all end up with the last exponent
        // set. Held in [shaders] to be disposed with the filter.
        final curve = program.fragmentShader()..setFloat(2, gamma);
        final back = program.fragmentShader()..setFloat(2, 1.0 / gamma);
        shaders
          ..forEach((shader) => shader.dispose())
          ..clear()
          ..addAll([curve, back]);
        blur = ImageFilter.compose(
          outer: ImageFilter.shader(back),
          inner: ImageFilter.compose(
            outer: blur,
            inner: ImageFilter.shader(curve),
          ),
        );
      }
    }
    if (opacity >= 1.0 && offset == 0.0) return blur;
    final shift = offset * 255.0;
    return ImageFilter.compose(
      outer: ColorFilter.matrix(<double>[
        1, 0, 0, 0, shift, //
        0, 1, 0, 0, shift, //
        0, 0, 1, 0, shift, //
        0, 0, 0, opacity, 0, //
      ]),
      inner: blur,
    );
  }

  final _blurShaders = <FragmentShader>[];
  final _frostShaders = <FragmentShader>[];
  final _frostClampShaders = <FragmentShader>[];

  EdgeInsets _clipExpansion;
  set clipExpansion(EdgeInsets value) {
    if (_clipExpansion == value) return;
    _clipExpansion = value;
    markNeedsPaint();
  }

  /// See [LiquidGlassSelfScaleScope]. Repaints on change: the shader's shape
  /// bounds are derived from [matteTransform], which this switches.
  bool _selfScaled;
  set selfScaled(bool value) {
    if (_selfScaled == value) return;
    _selfScaled = value;
    markNeedsPaint();
  }

  /// See [LiquidGlassPushBackScope]. When `false`, [_hasScale] returns
  /// `false` unconditionally — a static app-level scale (e.g.
  /// `responsive_framework`) is never mistaken for a CupertinoSheet push-back.
  bool _pushBackActive;
  set pushBackActive(bool value) {
    if (_pushBackActive == value) return;
    // Called by updateRenderObject during build. An attached ancestor may
    // still need layout (e.g. a newly inserted route SlideTransition), so
    // reading getTransformTo here can throw. Refresh the resting snapshot
    // on the next paint, after the entire ancestor chain has been laid out.
    _pushBackActive = value;
    markNeedsPaint();
  }

  List<BoxShadow> shadows;

  @override
  Size get desiredMatteSize => switch (owner?.rootNode) {
        final RenderView rv => rv.size,
        final RenderBox rb => rb.size,
        _ => Size.zero,
      };

  Matrix4? _unscaledTransform;
  Offset? _unscaledCaptureOrigin;

  bool _hasScale(Matrix4 m) {
    // A surface scaling itself leaves its backdrop where it was, so the live
    // transform is the right one and freezing would strand the shape.
    if (_selfScaled) return false;
    // A push-back scope must be active — a persistent app-level scale
    // (e.g. responsive_framework, FittedBox, InteractiveViewer) must never
    // freeze UV coordinates. Only a CupertinoSheet push-back emits the scope.
    if (!_pushBackActive) return false;
    // Detects the CupertinoSheet push-back, which scales the page down
    // uniformly on both X and Y axes simultaneously (< 1.0 on both).
    //
    // Requiring BOTH axes to shrink correctly rejects:
    //   - 1D jelly physics (one axis squashes, the other stretches; always one >= 1.0)
    //   - Pure translations (both axes remain 1.0)
    //   - Z-axis perspective flattening (m[10] == 0 but m[0] == m[5] == 1)
    final scaleX = m[0].abs();
    final scaleY = m[5].abs();
    // Use a very tight tolerance (0.9999) to catch the very first frame of the CupertinoSheet
    // scale animation. A looser tolerance (0.99) allowed early frames of the animation
    // (e.g., 0.995) to overwrite the snapshot before freezing, causing a slight jump.
    const threshold = LiquidGlassSelfScaleScope.freezeScaleThreshold;
    return (scaleX < threshold && scaleX > 0.0) &&
        (scaleY < threshold && scaleY > 0.0);
  }

  /// Snapshots the layer's current screen-space transform and capture origin
  /// whenever no ancestor scale is active. When a scale IS active (e.g.
  /// CupertinoSheet push-back), the snapshot is frozen at the last unscaled
  /// values so [matteTransform] and [captureOriginInScreenSpace] can return
  /// coordinates that match the unscaled [captureImage] texture.
  ///
  /// Called from [paint] on every frame — not from
  /// [onTransformChanged] — because [GeometryTransformTrackingLayer] skips
  /// the callback on the very first frame (when [_lastTransform] is null), and
  /// only fires again when the accumulated transform actually changes between
  /// scene builds.  A CupertinoSheet that opens before any movement would leave
  /// [_unscaledTransform] null if we relied on [onTransformChanged] alone,
  /// causing the frozen-coordinate fallback to silently miss.
  ///
  /// Updating a cached field inside [paint] is safe: it calls no
  /// [markNeedsPaint], no [setState], and no layout-invalidation, so it does
  /// not violate Flutter's read-only paint contract.
  void _updateScaleState(
      Matrix4 currentTransform, Offset currentCaptureOrigin) {
    if (!_hasScale(currentTransform)) {
      _unscaledTransform = currentTransform;
      _unscaledCaptureOrigin = currentCaptureOrigin;
    }
  }

  @override
  Matrix4 get matteTransform {
    if (_unscaledTransform case final frozen?
        when _hasScale(getTransformTo(null))) {
      return frozen;
    }
    return getTransformTo(null);
  }

  @override
  Offset get captureOriginInScreenSpace {
    if (_unscaledCaptureOrigin case final frozen?
        when _hasScale(getTransformTo(null))) {
      return frozen;
    }
    return super.captureOriginInScreenSpace;
  }

  @override
  void onTransformChanged() {
    // Geometry is in LOCAL space; matteTransform is applied at paint time,
    // so only a repaint — not a layout/geometry rebuild — is required here.
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!attached) return;
    // Refresh before the base paint reads matteTransform to build geometry.
    // This also records the resting baseline when geometry is not ready yet.
    _updateScaleState(getTransformTo(null), super.captureOriginInScreenSpace);
    super.paint(context, offset);
  }

  @override
  void paintLiquidGlass(
    PaintingContext context,
    Offset offset,
    List<(RenderLiquidGlassGeometry, GeometryCache, Matrix4)> shapes,
    Rect boundingBox,
  ) {
    if (!attached) return;

    // ── Pass 0: SDF Shadows ──────────────────────────────────────────────────
    if (shadows.isNotEmpty && geometryImage != null) {
      final localBounds = geometryLocalBounds.shift(offset);

      for (final shadow in shadows) {
        if (shadow.color.a == 0) continue;

        // Inflate clip rect to ensure large blurs aren't cut off
        final shadowClip = localBounds.shift(shadow.offset).inflate(
              shadow.spreadRadius + shadow.blurRadius * 3,
            );

        context.canvas.saveLayer(shadowClip, Paint());

        // 1. Draw the geometry matte as a blurred, tinted shadow
        final shadowPaint = Paint()
          ..colorFilter = ColorFilter.mode(shadow.color, BlendMode.srcIn)
          ..imageFilter = ImageFilter.blur(
            sigmaX: shadow.blurSigma,
            sigmaY: shadow.blurSigma,
            tileMode: TileMode.decal,
          );

        context.canvas.drawImageRect(
          geometryImage!,
          Rect.fromLTWH(
            0,
            0,
            geometryImage!.width.toDouble(),
            geometryImage!.height.toDouble(),
          ),
          localBounds.shift(shadow.offset),
          shadowPaint,
        );

        // 2. GPU Cutout (dstOut): punch out the interior using the same geometry
        // matte to prevent the glass from blurring its own shadow (dirty rim).
        context.canvas.drawImageRect(
          geometryImage!,
          Rect.fromLTWH(
            0,
            0,
            geometryImage!.width.toDouble(),
            geometryImage!.height.toDouble(),
          ),
          localBounds,
          Paint()..blendMode = BlendMode.dstOut,
        );

        context.canvas.restore();
      }
    }

    // ── Pass 0b: Lens ────────────────────────────────────────────────────────
    // With a paraxial lens under a frost the refraction runs first, on the
    // sharp backdrop, so the frost blurs the lensed image: the flat face
    // ends up a cloud while the rim band folds crisp content, as the native
    // band does. Ungrouped so the passes after it read its output.
    if (splitLensPass) {
      final lensLayer = (_lensLayerHandle.layer ??= BackdropFilterLayer())
        ..backdropKey = null
        ..filter = ImageFilter.shader(lensShader!);
      _lensClipLayerHandle.layer = context.pushClipRect(
        needsCompositing,
        offset,
        boundingBox,
        (context, offset) {
          context.pushLayer(lensLayer, (context, offset) {}, offset);
        },
        oldLayer: _lensClipLayerHandle.layer,
      );
    } else {
      _lensLayerHandle.layer = null;
      _lensClipLayerHandle.layer = null;
    }

    // ── Pass 1a: Blur ────────────────────────────────────────────────────────
    // Use Flutter's native ImageFilter.blur for smooth, multi-pass Gaussian
    // quality (the inline 9-tap shader approximation was pixelated with text).
    // Clip tightly to the actual pill shape path — no expansion needed here.
    //
    // Under a frost this is the ghost of the content that shows through the
    // cloud, so it runs on the sharp backdrop ahead of the frost, ungrouped
    // so the frost passes see it, and in its own tone curve (blurGamma).
    if (settings.effectiveBlur > 0) {
      final blurSigma = settings.effectiveBlur;
      final hasFrost = settings.effectiveFrost > 0;
      // Reuse cached blur filter when sigma hasn't changed.
      final blurGamma = settings.blurGamma;
      if (_cachedBlur == null ||
          _cachedBlurSigma != blurSigma ||
          _cachedBlurGamma != blurGamma) {
        _cachedBlur =
            _blurFilter(blurSigma, 1.0, _blurShaders, gamma: blurGamma);
        _cachedBlurSigma = blurSigma;
        _cachedBlurGamma = blurGamma;
      }

      final blurLayer = (_blurLayerHandle.layer ??= BackdropFilterLayer())
        // Scoped to this LiquidGlassLayer's BackdropGroup, unless the frost
        // passes after it have to read its output.
        ..backdropKey = hasFrost ? null : backdropKey
        ..filter = _cachedBlur!;

      final clipPath = Path();
      for (final geometry in shapes) {
        if (!geometry.$1.attached) continue;
        clipPath.addPath(
          geometry.$2.path,
          Offset.zero,
          matrix4: geometry.$3.storage,
        );
      }
      _clipPathLayerHandle.layer = context.pushClipPath(
        needsCompositing,
        offset,
        boundingBox,
        clipPath,
        (context, offset) {
          context.pushLayer(
            blurLayer,
            (context, offset) {
              paintShapeContents(context, offset, shapes, insideGlass: true);
            },
            offset,
          );
        },
        oldLayer: _clipPathLayerHandle.layer,
      );
    } else {
      _blurLayerHandle.layer = null;
      _clipPathLayerHandle.layer = null;
    }

    // ── Pass 1b: Frost ───────────────────────────────────────────────────────
    // The cloud of iOS 26 glass, composited so the ghost of the content
    // (the blur pass above) still shows through it at 1 - frostOpacity. The
    // native ghost is held back on one side: under the light material it
    // never goes more than a fixed step darker than the cloud, so black
    // detail is a flat pale band while white detail keeps its shape. A
    // first pass composites the cloud, shifted down by frostClamp, with
    // BlendMode.lighten (or shifted up with darken for a negative clamp);
    // the second composites the cloud normally at frostOpacity.
    if (settings.effectiveFrost > 0) {
      final frostSigma = settings.effectiveFrost;
      final frostOpacity = settings.frostOpacity.clamp(0.0, 1.0);
      final frostGamma = settings.frostGamma;
      final frostClamp = settings.frostClamp.clamp(-1.0, 1.0);
      final frostDilate = settings.frostDilate;
      if (_cachedFrost == null ||
          _cachedFrostSigma != frostSigma ||
          _cachedFrostOpacity != frostOpacity ||
          _cachedFrostGamma != frostGamma ||
          _cachedFrostClamp != frostClamp ||
          _cachedFrostDilate != frostDilate) {
        _cachedFrost = _blurFilter(
          frostSigma,
          frostOpacity,
          _frostShaders,
          gamma: frostGamma,
          dilate: frostDilate,
        );
        _cachedFrostClampFilter = frostClamp == 0
            ? null
            : _blurFilter(
                frostSigma,
                1.0,
                _frostClampShaders,
                gamma: frostGamma,
                offset: -frostClamp,
                dilate: frostDilate,
              );
        _cachedFrostSigma = frostSigma;
        _cachedFrostOpacity = frostOpacity;
        _cachedFrostGamma = frostGamma;
        _cachedFrostClamp = frostClamp;
        _cachedFrostDilate = frostDilate;
      }

      // A blended BackdropFilterLayer is composited over its whole rect, not
      // the clip path around it, so the blended pass cuts its output to the
      // matte itself: the backdrop is cut to the matte before the blur and
      // the edge made hard again after it (shaders/frost_mask.frag and
      // frost_unmask.frag). The mask reads this paint's matte uniforms, so
      // the filter is rebuilt each paint.
      final mask = frostMaskShader;
      final unmask = frostUnmaskShader;
      ImageFilter masked(ImageFilter filter) => mask == null || unmask == null
          ? filter
          : ImageFilter.compose(
              outer: ImageFilter.shader(unmask),
              inner: ImageFilter.compose(
                outer: filter,
                inner: ImageFilter.shader(mask),
              ),
            );

      // Not part of the layer's BackdropGroup: filters sharing a key read
      // one snapshot of the backdrop, so the shader pass would never see
      // the frost. Left ungrouped they read live, and the group's snapshot
      // is taken after they have drawn.
      if (_cachedFrostClampFilter case final clampFilter?) {
        _frostClampLayerHandle.layer ??= BackdropFilterLayer();
        _frostClampLayerHandle.layer!
          ..backdropKey = null
          ..blendMode = frostClamp > 0 ? BlendMode.lighten : BlendMode.darken
          ..filter = masked(clampFilter);
      } else {
        _frostClampLayerHandle.layer = null;
      }
      final frostLayer = (_frostLayerHandle.layer ??= BackdropFilterLayer())
        ..backdropKey = null
        ..blendMode = BlendMode.srcOver
        ..filter = _cachedFrost!;

      final frostPath = Path();
      for (final geometry in shapes) {
        if (!geometry.$1.attached) continue;
        frostPath.addPath(
          geometry.$2.path,
          Offset.zero,
          matrix4: geometry.$3.storage,
        );
      }
      _frostClipLayerHandle.layer = context.pushClipPath(
        needsCompositing,
        offset,
        boundingBox,
        frostPath,
        (context, offset) {
          final clampLayer = _frostClampLayerHandle.layer;
          if (clampLayer != null) {
            context.pushLayer(clampLayer, (context, offset) {}, offset);
          }
          context.pushLayer(frostLayer, (context, offset) {}, offset);
        },
        oldLayer: _frostClipLayerHandle.layer,
      );
    } else {
      _frostLayerHandle.layer = null;
      _frostClampLayerHandle.layer = null;
      _frostClipLayerHandle.layer = null;
    }

    // ── Pass 2: Glass refraction + lighting shader ────────────────────────────
    // Inflate the clip rect by _clipExpansion so jelly squash-and-stretch can
    // push deformed pixels beyond the tight bounding box without a hard clip
    // edge. For static glass _clipExpansion == EdgeInsets.zero (no-op).
    final clipRect = _clipExpansion == EdgeInsets.zero
        ? boundingBox
        : Rect.fromLTRB(
            boundingBox.left - _clipExpansion.left,
            boundingBox.top - _clipExpansion.top,
            boundingBox.right + _clipExpansion.right,
            boundingBox.bottom + _clipExpansion.bottom,
          );

    // Capture path: when a pre-captured background image is available, bypass
    // the BackdropFilterLayer entirely and draw the shader directly onto the
    // canvas, binding the captured image as uBackgroundTexture (slot 0).
    // This eliminates the live compositor read, making the indicator rendering
    // deterministic and immune to Impeller compositor ordering bugs (#99).
    //
    // IMPORTANT: skip the capture path when the ancestor transform applies a scale
    // (e.g. during a CupertinoSheet drag). The capture image's UV coordinates are
    // computed relative to the layer's original bounds. When scaled, FlutterFragCoord()
    // shifts relative to the baked UV constants, sending samples out of range →
    // The captureImage path correctly maps coordinates on Impeller, but suffers from
    // double-scaling if the ancestor transform applies a scale (like CupertinoSheet drag),
    // because the captureImage itself is captured unscaled.
    // To fix this, we snapshot the layer's unscaled transform on every paint
    // via _updateScaleState. The moment a 3D perspective scale is applied,
    // the snapshot stops updating. The matteTransform and
    // captureOriginInScreenSpace getters then return the last known unscaled
    // coordinates, perfectly neutralising the double-scale artifact.

    if (captureImage case final capture?) {
      paintLiquidGlassWithCapture(
        context,
        offset,
        shapes,
        clipRect,
        capture,
      );
      // paintLiquidGlassWithCapture handles all three passes (blur, shader, contents).
      // Release the stale BackdropFilter layer handles so the engine can collect
      // the offscreen surface when we're no longer using the backdrop path.
      _shaderHandle.layer = null;
      _clipRectLayerHandle.layer = null;
      // Capture path does not open a live backdrop pass — clear so that
      // descendant glass does not inherit a stale pass rect.
      backdropPassClipRectLocal = null;
      return;
    }
    // BackdropFilter path (default): live compositor read via BackdropFilterLayer.
    // Publish the clip rect so descendant premium glass can find the pass their
    // FlutterFragCoord() is relative to (see enclosingBackdropPassRect).
    backdropPassClipRectLocal = clipRect;
    final shaderLayer = (_shaderHandle.layer ??= BackdropFilterLayer())
      ..filter = ImageFilter.shader(renderShader!);

    try {
      _clipRectLayerHandle.layer = context.pushClipRect(
        needsCompositing,
        offset,
        clipRect,
        (context, offset) {
          context.pushLayer(
            shaderLayer,
            (context, offset) {
              paintShapeContents(context, offset, shapes, insideGlass: false);
            },
            offset,
          );
        },
        oldLayer: _clipRectLayerHandle.layer,
      );
    } finally {
      backdropPassClipRectLocal = null;
    }
  }

  @override
  void dispose() {
    // Eagerly clear filter references on the backdrop layers before nulling
    // the handles. During isolate shutdown on Mali GPUs, GC finalization of
    // BackdropFilterLayer retains DlRuntimeEffectColorSource → TextureVK →
    // Vulkan mutex chains that outlive the GPU context (Crash 2). Clearing
    // the filter property breaks this retention chain immediately.
    _shaderHandle.layer?.filter = ImageFilter.blur(sigmaX: 0, sigmaY: 0);
    _blurLayerHandle.layer?.filter = ImageFilter.blur(sigmaX: 0, sigmaY: 0);
    _frostLayerHandle.layer?.filter = ImageFilter.blur(sigmaX: 0, sigmaY: 0);
    _frostClampLayerHandle.layer?.filter =
        ImageFilter.blur(sigmaX: 0, sigmaY: 0);
    _lensLayerHandle.layer?.filter = ImageFilter.blur(sigmaX: 0, sigmaY: 0);
    _lensLayerHandle.layer = null;
    _lensClipLayerHandle.layer = null;
    _shaderHandle.layer = null;
    _blurLayerHandle.layer = null;
    _frostLayerHandle.layer = null;
    _frostClampLayerHandle.layer = null;
    _clipRectLayerHandle.layer = null;
    _clipPathLayerHandle.layer = null;
    _frostClipLayerHandle.layer = null;
    for (final shader in _blurShaders.followedBy(_frostShaders).followedBy(
          _frostClampShaders,
        )) {
      shader.dispose();
    }
    super.dispose();
  }
}
