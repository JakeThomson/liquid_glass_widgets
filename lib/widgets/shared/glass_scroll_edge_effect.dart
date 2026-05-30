import 'package:flutter/material.dart';

/// Edge effect style matching iOS 26's `.scrollEdgeEffectStyle`.
///
/// Controls how scroll content fades at the edges when it meets a glass
/// surface (navigation bar, bottom bar, etc.).
enum GlassScrollEdgeStyle {
  /// A rounded, diffused fade — content dissolves smoothly into the bar area.
  ///
  /// Matches iOS 26's `.soft` edge effect style. This is the default and is
  /// ideal for most list/scroll views with transparent navigation bars.
  soft,

  /// A crisp boundary — content has a sharper cutoff at the bar edge.
  ///
  /// Matches iOS 26's `.hard` edge effect style. Useful when you want a
  /// clear visual separation between the bar and content.
  hard,
}

/// A widget that fades scroll content at the top and/or bottom edges.
///
/// Matches iOS 26's `.scrollEdgeEffectStyle(_:for:)` modifier. Wraps a
/// scrollable child in a [ShaderMask] that applies alpha gradient fades
/// at the specified edges, creating the effect of content dissolving into
/// navigation bars or bottom bars rather than clipping sharply.
///
/// ## Usage
///
/// ```dart
/// GlassScrollEdgeEffect(
///   topFadeHeight: 100,
///   bottomFadeHeight: 80,
///   child: ListView.builder(
///     itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
///   ),
/// )
/// ```
///
/// ## With GlassAppBar
///
/// ```dart
/// Scaffold(
///   extendBodyBehindAppBar: true,
///   appBar: GlassAppBar(title: Text('Messages')),
///   body: GlassScrollEdgeEffect(
///     topFadeHeight: MediaQuery.paddingOf(context).top + 44 + 50,
///     bottomFadeHeight: 60 + MediaQuery.paddingOf(context).bottom,
///     child: ListView(...),
///   ),
/// )
/// ```
///
/// The [topFadeHeight] should typically cover the safe area + app bar height
/// + a buffer zone so content fades before reaching the navigation buttons.
class GlassScrollEdgeEffect extends StatelessWidget {
  /// Creates a scroll edge effect that fades content at the edges.
  const GlassScrollEdgeEffect({
    super.key,
    required this.child,
    this.topFadeHeight = 100.0,
    this.bottomFadeHeight = 60.0,
    this.fadeTop = true,
    this.fadeBottom = true,
    this.style = GlassScrollEdgeStyle.soft,
  });

  /// The scrollable content to apply edge fading to.
  final Widget child;

  /// The height of the top fade zone in logical pixels.
  ///
  /// Content within this zone fades from fully transparent (at the top edge)
  /// to fully visible. Should cover the safe area + navigation bar height +
  /// a buffer zone.
  ///
  /// Defaults to 100.0.
  final double topFadeHeight;

  /// The height of the bottom fade zone in logical pixels.
  ///
  /// Content within this zone fades from fully visible to fully transparent
  /// (at the bottom edge). Should cover the bottom bar height + safe area.
  ///
  /// Defaults to 60.0.
  final double bottomFadeHeight;

  /// Whether to fade content at the top edge.
  ///
  /// Defaults to true.
  final bool fadeTop;

  /// Whether to fade content at the bottom edge.
  ///
  /// Defaults to true.
  final bool fadeBottom;

  /// The edge effect style.
  ///
  /// [GlassScrollEdgeStyle.soft] produces a gradual, diffused fade (default).
  /// [GlassScrollEdgeStyle.hard] produces a sharper cutoff.
  ///
  /// Matches iOS 26's `.scrollEdgeEffectStyle(.soft/.hard, for: .top)`.
  final GlassScrollEdgeStyle style;

  @override
  Widget build(BuildContext context) {
    // No fading needed — return child directly.
    if (!fadeTop && !fadeBottom) return child;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        // Compute fractional stops based on fade heights relative to the
        // total bounds. Soft uses a smooth linear gradient; hard uses a
        // tighter transition zone (1/3 of the soft height).
        final effectiveTopHeight =
            fadeTop ? _effectiveHeight(topFadeHeight, bounds.height) : 0.0;
        final effectiveBottomHeight =
            fadeBottom ? _effectiveHeight(bottomFadeHeight, bounds.height) : 0.0;

        final topStop = effectiveTopHeight / bounds.height;
        final bottomStop =
            (bounds.height - effectiveBottomHeight) / bounds.height;

        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            if (fadeTop) Colors.transparent,
            Colors.black,
            Colors.black,
            if (fadeBottom) Colors.transparent,
          ],
          stops: [
            if (fadeTop) 0.0,
            fadeTop ? topStop : 0.0,
            fadeBottom ? bottomStop : 1.0,
            if (fadeBottom) 1.0,
          ],
        ).createShader(bounds);
      },
      child: child,
    );
  }

  double _effectiveHeight(double height, double boundsHeight) {
    // Hard style uses a tighter transition (1/3 of soft).
    final adjusted =
        style == GlassScrollEdgeStyle.hard ? height * 0.33 : height;
    // Clamp to half the available height to avoid overlapping zones.
    return adjusted.clamp(0.0, boundsHeight * 0.4);
  }
}
