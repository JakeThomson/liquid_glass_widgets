import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import '../../../src/renderer/liquid_glass_renderer.dart';
import '../../../types/glass_quality.dart';
import '../../effects/glass_materialize.dart';
import '../../effects/shared/glass_materialize_effect.dart';
import '../../interactive/glass_button.dart';
import '../../overlays/glass_menu.dart';
import '../../shared/glass_accessibility_scope.dart';
import '../../shared/glass_isolation_scope.dart';
import '../glass_app_bar.dart';
import '../glass_bar_item.dart';
import '../glass_navigation_shell.dart';

/// Geometry and timing constants for the pinned chrome.
///
/// Grouped here so the choreography can be tuned in one place.
///
/// The geometry members are exported so a bar that is not a [GlassAppBar] can
/// draw its in-route chrome to the same numbers; without that, the chrome
/// resizes at the moment the shell takes it over. The timing members
/// ([crossFadeStart], [crossFadeEnd], [swapAt], [capsuleStretch]) and the
/// helpers that read them describe the shell's own choreography and may be
/// retuned — align to the geometry, not to these.
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

  /// Stretch factor of a shell that shares with nothing, matching the
  /// [GlassButton] default a lone circular button has always used.
  static const double buttonStretch = 0.5;

  /// Gap between two shells within one cluster.
  ///
  /// Matches the gap the bar itself leaves between its leading and actions
  /// slots, so a split cluster reads the same in-route and pinned.
  static const double groupGap = 8.0;

  /// Window during which a matched item's icon cross-fades.
  static const double crossFadeStart = 0.3;

  /// End of the icon cross-fade window.
  static const double crossFadeEnd = 0.7;

  /// Point in the transition at which the chrome switches from showing the
  /// outgoing route's configuration to the incoming one.
  static const double swapAt = 0.5;

  /// Start of the window over which an appearing cluster materializes, in
  /// route progress. The window ends at 1.0.
  ///
  /// It straddles [swapAt] deliberately: the configuration must swap while
  /// the cluster is still partially dissolved, never while it is fully solid.
  static const double materializeStart = 0.45;

  /// Scale a cluster swells to while dematerialized, from the native
  /// capture. Gentler than the standalone default: the bar's clusters are
  /// anchored to an edge, where a deep scale reads as a slide.
  static const double materializeScaleFrom = 1.1;

  /// End of the window over which a disappearing cluster dematerializes, in
  /// route progress. The window starts at 0.0.
  static const double dematerializeEnd = 0.55;

  /// The materialize phase of a cluster at transition [progress]:
  /// 0.0 = fully dematerialized (not built), 1.0 = settled glass.
  ///
  /// A cluster only the incoming route has materializes over the tail of the
  /// transition; one only the outgoing route has dematerializes over the
  /// head. Both are pure functions of [progress], so a pop — which runs the
  /// same value backwards — plays each window in reverse and the exit still
  /// leads the entrance in both directions, with no direction to get wrong.
  ///
  /// [progress] is not raw route progress during an interactive back-swipe:
  /// the shell holds it still until the gesture commits and then re-times it
  /// over the remaining travel, so the chrome never dissolves under a finger
  /// that may yet be lifted. See `GlassNavigationShellState._holdForGesture`.
  ///
  /// The windows are symmetric on purpose. The native asymmetry — an exit
  /// that lingers past its entrance — lives in the effect's own sub-curves,
  /// where it survives a reversed transition; encoding it here as
  /// direction-aware windows would snap when a swipe reverses mid-flight,
  /// for the same reason the capsule's geometry curve is symmetric.
  static double clusterPhaseAt({
    required bool inFrom,
    required bool inTo,
    required double progress,
  }) {
    if (inFrom && inTo) return 1.0;
    if (!inFrom && !inTo) return 0.0;
    if (inTo) {
      return ((progress - materializeStart) / (1.0 - materializeStart))
          .clamp(0.0, 1.0);
    }
    return 1.0 - (progress / dematerializeEnd).clamp(0.0, 1.0);
  }

  /// Which side's configuration is showing at transition [progress].
  static bool showsIncomingAt(double progress) => progress >= swapAt;
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
    required this.topRoute,
    this.transition = GlassEffectTransition.materialize,
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

  /// The topmost registered route, used for the default back action.
  final ModalRoute<dynamic> topRoute;

  /// How clusters that appear or disappear outright transition.
  ///
  /// Set from [GlassNavigationShell.effectTransition]; the host downgrades
  /// it to [GlassEffectTransition.identity] under reduce motion.
  final GlassEffectTransition transition;
}

/// Renders the pinned leading and trailing clusters above the [Navigator].
///
/// A surviving cluster keeps one persistent glass shell whose geometry
/// animates; its element is never remounted mid-morph, because a glass
/// surface's backdrop pass renders fully or not at all and a shell that
/// remounts pops. Clusters that appear or disappear outright materialize
/// instead, over the windows in [GlassNavPinnedMetrics.clusterPhaseAt] — the
/// effect dissolves the cluster's *composited own layer* through the shader's
/// own visibility uniform, which is a fade the backdrop pass does honour.
class GlassNavPinnedHost extends StatelessWidget {
  /// Creates the pinned host for the given frame [state].
  const GlassNavPinnedHost({super.key, required this.state});

  /// The chrome to render.
  final GlassNavPinnedState state;

  /// The phase an appearing or disappearing cluster is at, honouring the
  /// shell's [GlassEffectTransition] and the user's reduce-motion setting.
  ///
  /// [GlassEffectTransition.identity] collapses the window back to the single
  /// switch at [GlassNavPinnedMetrics.swapAt] this chrome used before the
  /// effect existed, which is also what reduce motion selects — the effect's
  /// own reduce-motion path drops the scale and blur but still cross-fades,
  /// and a bar that dissolves on every push is the motion being asked about.
  static double phaseFor(
    BuildContext context,
    GlassNavPinnedState state, {
    required bool inFrom,
    required bool inTo,
  }) {
    final identity = state.transition == GlassEffectTransition.identity ||
        GlassAccessibilityData.of(context).reduceMotion;
    if (identity) {
      if (inFrom && inTo) return 1.0;
      if (!inFrom && !inTo) return 0.0;
      final showsIncoming =
          GlassNavPinnedMetrics.showsIncomingAt(state.progress);
      return (inTo ? showsIncoming : !showsIncoming) ? 1.0 : 0.0;
    }
    return GlassNavPinnedMetrics.clusterPhaseAt(
      inFrom: inFrom,
      inTo: inTo,
      progress: state.progress,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final settings = state.to.buttonSettings ?? state.from.buttonSettings;
    final textDirection = Directionality.of(context);

    // Everything retreats together when an unregistered route covers the bar.
    // Each cluster scales about its own anchored edge: scaling the full-width
    // Stack instead would drag both clusters toward the centre.
    final coverageScale = 1.0 - Curves.easeIn.transform(state.coverage);
    if (coverageScale <= 0.01) return const SizedBox.shrink();

    Widget chrome = Stack(
      clipBehavior: Clip.none,
      children: [
        for (final side in _BarSide.values)
          Positioned.directional(
            textDirection: textDirection,
            start: side == _BarSide.leading ? 0 : null,
            end: side == _BarSide.trailing ? 0 : null,
            top: 0,
            child: _PinnedSide(
              state: state,
              side: side,
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
// Clusters
// =============================================================================

/// Which edge of the bar a cluster is anchored to.
///
/// Direction-relative, not absolute: the leading cluster sits on the left in
/// LTR and on the right in RTL, matching the bar's own leading slot.
enum _BarSide { leading, trailing }

/// One glass shell's worth of items within a cluster.
///
/// Mirrors the grouping iOS 26 derives from `UIBarButtonItem.sharesBackground`
/// and `hidesSharedBackground`: consecutive shared items form one capsule, and
/// anything else stands alone.
///
/// Shared with [GlassAppBar]'s in-route fallback so the two paths group and
/// size items identically; this library is not exported from the package
/// barrel.
@immutable
class GlassNavBarGroup {
  /// Creates a group of items sharing one background.
  const GlassNavBarGroup({required this.items, required this.background});

  /// The items sharing this group's background, leading to trailing.
  final List<GlassBarActionItem> items;

  /// How this group's background is drawn, taken from its items.
  final GlassBarItemBackground background;

  /// Whether a glass shell is drawn behind [items].
  bool get glass => background != GlassBarItemBackground.none;

  /// Height of the shell, and of an icon slot inside it.
  ///
  /// A group that shares with nothing is the 44pt circular button iOS 26 draws
  /// for a lone bar item — at that height the capsule's 22pt radius is clamped
  /// to exactly half the box, so the rounded rectangle *is* a circle. A shared
  /// capsule keeps the taller icon-slot height it has always had.
  double get height => background == GlassBarItemBackground.shared
      ? GlassNavPinnedMetrics.slot
      : GlassNavPinnedMetrics.backDiameter;

  /// Width of an icon slot inside the shell, square with [height].
  double get slotWidth => height;

  /// Press-stretch factor for the shell.
  double get stretch => background == GlassBarItemBackground.shared
      ? GlassNavPinnedMetrics.capsuleStretch
      : GlassNavPinnedMetrics.buttonStretch;
}

/// Splits a cluster's items into the shells that will actually be drawn.
///
/// Runs of [GlassBarItemBackground.shared] items collapse into one group;
/// every other item stands alone, so it can be given its own shell or none.
///
/// Shared with [GlassAppBar]'s in-route fallback; this library is not exported
/// from the package barrel.
List<GlassNavBarGroup> groupGlassNavBarItems(List<GlassBarActionItem> items) {
  final groups = <GlassNavBarGroup>[];
  var run = <GlassBarActionItem>[];

  void flushRun() {
    if (run.isEmpty) return;
    groups.add(GlassNavBarGroup(
      items: run,
      background: GlassBarItemBackground.shared,
    ));
    run = <GlassBarActionItem>[];
  }

  for (final item in items) {
    if (item.background == GlassBarItemBackground.shared) {
      run.add(item);
      continue;
    }
    flushRun();
    groups.add(GlassNavBarGroup(items: [item], background: item.background));
  }
  flushRun();
  return groups;
}

/// The two sides a group interpolates between at [progress].
///
/// A glass shell and a bare item cannot morph into one another, because that
/// would mean fading glass in or out. Dropping the side that is not showing
/// turns the pair into an exit followed by an entrance, which the single
/// switch at [GlassNavPinnedMetrics.swapAt] already handles.
({GlassNavBarGroup? from, GlassNavBarGroup? to}) _resolveGroupSides(
  GlassNavBarGroup? from,
  GlassNavBarGroup? to,
  double progress,
) {
  if (from != null && to != null && from.glass != to.glass) {
    return GlassNavPinnedMetrics.showsIncomingAt(progress)
        ? (from: null, to: to)
        : (from: from, to: null);
  }
  return (from: from, to: to);
}

/// Whether a group draws anything at [state]'s progress.
///
/// The cluster asks before laying out, so a group that is switched off takes
/// no gap in the row either. Asked of the materialize phase rather than of a
/// hard switch: a group part-way through its window is still drawing, and
/// dropping it there would pop the very transition the window exists to play.
bool _groupShowsAt(
  BuildContext context,
  GlassNavPinnedState state,
  GlassNavBarGroup? from,
  GlassNavBarGroup? to,
) {
  final sides = _resolveGroupSides(from, to, state.progress);
  if (sides.from == null && sides.to == null) return false;
  return GlassNavPinnedHost.phaseFor(
        context,
        state,
        inFrom: sides.from != null,
        inTo: sides.to != null,
      ) >
      0.0;
}

/// Identity carried by the automatic back button.
///
/// Gives it the same standing as an item with an explicit `id`, so a back
/// button that survives a transition holds its place instead of being matched
/// positionally against whatever the destination happens to put first.
const Object _backItemId = #glassNavBackItem;

/// One edge's worth of pinned chrome.
///
/// Resolves each route's items for this side — synthesising the automatic back
/// button as the leading cluster's first item — splits both into groups, and
/// renders one [_PinnedGroup] per group. Groups are matched across routes by
/// position, which is enough while a cluster is one shell in every case the
/// package renders today.
class _PinnedSide extends StatelessWidget {
  const _PinnedSide({
    required this.state,
    required this.side,
    required this.coverageScale,
  });

  final GlassNavPinnedState state;
  final _BarSide side;

  /// Retreat factor applied when an unregistered route covers the bar.
  final double coverageScale;

  /// The automatic back button, as an ordinary item.
  ///
  /// Built here rather than stored on the registration because its label is
  /// localised, and that needs a context. It shares with nothing, which is
  /// what makes a back-only cluster the circle it has always been.
  GlassBarIconItem _backItem(
    BuildContext context,
    GlassNavBarRegistration registration,
  ) {
    return GlassBarIconItem(
      icon: const Icon(CupertinoIcons.back),
      id: _backItemId,
      label: Localizations.of<CupertinoLocalizations>(
            context,
            CupertinoLocalizations,
          )?.backButtonLabel ??
          // The same string DefaultCupertinoLocalizations returns, for apps
          // that ship no localizations delegates at all.
          'Back',
      background: GlassBarItemBackground.separate,
      onTap: () {
        final onBack = registration.onBack;
        if (onBack != null) {
          onBack();
        } else {
          state.topRoute.navigator?.maybePop();
        }
      },
    );
  }

  /// Everything this side renders for one route, back button included.
  List<GlassBarActionItem> _itemsFor(
    BuildContext context,
    GlassNavBarRegistration registration,
  ) {
    if (side == _BarSide.trailing) return registration.actionItems;
    final leading = registration.leadingItems;
    if (!registration.showsBackButton) return leading;
    return [_backItem(context, registration), ...leading];
  }

  @override
  Widget build(BuildContext context) {
    if (coverageScale <= 0.01) return const SizedBox.shrink();

    final fromGroups = groupGlassNavBarItems(_itemsFor(context, state.from));
    final toGroups = groupGlassNavBarItems(_itemsFor(context, state.to));
    final count = math.max(fromGroups.length, toGroups.length);
    if (count == 0) return const SizedBox.shrink();

    // Anchored at the box's left edge when this side sits on the left, so each
    // cluster grows away from the bar edge it is pinned to.
    final ltr = Directionality.of(context) == TextDirection.ltr;
    final anchoredAtStart = (side == _BarSide.leading) == ltr;

    return Transform.scale(
      scale: coverageScale,
      alignment: side == _BarSide.leading
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: IgnorePointer(
        ignoring: !state.settled,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: GlassNavPinnedMetrics.groupGap,
          children: [
            for (var i = 0; i < count; i++)
              if (_groupShowsAt(
                context,
                state,
                i < fromGroups.length ? fromGroups[i] : null,
                i < toGroups.length ? toGroups[i] : null,
              ))
                _PinnedGroup(
                  // Keyed by position so a surviving shell keeps its element:
                  // a glass surface that remounts mid-morph pops its backdrop.
                  key: ValueKey<int>(i),
                  state: state,
                  from: i < fromGroups.length ? fromGroups[i] : null,
                  to: i < toGroups.length ? toGroups[i] : null,
                  anchoredAtStart: anchoredAtStart,
                ),
          ],
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
/// Public for testing; held back from the barrel's `show` clause.
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
/// [anchoredAtStart] follows the cluster it is matching: a trailing cluster
/// counts positions from its trailing edge, a leading one from its leading
/// edge. Either way an item keeps its place when items are added on the far
/// side of the cluster from the bar edge it is pinned to.
///
/// Public for testing; held back from the barrel's `show` clause.
@visibleForTesting
List<GlassNavActionSlot> matchGlassNavActions(
  List<GlassBarActionItem> from,
  List<GlassBarActionItem> to, {
  bool anchoredAtStart = false,
}) {
  // Slot index counts from the anchored edge, because that is the edge the
  // cluster grows away from.
  int slotOf(int index, int length) =>
      anchoredAtStart ? index : length - 1 - index;

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
    // 2. Positional fallback, counting from the anchored edge. An item
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
    required this.height,
    required this.anchoredAtStart,
    required super.children,
  });

  /// Per-slot placement in each cluster, indexed by slot.
  final List<_SlotOrder> orders;

  /// Interpolation for the overall width.
  final double widthT;

  /// Interpolation for per-item positions and widths.
  final double positionT;

  /// Fixed cluster height.
  final double height;

  /// Whether items are placed relative to the box's left edge.
  ///
  /// The cluster's width changes across a morph, so only the anchored edge
  /// holds still — items measured from the other one would drift as the shell
  /// resized around them.
  final bool anchoredAtStart;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPinnedCluster(
        orders: orders,
        widthT: widthT,
        positionT: positionT,
        clusterHeight: height,
        anchoredAtStart: anchoredAtStart,
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
      ..clusterHeight = height
      ..anchoredAtStart = anchoredAtStart;
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
    required double clusterHeight,
    required bool anchoredAtStart,
  })  : _orders = orders,
        _widthT = widthT,
        _positionT = positionT,
        _clusterHeight = clusterHeight,
        _anchoredAtStart = anchoredAtStart;

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

  double _clusterHeight;
  set clusterHeight(double value) {
    if (_clusterHeight == value) return;
    _clusterHeight = value;
    markNeedsLayout();
  }

  bool _anchoredAtStart;
  set anchoredAtStart(bool value) {
    if (_anchoredAtStart == value) return;
    _anchoredAtStart = value;
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

    // Distance from the cluster's anchored edge for each slot, per side.
    final fromEdge = List<double?>.filled(slotCount, null);
    final toEdge = List<double?>.filled(slotCount, null);

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
      // Walk leading to trailing, recording how far each slot sits from the
      // anchored edge — which is what it consumed on the way there, or what is
      // left beyond it when the far edge is the anchor.
      var consumed = 0.0;
      for (final slot in ordered) {
        final w = widthOf(slot, from: from);
        final edge = _anchoredAtStart ? consumed : total - consumed - w;
        if (from) {
          fromEdge[slot] = edge;
        } else {
          toEdge[slot] = edge;
        }
        consumed += w;
      }
      return total;
    }

    final fromTotal = layoutSide(from: true);
    final toTotal = layoutSide(from: false);

    final width = lerpDouble(fromTotal, toTotal, _widthT)!;
    size = constraints.constrain(Size(width, _clusterHeight));

    // Position every child by its interpolated distance from the anchored edge.
    child = firstChild;
    while (child != null) {
      final data = child.parentData! as _ClusterParentData;
      final slot = data.slot;
      final edge = lerpDouble(
        fromEdge[slot] ?? toEdge[slot] ?? 0.0,
        toEdge[slot] ?? fromEdge[slot] ?? 0.0,
        _positionT,
      )!;
      final slotWidth = lerpDouble(
        widthOf(slot, from: true),
        widthOf(slot, from: false),
        _positionT,
      )!;
      final x = _anchoredAtStart ? edge : size.width - edge - slotWidth;
      data.offset = Offset(
        x + (slotWidth - child.size.width) / 2.0,
        (size.height - child.size.height) / 2.0,
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
    return constraints.constrain(Size(width, _clusterHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _ClusterParentData;
      final childOffset = offset + data.offset;
      if (data.opacity >= 1.0) {
        context.paintChild(child, childOffset);
      } else if (data.opacity > 0.0) {
        // Item contents are not glass, so fading them here is safe — the
        // capsule's own shell dissolves through the shader instead.
        context.pushOpacity(
          childOffset,
          (data.opacity * 255).round(),
          (ctx, off) => ctx.paintChild(child!, off),
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

/// Applies a per-child opacity through the cluster's parent data.
class _ClusterChild extends ParentDataWidget<_ClusterParentData> {
  const _ClusterChild({
    required this.slot,
    required this.isFrom,
    required this.opacity,
    required super.child,
  });

  final int slot;
  final bool isFrom;
  final double opacity;

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
// One group's shell
// -----------------------------------------------------------------------------

/// One group of a cluster, on both routes, interpolated.
///
/// A group that survives a transition keeps one persistent glass shell whose
/// geometry animates; its element is never remounted mid-morph. While both
/// routes have the group the shell only animates geometry; when just one does
/// it materializes in or out around that geometry. The items inside it —
/// which are not glass — cross-fade freely either way.
class _PinnedGroup extends StatefulWidget {
  const _PinnedGroup({
    super.key,
    required this.state,
    required this.from,
    required this.to,
    required this.anchoredAtStart,
  });

  final GlassNavPinnedState state;

  /// This group on the outgoing route, or null if it only enters.
  final GlassNavBarGroup? from;

  /// This group on the incoming route, or null if it only exits.
  final GlassNavBarGroup? to;

  /// Whether items are placed relative to the box's left edge.
  final bool anchoredAtStart;

  @override
  State<_PinnedGroup> createState() => _PinnedGroupState();
}

class _PinnedGroupState extends State<_PinnedGroup> {
  /// Drives the pull-down of whichever item is currently the menu trigger.
  final GlassMenuController _menu = GlassMenuController();

  @override
  void didUpdateWidget(covariant _PinnedGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dismiss on the first unsettled frame. A route-owned menu goes away with
    // its route, but this shell outlives every route it serves, so an open
    // menu would otherwise hang over the bar while the page slid out from
    // under it.
    if (oldWidget.state.settled && !widget.state.settled && _menu.isOpen) {
      _menu.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final p = state.progress;
    final showsIncoming = GlassNavPinnedMetrics.showsIncomingAt(p);

    final sides = _resolveGroupSides(widget.from, widget.to, p);
    final from = sides.from;
    final to = sides.to;
    if (from == null && to == null) return const SizedBox.shrink();

    final fromItems = from?.items ?? const <GlassBarActionItem>[];
    final toItems = to?.items ?? const <GlassBarActionItem>[];

    // A symmetric curve, because this same interpolation is walked forwards on
    // a push and backwards on a pop. A directional ease reads correctly one way
    // and snaps the other — an easeIn exit becomes an instant entrance on pop.
    final eased = Curves.easeInOut.transform(p);

    // With one side empty the shell holds the width it has: collapsing the
    // width would leave a degenerate glass shape on the way out.
    final widthT = fromItems.isEmpty
        ? 1.0
        : toItems.isEmpty
            ? 0.0
            : eased;

    // Drives the materialize window for a group that only one route has. The
    // side has already dropped groups whose phase is zero, so this is only
    // ever a partial phase or a full one.
    final phase = GlassNavPinnedHost.phaseFor(
      context,
      state,
      inFrom: fromItems.isNotEmpty,
      inTo: toItems.isNotEmpty,
    );

    // Geometry for a side that does not exist comes from the side that does,
    // so an entering or exiting group holds its shape rather than resizing.
    final fromGroup = from ?? to!;
    final toGroup = to ?? from!;

    final slots = matchGlassNavActions(
      fromItems,
      toItems,
      anchoredAtStart: widget.anchoredAtStart,
    );

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

    // Where each slot sits within each group, leading to trailing.
    final orders = <_SlotOrder>[];
    var fromOrder = 0;
    var toOrder = 0;
    final fromOrders = <int, int>{};
    final toOrders = <int, int>{};
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].toItem != null) toOrders[i] = toOrder++;
    }
    // Outgoing order follows the outgoing group, not the slot list.
    for (final item in fromItems) {
      final i = slots.indexWhere((s) => identical(s.fromItem, item));
      if (i >= 0) fromOrders[i] = fromOrder++;
    }
    for (var i = 0; i < slots.length; i++) {
      orders.add(_SlotOrder(fromOrder: fromOrders[i], toOrder: toOrders[i]));
    }

    // Cross-fade window for a matched item whose content changed, and
    // entering / exiting items during a morph.
    final q = ((p - GlassNavPinnedMetrics.crossFadeStart) /
            (GlassNavPinnedMetrics.crossFadeEnd -
                GlassNavPinnedMetrics.crossFadeStart))
        .clamp(0.0, 1.0);

    final morphing = fromItems.isNotEmpty && toItems.isNotEmpty;

    final children = <Widget>[];
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final crossFades = slot.crossFades;
      final fromItem = slot.fromItem;
      final toItem = slot.toItem;

      if (fromItem != null) {
        if (toItem == null) {
          // Exiting item: smoothly fade out with (1 - q) across the transition window.
          // While transition is in-flight, keep mounted in morphing groups so natural width is preserved.
          final visible =
              state.settled ? !showsIncoming : (morphing || q < 1.0);
          if (visible) {
            children.add(_ClusterChild(
              slot: i,
              isFrom: true,
              opacity: state.settled ? 1.0 : (1.0 - q),
              child: _ClusterItem(
                item: fromItem,
                enabled: false,
                slotWidth: fromGroup.slotWidth,
              ),
            ));
          }
        } else if (crossFades && (!state.settled ? q < 1.0 : !showsIncoming)) {
          // Cross-fading outgoing side.
          children.add(_ClusterChild(
            slot: i,
            isFrom: true,
            opacity: state.settled ? 1.0 : (1.0 - q),
            child: _ClusterItem(
              item: fromItem,
              enabled: false,
              slotWidth: fromGroup.slotWidth,
            ),
          ));
        }
      }

      if (toItem != null) {
        if (fromItem == null) {
          // Entering item: smoothly fade in with q across the transition window.
          // While transition is in-flight, keep mounted in morphing groups so natural width is preserved.
          final visible = state.settled ? showsIncoming : (morphing || q > 0.0);
          if (visible) {
            children.add(_ClusterChild(
              slot: i,
              isFrom: false,
              opacity: state.settled ? 1.0 : q,
              child: _ClusterItem(
                item: toItem,
                enabled: state.settled,
                slotWidth: toGroup.slotWidth,
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
            child: _ClusterItem(
              item: toItem,
              enabled: state.settled,
              slotWidth: toGroup.slotWidth,
              onMenuTap: identical(toItem, menuItem) ? _menu.open : null,
            ),
          ));
        }
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();

    final cluster = _PinnedCluster(
      orders: orders,
      widthT: widthT,
      positionT: eased,
      height: lerpDouble(fromGroup.height, toGroup.height, eased)!,
      anchoredAtStart: widget.anchoredAtStart,
      children: children,
    );

    // Both wrappers are unconditional, even at rest and even with no menu
    // item: inserting or removing either would remount the group's element,
    // and a glass shell that remounts mid-morph pops its backdrop. At a phase
    // of 1.0 the effect is paint-neutral, and a closed GlassMenu adds only
    // inert wrappers and mounts no overlay, so the resting case costs nothing.
    return GlassMaterializeEffect(
      progress: phase,
      // The window this group traverses is the incoming one exactly when it is
      // the incoming route that has it; the profile follows from the same
      // fact, so a pop reverses both together.
      profile: toItems.isNotEmpty
          ? GlassMaterializeProfile.entrance
          : GlassMaterializeProfile.exit,
      // It swells from the bar edge its cluster is pinned to.
      alignment:
          widget.anchoredAtStart ? Alignment.centerLeft : Alignment.centerRight,
      scaleFrom: GlassNavPinnedMetrics.materializeScaleFrom,
      child: GlassMenu(
        controller: _menu,
        items: menuItem?.menuItems ?? const <Widget>[],
        menuAlignment: menuItem?.menuAlignment,
        // The fallback is never read: with no menu item there is no trigger
        // to open one. It matches GlassMenu's own default.
        menuWidth: menuItem?.menuWidth ?? 200,
        triggerBuilder: (context, _) => toGroup.glass
            ? _buildShell(
                cluster: cluster,
                stretch: lerpDouble(fromGroup.stretch, toGroup.stretch, eased)!,
              )
            : cluster,
      ),
    );
  }

  /// The glass shell itself, sized by the measured cluster.
  ///
  /// Split out so it can be handed to [GlassMenu.triggerBuilder] — the menu
  /// morphs the whole shell, not the tapped item's slot, matching iOS 26's
  /// `GlassEffectContainer`.
  ///
  /// The radius is the capsule's in every case: clamped to half the box, it is
  /// a capsule at the shared-cluster height and exactly a circle at the height
  /// a group that shares with nothing uses.
  Widget _buildShell({required Widget cluster, required double stretch}) {
    return GlassButton.custom(
      onTap: () {},
      shape: const LiquidRoundedRectangle(
        borderRadius: GlassNavPinnedMetrics.capsuleRadius,
      ),
      // Sized by the measured cluster, exactly as GlassButtonGroup.icons
      // sizes to its content.
      width: null,
      height: null,
      stretch: stretch,
      useOwnLayer: true,
      canRequestFocus: false,
      excludeFromSemantics: true,
      child: ClipRect(child: cluster),
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
    required this.slotWidth,
    this.onMenuTap,
  });

  final GlassBarActionItem item;
  final bool enabled;

  /// Width an icon is padded to, matching the height of the group it sits in.
  final double slotWidth;

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
          width: slotWidth,
          child: Center(child: icon),
        ),
      GlassBarMenuItem(:final icon) => SizedBox(
          width: slotWidth,
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
