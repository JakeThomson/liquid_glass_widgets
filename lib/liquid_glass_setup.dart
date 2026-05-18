import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'theme/glass_theme.dart';
import 'theme/glass_theme_data.dart';
import 'types/glass_quality.dart';
import 'utils/accessibility_config.dart' as glass_config;
import 'utils/glass_performance_monitor.dart';
import 'src/renderer/liquid_glass_renderer.dart';
import 'widgets/shared/glass_backdrop_scope.dart';
import 'widgets/shared/glass_adaptive_scope.dart';
import 'widgets/shared/glass_effect.dart';
import 'widgets/shared/glass_accessibility_scope.dart';
import 'widgets/shared/lightweight_liquid_glass.dart';

/// Entry point and configuration for the Liquid Glass Widgets library.
///
/// ## Setup
///
/// Two async steps, then one builder:
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await LiquidGlassWidgets.initialize(); // pre-warms shaders
///
///   runApp(MaterialApp(
///     home: const MyHomePage(),
///     // One line installs accessibility, adaptive quality, and global theme:
///     builder: LiquidGlassWidgets.appBuilder(
///       adaptiveQuality: true,
///       theme: GlassThemeData(
///         light: GlassThemeVariant(settings: GlassThemeSettings(blur: 10)),
///         dark:  GlassThemeVariant(settings: GlassThemeSettings(blur: 14)),
///       ),
///     ),
///   ));
/// }
/// ```
///
/// Use [wrap] for advanced cases where you need control over the widget tree
/// above `MaterialApp` — e.g. a custom app widget that does not use
/// `MaterialApp` at all.
class LiquidGlassWidgets {
  LiquidGlassWidgets._();

  // ── Global accessors ───────────────────────────────────────────────────────

  /// Whether glass widgets automatically respect system accessibility settings
  /// (Reduce Motion, Reduce Transparency / High Contrast).
  ///
  /// Set via [wrap]. Defaults to `true`. Read by glass widgets at build time
  /// via [GlassAccessibilityScope] or a direct [MediaQuery] fallback.
  ///
  /// The setter is provided as an escape hatch for tests and advanced runtime
  /// overrides. In production code, prefer setting this through [wrap].
  static bool get respectSystemAccessibility =>
      glass_config.respectSystemAccessibility;
  static set respectSystemAccessibility(bool value) =>
      glass_config.respectSystemAccessibility = value;

  /// Deprecated — use [respectSystemAccessibility] instead.
  ///
  /// Retained for discoverability (the two-word form reads naturally as a
  /// boolean predicate). Will be removed in v1.0.
  @Deprecated('Use respectSystemAccessibility instead.')
  static bool get respectsAccessibility => respectSystemAccessibility;
  @Deprecated('Use respectSystemAccessibility instead.')
  static set respectsAccessibility(bool value) =>
      respectSystemAccessibility = value;

  /// Global [LiquidGlassSettings] override for the entire application.
  ///
  /// When set, these settings are used as the base for all glass widgets
  /// unless overridden at the widget or layer level.
  static LiquidGlassSettings? globalSettings;

  // ── initialize() ───────────────────────────────────────────────────────────

  /// Initializes platform-level resources for the Liquid Glass library.
  ///
  /// **Responsibility**: async platform / engine setup only. Call once in
  /// `main()` before [runApp]. All behavioral configuration belongs in [wrap].
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await LiquidGlassWidgets.initialize();
  ///   runApp(LiquidGlassWidgets.wrap(const MyApp()));
  /// }
  /// ```
  ///
  /// ### Parameters
  ///
  /// **`enablePerformanceMonitor`** (default `true`)\
  /// In debug and profile builds, the library registers a
  /// `SchedulerBinding.addTimingsCallback` that watches raster durations while
  /// [GlassQuality.premium] surfaces are mounted. When frames consistently
  /// exceed the GPU budget, a single [FlutterError] is emitted with actionable
  /// guidance. The monitor is **automatically disabled in release builds** —
  /// zero overhead in shipped apps. Set to `false` to suppress it during
  /// profiling sessions where the warning would be a false positive.
  ///
  /// ### Tasks performed
  ///
  /// 1. Pre-warms / precaches the lightweight fragment shader.
  /// 2. Pre-warms the interactive indicator shader (custom refraction).
  /// 3. Pre-warms the Impeller rendering pipeline (iOS / Android / macOS).
  /// 4. Optionally registers the debug performance monitor.
  static Future<void> initialize({
    bool enablePerformanceMonitor = true,
  }) async {
    debugPrint('[LiquidGlass] Initializing library...');

    // 1. Pre-warm shaders — prevents the "white flash" on first render.
    await Future.wait([
      LightweightLiquidGlass.preWarm(),
      GlassEffect.preWarm(),
      _warmUpImpellerPipeline(),
    ]);

    // 2. Register the debug performance monitor (no-op in release builds).
    if (enablePerformanceMonitor && !kReleaseMode) {
      GlassPerformanceMonitor.start();
    }

    debugPrint('[LiquidGlass] Initialization complete.');
  }

  // ── wrap() ─────────────────────────────────────────────────────────────────

  /// Wraps [child] in the Liquid Glass infrastructure scopes and applies all
  /// behavioral configuration.
  ///
  /// **Responsibility**: widget-tree composition and runtime behavior. All
  /// configuration that affects how glass widgets behave lives here — explicit,
  /// visible, and co-located with the widget tree entry point.
  ///
  /// **Always call this** — at minimum it installs [GlassBackdropScope], which
  /// allows glass surfaces to share a single GPU backdrop capture and roughly
  /// halves blit cost when multiple glass widgets are visible simultaneously.
  ///
  /// ```dart
  /// // Zero-config (most apps):
  /// runApp(LiquidGlassWidgets.wrap(const MyApp()));
  ///
  /// // Recommended for Android / broad device support:
  /// runApp(LiquidGlassWidgets.wrap(
  ///   const MyApp(),
  ///   adaptiveQuality: true,
  /// ));
  ///
  /// // Game / experience — bypass accessibility, conservative quality start:
  /// runApp(LiquidGlassWidgets.wrap(
  ///   const MyApp(),
  ///   respectSystemAccessibility: false,
  ///   adaptiveQuality: true,
  ///   adaptiveConfig: GlassAdaptiveScopeConfig(
  ///     initialQuality: GlassQuality.standard,
  ///     allowStepUp: true,
  ///   ),
  /// ));
  /// ```
  ///
  /// ### Parameters
  ///
  /// **`respectSystemAccessibility`** (default `true`)\
  /// When `true`, system Reduce Motion and Reduce Transparency flags are
  /// respected automatically — no extra setup required. All glass widgets read
  /// `MediaQuery` directly and degrade gracefully. Set to `false` to ignore
  /// system accessibility flags globally (e.g. for a game where full glass
  /// fidelity is intentional regardless of OS settings). A
  /// [GlassAccessibilityScope] placed anywhere in the widget tree always takes
  /// precedence over this flag, allowing per-subtree overrides.
  ///
  /// **`adaptiveQuality`** (default `false`, **experimental**)\
  /// When `true`, inserts a root [GlassAdaptiveScope] that automatically
  /// benchmarks the device and adjusts the global glass quality ceiling in real
  /// time. Three phases:
  ///
  /// - **Phase 1** (synchronous): forces `minimal` where shaders are
  ///   unsupported; caps at `standard` on web.
  /// - **Phase 2** (~180 frames ≈ 3 s at 60 fps): measures real P75 raster
  ///   durations and sets the initial quality tier.
  /// - **Phase 3** (ongoing, near-zero overhead): degrades when P95 exceeds
  ///   1.5× the frame budget for 3 consecutive windows; recovers when P95
  ///   drops below 0.6× budget for 10 consecutive windows.
  ///
  /// **Experimental in 0.8.0** — Phase 2 thresholds (12 ms / 20 ms P75) are
  /// based on reasoning, not yet validated across the full Android device
  /// landscape. Enable this feature and report unexpected quality degradation
  /// or promotion to help us tune the thresholds.
  ///
  /// Acts as an app-wide *quality ceiling* — individual widgets with an
  /// explicit `quality:` parameter are still capped by it. When no
  /// [adaptiveConfig] is provided, the scope starts at [GlassQuality.standard]
  /// to prevent jank during the warm-up window on mid-range devices.
  ///
  /// For per-screen control, use [GlassAdaptiveScope] directly in the tree.

  ///
  /// **`adaptiveConfig`** (optional)\
  /// Custom [GlassAdaptiveScopeConfig] for the root [GlassAdaptiveScope].
  /// Ignored when [adaptiveQuality] is `false`. Defaults to
  /// `GlassAdaptiveScopeConfig(initialQuality: GlassQuality.standard)`.
  ///
  /// ### Scope nesting order (outermost → innermost → child)
  ///
  /// `GlassAdaptiveScope` (when enabled) → `GlassBackdropScope` → `child`
  static Widget wrap({
    required Widget child,
    bool respectSystemAccessibility = true,
    bool adaptiveQuality = false,
    GlassAdaptiveScopeConfig? adaptiveConfig,
  }) {
    // Apply global accessibility preference.
    glass_config.respectSystemAccessibility = respectSystemAccessibility;

    Widget result = GlassBackdropScope(child: child);

    if (adaptiveQuality) {
      // When no adaptiveConfig is given: GlassAdaptiveScope.initState() seeds
      // the first frame at GlassQuality.standard while Phase 2 benchmarks the
      // device (~3 s). Phase 2 then promotes to `premium` if the device passes
      // the warmup threshold — no caller config needed.
      //
      // When the caller provides adaptiveConfig: use their settings as-is.
      // If initialQuality is null, Phase 2 still runs fresh and promotes/demotes
      // from the conservative standard starting point.
      final config = adaptiveConfig ?? const GlassAdaptiveScopeConfig();

      result = GlassAdaptiveScope(
        minQuality: config.minQuality,
        maxQuality: config.maxQuality,
        initialQuality: config.initialQuality,
        targetFrameMs: config.targetFrameMs,
        allowStepUp: config.allowStepUp,
        onQualityChanged: config.onQualityChanged,
        onDiagnostic: config.onDiagnostic,
        debugLogDiagnostics: config.debugLogDiagnostics,
        child: result,
      );
    }

    return result;
  }

  // ── appBuilder() ───────────────────────────────────────────────────────────

  /// Returns a [TransitionBuilder] for use in `MaterialApp.builder` that
  /// installs the complete Liquid Glass infrastructure **inside** the
  /// `MaterialApp` context.
  ///
  /// This is the **recommended setup for most apps**. Placing the scopes inside
  /// `MaterialApp.builder` (rather than above `MaterialApp` via [wrap]) gives
  /// them access to `MediaQuery` from the very first frame — meaning
  /// accessibility preferences (Reduce Motion, Reduce Transparency) and the
  /// adaptive quality benchmark are both read correctly on startup.
  ///
  /// ## What it installs (outermost → innermost)
  ///
  /// 1. **[GlassBackdropScope]** — root backdrop isolation; prevents ghosting
  ///    during navigation transitions.
  /// 2. **[GlassAdaptiveScope]** (when `adaptiveQuality: true`) — benchmarks
  ///    the device and applies a global quality ceiling automatically.
  /// 3. **[GlassAccessibilityScope]** — reads Reduce Motion / Reduce
  ///    Transparency from `MediaQuery` once and propagates down the tree,
  ///    eliminating per-widget lookups.
  /// 4. **[GlassTheme]** (when `theme` is provided) — makes your global glass
  ///    theme available to every widget below without any manual tree nesting.
  ///
  /// ## Recommended usage
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await LiquidGlassWidgets.initialize();
  ///
  ///   runApp(MaterialApp(
  ///     home: const MyHomePage(),
  ///     builder: LiquidGlassWidgets.appBuilder(
  ///       adaptiveQuality: true,
  ///       theme: GlassThemeData(
  ///         light: GlassThemeVariant(
  ///           settings: GlassThemeSettings(blur: 10, thickness: 30),
  ///         ),
  ///         dark: GlassThemeVariant(
  ///           settings: GlassThemeSettings(blur: 14, thickness: 40),
  ///         ),
  ///       ),
  ///     ),
  ///   ));
  /// }
  /// ```
  ///
  /// ## Composing with an existing builder
  ///
  /// If you already use `MaterialApp.builder` for another purpose (e.g.
  /// `flutter_screenutil`), compose manually:
  ///
  /// ```dart
  /// MaterialApp(
  ///   builder: (context, child) {
  ///     // Your existing builder wraps LiquidGlass:
  ///     final glassChild = LiquidGlassWidgets.appBuilder()(
  ///       context, child,
  ///     );
  ///     return ScreenUtilInit(child: glassChild);
  ///   },
  /// )
  /// ```
  ///
  /// ## Parameters
  ///
  /// All parameters are identical in meaning to those on [wrap]. See [wrap] for
  /// full documentation of `adaptiveQuality`, `adaptiveConfig`, and
  /// `respectSystemAccessibility`.
  static TransitionBuilder appBuilder({
    GlassThemeData? theme,
    bool respectSystemAccessibility = true,
    bool adaptiveQuality = false,
    GlassAdaptiveScopeConfig? adaptiveConfig,
  }) {
    // Apply global accessibility preference synchronously — this mirrors the
    // behaviour of wrap() so the two methods are equivalent in that regard.
    glass_config.respectSystemAccessibility = respectSystemAccessibility;

    return (BuildContext context, Widget? child) {
      // child is the full app widget tree produced by MaterialApp (Navigator,
      // routes, overlays). We must never drop it.
      Widget result = child ?? const SizedBox.shrink();

      // 4. Innermost scope: GlassTheme (optional).
      // Placed deepest so it can read the MediaQuery available inside builder.
      if (theme != null) {
        result = GlassTheme(data: theme, child: result);
      }

      // 3. GlassAccessibilityScope — reads Reduce Motion / High Contrast from
      // MediaQuery once per rebuild and propagates via InheritedWidget,
      // eliminating per-widget MediaQuery lookups.
      result = GlassAccessibilityScope(child: result);

      // 2. GlassAdaptiveScope — optional quality ceiling + benchmarking.
      if (adaptiveQuality) {
        final config = adaptiveConfig ?? const GlassAdaptiveScopeConfig();
        result = GlassAdaptiveScope(
          minQuality: config.minQuality,
          maxQuality: config.maxQuality,
          initialQuality: config.initialQuality,
          targetFrameMs: config.targetFrameMs,
          allowStepUp: config.allowStepUp,
          onQualityChanged: config.onQualityChanged,
          onDiagnostic: config.onDiagnostic,
          debugLogDiagnostics: config.debugLogDiagnostics,
          child: result,
        );
      }

      // 1. Outermost scope: GlassBackdropScope — root backdrop group that
      // prevents navigation-transition ghosting across all routes.
      result = GlassBackdropScope(child: result);

      return result;
    };
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Warms up the Impeller rendering pipeline for glass effects.
  ///
  /// Instantiates a minimal [LiquidGlassLayer] to trigger Impeller pipeline
  /// compilation — eliminating first-frame jank when glass effects appear.
  /// Skipped on Skia / Web where Impeller is not active.
  static Future<void> _warmUpImpellerPipeline() async {
    if (!ui.ImageFilter.isShaderFilterSupported) {
      debugPrint('[LiquidGlass] Skipping Impeller warm-up (Skia/Web detected)');
      return;
    }

    try {
      const warmUpSettings = LiquidGlassSettings(
        blur: 3,
        thickness: 30,
        refractiveIndex: 1.5,
      );

      // Instantiating the layer triggers Impeller pipeline compilation.
      // We don't need to render it.
      final _ = LiquidGlassLayer(
        settings: warmUpSettings,
        child: const SizedBox.shrink(),
      );

      // Brief delay to allow pipeline compilation to complete.
      await Future.delayed(const Duration(milliseconds: 16));

      debugPrint('[LiquidGlass] ✓ Impeller pipeline warmed up');
    } catch (e) {
      debugPrint('[LiquidGlass] Impeller warm-up failed (non-critical): $e');
    }
  }
}
