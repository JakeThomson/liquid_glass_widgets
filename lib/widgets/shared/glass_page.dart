import 'package:flutter/material.dart';

import '../interactive/liquid_glass_scope.dart';
import 'glass_adaptive_scope.dart';
import 'glass_backdrop_scope.dart';
import '../../types/glass_quality.dart';

/// The recommended root widget for building a route or screen with glass surfaces.
///
/// [GlassPage] completely eliminates the boilerplate required to set up a
/// performant, correct glass UI. It handles everything automatically:
///
/// 1. **Background Scope**: Wraps the route in a [LiquidGlassScope] so that
///    [GlassBackgroundSource] can locate the capture key — this is what makes
///    real background colour absorption work.
/// 2. **Ghosting Prevention**: Wraps the route in a [GlassBackdropScope] to
///    isolate this route's backdrop from neighbouring routes during navigation
///    transitions, preventing visual ghosting artefacts.
/// 3. **Texture Capture**: Automatically marks your [background] widget as the
///    texture source so glass elements can perform real colour absorption and
///    refraction (Impeller parity on Skia/Web paths).
/// 4. **Transparent Scaffold**: Forces the [Scaffold]'s default background
///    colour to transparent via a [Theme] override, ensuring the wallpaper
///    shows through without any extra configuration.
/// 5. **Adaptive Quality**: Reads the nearest [GlassAdaptiveScope] (typically
///    set once in [LiquidGlassWidgets.wrap]) and disables the expensive texture
///    capture when the device has been throttled to [GlassQuality.minimal],
///    saving GPU cycles automatically.
///
/// ## Performance characteristics
///
/// | State | Cost |
/// |-------|------|
/// | Not using `GlassPage` at all | Zero — no wrappers present |
/// | `GlassPage` without a background or `enableBackgroundSampling: false` | Near-zero — `LiquidGlassScope` key is allocated but no Ticker runs |
/// | Adaptive quality degraded to [GlassQuality.minimal] | Near-zero — `GlassBackgroundSource` detaches its RepaintBoundary; Ticker detects this and stops itself |
/// | Background sampling active, static background | Very low — Ticker fires each frame, detects no change, does nothing after the first capture |
/// | Background sampling active, background scrolling/animating | Normal — Ticker captures when size or position changes |
///
/// ## Recommended setup
///
/// ### App root (once):
/// ```dart
/// void main() async {
///   await LiquidGlassWidgets.initialize();
///   runApp(LiquidGlassWidgets.wrap(
///     child: MyApp(),
///     adaptiveQuality: true, // auto-degrades on weaker devices
///   ));
/// }
/// ```
///
/// ### Each screen (one wrapper, nothing else):
/// ```dart
/// class HomeScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return GlassPage(
///       background: Image.asset('assets/wallpaper.jpg', fit: BoxFit.cover),
///       child: Scaffold(
///         appBar: GlassAppBar(title: const Text('Home')),
///         body: MyContent(),
///       ),
///     );
///   }
/// }
/// ```
///
/// ### Opting out of texture capture (pure frosted look, no wallpaper):
/// ```dart
/// GlassPage(
///   enableBackgroundSampling: false,
///   background: Container(color: Colors.black),
///   child: Scaffold(...),
/// )
/// ```
///
/// No [LiquidGlassScope], [GlassAdaptiveScope], or [GlassBackdropScope]
/// needed at the screen level — [GlassPage] handles all of it.
class GlassPage extends StatelessWidget {
  /// Creates a [GlassPage].
  ///
  /// The [background] widget will be drawn beneath the [child] and, unless
  /// [enableBackgroundSampling] is `false`, captured into a GPU texture for
  /// glass refraction and colour absorption.
  ///
  /// The [child] is typically a [Scaffold], which will automatically receive
  /// a transparent background via a [Theme] override.
  const GlassPage({
    super.key,
    required this.background,
    required this.child,
    this.enableBackgroundSampling = true,
  });

  /// The background widget (e.g. an [Image] or gradient [Container]) that
  /// sits behind the app content and provides colours for the glass to absorb.
  final Widget background;

  /// The main content of the screen, typically a [Scaffold].
  final Widget child;

  /// Whether to capture the [background] as a GPU texture for glass colour
  /// absorption.
  ///
  /// Defaults to `true` — recommended when using a wallpaper or image
  /// background so that glass elements absorb real background colours.
  ///
  /// Set to `false` for:
  /// - Screens where a pure frosted/tinted look is preferred with no wallpaper.
  /// - Screens with a solid colour background where sampling adds no visual value.
  /// - Performance-critical pages that need to avoid the RepaintBoundary cost.
  ///
  /// When `false`, the [background] is still rendered but no [RepaintBoundary]
  /// is inserted and no Ticker runs. The performance cost is zero beyond the
  /// minimal overhead of [LiquidGlassScope] (one [GlobalKey] allocation).
  ///
  /// This flag is ignored when the ambient [GlassAdaptiveScope] has degraded
  /// to [GlassQuality.minimal] — sampling is always disabled in that tier
  /// regardless of this setting.
  final bool enableBackgroundSampling;

  @override
  Widget build(BuildContext context) {
    // Read the adaptive quality ceiling from the root GlassAdaptiveScope set
    // in LiquidGlassWidgets.wrap(). Only used to decide whether to enable the
    // expensive background texture capture. Glass widget rendering quality is
    // handled automatically by GlassThemeHelpers.resolveQuality() inside each
    // individual glass widget — no action needed here for that.
    final quality = GlassAdaptiveScopeData.maybeOf(context)?.effectiveQuality
        ?? GlassQuality.premium;

    // Sampling is enabled only when: the user has not explicitly disabled it
    // AND the adaptive scope has not degraded quality to minimal.
    final bool doSample = enableBackgroundSampling && quality != GlassQuality.minimal;

    return LiquidGlassScope(
      // Provides the GlobalKey that GlassBackgroundSource uses to tag the
      // RepaintBoundary. Without this, GlassBackgroundSource.of(context)
      // returns null and background sampling silently falls back to synthetic
      // frost on every screen.
      child: GlassBackdropScope(
        // Isolates this route's BackdropGroup from adjacent routes during
        // push/pop transitions — prevents visual ghosting artefacts.
        // Safe to nest: BackdropGroup is an InheritedWidget and each instance
        // creates its own key; the nearest ancestor always wins.
        child: Stack(
          children: [
            // 1. Background layer — tagged for GPU texture capture when enabled
            Positioned.fill(
              child: GlassBackgroundSource(
                enabled: doSample,
                child: background,
              ),
            ),

            // 2. Content layer — transparent scaffold theme applied here
            Positioned.fill(
              child: Theme(
                // Force the default Scaffold background to transparent so the
                // wallpaper shows through. If the user explicitly sets a
                // backgroundColor on their Scaffold, that still overrides this.
                data: Theme.of(context).copyWith(
                  scaffoldBackgroundColor: Colors.transparent,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
