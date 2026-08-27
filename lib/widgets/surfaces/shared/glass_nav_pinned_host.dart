import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../../../src/renderer/liquid_glass_renderer.dart';
import '../../../types/glass_quality.dart';
import '../../../utils/glass_spring.dart';
import '../../interactive/glass_button.dart';
import '../../overlays/glass_menu.dart';
import '../../shared/glass_isolation_scope.dart';
import '../glass_app_bar.dart';
import '../glass_bar_item.dart';
import '../glass_navigation_shell.dart';

/// Geometry and timing constants for the pinned chrome.
///
/// Grouped here so the choreography can be tuned in one place.
abstract final class GlassNavPinnedMetrics {
  /// Width and height of one icon slot inside the actions capsule.
  ///
  /// Matches `GlassButtonGroup.icons`: 22pt icon + `EdgeInsets.all(12)`.
  static const double slot = 46.0;

  /// Corner radius of the actions capsule, matching `GlassButtonGroup.icons`.
  static const double capsuleRadius = 22.0;

  /// Diameter of the circular back button.
  static const double backDiameter = 44.0;

  /// Icon size inside both clusters.
  static const double iconSize = 22.0;

  /// Height of the toolbar row, matching [GlassAppBar.toolbarHeight].
  static const double toolbarHeight = 44.0;

  /// Horizontal inset, matching [GlassAppBar.padding].
  static const double horizontalPadding = 8.0;

  /// Stretch factor of the capsule shell, matching `GlassButtonGroup.icons`.
  static const double capsuleStretch = 0.15;

  /// Start of the capsule morph, as a fraction of the route transition.
  ///
  /// The capsule rides the whole transition: natively its spring settles in
  /// the same breath as the page lands, which is what keeps the bounce in
  /// sync with the slide — the bar and the page are on the same clock. The
  /// tiny lead-in keeps the first moving frame from reading as a jump.
  static const double morphStart = 0.03;

  /// End of the capsule morph, as a fraction of the route transition.
  static const double morphEnd = 1.0;

  /// Window during which a matched item's icon cross-fades, as a fraction of
  /// the [morphStart]..[morphEnd] morph window.
  static const double crossFadeStart = 0.25;

  /// End of the icon cross-fade window.
  static const double crossFadeEnd = 0.6;

  /// Peak of the gel swell, as a fraction of the pill's size.
  ///
  /// The swell is not a width effect: natively the entire capsule — height,
  /// radius, glyphs — puffs up together while the cluster is already
  /// travelling toward its new width, then relaxes. It scales the pill about
  /// its own centre, so both edges move outward.
  static const double swellAmount = 0.22;

  /// Portion of the morph over which the swell rises and falls.
  static const double swellWindow = 0.6;

  /// How much of the spring's overshoot squeezes the whole pill.
  ///
  /// The spring lands through its overshoot; coupling that excursion into
  /// the same uniform scale the swell uses is what makes the bounce read on
  /// the whole pill — height included — rather than in width alone.
  static const double squeezeScale = 0.35;

  /// The gel swell at [morphT] through the morph window.
  static double swellPulseAt(double morphT) {
    final x = (morphT / swellWindow).clamp(0.0, 1.0);
    return swellAmount * math.sin(math.pi * x);
  }

  /// Peak gaussian blur applied to a glyph on its way out.
  ///
  /// The native morph never shows a glyph plainly fading: an outgoing glyph
  /// smears away under heavy blur as the capsule reshapes under it, which
  /// reads as motion blur on the whole cluster.
  static const double morphBlurSigma = 6.0;

  /// Blur at which an incoming glyph arrives.
  ///
  /// Softer than the outgoing smear: natively the arriving glyph is soft but
  /// its silhouette stays readable the whole way in.
  static const double glyphArriveSigma = 3.5;

  /// Route progress window over which an incoming glyph sharpens.
  ///
  /// Sharpening starts while the capsule is still bouncing and finishes just
  /// ahead of the landing — natively the blur is the last thing to clear.
  static const double glyphSharpenStart = 0.5;

  /// End of the incoming glyph's sharpening window.
  static const double glyphSharpenEnd = 0.9;

  /// Point in the transition at which the chrome switches from showing the
  /// outgoing route's configuration to the incoming one.
  static const double swapAt = 0.5;

  /// The scale of a capsule that only one side has, at route [progress].
  ///
  /// Appearing and disappearing are animated in scale, never in opacity — a
  /// glass surface's backdrop pass renders fully or not at all, but the
  /// native bar gels an emptied cluster out and a new one in, and scale is
  /// the one dimension glass can safely animate. The gel rides the same
  /// spring as everything else, so an appearing capsule bounces past full
  /// size on its way in; walked backwards on a pop it leaves the same way.
  /// A capsule both sides share stays at full presence — its gel is the
  /// swell pulse, not this.
  static double capsulePresenceAt({
    required bool fromEmpty,
    required bool toEmpty,
    required double progress,
  }) {
    if (fromEmpty && toEmpty) return 0.0;
    if (!fromEmpty && !toEmpty) return 1.0;
    final appearT = GlassNavMorphCurve.instance
        .transform(morphProgressAt(progress))
        .clamp(0.0, double.infinity);
    return fromEmpty ? appearT : (1.0 - appearT).clamp(0.0, 1.0);
  }

  /// Which side's configuration is showing at transition [progress].
  static bool showsIncomingAt(double progress) => progress >= swapAt;

  /// Progress through the [morphStart]..[morphEnd] window at route [progress].
  static double morphProgressAt(double progress) =>
      ((progress - morphStart) / (morphEnd - morphStart)).clamp(0.0, 1.0);

  /// Blur of an outgoing glyph at [morphT] through the morph window.
  ///
  /// Ramps to full strength ahead of the fade, so a glyph is already soft
  /// before its opacity starts moving — the native smear.
  static double outgoingSigmaAt(double morphT) =>
      morphBlurSigma * (morphT * 3.0).clamp(0.0, 1.0);

  /// Blur of an incoming glyph at route [progress].
  static double incomingSigmaAt(double progress) =>
      glyphArriveSigma *
      (1.0 -
          ((progress - glyphSharpenStart) /
                  (glyphSharpenEnd - glyphSharpenStart))
              .clamp(0.0, 1.0));
}

/// The motion of a morphing capsule: the package's bouncy spring as a curve.
///
/// The cluster's width and item positions travel on this from the first
/// frame of the transition to the last, overshooting the target and settling
/// back exactly as the page lands — capsule and page share one clock. It
/// samples [GlassSpring.bouncy] — the same profile the liquid morphs
/// elsewhere in the package ride — as a curve rather than as a live
/// simulation, because the pinned chrome is a pure interpolation of the
/// route clock: a time-driven spring would detach the morph from back-swipe
/// scrubbing.
///
/// Public for testing; this library is not exported from the package barrel.
@visibleForTesting
class GlassNavMorphCurve extends Curve {
  const GlassNavMorphCurve._();

  /// The shared instance; the underlying simulation is stateless.
  static const GlassNavMorphCurve instance = GlassNavMorphCurve._();

  /// The perceptual settle duration [GlassSpring.bouncy] is specified with.
  static const double _settleSeconds = 0.5;

  static final SpringSimulation _simulation =
      SpringSimulation(GlassSpring.bouncy(extraBounce: 0.1), 0.0, 1.0, 0.0);

  /// The residual at the end of the sample window, divided out so the curve
  /// honours the Curve contract of ending exactly at 1.
  static final double _terminal = _simulation.x(_settleSeconds);

  @override
  double transformInternal(double t) =>
      _simulation.x(t * _settleSeconds) / _terminal;
}

/// The chrome to render for the current frame.
///
/// [progress] is the top route's own entrance animation: 1 at rest, running
/// 0 to 1 on a push and scrubbing 1 to 0 during a pop or back-swipe. The host
/// renders a straight interpolation from [from] to [to] over it, which makes
/// every case — push, pop, cancelled swipe, interrupted transition — fall out
/// of one formula.
@immutable
class GlassNavPinnedState {
  /// Creates a description of the chrome for one frame.
  const GlassNavPinnedState({
    required this.from,
    required this.to,
    required this.progress,
    required this.coverage,
    required this.settled,
    required this.popping,
    required this.topRoute,
  });

  /// Chrome of the route beneath the top one.
  final GlassNavBarRegistration from;

  /// Chrome of the topmost registered route.
  final GlassNavBarRegistration to;

  /// The top route's entrance progress, 0 to 1.
  final double progress;

  /// How much the top route is covered by an unregistered route, 0 to 1.
  ///
  /// Drives the chrome out of the way when a plain route or a modal sheet is
  /// presented above the pinned bar.
  final double coverage;

  /// Whether the chrome is at rest and may be tapped.
  ///
  /// False for the whole of a push, pop or back-swipe. Taps are swallowed
  /// while a transition runs because the chrome is showing a blend of two
  /// routes' items, so acting on one of them would fire an action the user
  /// can no longer see. [progress] cannot answer this on its own — a pop
  /// begins at 1.0 — so the shell derives it from the route instead.
  final bool settled;

  /// Whether the transition is a pop — an animated pop or a back-swipe.
  ///
  /// A pop plays the same forward choreography as a push, toward the other
  /// target: the clock is mirrored and the from/to roles swap, so the swell
  /// leads and the bounce lands with the page in both directions. Rendering
  /// the push in reverse instead put all the motion at the wrong end of a
  /// pop.
  final bool popping;

  /// The topmost registered route, used for the default back action.
  final ModalRoute<dynamic> topRoute;
}

/// Renders the pinned back button and actions capsule above the [Navigator].
///
/// A surviving cluster keeps one persistent glass shell whose geometry
/// animates; its element is never remounted mid-morph. That matters because a
/// glass surface's backdrop pass renders fully or not at all, so fading one in
/// or out visibly pops — geometry may animate, opacity may not. Clusters that
/// appear or disappear outright do so in a single switch at
/// [GlassNavPinnedMetrics.swapAt] rather than animating.
class GlassNavPinnedHost extends StatelessWidget {
  /// Creates the pinned host for the given frame [state].
  const GlassNavPinnedHost({super.key, required this.state});

  /// The chrome to render.
  final GlassNavPinnedState state;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final settings = state.to.buttonSettings ?? state.from.buttonSettings;

    // Everything retreats together when an unregistered route covers the bar.
    // Each cluster scales about its own anchored edge: scaling the full-width
    // Stack instead would drag both clusters toward the centre.
    final coverageScale = 1.0 - Curves.easeIn.transform(state.coverage);
    if (coverageScale <= 0.01) return const SizedBox.shrink();

    Widget chrome = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: _PinnedBackButton(state: state, coverageScale: coverageScale),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: _PinnedActionsCapsule(
            state: state,
            coverageScale: coverageScale,
          ),
        ),
      ],
    );

    if (settings != null) {
      chrome = DefaultButtonSettings(settings: settings, child: chrome);
    }

    return Positioned(
      top: topPad,
      left: GlassNavPinnedMetrics.horizontalPadding,
      right: GlassNavPinnedMetrics.horizontalPadding,
      height: GlassNavPinnedMetrics.toolbarHeight,
      child: GlassIsolationScope(
        isolated: true,
        defaultQuality: GlassQuality.premium,
        child: chrome,
      ),
    );
  }
}

// =============================================================================
// Back button
// =============================================================================

/// The pinned circular back button.
///
/// It stays put while both routes show one. When only one side has a back
/// button — the first push off the root, or the pop back to it — the button
/// gels in and out on the same spring the capsule rides: it scales up
/// through the morph window, overshooting like the capsule bounce, while the
/// chevron arrives soft and sharpens last. Glass opacity is never animated,
/// but scale is — the same transform the coverage retreat already uses.
class _PinnedBackButton extends StatelessWidget {
  const _PinnedBackButton({required this.state, required this.coverageScale});

  final GlassNavPinnedState state;

  /// Retreat factor applied when an unregistered route covers the bar.
  final double coverageScale;

  @override
  Widget build(BuildContext context) {
    // Mirrored on a pop for the same reason the capsule mirrors: the gel
    // leads in both directions. The back action itself stays with the real
    // top route — taps are swallowed mid-transition anyway.
    final p = state.popping ? 1.0 - state.progress : state.progress;
    final fromShows = state.popping
        ? state.to.showsBackButton
        : state.from.showsBackButton;
    final toShows = state.popping
        ? state.from.showsBackButton
        : state.to.showsBackButton;

    // Present on both sides: pinned and inert to the transition. Absent on
    // both: nothing to render.
    var morphScale = 1.0;
    var chevronSigma = 0.0;
    if (!fromShows && !toShows) return const SizedBox.shrink();
    if (fromShows != toShows && !state.settled) {
      final springT = GlassNavMorphCurve.instance
          .transform(GlassNavPinnedMetrics.morphProgressAt(p));
      // Springs in from nothing with the same bounce the capsule rides.
      final appearT = springT.clamp(0.0, double.infinity);
      morphScale = fromShows ? 1.0 - appearT : appearT;
      chevronSigma = toShows
          ? GlassNavPinnedMetrics.incomingSigmaAt(p)
          : GlassNavPinnedMetrics.outgoingSigmaAt(
              GlassNavPinnedMetrics.morphProgressAt(p));
    } else if (!(GlassNavPinnedMetrics.showsIncomingAt(p)
        ? toShows
        : fromShows)) {
      return const SizedBox.shrink();
    }
    if (morphScale <= 0.01 || coverageScale <= 0.01) {
      return const SizedBox.shrink();
    }

    Widget chevron = const Icon(CupertinoIcons.back);
    if (chevronSigma > 0.01) {
      // The chevron is content, not glass, so filtering it is safe.
      chevron = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: chevronSigma,
          sigmaY: chevronSigma,
          tileMode: TileMode.decal,
        ),
        child: chevron,
      );
    }

    return Transform.scale(
      scale: coverageScale * morphScale,
      alignment: Alignment.centerLeft,
      child: IgnorePointer(
        ignoring: !state.settled,
        child: GlassButton(
          icon: chevron,
          width: GlassNavPinnedMetrics.backDiameter,
          height: GlassNavPinnedMetrics.backDiameter,
          iconSize: GlassNavPinnedMetrics.iconSize,
          useOwnLayer: true,
          label: 'Back',
          onTap: () {
            final onBack = state.to.onBack;
            if (onBack != null) {
              onBack();
            } else {
              state.topRoute.navigator?.maybePop();
            }
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Item matching
// =============================================================================

/// One item's place in the morph between two routes' action clusters.
///
/// Public for testing; this library is not exported from the package barrel.
@immutable
@visibleForTesting
class GlassNavActionSlot {
  /// Creates a slot pairing an outgoing item with an incoming one.
  const GlassNavActionSlot({this.fromItem, this.toItem});

  /// The item on the outgoing route, if any.
  final GlassBarActionItem? fromItem;

  /// The item on the incoming route, if any.
  final GlassBarActionItem? toItem;

  /// Whether this item exists only on the incoming route.
  bool get isEnter => fromItem == null;

  /// Whether this item exists only on the outgoing route.
  bool get isExit => toItem == null;

  /// Whether both sides exist but render different content.
  bool get crossFades {
    final from = fromItem;
    final to = toItem;
    return from != null && to != null && from.content != to.content;
  }
}

/// Pairs two routes' action items so matched ones morph in place.
///
/// Mirrors UIKit, which matches bar button items by identifier when one is
/// set and otherwise falls back to position and content heuristics.
///
/// Returned slots are ordered leading-to-trailing in the incoming cluster,
/// with items that only exist on the outgoing route appended.
///
/// Public for testing; this library is not exported from the package barrel.
@visibleForTesting
List<GlassNavActionSlot> matchGlassNavActions(
  List<GlassBarActionItem> from,
  List<GlassBarActionItem> to,
) {
  // Slot index counts from the trailing edge, because the cluster is anchored
  // there — an item keeps its place when items are added on the leading side.
  int slotOf(int index, int length) => length - 1 - index;

  final slots = <GlassNavActionSlot>[];
  final usedFrom = <int>{};

  int? takeMatch(GlassBarActionItem toItem, int toIndex) {
    // 1. Explicit identifier match, mirroring UIBarButtonItem.identifier.
    if (toItem.id != null) {
      for (var i = 0; i < from.length; i++) {
        if (usedFrom.contains(i)) continue;
        if (from[i].id == toItem.id) return i;
      }
    }
    // 2. Positional fallback, counting from the trailing edge. An item
    //    carrying a different explicit id is never matched positionally.
    final wanted = slotOf(toIndex, to.length);
    for (var i = 0; i < from.length; i++) {
      if (usedFrom.contains(i)) continue;
      if (from[i].id != null && from[i].id != toItem.id) continue;
      if (slotOf(i, from.length) == wanted) return i;
    }
    return null;
  }

  for (var i = 0; i < to.length; i++) {
    final match = takeMatch(to[i], i);
    if (match != null) usedFrom.add(match);
    slots.add(GlassNavActionSlot(
      fromItem: match != null ? from[match] : null,
      toItem: to[i],
    ));
  }

  // Anything left on the outgoing route exits in place.
  for (var i = 0; i < from.length; i++) {
    if (usedFrom.contains(i)) continue;
    slots.add(GlassNavActionSlot(fromItem: from[i]));
  }

  return slots;
}

// -----------------------------------------------------------------------------
// Measuring cluster layout
// -----------------------------------------------------------------------------

/// Where a slot sits within each of the two clusters being interpolated.
@immutable
class _SlotOrder {
  const _SlotOrder({this.fromOrder, this.toOrder});

  /// Index within the outgoing cluster, leading to trailing.
  final int? fromOrder;

  /// Index within the incoming cluster, leading to trailing.
  final int? toOrder;
}

/// Identifies which slot and which side a child belongs to.
class _ClusterParentData extends ContainerBoxParentData<RenderBox> {
  int slot = 0;
  bool isFrom = false;
  double opacity = 1.0;
  double blurSigma = 0.0;
}

/// Lays out both routes' clusters and interpolates between them.
///
/// Item widths are **measured**, not assumed, which is what lets custom
/// content sit in the bar: the cluster sizes itself around whatever the item
/// turns out to be, exactly as UIKit measures a `customView` during layout.
/// Icons simply measure to the standard slot width.
class _PinnedCluster extends MultiChildRenderObjectWidget {
  const _PinnedCluster({
    required this.orders,
    required this.widthT,
    required this.positionT,
    required this.morphScale,
    required this.height,
    required super.children,
  });

  /// Per-slot placement in each cluster, indexed by slot.
  final List<_SlotOrder> orders;

  /// Interpolation for the overall width.
  final double widthT;

  /// Interpolation for per-item positions and widths.
  final double positionT;

  /// Uniform gel scale applied to the cluster's real geometry.
  final double morphScale;

  /// Fixed cluster height, before the gel scale.
  final double height;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPinnedCluster(
        orders: orders,
        widthT: widthT,
        positionT: positionT,
        morphScale: morphScale,
        clusterHeight: height,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPinnedCluster renderObject,
  ) {
    renderObject
      ..orders = orders
      ..widthT = widthT
      ..positionT = positionT
      ..morphScale = morphScale
      ..clusterHeight = height;
  }
}

class _RenderPinnedCluster extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ClusterParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ClusterParentData> {
  _RenderPinnedCluster({
    required List<_SlotOrder> orders,
    required double widthT,
    required double positionT,
    required double morphScale,
    required double clusterHeight,
  })  : _orders = orders,
        _widthT = widthT,
        _positionT = positionT,
        _morphScale = morphScale,
        _clusterHeight = clusterHeight;

  List<_SlotOrder> _orders;
  set orders(List<_SlotOrder> value) {
    if (_orders == value) return;
    _orders = value;
    markNeedsLayout();
  }

  double _widthT;
  set widthT(double value) {
    if (_widthT == value) return;
    _widthT = value;
    markNeedsLayout();
  }

  double _positionT;
  set positionT(double value) {
    if (_positionT == value) return;
    _positionT = value;
    markNeedsLayout();
  }

  double _morphScale;
  set morphScale(double value) {
    if (_morphScale == value) return;
    _morphScale = value;
    markNeedsLayout();
  }

  double _clusterHeight;
  set clusterHeight(double value) {
    if (_clusterHeight == value) return;
    _clusterHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ClusterParentData) {
      child.parentData = _ClusterParentData();
    }
  }

  @override
  void performLayout() {
    final slotCount = _orders.length;
    // Measured natural width of each slot on each side.
    final fromWidths = List<double?>.filled(slotCount, null);
    final toWidths = List<double?>.filled(slotCount, null);

    // Children size themselves; only the height is imposed.
    final childConstraints = BoxConstraints.tightFor(height: _clusterHeight);

    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _ClusterParentData;
      child.layout(childConstraints, parentUsesSize: true);
      if (data.isFrom) {
        fromWidths[data.slot] = child.size.width;
      } else {
        toWidths[data.slot] = child.size.width;
      }
      child = data.nextSibling;
    }

    // A slot missing one side keeps the width it does have, so an entering or
    // exiting item scales in place rather than resizing.
    double widthOf(int slot, {required bool from}) =>
        (from ? fromWidths[slot] : toWidths[slot]) ??
        (from ? toWidths[slot] : fromWidths[slot]) ??
        0.0;

    // Distance from the cluster's trailing edge for each slot, per side.
    final fromRight = List<double?>.filled(slotCount, null);
    final toRight = List<double?>.filled(slotCount, null);

    double layoutSide({required bool from}) {
      final ordered = <int>[];
      for (var slot = 0; slot < slotCount; slot++) {
        final order = from ? _orders[slot].fromOrder : _orders[slot].toOrder;
        if (order != null) ordered.add(slot);
      }
      ordered.sort((a, b) {
        final oa = (from ? _orders[a].fromOrder : _orders[a].toOrder)!;
        final ob = (from ? _orders[b].fromOrder : _orders[b].toOrder)!;
        return oa.compareTo(ob);
      });

      var total = 0.0;
      for (final slot in ordered) {
        total += widthOf(slot, from: from);
      }
      // Walk leading to trailing, recording how much sits to the right.
      var consumed = 0.0;
      for (final slot in ordered) {
        final w = widthOf(slot, from: from);
        final right = total - consumed - w;
        if (from) {
          fromRight[slot] = right;
        } else {
          toRight[slot] = right;
        }
        consumed += w;
      }
      return total;
    }

    final fromTotal = layoutSide(from: true);
    final toTotal = layoutSide(from: false);

    // The gel scales the box itself: the glass shell wrapping this cluster
    // re-renders at the true inflated size, and paint scales the children to
    // fill it, so shell and glyphs stretch as one body.
    final width = lerpDouble(fromTotal, toTotal, _widthT)!;
    size = constraints
        .constrain(Size(width * _morphScale, _clusterHeight * _morphScale));

    // Position every child by its interpolated distance from the trailing
    // edge — in the pre-scale space, because paint scales the lot into the
    // inflated box.
    child = firstChild;
    while (child != null) {
      final data = child.parentData! as _ClusterParentData;
      final slot = data.slot;
      final right = lerpDouble(
        fromRight[slot] ?? toRight[slot] ?? 0.0,
        toRight[slot] ?? fromRight[slot] ?? 0.0,
        _positionT,
      )!;
      final slotWidth = lerpDouble(
        widthOf(slot, from: true),
        widthOf(slot, from: false),
        _positionT,
      )!;
      final x = width - right - slotWidth;
      data.offset = Offset(
        x + (slotWidth - child.size.width) / 2.0,
        (_clusterHeight - child.size.height) / 2.0,
      );
      child = data.nextSibling;
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    // Mirrors performLayout's sizing: measure both sides' totals from the
    // children's dry sizes and interpolate.
    final slotCount = _orders.length;
    final fromWidths = List<double?>.filled(slotCount, null);
    final toWidths = List<double?>.filled(slotCount, null);
    final childConstraints = BoxConstraints.tightFor(height: _clusterHeight);

    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _ClusterParentData;
      final width = child.getDryLayout(childConstraints).width;
      if (data.isFrom) {
        fromWidths[data.slot] = width;
      } else {
        toWidths[data.slot] = width;
      }
      child = data.nextSibling;
    }

    double totalFor({required bool from}) {
      var total = 0.0;
      for (var slot = 0; slot < slotCount; slot++) {
        final order = from ? _orders[slot].fromOrder : _orders[slot].toOrder;
        if (order == null) continue;
        total += (from ? fromWidths[slot] : toWidths[slot]) ??
            (from ? toWidths[slot] : fromWidths[slot]) ??
            0.0;
      }
      return total;
    }

    final width = lerpDouble(
      totalFor(from: true),
      totalFor(from: false),
      _widthT,
    )!;
    return constraints
        .constrain(Size(width * _morphScale, _clusterHeight * _morphScale));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_morphScale != 1.0) {
      // Children are laid out at their natural size and scaled into the
      // inflated box, glyphs and all — the stretch carries the contents.
      // Compositing is forced: the blurring glyphs paint into their own
      // layers, and only a transform *layer* carries those with the scale —
      // a canvas transform leaves them pinned at their unscaled positions
      // while the pill inflates around them.
      final scale = Matrix4.diagonal3Values(_morphScale, _morphScale, 1.0);
      context.pushTransform(true, offset, scale, _paintChildren);
      return;
    }
    _paintChildren(context, offset);
  }

  void _paintChildren(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _ClusterParentData;
      final childOffset = offset + data.offset;
      final current = child;

      // Item contents are not glass, so fading and filtering them is safe —
      // unlike the capsule itself, which only ever animates geometry. The
      // blur sits inside the opacity so a glyph fades as one soft image.
      void paintContent(PaintingContext ctx, Offset off) {
        if (data.blurSigma > 0.01) {
          ctx.pushLayer(
            ImageFilterLayer(
              imageFilter: ImageFilter.blur(
                sigmaX: data.blurSigma,
                sigmaY: data.blurSigma,
                tileMode: TileMode.decal,
              ),
            ),
            (c, o) => c.paintChild(current, o),
            off,
          );
        } else {
          ctx.paintChild(current, off);
        }
      }

      if (data.opacity >= 1.0) {
        paintContent(context, childOffset);
      } else if (data.opacity > 0.0) {
        context.pushOpacity(
          childOffset,
          (data.opacity * 255).round(),
          paintContent,
        );
      }
      child = data.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

/// Applies a per-child opacity and blur through the cluster's parent data.
class _ClusterChild extends ParentDataWidget<_ClusterParentData> {
  const _ClusterChild({
    required this.slot,
    required this.isFrom,
    required this.opacity,
    required this.blurSigma,
    required super.child,
  });

  final int slot;
  final bool isFrom;
  final double opacity;
  final double blurSigma;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _ClusterParentData;
    var needsPaint = false;
    var needsLayout = false;
    if (data.slot != slot) {
      data.slot = slot;
      needsLayout = true;
    }
    if (data.isFrom != isFrom) {
      data.isFrom = isFrom;
      needsLayout = true;
    }
    if (data.opacity != opacity) {
      data.opacity = opacity;
      needsPaint = true;
    }
    if (data.blurSigma != blurSigma) {
      data.blurSigma = blurSigma;
      needsPaint = true;
    }
    final parent = renderObject.parent;
    if (parent is RenderObject) {
      if (needsLayout) {
        parent.markNeedsLayout();
      } else if (needsPaint) {
        parent.markNeedsPaint();
      }
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _PinnedCluster;
}

// -----------------------------------------------------------------------------
// Actions capsule
// -----------------------------------------------------------------------------

/// The pinned trailing actions cluster.
///
/// A single persistent glass shell that sizes itself to a measured cluster.
/// The shell only ever animates geometry; the items inside it — which are not
/// glass — cross-fade freely.
class _PinnedActionsCapsule extends StatefulWidget {
  const _PinnedActionsCapsule({
    required this.state,
    required this.coverageScale,
  });

  final GlassNavPinnedState state;

  /// Retreat factor applied when an unregistered route covers the bar.
  final double coverageScale;

  @override
  State<_PinnedActionsCapsule> createState() => _PinnedActionsCapsuleState();
}

class _PinnedActionsCapsuleState extends State<_PinnedActionsCapsule> {
  /// Drives the pull-down of whichever item is currently the menu trigger.
  final GlassMenuController _menu = GlassMenuController();

  @override
  void didUpdateWidget(covariant _PinnedActionsCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dismiss on the first unsettled frame. A route-owned menu goes away with
    // its route, but this capsule outlives every route it serves, so an open
    // menu would otherwise hang over the bar while the page slid out from
    // under it.
    if (oldWidget.state.settled && !widget.state.settled && _menu.isOpen) {
      _menu.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final coverageScale = widget.coverageScale;
    // A pop is the same forward choreography toward the other target: mirror
    // the clock and swap the roles, so the swell leads and the bounce lands
    // with the page in both directions. A cancelled swipe simply walks the
    // mirrored clock back to its start, which is the same resting frame.
    final popping = state.popping;
    final fromItems =
        popping ? state.to.actionItems : state.from.actionItems;
    final toItems = popping ? state.from.actionItems : state.to.actionItems;

    if (fromItems.isEmpty && toItems.isEmpty) return const SizedBox.shrink();

    final p = popping ? 1.0 - state.progress : state.progress;
    // The capsule and the page share one clock: the morph spring runs the
    // full length of the route transition and settles with it.
    final morphT = GlassNavPinnedMetrics.morphProgressAt(p);
    // Width and item positions ride the same spring: the overshoot only reads
    // as a bounce when the glyphs travel with the shell, so splitting the two
    // onto different curves makes the capsule feel detached from its contents.
    final springT = GlassNavMorphCurve.instance.transform(morphT);
    // Width travels the whole transition; the gel lives in a uniform scale
    // of the pill's real geometry: the swell pulse inflates it early, and
    // the spring's landing overshoot squeezes it — height, radius and
    // glyphs together, the way stretching any glass in this package carries
    // its contents with it. Never a paint-transform: the glass texture has
    // no headroom for one, and a scaled texture is exactly the shell/content
    // disconnect this replaces.
    final overshoot = (springT - 1.0).clamp(0.0, 1.0);
    final gelScale = fromItems.isEmpty || toItems.isEmpty || state.settled
        ? 1.0
        : 1.0 +
            GlassNavPinnedMetrics.swellPulseAt(morphT) -
            GlassNavPinnedMetrics.squeezeScale * overshoot;
    // A capsule only one side has gels in or out through the same scale the
    // swell pulse uses; a shared capsule stays at presence 1 and pulses.
    final presence = state.settled
        ? 1.0
        : GlassNavPinnedMetrics.capsulePresenceAt(
            fromEmpty: fromItems.isEmpty,
            toEmpty: toItems.isEmpty,
            progress: p,
          );
    final morphScale = gelScale * presence;
    final clampedT = springT.clamp(0.0, 1.0);

    // With one side empty the capsule holds the width it has: collapsing the
    // width would leave a degenerate glass shape on the way out — the gel
    // scale is what takes it off screen.
    final widthT = fromItems.isEmpty
        ? 1.0
        : toItems.isEmpty
            ? 0.0
            : clampedT;
    if (morphScale <= 0.01 || coverageScale <= 0.01) {
      return const SizedBox.shrink();
    }

    final slots = matchGlassNavActions(fromItems, toItems);
    final showsIncoming = GlassNavPinnedMetrics.showsIncomingAt(p);

    // Whichever side is showing owns the menu. A menu can only be opened at
    // rest, where that is always the incoming side, but the trigger is rebuilt
    // every frame and must agree with the icons actually on screen. Only the
    // first menu item counts, matching GlassButtonGroup.
    GlassBarMenuItem? menuItem;
    for (final item in showsIncoming ? toItems : fromItems) {
      if (item is GlassBarMenuItem) {
        menuItem = item;
        break;
      }
    }

    // Where each slot sits within each cluster, leading to trailing.
    final orders = <_SlotOrder>[];
    var fromOrder = 0;
    var toOrder = 0;
    final fromOrders = <int, int>{};
    final toOrders = <int, int>{};
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].toItem != null) toOrders[i] = toOrder++;
    }
    // Outgoing order follows the outgoing cluster, not the slot list.
    for (final item in fromItems) {
      final i = slots.indexWhere((s) => identical(s.fromItem, item));
      if (i >= 0) fromOrders[i] = fromOrder++;
    }
    for (var i = 0; i < slots.length; i++) {
      orders.add(_SlotOrder(fromOrder: fromOrders[i], toOrder: toOrders[i]));
    }

    // Cross-fade window for a matched item whose content changed, and
    // entering / exiting items during a capsule morph.
    final q = ((morphT - GlassNavPinnedMetrics.crossFadeStart) /
            (GlassNavPinnedMetrics.crossFadeEnd -
                GlassNavPinnedMetrics.crossFadeStart))
        .clamp(0.0, 1.0);

    // Glyph blur, the other half of the native read. An outgoing glyph blurs
    // away as it fades; an incoming one arrives at full blur and holds it past
    // the end of the geometry morph, sharpening last. Item contents are not
    // glass, so filtering them is safe — unlike the capsule shell.
    final outSigma =
        state.settled ? 0.0 : GlassNavPinnedMetrics.outgoingSigmaAt(morphT);
    final inSigma =
        state.settled ? 0.0 : GlassNavPinnedMetrics.incomingSigmaAt(p);

    final morphingCapsule = fromItems.isNotEmpty && toItems.isNotEmpty;

    final children = <Widget>[];
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final crossFades = slot.crossFades;
      final fromItem = slot.fromItem;
      final toItem = slot.toItem;

      if (fromItem != null) {
        if (toItem == null) {
          // Exiting item: smoothly fade out with (1 - q) across the transition window.
          // While transition is in-flight, keep mounted in morphing capsules so natural width is preserved.
          final visible =
              state.settled ? !showsIncoming : (morphingCapsule || q < 1.0);
          if (visible) {
            children.add(_ClusterChild(
              slot: i,
              isFrom: true,
              opacity: state.settled ? 1.0 : (1.0 - q),
              blurSigma: outSigma,
              child: _ClusterItem(item: fromItem, enabled: false),
            ));
          }
        } else if (crossFades && (!state.settled ? q < 1.0 : !showsIncoming)) {
          // Cross-fading outgoing side.
          children.add(_ClusterChild(
            slot: i,
            isFrom: true,
            opacity: state.settled ? 1.0 : (1.0 - q),
            blurSigma: outSigma,
            child: _ClusterItem(item: fromItem, enabled: false),
          ));
        }
      }

      if (toItem != null) {
        if (fromItem == null) {
          // Entering item: smoothly fade in with q across the transition window.
          // While transition is in-flight, keep mounted in morphing capsules so natural width is preserved.
          final visible =
              state.settled ? showsIncoming : (morphingCapsule || q > 0.0);
          if (visible) {
            children.add(_ClusterChild(
              slot: i,
              isFrom: false,
              opacity: state.settled ? 1.0 : q,
              blurSigma: inSigma,
              child: _ClusterItem(
                item: toItem,
                enabled: state.settled,
                onMenuTap: identical(toItem, menuItem) ? _menu.open : null,
              ),
            ));
          }
        } else if (!crossFades || (!state.settled ? q > 0.0 : showsIncoming)) {
          // Matched persistent item or cross-fading incoming side.
          children.add(_ClusterChild(
            slot: i,
            isFrom: false,
            opacity: crossFades ? (state.settled ? 1.0 : q) : 1.0,
            blurSigma: crossFades ? inSigma : 0.0,
            child: _ClusterItem(
              item: toItem,
              enabled: state.settled,
              onMenuTap: identical(toItem, menuItem) ? _menu.open : null,
            ),
          ));
        }
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();

    // Wrapped unconditionally, even with no menu item: inserting or removing a
    // GlassMenu ancestor would remount the capsule's element, and a glass shell
    // that remounts mid-morph pops its backdrop. Closed, GlassMenu adds only
    // inert wrappers and mounts no overlay, so the empty case costs nothing.
    // Coverage retreats about the anchored trailing edge. The gel is real
    // geometry — the cluster lays out at scale and the glass re-renders its
    // true shape — so all that remains here is recentring: the pill is
    // anchored top-trailing, and natively the swell moves both edges
    // outward, so half of any growth is walked back across each axis.
    final f = morphScale <= 0.01 ? 0.0 : (1.0 - 1.0 / morphScale) / 2.0;
    return Transform.scale(
      scale: coverageScale,
      alignment: Alignment.centerRight,
      child: FractionalTranslation(
        translation: Offset(f, -f),
        child: IgnorePointer(
          ignoring: !state.settled,
          child: GlassMenu(
            controller: _menu,
            items: menuItem?.menuItems ?? const <Widget>[],
            menuAlignment: menuItem?.menuAlignment,
            // The fallback is never read: with no menu item there is no
            // trigger to open one. It matches GlassMenu's own default.
            menuWidth: menuItem?.menuWidth ?? 200,
            triggerBuilder: (context, _) => _buildCapsule(
              orders: orders,
              widthT: widthT,
              positionT: clampedT,
              morphScale: morphScale,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  /// The glass shell itself, sized by the measured cluster.
  ///
  /// Split out so it can be handed to [GlassMenu.triggerBuilder] — the menu
  /// morphs the whole capsule, not the tapped item's slot, matching iOS 26's
  /// `GlassEffectContainer`.
  Widget _buildCapsule({
    required List<_SlotOrder> orders,
    required double widthT,
    required double positionT,
    required double morphScale,
    required List<Widget> children,
  }) {
    return GlassButton.custom(
      onTap: () {},
      // The radius scales with the gel so the shape stays a true scaled
      // capsule rather than squaring off as it inflates.
      shape: LiquidRoundedRectangle(
        borderRadius: GlassNavPinnedMetrics.capsuleRadius * morphScale,
      ),
      // Sized by the measured cluster, exactly as GlassButtonGroup.icons
      // sizes to its content.
      width: null,
      height: null,
      stretch: GlassNavPinnedMetrics.capsuleStretch,
      useOwnLayer: true,
      canRequestFocus: false,
      excludeFromSemantics: true,
      child: ClipRect(
        child: _PinnedCluster(
          orders: orders,
          widthT: widthT,
          positionT: positionT,
          morphScale: morphScale,
          height: GlassNavPinnedMetrics.slot,
          children: children,
        ),
      ),
    );
  }
}

/// One item's content inside the cluster.
///
/// Icons are padded to the standard slot width; custom content is measured at
/// whatever width it wants, which is what lets it sit in the bar at all.
class _ClusterItem extends StatelessWidget {
  const _ClusterItem({
    required this.item,
    required this.enabled,
    this.onMenuTap,
  });

  final GlassBarActionItem item;
  final bool enabled;

  /// Opens the capsule's pull-down.
  ///
  /// Supplied only for the one item acting as the menu trigger, and only on
  /// the side that can be tapped, so an outgoing item never reopens a menu on
  /// its way out.
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && item.enabled;

    Widget content = switch (item) {
      GlassBarIconItem(:final icon) => SizedBox(
          width: GlassNavPinnedMetrics.slot,
          child: Center(child: icon),
        ),
      GlassBarMenuItem(:final icon) => SizedBox(
          width: GlassNavPinnedMetrics.slot,
          child: Center(child: icon),
        ),
      GlassBarCustomItem(:final child) => child,
    };

    content = IconTheme.merge(
      data: IconThemeData(
        size: GlassNavPinnedMetrics.iconSize,
        color: CupertinoColors.label.resolveFrom(context),
      ),
      child: content,
    );

    if (!item.enabled) {
      content = Opacity(opacity: 0.5, child: content);
    }

    return Semantics(
      button: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? (onMenuTap ?? item.onTap) : null,
        child: content,
      ),
    );
  }
}
