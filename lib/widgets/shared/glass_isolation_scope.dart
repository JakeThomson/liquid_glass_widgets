import 'package:flutter/widgets.dart';

/// An [InheritedWidget] that tells descendant glass widgets to use their own
/// independent glass rendering layer instead of sharing the page-level layer.
///
/// This is a zero-cost scope marker — it doesn't create any glass rendering
/// context, shader, or compositing layer. It simply provides a signal that
/// descendant [AdaptiveGlass] widgets check to decide whether to use
/// `useOwnLayer: true`.
///
/// Used by [GlassScaffold] to isolate app bar and bottom bar glass from body
/// glass, preventing z-ordering issues in the shared glass compositing layer.
///
/// ## Why is this needed?
///
/// When glass widgets share a single [AdaptiveLiquidGlassLayer] (the default
/// setup via [GlassPage]), all glass surfaces — body cards, app bar buttons,
/// bottom bar controls — are composited in a single shader pass. The rendering
/// order within this shared pass follows widget tree traversal, which may not
/// match the visual z-ordering defined by [Stack] position.
///
/// Wrapping the app bar or bottom bar in [GlassIsolationScope] causes their
/// glass widgets to render independently (each with its own tiny glass surface)
/// rather than grouping with the page-level layer. This ensures they always
/// paint above body glass, with zero extra shader or compositing overhead.
class GlassIsolationScope extends InheritedWidget {
  /// Creates a glass isolation scope.
  const GlassIsolationScope({super.key, required super.child});

  /// Returns `true` if the given [context] is inside a [GlassIsolationScope].
  ///
  /// Used by [AdaptiveGlass] to decide whether to force `useOwnLayer: true`.
  static bool isIsolated(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<GlassIsolationScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(GlassIsolationScope oldWidget) => false;
}
