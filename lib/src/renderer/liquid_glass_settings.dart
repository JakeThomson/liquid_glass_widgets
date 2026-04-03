import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
// [LOCAL PATCH]: GlassSpecularSharpness is our own type (not vendored).
// It lives in lib/types/ not lib/src/renderer/.
import '../../types/glass_specular_sharpness.dart';
import 'liquid_glass_renderer.dart';
import 'liquid_glass_render_scope.dart';

/// Represents the settings for a liquid glass effect.
class LiquidGlassSettings with EquatableMixin {
  /// Creates a new [LiquidGlassSettings] with the given settings.
  const LiquidGlassSettings({
    this.visibility = 1.0,
    this.glassColor = const Color.fromARGB(0, 255, 255, 255),
    this.thickness = 20,
    this.blur = 5,
    this.chromaticAberration = .01,
    this.lightAngle = 0.5 * pi,
    this.lightIntensity = .5,
    this.ambientStrength = 0,
    this.refractiveIndex = 1.2,
    this.saturation = 1.5,
    this.specularSharpness = GlassSpecularSharpness.medium,
  });

  /// Creates [LiquidGlassSettings] using Figma-inspired parameter names.
  ///
  /// **Important — units are not Figma percentages:**
  ///
  /// | Parameter | Range | Maps to |
  /// |-----------|-------|---------|
  /// | [refraction] | 0–100 % | [refractiveIndex] via `1 + (v/100) × 0.2` |
  /// | [depth] | logical pixels | [thickness] **directly** (not a Figma %) |
  /// | [dispersion] | 0–100 % | [chromaticAberration] via `4 × (v/100)` |
  /// | [frost] | logical pixels | [blur] **directly** (not a Figma %) |
  ///
  /// Figma's internal `depth` and `frost` use proprietary units with no public
  /// pixel-equivalent formula. Pass [depth] and [frost] as the logical-pixel
  /// values you want — typical ranges: depth 10–40, frost 2–8.
  LiquidGlassSettings.figma({
    required double refraction,
    required double depth,
    required double dispersion,
    required double frost,
    double visibility = 1.0,
    double lightIntensity = 50,
    double lightAngle = 0.5 * pi,
    Color glassColor = const Color.fromARGB(0, 255, 255, 255),
    GlassSpecularSharpness specularSharpness = GlassSpecularSharpness.medium,
  }) : this(
          visibility: visibility,
          refractiveIndex: 1 + (refraction / 100) * 0.2,
          thickness: depth,
          chromaticAberration: 4 * (dispersion / 100),
          lightIntensity: lightIntensity / 100,
          blur: frost,
          lightAngle: lightAngle,
          ambientStrength: 0.1,
          saturation: 1.5,
          glassColor: glassColor,
          specularSharpness: specularSharpness,
        );

  /// Retrieves the nearest [LiquidGlassSettings] from the widget tree.
  ///
  /// This will look for the nearest ancestor [LiquidGlassLayer] or
  /// [LiquidGlassRenderScope] widget in the widget tree.
  static LiquidGlassSettings of(BuildContext context) {
    return LiquidGlassRenderScope.of(context).settings;
  }

  /// A factor that can be used to scale all thickness-related properties.
  ///
  /// Defaults to 1.0.
  final double visibility;

  /// The color tint of the glass effect.
  ///
  /// Opacity defines the intensity of the tint.
  final Color glassColor;

  /// The effective glass color taking visibility into account.
  Color get effectiveGlassColor =>
      glassColor.withValues(alpha: glassColor.a * visibility);

  /// The thickness of the glass surface.
  ///
  /// Thicker surfaces refract the light more intensely.
  final double thickness;

  /// The effective thickness taking visibility into account.
  double get effectiveThickness => thickness * visibility;

  /// The blur of the glass effect.
  ///
  /// Higher values create a more frosted appearance.
  ///
  /// Defaults to 0.
  final double blur;

  /// The effective blur taking visibility into account.
  double get effectiveBlur => blur * visibility;

  /// The chromatic aberration of the glass effect (WIP).
  ///
  /// This is a little ugly still.
  ///
  /// Higher values create more pronounced color fringes.
  final double chromaticAberration;

  /// The effective chromatic aberration taking visibility into account.
  double get effectiveChromaticAberration => chromaticAberration * visibility;

  /// The angle of the light source in radians.
  ///
  /// This determines where the highlights on shapes will come from.
  final double lightAngle;

  /// The intensity of the light source.
  ///
  /// Higher values create more pronounced highlights.
  final double lightIntensity;

  /// The effective light intensity taking visibility into account.
  double get effectiveLightIntensity => lightIntensity * visibility;

  /// The strength of the ambient light.
  ///
  /// Higher values create more pronounced ambient light.
  final double ambientStrength;

  /// The effective ambient strength taking visibility into account.
  double get effectiveAmbientStrength => ambientStrength * visibility;

  /// The strength of the refraction.
  ///
  /// Higher values create more pronounced refraction.
  /// Defaults to 1.51
  final double refractiveIndex;

  /// The saturation adjustment for pixels that shine through the glass.
  ///
  /// 1.0 means no change, values < 1.0 desaturate the background,
  /// values > 1.0 increase saturation.
  /// Defaults to 1.0
  final double saturation;

  /// The sharpness of the specular highlight on the glass rim.
  ///
  /// Controls how tightly focused the specular lobe is. Each variant maps to
  /// a fixed power-of-2 exponent the shader computes with a zero-transcendental
  /// multiply chain — 3–5× faster than `pow()` on mobile GPUs.
  ///
  /// Defaults to [GlassSpecularSharpness.medium] which matches iOS 26.
  final GlassSpecularSharpness specularSharpness;

  /// The effective saturation taking visibility into account.
  double get effectiveSaturation => 1 + (saturation - 1) * visibility;

  /// Creates a new [LiquidGlassSettings] with the given settings.
  LiquidGlassSettings copyWith({
    double? visibility,
    Color? glassColor,
    double? thickness,
    double? blur,
    double? chromaticAberration,
    double? blend,
    double? lightAngle,
    double? lightIntensity,
    double? ambientStrength,
    double? refractiveIndex,
    double? saturation,
    GlassSpecularSharpness? specularSharpness,
  }) =>
      LiquidGlassSettings(
        visibility: visibility ?? this.visibility,
        glassColor: glassColor ?? this.glassColor,
        thickness: thickness ?? this.thickness,
        blur: blur ?? this.blur,
        chromaticAberration: chromaticAberration ?? this.chromaticAberration,
        lightAngle: lightAngle ?? this.lightAngle,
        lightIntensity: lightIntensity ?? this.lightIntensity,
        ambientStrength: ambientStrength ?? this.ambientStrength,
        refractiveIndex: refractiveIndex ?? this.refractiveIndex,
        saturation: saturation ?? this.saturation,
        specularSharpness: specularSharpness ?? this.specularSharpness,
      );

  @override
  List<Object?> get props => [
        visibility,
        glassColor,
        thickness,
        blur,
        chromaticAberration,
        lightAngle,
        lightIntensity,
        ambientStrength,
        refractiveIndex,
        saturation,
        specularSharpness,
      ];
}
