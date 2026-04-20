// ---------------------------------------------------------------------------
// GlassAdaptiveScope — v0.8.0
//
// Wraps any subtree and automatically adjusts GlassQuality based on real
// raster performance observed from SchedulerBinding frame timings.
//
// ## Three-phase adaptation
//
// Phase 1 — Static probe (synchronous, at scope mount):
//   Tests hard device capabilities. Forces minimal on software renderers and
//   broken shader drivers (ImageFilter.isShaderFilterSupported == false).
//   Caps at standard on web (kIsWeb).
//
// Phase 2 — Warm-up benchmark (first 180 frames ≈ 3 s at 60 fps):
//   Collects raster durations and computes P75 to estimate the device baseline.
//   P75 < 12 ms  → start at maxQuality (premium by default)
//   P75 12–20 ms → step to standard
//   P75 > 20 ms  → step to minimal
//
// Phase 3 — Runtime hysteresis (ongoing, very low overhead):
//   Degrades quality when P95 > targetFrameMs × 1.5 for 3 consecutive windows.
//   Upgrades quality (if allowStepUp) when P95 < targetFrameMs × 0.6
//   for 10 consecutive windows. Hard 8-second cooldown between any change.
//   Degradation is 3× faster than recovery — jank is noticed immediately;
//   recovery should be invisible and stable.
//
// ## Key design constraint
//
// GlassAdaptiveScope acts as a **quality ceiling**, not a floor.
// A widget that explicitly requests GlassQuality.minimal will not be upgraded
// to standard even when the scope is at premium. A widget that requests
// premium will be silently capped to standard if the scope has stepped down
// to standard.
//
// This ceiling is enforced by GlassThemeHelpers.resolveQuality, which reads
// GlassAdaptiveScopeData.maybeOf(context) after resolving the widget-level
// and inherited qualities.
//
// Widgets with an **explicit** quality parameter are not affected — the
// resolution chain handles this: the explicit param is resolved before the
// adaptive cap is applied. (That is intentional — the developer's explicit
// override wins.)
//
// ## Debug / Profile builds
//
// In debug and profile builds, GlassPerformanceMonitor continues to run
// alongside GlassAdaptiveScope. The monitor emits developer warnings; the
// scope acts on them. They share SchedulerBinding's callback list — Flutter
// handles multiple listeners correctly.
//
// ## Usage
//
// ```dart
// // Minimal — zero config, sensible defaults
// GlassAdaptiveScope(
//   child: MaterialApp(...),
// )
//
// // Advanced — full control
// GlassAdaptiveScope(
//   minQuality: GlassQuality.standard,  // never go below standard
//   maxQuality: GlassQuality.premium,
//   targetFrameMs: 8,                   // 120 Hz ProMotion target
//   allowStepUp: true,                  // allow recovery after throttle
//   onQualityChanged: (from, to) {
//     analytics.log('glass_quality', {'from': from.name, 'to': to.name});
//   },
//   child: child,
// )
//
// // Read from any descendant
// final quality = GlassAdaptiveScopeData.of(context).effectiveQuality;
// ```
// ---------------------------------------------------------------------------

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../../utils/glass_quality_adapter.dart';
import '../../types/glass_quality.dart';

// ---------------------------------------------------------------------------
// GlassAdaptiveScopeData — immutable data carried by the InheritedWidget
// ---------------------------------------------------------------------------

/// Data propagated by [GlassAdaptiveScope] to all glass widgets below it.
///
/// Obtain via [GlassAdaptiveScopeData.of] or [GlassAdaptiveScopeData.maybeOf].
@immutable
class GlassAdaptiveScopeData {
  /// Creates [GlassAdaptiveScopeData].
  const GlassAdaptiveScopeData({
    required this.effectiveQuality,
    required this.phase,
  });

  /// The current quality ceiling enforced by the scope.
  ///
  /// All glass widgets that inherit quality (those without an explicit
  /// `quality:` parameter) will be capped at this level via
  /// [GlassThemeHelpers.resolveQuality].
  final GlassQuality effectiveQuality;

  /// The current adaptation phase (probe → warmup → runtime).
  ///
  /// Useful for analytics or development UIs. Widgets should not change their
  /// behaviour based on this value.
  final AdaptivePhase phase;

  /// Returns the nearest [GlassAdaptiveScopeData] from the widget tree.
  ///
  /// Throws a [FlutterError] if no [GlassAdaptiveScope] ancestor is found.
  /// Use [maybeOf] in contexts where the scope may not be present.
  static GlassAdaptiveScopeData of(BuildContext context) {
    final data = maybeOf(context);
    assert(
      data != null,
      'GlassAdaptiveScopeData.of() was called on a context that does not have '
      'a GlassAdaptiveScope ancestor. Make sure GlassAdaptiveScope is placed '
      'above this widget in the tree.',
    );
    return data!;
  }

  /// Returns the nearest [GlassAdaptiveScopeData], or `null` if not found.
  ///
  /// Glass widgets use this variant internally — if no scope is present, the
  /// normal quality resolution chain runs unchanged.
  static GlassAdaptiveScopeData? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_InheritedAdaptiveQuality>()
        ?.data;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlassAdaptiveScopeData &&
          runtimeType == other.runtimeType &&
          effectiveQuality == other.effectiveQuality &&
          phase == other.phase;

  @override
  int get hashCode => Object.hash(effectiveQuality, phase);

  @override
  String toString() =>
      'GlassAdaptiveScopeData(quality: $effectiveQuality, phase: $phase)';
}

// ---------------------------------------------------------------------------
// GlassAdaptiveScopeConfig — bundled configuration value object
// ---------------------------------------------------------------------------

/// Bundles all [GlassAdaptiveScope] configuration into a single, portable
/// value object.
///
/// **Experimental** — this API is available in 0.8.0 for community feedback.
/// Phase 2 timing thresholds (12 ms / 20 ms P75) have been validated by
/// reasoning but not yet by broad real-device data. If you observe unexpected
/// quality degradation or promotion, please file an issue with your device
/// model, raster timings (from Flutter DevTools), and the quality tier you
/// expected vs received.
///
/// Use this when passing scope configuration through an API that cannot
/// accept individual widget parameters directly — e.g. [LiquidGlassWidgets.wrap]:
///
/// ```dart
/// runApp(LiquidGlassWidgets.wrap(
///   const MyApp(),
///   adaptiveQuality: true,
///   adaptiveConfig: GlassAdaptiveScopeConfig(
///     initialQuality: GlassQuality.standard, // earn your way up to premium
///     allowStepUp: true,
///   ),
/// ));
/// ```
///
/// All fields mirror the corresponding parameters on [GlassAdaptiveScope].
@experimental
@immutable
class GlassAdaptiveScopeConfig {
  /// Creates a [GlassAdaptiveScopeConfig] with sensible defaults.
  const GlassAdaptiveScopeConfig({
    this.minQuality = GlassQuality.minimal,
    this.maxQuality = GlassQuality.premium,
    this.initialQuality,
    this.targetFrameMs = 16,
    this.allowStepUp = false,
    this.onQualityChanged,
  });

  /// The lowest quality tier the scope will ever enforce.
  /// Defaults to [GlassQuality.minimal].
  final GlassQuality minQuality;

  /// The highest quality tier the scope may use.
  /// Defaults to [GlassQuality.premium].
  final GlassQuality maxQuality;

  /// The quality to display before the warm-up benchmark completes.
  /// When null (the default), [maxQuality] is used.
  final GlassQuality? initialQuality;

  /// The raster frame duration target in milliseconds. Defaults to `16` (60 fps).
  final int targetFrameMs;

  /// When `true`, the scope may step quality up after sustained good performance.
  /// Defaults to `false`.
  final bool allowStepUp;

  /// Called whenever the effective quality tier changes.
  final void Function(GlassQuality from, GlassQuality to)? onQualityChanged;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlassAdaptiveScopeConfig &&
          runtimeType == other.runtimeType &&
          minQuality == other.minQuality &&
          maxQuality == other.maxQuality &&
          initialQuality == other.initialQuality &&
          targetFrameMs == other.targetFrameMs &&
          allowStepUp == other.allowStepUp;

  @override
  int get hashCode => Object.hash(
        minQuality,
        maxQuality,
        initialQuality,
        targetFrameMs,
        allowStepUp,
      );
}

// ---------------------------------------------------------------------------
// GlassAdaptiveScope — public widget
// ---------------------------------------------------------------------------

/// Automatically adjusts [GlassQuality] for its subtree based on real device
/// raster performance, handling three scenarios developers can't easily test:
///
/// - **Broken/slow shader drivers** (Pixel 4a, Galaxy A22 class devices):
///   detected in Phase 1 (static probe) and capped immediately.
/// - **Warm-up jank** ("wrong quality at startup"):
///   resolved by Phase 2 benchmark over the first 180 frames.
/// - **Thermal throttling** ("fine at launch, janky after 10 minutes"):
///   detected and corrected by Phase 3 runtime hysteresis.
///
/// The scope acts as a **quality ceiling** — it only caps inherited quality,
/// never overrides explicit `quality:` widget parameters. See the file-level
/// documentation for the complete architecture description.
///
/// **Experimental** — available in 0.8.0 for community feedback. The Phase 2
/// timing thresholds (P75 < 12 ms → premium, 12–20 ms → standard, > 20 ms →
/// minimal) have been validated by reasoning but not yet by broad real-device
/// data across the Android fragmentation landscape. If you observe unexpected
/// behaviour, please file an issue with your device model and raster timings.
///
/// ```dart
/// GlassAdaptiveScope(
///   child: MaterialApp(home: MyHome()),
/// )
/// ```
@experimental
class GlassAdaptiveScope extends StatefulWidget {
  /// Creates a [GlassAdaptiveScope].
  ///
  /// [child] is required. All other parameters have sensible defaults.
  const GlassAdaptiveScope({
    required this.child,
    this.minQuality = GlassQuality.minimal,
    this.maxQuality = GlassQuality.premium,
    this.initialQuality,
    this.targetFrameMs = 16,
    this.allowStepUp = false,
    this.onQualityChanged,
    super.key,
  });

  /// The widget subtree that will have its glass quality automatically managed.
  final Widget child;

  /// The lowest quality tier the scope will ever enforce.
  ///
  /// Widgets in the subtree will never be capped lower than this value.
  /// Defaults to [GlassQuality.minimal] (allow full degradation to
  /// shader-free BackdropFilter mode).
  final GlassQuality minQuality;

  /// The highest quality tier the scope may use.
  ///
  /// The Phase 2 warm-up benchmark respects this ceiling — even on a fast
  /// device, quality will not exceed [maxQuality].
  /// Defaults to [GlassQuality.premium].
  final GlassQuality maxQuality;

  /// The quality to start at, skipping Phase 2 (the warm-up benchmark).
  ///
  /// When non-null, the adapter jumps directly to Phase 3 (runtime hysteresis)
  /// using this quality as the starting point — eliminating the ~3-second
  /// warm-up jank window on repeat launches.
  ///
  /// **Use this to restore a persisted quality across cold starts:**
  ///
  /// ```dart
  /// // In main.dart — persist settled quality to SharedPreferences:
  /// final prefs = await SharedPreferences.getInstance();
  /// final saved = prefs.getString('glass_quality');
  /// final initial = saved != null
  ///     ? GlassQuality.values.byName(saved)
  ///     : null; // null = run Phase 2 on first launch
  ///
  /// runApp(LiquidGlassWidgets.wrap(
  ///   const MyApp(),
  ///   adaptiveQuality: true,
  ///   adaptiveConfig: GlassAdaptiveScopeConfig(
  ///     initialQuality: initial,
  ///     allowStepUp: true,
  ///     onQualityChanged: (_, to) => prefs.setString('glass_quality', to.name),
  ///   ),
  /// ));
  /// ```
  ///
  /// Within a single app process, [GlassQualityAdapter._sessionSettledQuality]
  /// also auto-skips Phase 2 on remounts — no extra code required.
  final GlassQuality? initialQuality;

  /// The raster frame duration target in milliseconds.
  ///
  /// Used as the reference for Phase 3 thresholds:
  ///   - Degrade when P95 > [targetFrameMs] × 1.5
  ///   - Upgrade when P95 < [targetFrameMs] × 0.6 (if [allowStepUp])
  ///
  /// Set to `8` for 120 Hz ProMotion displays.
  /// Defaults to `16` (60 fps budget).
  final int targetFrameMs;

  /// When `true`, the scope may step quality **up** to [maxQuality] after a
  /// sustained period of good performance (e.g. after thermal recovery).
  ///
  /// Defaults to `false`. Step-up uses a 10-window window (≈ 20 seconds) plus
  /// an 8-second cooldown to prevent oscillation. Even with `allowStepUp: true`
  /// the transition is very slow — users should not perceive any flicker.
  final bool allowStepUp;

  /// Called on the main thread whenever the effective quality changes.
  ///
  /// Receives `(GlassQuality from, GlassQuality to)`. Useful for analytics:
  /// ```dart
  /// onQualityChanged: (from, to) {
  ///   analytics.log('glass_quality', {'from': from.name, 'to': to.name});
  /// },
  /// ```
  final void Function(GlassQuality from, GlassQuality to)? onQualityChanged;

  @override
  State<GlassAdaptiveScope> createState() => _GlassAdaptiveScopeState();
}

class _GlassAdaptiveScopeState extends State<GlassAdaptiveScope>
    with WidgetsBindingObserver {
  late GlassQualityAdapter _adapter;
  late GlassQuality _effectiveQuality;

  @override
  void initState() {
    super.initState();
    // Seed _effectiveQuality using the same source priority the adapter will
    // use in start(): developer-provided initialQuality beats session cache
    // beats maxQuality. Doing this before creating and starting the adapter
    // ensures the very first rendered frame shows the correct quality and
    // there is no one-frame flash from maxQuality to a cached lower value.
    _effectiveQuality = widget.initialQuality ??
        GlassQualityAdapter.sessionSettledQuality ??
        widget.maxQuality;
    _createAdapter();
    WidgetsBinding.instance.addObserver(this);
    _adapter.start();
  }

  @override
  void didUpdateWidget(GlassAdaptiveScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recreate the adapter if configuration changed.
    if (oldWidget.minQuality != widget.minQuality ||
        oldWidget.maxQuality != widget.maxQuality ||
        oldWidget.targetFrameMs != widget.targetFrameMs ||
        oldWidget.allowStepUp != widget.allowStepUp) {
      _adapter.stop();
      // Mirror the same seeding logic as initState to avoid a one-frame flash.
      _effectiveQuality = widget.initialQuality ??
          GlassQualityAdapter.sessionSettledQuality ??
          widget.maxQuality;
      _createAdapter();
      _adapter.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adapter.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On resume, reset the benchmark so thermal recovery is detected.
    // The adapter re-runs Phase 2 from a clean slate while preserving the
    // current quality until the new benchmark completes.
    if (state == AppLifecycleState.resumed) {
      _adapter.reset();
    }
  }

  void _createAdapter() {
    _adapter = GlassQualityAdapter(
      minQuality: widget.minQuality,
      maxQuality: widget.maxQuality,
      targetFrameMs: widget.targetFrameMs,
      allowStepUp: widget.allowStepUp,
      initialQuality: widget.initialQuality,
      onQualityChanged: _onQualityChanged,
    );
  }

  void _onQualityChanged(GlassQuality from, GlassQuality to) {
    // Defer the setState to after the next frame draw to avoid causing the very
    // frame drop we are trying to fix. addPostFrameCallback is properly
    // drained in widget tests (unlike scheduleTask).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _effectiveQuality = to);
      widget.onQualityChanged?.call(from, to);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedAdaptiveQuality(
      data: GlassAdaptiveScopeData(
        effectiveQuality: _effectiveQuality,
        phase: _adapter.phase,
      ),
      child: widget.child,
    );
  }

  /// Exposes the adapter for widget-level testing.
  @visibleForTesting
  GlassQualityAdapter get adapter => _adapter;
}

// ---------------------------------------------------------------------------
// _InheritedAdaptiveQuality — internal InheritedWidget
// ---------------------------------------------------------------------------

/// Internal [InheritedWidget] that carries [GlassAdaptiveScopeData] down the
/// tree. Not exported — access only via [GlassAdaptiveScopeData.of].
class _InheritedAdaptiveQuality extends InheritedWidget {
  const _InheritedAdaptiveQuality({
    required this.data,
    required super.child,
  });

  final GlassAdaptiveScopeData data;

  @override
  bool updateShouldNotify(_InheritedAdaptiveQuality oldWidget) =>
      data != oldWidget.data;
}
