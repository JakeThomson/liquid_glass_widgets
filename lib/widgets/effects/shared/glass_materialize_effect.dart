// NOT part of the public API — do not export from liquid_glass_widgets.dart.
//
// The progress-driven core of the materialize transition. The public widgets
// in glass_materialize.dart and the pinned navigation host both render
// through this; it exists separately because the host must drive it as a pure
// function of route progress (a controller could not scrub a back-swipe),
// while the public widgets own the [Animation] that produces that progress.
library;

import 'package:flutter/widgets.dart';

import '../../../src/renderer/internal/glass_materialize_scope.dart';
import '../../../src/renderer/liquid_glass_renderer.dart';
import '../../shared/glass_accessibility_scope.dart';

/// Which side of the materialize choreography a subtree is playing.
///
/// The two are not mirror images, matching the native transition: an
/// entrance resolves the glass early and lets the content sharpen last,
/// while an exit empties the content first and dissolves the glass after.
/// A single [GlassMaterializeEffect.progress] axis (0 = dematerialized,
/// 1 = at rest) is traversed in either direction, so a scrubbed or cancelled
/// transition rewinds the same choreography rather than snapping to the
/// other profile.
enum GlassMaterializeProfile {
  /// The subtree is appearing: glass resolves first, content sharpens last.
  entrance,

  /// The subtree is disappearing: content leaves first, glass dissolves
  /// after — the circle is briefly visibly empty, as on iOS 26.
  exit,
}

// =============================================================================
// Choreography
// =============================================================================

/// The sub-curves of the materialize choreography over one progress axis.
///
/// Tuned against a 120fps capture of iOS 26's
/// `glassEffectTransition(.materialize)` on the native navigation bar.
abstract final class GlassMaterializeChoreography {
  /// Glass channel of an entrance: resolved by three quarters of the way in,
  /// so the shape exists before the icon does.
  static const Interval entranceGlass =
      Interval(0.0, 0.75, curve: Curves.easeOutCubic);

  /// Content channel of an entrance: starts after the glass has begun to
  /// form and sharpens right up to the end.
  static const Interval entranceContent =
      Interval(0.25, 1.0, curve: Curves.easeOut);

  /// Glass channel of an exit: holds almost to the end of the axis, so the
  /// shell outlives its content on the way out.
  static const Interval exitGlass = Interval(0.0, 0.85, curve: Curves.easeIn);

  /// Content channel of an exit: gone by 0.45, while [exitGlass] is still
  /// well above zero — the visibly empty shell the native bar shows.
  static const Interval exitContent = Interval(0.45, 1.0);

  /// Scale curve, shared by both profiles.
  static const Curve scale = Curves.easeOutCubic;
}

// =============================================================================
// Effect
// =============================================================================

/// Renders [child] at a point along the materialize choreography.
///
/// [progress] 0.0 is fully dematerialized, 1.0 is at rest. The widget builds
/// the same tree shape at every value — a self-scale scope, a scale
/// transform and a [GlassMaterializeScope], all at identity when resting —
/// so the glass shells below it never remount as a transition starts or
/// settles. What varies is only the scope's per-frame values, which the
/// glass surfaces resolve themselves (see [GlassMaterializeScope]).
///
/// Under reduce motion both channels collapse to a plain cross-dissolve of
/// [progress]: no scale, no gaussian blur, just the shader's visibility fade
/// — a fade is not motion, and matches how iOS treats the native transition.
class GlassMaterializeEffect extends StatelessWidget {
  /// Renders [child] at [progress] along the [profile] choreography.
  const GlassMaterializeEffect({
    required this.progress,
    required this.profile,
    required this.child,
    this.alignment = Alignment.center,
    this.scaleFrom = 1.0,
    this.blobSigma = 12.0,
    this.contentSigma = 8.0,
    super.key,
  });

  /// How materialized the subtree is: 0.0 = fully dematerialized, 1.0 = at
  /// rest.
  final double progress;

  /// Which side of the choreography [progress] traverses.
  final GlassMaterializeProfile profile;

  /// The subtree containing the glass to materialize.
  final Widget child;

  /// Where the scale converges, matching [Transform.scale]'s alignment.
  final Alignment alignment;

  /// Scale at full dematerialization; 1.0 disables the scale entirely.
  final double scaleFrom;

  /// The raw shader blur while the glass is unresolved, in logical pixels.
  final double blobSigma;

  /// Peak gaussian sigma on the glass content, in logical pixels.
  final double contentSigma;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final reduceMotion = GlassAccessibilityData.of(context).reduceMotion;

    final double glass;
    final double content;
    final double sigma;
    final double scale;
    if (reduceMotion) {
      glass = t;
      content = t;
      sigma = 0.0;
      scale = 1.0;
    } else {
      switch (profile) {
        case GlassMaterializeProfile.entrance:
          glass = GlassMaterializeChoreography.entranceGlass.transform(t);
          content = GlassMaterializeChoreography.entranceContent.transform(t);
        case GlassMaterializeProfile.exit:
          glass = GlassMaterializeChoreography.exitGlass.transform(t);
          content = GlassMaterializeChoreography.exitContent.transform(t);
      }
      sigma = contentSigma * (1.0 - content);
      scale = scaleFrom +
          (1.0 - scaleFrom) * GlassMaterializeChoreography.scale.transform(t);
    }

    return LiquidGlassSelfScaleScope(
      // The backdrop holds still while the effect scales the glass, so the
      // shader must follow the live transform rather than freeze its UVs.
      selfScaled: scale < LiquidGlassSelfScaleScope.freezeScaleThreshold,
      child: Transform.scale(
        scale: scale,
        alignment: alignment,
        child: GlassMaterializeScope(
          glassProgress: glass,
          contentOpacity: content,
          contentSigma: sigma,
          blobSigma: blobSigma,
          child: child,
        ),
      ),
    );
  }
}
