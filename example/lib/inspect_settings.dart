import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  final settings = LiquidGlassSettings.figma(
    refraction: 60,
    depth: 80,
    dispersion: 100,
    frost: 2,
    lightAngle: -45,
    lightIntensity: 70,
    glassColor: Colors.white.withValues(alpha: .6),
  );

  debugPrint('Blur: ${settings.blur}');
  debugPrint('Thickness: ${settings.thickness}');
  debugPrint('Refractive Index: ${settings.refractiveIndex}');
  debugPrint('Chromatic Aberration: ${settings.chromaticAberration}');
  debugPrint('Light Intensity: ${settings.lightIntensity}');
  debugPrint('Ambient Strength: ${settings.ambientStrength}');
  debugPrint('Saturation: ${settings.saturation}');
  debugPrint('Light Angle: ${settings.lightAngle}');
  debugPrint('Glass Color: ${settings.glassColor}');
}
