import 'package:flutter/widgets.dart';
import '../../../src/renderer/liquid_glass_renderer.dart';

// =============================================================================
// kDefaultSheetSettings — shared glass preset for sheets
// =============================================================================

/// Default [LiquidGlassSettings] for both [GlassSheet] and [GlassModalSheet].
///
/// Centralised here so that all sheet types produce visually identical glass
/// following the Apple News / iOS 26 modal aesthetic:
/// - `thickness: 30` — deep surface feel.
/// - `blur: 2` — subtle background frosting.
/// - `refractiveIndex: 1.2` — standard glass refraction.
const kDefaultSheetSettings = LiquidGlassSettings(
  glassColor: Color(0xAA1C1C1E),
  thickness: 30.0,
  blur: 2.0,
  lightIntensity: 0.5,
  chromaticAberration: 0.01,
  refractiveIndex: 1.2,
  saturation: 1.2,
  ambientStrength: 0.0,
);
