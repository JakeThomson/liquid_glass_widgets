import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../src/renderer/liquid_glass_renderer.dart';

import '../../theme/glass_theme_data.dart';
import '../../types/glass_quality.dart';
import 'inherited_liquid_glass.dart';

/// An adaptive liquid glass layer that provides a glass background with proper
/// fallback handling across all platforms.
///
/// This is a custom replacement for `LiquidGlassLayer` that uses `AdaptiveGlass`
/// for rendering, ensuring the background uses the lightweight shader on web/Skia
/// instead of falling back to FakeGlass.
///
/// **Fallback chain for background:**
/// - Premium + Impeller → Full shader (best quality) + blending support
/// - Premium + Skia/web → Lightweight shader (not FakeGlass!)
/// - Standard → Lightweight shader
///
/// **Blending:**
/// - `blendAmount` parameter only works on Impeller (requires full renderer)
/// - On Skia, blending is ignored (widgets render separately)
/// - This matches chromatic aberration behavior (Impeller-only features)
///
/// **Usage:**
/// ```dart
/// // With explicit settings:
/// AdaptiveLiquidGlassLayer(
///   settings: LiquidGlassSettings(...),
///   quality: GlassQuality.premium,
///   shape: LiquidRoundedSuperellipse(borderRadius: 32),
///   blendAmount: 10.0, // Impeller-only
///   child: YourContent(),
/// )
///
/// // Or use theme (recommended):
/// AdaptiveLiquidGlassLayer(
///   child: YourContent(), // Uses GlassTheme settings automatically
/// )
/// ```
class AdaptiveLiquidGlassLayer extends StatelessWidget {
  const AdaptiveLiquidGlassLayer({
    required this.child,
    this.shape = const LiquidRoundedSuperellipse(borderRadius: 0),
    this.settings,
    this.quality,
    this.clipBehavior = Clip.antiAlias,
    this.blendAmount = 10.0,
    super.key,
  });

  /// The widget to display inside the glass layer.
  final Widget child;

  /// The shape of the glass background.
  final LiquidShape shape;

  /// Glass effect settings for the background.
  ///
  /// If null, uses settings from [GlassTheme] based on current brightness.
  final LiquidGlassSettings? settings;

  /// Rendering quality for the glass effect.
  ///
  /// If null, uses quality from [GlassTheme].
  final GlassQuality? quality;

  /// Clip behavior for the glass shape.
  final Clip clipBehavior;

  /// Blend amount for smooth glass transitions (Impeller-only).
  ///
  /// Higher values create smoother blending between overlapping glass elements.
  /// Only works on Impeller - ignored on Skia (like chromatic aberration).
  ///
  /// Defaults to 10.0.
  final double blendAmount;

  /// Detects if Impeller rendering engine is active.
  static bool get _canUseImpeller => ui.ImageFilter.isShaderFilterSupported;

  @override
  Widget build(BuildContext context) {
    // Resolve settings and quality from theme if not explicitly provided
    final themeData = GlassThemeData.of(context);
    final effectiveSettings = settings ??
        themeData.settingsFor(context) ??
        const LiquidGlassSettings();
    final effectiveQuality =
        quality ?? themeData.qualityFor(context) ?? GlassQuality.standard;

    // Detect if we should use the full Impeller-native rendering pipeline
    final bool useFullRenderer =
        _canUseImpeller && effectiveQuality == GlassQuality.premium;

    // On Skia/Web, we want to provide a single BackdropFilter for the whole layer
    // to avoid each child doing its own expensive blur.
    Widget content = child;

    // Root Provider: Always exists to satisfy assertions for grouped widgets.
    // useBackdropGroup: true is safe — when no BackdropGroup ancestor exists,
    // BackdropGroup.of(context) returns null and the backdropKey is null,
    // giving identical behaviour to false.  When a GlassBackdropScope is
    // present in the tree, all layers under it share one GPU blur capture.
    return LiquidGlassLayer(
      settings: effectiveSettings,
      useBackdropGroup: true,
      child: InheritedLiquidGlass(
        settings: effectiveSettings,
        quality: effectiveQuality,
        isBlurProvidedByAncestor:
            false, // Root never provides the blur; containers do.
        child: useFullRenderer
            ? LiquidGlassBlendGroup(
                blend: blendAmount,
                child: content,
              )
            : content,
      ),
    );
  }
}
