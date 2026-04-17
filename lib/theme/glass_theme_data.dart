import 'package:flutter/material.dart';
import '../src/renderer/liquid_glass_renderer.dart';

import '../types/glass_quality.dart';
import 'glass_theme_helpers.dart';

/// Color palette for glass glow effects.
///
/// Provides semantic colors for different interaction states and contexts.
/// Colors are used for glow effects on buttons, active states, and highlights.
@immutable
class GlassGlowColors {
  /// Creates a glow color palette.
  const GlassGlowColors({
    this.primary,
    this.secondary,
    this.success,
    this.warning,
    this.danger,
    this.info,
  });

  /// Primary brand color for default interactive elements
  final Color? primary;

  /// Secondary brand color for alternative actions
  final Color? secondary;

  /// Success state color (typically green)
  final Color? success;

  /// Warning state color (typically orange/yellow)
  final Color? warning;

  /// Danger/error state color (typically red)
  final Color? danger;

  /// Informational color (typically blue)
  final Color? info;

  /// Creates a copy with overridden values.
  GlassGlowColors copyWith({
    Color? primary,
    Color? secondary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return GlassGlowColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  /// Fallback glow colors with sensible defaults.
  ///
  /// The primary color is intentionally left null here so that
  /// [GlassThemeData.glowColorsFor] can substitute a brightness-aware warm
  /// specular highlight at runtime (more visible in light mode, more restrained
  /// in dark mode where the glass surface is already luminous).
  static const GlassGlowColors fallback = GlassGlowColors(
    // primary is null — resolved at runtime by glowColorsFor() based on
    // current brightness. See GlassThemeData.glowColorsFor.
    secondary: Color(0xFF5856D6), // iOS purple
    success: Color(0xFF34C759), // iOS green
    warning: Color(0xFFFF9500), // iOS orange
    danger: Color(0xFFFF3B30), // iOS red
    info: Color(0xFF5AC8FA), // iOS light blue
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlassGlowColors &&
          runtimeType == other.runtimeType &&
          primary == other.primary &&
          secondary == other.secondary &&
          success == other.success &&
          warning == other.warning &&
          danger == other.danger &&
          info == other.info;

  @override
  int get hashCode => Object.hash(
        primary,
        secondary,
        success,
        warning,
        danger,
        info,
      );
}

/// Theme configuration for a specific brightness (light or dark).
///
/// Contains all styling information for glass widgets in a single theme mode.
@immutable
class GlassThemeVariant {
  /// Creates a theme variant for light or dark mode.
  const GlassThemeVariant({
    this.settings,
    this.quality,
    this.glowColors,
  });

  /// Default glass visual settings for all widgets.
  ///
  /// Individual widgets can override this via their `settings` parameter.
  final LiquidGlassSettings? settings;

  /// Default rendering quality for all widgets.
  ///
  /// Individual widgets can override this via their `quality` parameter.
  final GlassQuality? quality;

  /// Semantic color palette for glow effects.
  final GlassGlowColors? glowColors;

  /// Creates a copy with overridden values.
  GlassThemeVariant copyWith({
    LiquidGlassSettings? settings,
    GlassQuality? quality,
    GlassGlowColors? glowColors,
  }) {
    return GlassThemeVariant(
      settings: settings ?? this.settings,
      quality: quality ?? this.quality,
      glowColors: glowColors ?? this.glowColors,
    );
  }

  /// Default light theme variant.
  static const GlassThemeVariant light = GlassThemeVariant(
    settings: LiquidGlassSettings(
      thickness: 30.0,
      blur: 3.0,
      glassColor:
          Color(0x32D2DCF0), // Cool blue-white tint for white backgrounds
      chromaticAberration: 0.5,
      refractiveIndex: 1.65,
      lightIntensity: 1.2,
      ambientStrength: 0.6,
      saturation: 1.2,
    ),
    quality: GlassQuality.standard,
    glowColors: GlassGlowColors.fallback,
  );

  /// Default dark theme variant.
  static const GlassThemeVariant dark = GlassThemeVariant(
    settings: LiquidGlassSettings(
      thickness: 40.0,
      blur: 5.0,
      lightIntensity: 1.5,
      refractiveIndex: 1.2,
      saturation: 1.1,
    ),
    quality: GlassQuality.standard,
    glowColors: GlassGlowColors.fallback,
  );

  /// Shader-free theme variant for maximum compatibility.
  ///
  /// All glass widgets in this subtree use [GlassQuality.minimal]: plain
  /// BackdropFilter blur with a tinted container. No fragment shaders,
  /// no texture capture, no specular effects.
  ///
  /// Use this as your global theme when targeting pre-iPhone 13 / pre-A15
  /// devices, or when the [GlassPerformanceMonitor] consistently warns about
  /// GPU budget overruns:
  ///
  /// ```dart
  /// GlassTheme(
  ///   data: GlassThemeData(
  ///     light: GlassThemeVariant.minimal,
  ///     dark: GlassThemeVariant.minimal,
  ///   ),
  ///   child: child!,
  /// )
  /// ```
  static const GlassThemeVariant minimal = GlassThemeVariant(
    settings: LiquidGlassSettings(
      thickness: 30.0,
      blur: 12.0,
      lightIntensity: 1.0,
    ),
    quality: GlassQuality.minimal,
    glowColors: GlassGlowColors.fallback,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlassThemeVariant &&
          runtimeType == other.runtimeType &&
          settings == other.settings &&
          quality == other.quality &&
          glowColors == other.glowColors;

  @override
  int get hashCode => Object.hash(settings, quality, glowColors);
}

/// Theme data for liquid glass widgets.
///
/// Provides centralized styling for all glass widgets in your app, with
/// automatic light/dark mode support based on [MediaQuery] brightness.
///
/// ## Usage
///
/// Wrap your app with [GlassTheme] to provide theme data:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData.light(),
///   darkTheme: ThemeData.dark(),
///   builder: (context, child) => GlassTheme(
///     data: GlassThemeData(
///       light: GlassThemeVariant(
///         settings: LiquidGlassSettings(thickness: 30, blur: 3),
///         quality: GlassQuality.standard,
///       ),
///       dark: GlassThemeVariant(
///         settings: LiquidGlassSettings(thickness: 40, blur: 5),
///         quality: GlassQuality.standard,
///       ),
///     ),
///     child: child!,
///   ),
/// )
/// ```
///
/// Access theme data in widgets:
///
/// ```dart
/// final theme = GlassThemeData.of(context);
/// final settings = theme.settings; // Automatically uses light/dark variant
/// ```
@immutable
class GlassThemeData {
  /// Creates glass theme data with separate light and dark configurations.
  const GlassThemeData({
    this.light = GlassThemeVariant.light,
    this.dark = GlassThemeVariant.dark,
  });

  /// Theme variant for light mode.
  final GlassThemeVariant light;

  /// Theme variant for dark mode.
  final GlassThemeVariant dark;

  /// Retrieves the theme data from the widget tree.
  ///
  /// Returns the current [GlassThemeData] from the nearest GlassTheme
  /// ancestor. If no theme is found, returns [GlassThemeData.fallback].
  static GlassThemeData of(BuildContext context) {
    return GlassThemeHelpers.of(context);
  }

  /// Retrieves the appropriate theme variant based on current brightness.
  ///
  /// Automatically selects light or dark variant based on [MediaQuery]
  /// brightness. Individual widgets can use this to get theme-aware settings.
  GlassThemeVariant variantFor(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.dark ? dark : light;
  }

  /// Gets glass settings for current brightness.
  LiquidGlassSettings? settingsFor(BuildContext context) {
    return variantFor(context).settings;
  }

  /// Gets rendering quality for current brightness.
  GlassQuality? qualityFor(BuildContext context) {
    return variantFor(context).quality;
  }

  /// Gets glow colors for current brightness.
  ///
  /// If the caller has not set an explicit [GlassGlowColors.primary], this
  /// method substitutes a brightness-aware neutral white specular highlight
  /// matching the iOS 26 press feedback model. iOS 26 glass surfaces produce
  /// a bright, grey-white highlight on interaction — like light diffracting
  /// through frosted glass — not a colored or dim tint.
  ///
  /// Opacity is higher in light mode (glass is more transparent, highlight
  /// needs more presence) and slightly lower in dark mode (the glass surface
  /// is already luminous from the dark blurred background).
  GlassGlowColors glowColorsFor(BuildContext context) {
    final colors = variantFor(context).glowColors ?? GlassGlowColors.fallback;

    // Only inject the adaptive primary when the caller has not provided one.
    if (colors.primary != null) return colors;

    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    // 0x59 = ~35% opacity in light mode; 0x38 = ~22% opacity in dark mode.
    // Pure neutral white (0xFFFFFF) — iOS 26 highlights are bright and grey-white,
    // not warm or tinted. The BlendMode.plus compositing in GlassGlowLayer keeps
    // this from blowing out even at higher opacity values.
    final adaptivePrimary =
        isDark ? const Color(0x38FFFFFF) : const Color(0x59FFFFFF);

    return colors.copyWith(primary: adaptivePrimary);
  }

  /// Creates a copy with overridden values.
  GlassThemeData copyWith({
    GlassThemeVariant? light,
    GlassThemeVariant? dark,
  }) {
    return GlassThemeData(
      light: light ?? this.light,
      dark: dark ?? this.dark,
    );
  }

  /// Default fallback theme when no [GlassTheme] is present in widget tree.
  factory GlassThemeData.fallback() {
    return const GlassThemeData(
      light: GlassThemeVariant.light,
      dark: GlassThemeVariant.dark,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlassThemeData &&
          runtimeType == other.runtimeType &&
          light == other.light &&
          dark == other.dark;

  @override
  int get hashCode => Object.hash(light, dark);
}
