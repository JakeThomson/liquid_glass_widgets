import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../src/renderer/liquid_glass_renderer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../types/glass_quality.dart';
import 'glass_accessibility_scope.dart';
import 'lightweight_liquid_glass.dart';
import 'inherited_liquid_glass.dart';

/// Adaptive glass widget that intelligently chooses between premium and
/// lightweight shaders based on renderer capabilities.
///
/// **Fallback chain:**
/// 1. Premium quality + Impeller available → Full shader (best quality)
/// 2. Premium quality + Skia/web → Lightweight shader (our calibrated shader)
/// 3. Standard quality → Always lightweight shader
/// 4. If lightweight shader fails → FakeGlass (final fallback)
///
/// This ensures users never see FakeGlass unless absolutely necessary.
class AdaptiveGlass extends StatelessWidget {
  const AdaptiveGlass({
    required this.shape,
    required this.settings,
    required this.child,
    this.quality = GlassQuality.standard,
    this.useOwnLayer = true,
    this.clipBehavior = Clip.antiAlias,
    this.allowElevation = true,
    this.glowIntensity = 0.0,
    super.key,
  });

  final LiquidShape shape;
  final LiquidGlassSettings settings;
  final Widget child;
  final GlassQuality quality;
  final bool useOwnLayer;
  final Clip clipBehavior;

  /// Whether to allow "Specular Elevation" when in a grouped context.
  /// Should be true for interactive objects (buttons) and false for layers/containers.
  final bool allowElevation;

  /// Interactive glow intensity for Skia/Web (0.0-1.0).
  ///
  /// On Impeller, this is ignored and [GlassGlow] widget is used instead.
  /// On Skia/Web, this controls shader-based button press feedback.
  ///
  /// Defaults to 0.0 (no glow).
  final double glowIntensity;

  /// Detects if Impeller rendering engine is active.
  ///
  /// Returns true when shader filters are supported (Impeller),
  /// false when using Skia or web renderers.
  ///
  /// This is the same check used internally by liquid_glass_renderer.
  static bool get _canUseImpeller => ui.ImageFilter.isShaderFilterSupported;

  /// Static helper to render glass in a grouped context without creating a new layer.
  /// This is the adaptive replacement for [LiquidGlass.grouped].
  static Widget grouped({
    required LiquidShape shape,
    required Widget child,
    GlassQuality quality = GlassQuality.standard,
    Clip clipBehavior = Clip.antiAlias,
    double glowIntensity = 0.0,
  }) {
    return AdaptiveGlass(
      shape: shape,
      settings: const LiquidGlassSettings(), // Inherited via inLayer
      quality: quality,
      useOwnLayer: false,
      clipBehavior: clipBehavior,
      glowIntensity: glowIntensity,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ---- IP1: ACCESSIBILITY FAST-PATH ----------------------------------------
    // iOS 26 glass degrades to a solid frosted panel when "Reduce Transparency"
    // is enabled. We honour the equivalent Flutter signal (highContrast, which
    // is the closest available platform proxy for isReduceTransparencyEnabled).
    //
    // When triggered, the entire glass shader pipeline is bypassed. The fallback
    // is a ClipRRect + BackdropFilter(blur) + semi-opaque tinted container —
    // still visually layered, but with no refraction, no specular, and no
    // chromatic aberration. Zero GPU shader cost.
    //
    // GlassAccessibilityScope must be in the widget tree for this to activate;
    // without it, defaults.reduceTransparency = false and we proceed normally.
    // --------------------------------------------------------------------------
    final accessibilityData = GlassAccessibilityData.of(context);
    if (accessibilityData.reduceTransparency) {
      return _FrostedFallback(
        shape: shape,
        settings: settings,
        clipBehavior: clipBehavior,
        child: child,
      );
    }

    // If we are on Skia/Web, we CANNOT use LiquidGlass.grouped or withOwnLayer
    // because those will fall back to FakeGlass (solid color) inside the renderer.
    // We MUST use our LightweightLiquidGlass to get actual glass effects.

    final bool canUsePremiumShader =
        !kIsWeb && _canUseImpeller && quality == GlassQuality.premium;

    if (!canUsePremiumShader) {
      // 1. Detect Grouped Elevation
      // When a parent provides the blur (Batch-Blur Optimization), we lose the
      // "double-darkening" effect of nested blurs. We compensate with the
      // densityFactor parameter (0.0-1.0) which triggers synthetic density physics
      // in the shader to make elevated widgets "pop" against the background.
      final inherited =
          context.dependOnInheritedWidgetOfExactType<InheritedLiquidGlass>();
      final bool shouldElevate =
          allowElevation && (inherited?.isBlurProvidedByAncestor ?? false);

      // Calculate density factor for shader (0.0 = normal, 1.0 = elevated)
      final double densityFactor = shouldElevate ? 1.0 : 0.0;

      // In grouped mode, inherit settings from the ancestor layer so that
      // dynamic properties (e.g. glassColor.alpha) flow correctly to the shader.
      // The `settings` field in AdaptiveGlass.grouped() is a const placeholder;
      // the real settings live in InheritedLiquidGlass.
      final baseSettings =
          (!useOwnLayer && inherited != null) ? inherited.settings : settings;

      // Apply subtle elevation boost to settings (preserves saturation!)
      final color = baseSettings.effectiveGlassColor;
      final effectiveSettings = shouldElevate
          ? LiquidGlassSettings(
              glassColor:
                  color.withValues(alpha: (color.a + 0.2).clamp(0.0, 1.0)),
              refractiveIndex: baseSettings.refractiveIndex,
              thickness: baseSettings.effectiveThickness,
              lightAngle: baseSettings.lightAngle,
              lightIntensity:
                  (baseSettings.effectiveLightIntensity * 1.2).clamp(0.0, 10.0),
              chromaticAberration: baseSettings.chromaticAberration,
              blur: baseSettings.effectiveBlur,
              visibility: baseSettings.visibility,
              saturation:
                  baseSettings.effectiveSaturation, // Preserve user saturation!
              ambientStrength:
                  (baseSettings.effectiveAmbientStrength * 0.4).clamp(0.0, 1.0),
            )
          : baseSettings;

      // PIPELINE HAND-OFF (The Secret Sauce)
      // If this is a container (allowElevation=false), we are providing a blur
      // for all our children to use. We update the InheritedLiquidGlass tree.
      if (!allowElevation) {
        return LightweightLiquidGlass(
          shape: shape,
          settings: effectiveSettings,
          densityFactor: 0.0, // Containers are never elevated
          glowIntensity: 0.0, // Containers don't glow
          child: InheritedLiquidGlass(
            settings: effectiveSettings,
            quality: quality,
            isBlurProvidedByAncestor: true,
            child: child,
          ),
        );
      }

      return LightweightLiquidGlass(
        shape: shape,
        settings: effectiveSettings,
        densityFactor: densityFactor, // 0.0 or 1.0 based on elevation
        glowIntensity: glowIntensity, // Pass through from button animation
        child: child,
      );
    }

    // Impeller + Premium Path: Use the renderer's native path
    if (useOwnLayer) {
      // Wrap in RepaintBoundary to give Impeller hints for tile-based rendering.
      // This allows Impeller to skip rasterizing unchanged tiles, improving
      // performance for static surfaces (app bars, bottom bars, etc.)
      return RepaintBoundary(
        child: LiquidGlass.withOwnLayer(
          shape: shape,
          settings: settings,
          clipBehavior: clipBehavior,
          child: child,
        ),
      );
    } else {
      return LiquidGlass.grouped(
        shape: shape,
        clipBehavior: clipBehavior,
        child: child,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// _FrostedFallback — IP1 accessibility degradation surface
//
// Replaces the full glass shader pipeline when "Reduce Transparency" (or its
// per-platform equivalent) is active. Fully cross-platform:
//   • iOS / macOS : ClipRRect + BackdropFilter are both supported
//   • Android     : BackdropFilter maps to RenderEffect blur (API 31+), Skia below
//   • Web         : BackdropFilter maps to CSS backdrop-filter (all major browsers)
//   • Windows     : Skia BlurImageFilter
//   • Linux       : Skia BlurImageFilter
//
// No GLSL shaders, no FragmentShader, no Impeller-specific paths.
// Result: a solid frosted panel with the glass tint color applied as a
// semi-opaque overlay — matching iOS 26's Reduce Transparency behaviour.
// ---------------------------------------------------------------------------
class _FrostedFallback extends StatelessWidget {
  const _FrostedFallback({
    required this.shape,
    required this.settings,
    required this.child,
    this.clipBehavior = Clip.antiAlias,
  });

  final LiquidShape shape;
  final LiquidGlassSettings settings;
  final Widget child;
  final Clip clipBehavior;

  // Resolve the corner radius from the shape for ClipRRect.
  // Only LiquidRoundedRectangle / LiquidRoundedSuperellipse carry a radius;
  // LiquidOval and other shapes fall back to 0 (ClipRRect acts as ClipRect).
  BorderRadius get _borderRadius {
    final r = switch (shape) {
      LiquidRoundedRectangle(:final borderRadius) => borderRadius,
      LiquidRoundedSuperellipse(:final borderRadius) => borderRadius,
      _ => 0.0,
    };
    return BorderRadius.circular(r);
  }

  @override
  Widget build(BuildContext context) {
    final blur = settings.effectiveBlur.clamp(1.0, 40.0);
    final tint = settings.effectiveGlassColor;

    // A neutral-to-tinted frosted overlay:
    //  • BackdropFilter provides the blur (same sigma as the normal glass blur)
    //  • The colored container gives a subtle tint that approximates the glass
    //    body color without any refraction or specular highlights
    //  • Opacity is intentionally higher than normal glass (0.55-0.70) to meet
    //    the intent of Reduce Transparency — less see-through, more legible
    final double frostedAlpha = (tint.a * 0.5 + 0.40).clamp(0.40, 0.80);
    final frostedColor = tint.withValues(alpha: frostedAlpha);

    return ClipRRect(
      borderRadius: _borderRadius,
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: frostedColor,
            borderRadius: _borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}
