import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import '../../../src/renderer/liquid_glass_renderer.dart';
import '../../../types/glass_quality.dart';
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

  /// Window during which a matched item's icon cross-fades.
  static const double crossFadeStart = 0.3;

  /// End of the icon cross-fade window.
  static const double crossFadeEnd = 0.7;

  /// Point in the transition at which the chrome switches from showing the
  /// outgoing route's configuration to the incoming one.
  static const double swapAt = 0.5;

  /// Whether the actions capsule is visible at transition [progress].
  ///
  /// Appearing and disappearing are deliberately **not** animated. Scaling a
  /// cluster in or out looked wrong in both directions — an exit that drifts
  /// and shrinks, an entrance that grows — and neither matches the native bar,
  /// which cross-fades glass the package cannot cross-fade. The capsule is
  /// simply present or absent, switching once at [swapAt]. What does animate
  /// is the part that matters: a surviving capsule morphing in place.
  static bool capsuleVisibleAt({
    required bool fromEmpty,
    required bool toEmpty,
    required double progress,
  }) {
    if (fromEmpty && toEmpty) return false;
    if (fromEmpty) return progress >= swapAt;
    if (toEmpty) return progress < swapAt;
    return true;
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
/// It stays put for the whole transition. When the destination has no back
/// button — popping to the root — it is removed in a single switch at
/// [GlassNavPinnedMetrics.swapAt], like the capsule.
class _PinnedBackButton extends StatelessWidget {
  const _PinnedBackButton({required this.state, required this.coverageScale});

  final GlassNavPinnedState state;

  /// Retreat factor applied when an unregistered route covers the bar.
  final double coverageScale;

  @override
  Widget build(BuildContext context) {
    // Not animated in or out, for the same reason as the capsule: it is simply
    // shown or not, switching once at the same instant the capsule does.
    final shown = GlassNavPinnedMetrics.showsIncomingAt(state.progress)
        ? state.to.showsBackButton
        : state.from.showsBackButton;
    if (!shown || coverageScale <= 0.01) return const SizedBox.shrink();

    return Transform.scale(
      scale: coverageScale,
      alignment: Alignment.centerLeft,
      child: IgnorePointer(
        ignoring: !state.settled,
        child: GlassButton(
          icon: const Icon(CupertinoIcons.back),
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

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPinnedCluster(
        orders: orders,
        widthT: widthT,
        positionT: positionT,
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
    required double clusterHeight,
  })  : _orders = orders,
        _widthT = widthT,
        _positionT = positionT,
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

    final width = lerpDouble(fromTotal, toTotal, _widthT)!;
    size = constraints.constrain(Size(width, _clusterHeight));

    // Position every child by its interpolated distance from the trailing edge.
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
      final x = size.width - right - slotWidth;
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
        // Item contents are not glass, so fading them is safe — unlike the
        // capsule itself, which only ever animates geometry.
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
    final fromItems = state.from.actionItems;
    final toItems = state.to.actionItems;

    if (fromItems.isEmpty && toItems.isEmpty) return const SizedBox.shrink();

    final p = state.progress;
    // A symmetric curve, because this same interpolation is walked forwards on
    // a push and backwards on a pop. A directional ease reads correctly one way
    // and snaps the other — an easeIn exit becomes an instant entrance on pop.
    final eased = Curves.easeInOut.transform(p);

    // With one side empty the capsule holds the width it has: collapsing the
    // width would leave a degenerate glass shape on the way out.
    final widthT = fromItems.isEmpty
        ? 1.0
        : toItems.isEmpty
            ? 0.0
            : eased;
    final visible = GlassNavPinnedMetrics.capsuleVisibleAt(
      fromEmpty: fromItems.isEmpty,
      toEmpty: toItems.isEmpty,
      progress: p,
    );
    if (!visible || coverageScale <= 0.01) return const SizedBox.shrink();

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
    final q = ((p - GlassNavPinnedMetrics.crossFadeStart) /
            (GlassNavPinnedMetrics.crossFadeEnd -
                GlassNavPinnedMetrics.crossFadeStart))
        .clamp(0.0, 1.0);

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
              child: _ClusterItem(item: fromItem, enabled: false),
            ));
          }
        } else if (crossFades && (!state.settled ? q < 1.0 : !showsIncoming)) {
          // Cross-fading outgoing side.
          children.add(_ClusterChild(
            slot: i,
            isFrom: true,
            opacity: state.settled ? 1.0 : (1.0 - q),
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
    return Transform.scale(
      scale: coverageScale,
      alignment: Alignment.centerRight,
      child: IgnorePointer(
        ignoring: !state.settled,
        child: GlassMenu(
          controller: _menu,
          items: menuItem?.menuItems ?? const <Widget>[],
          menuAlignment: menuItem?.menuAlignment,
          // The fallback is never read: with no menu item there is no trigger
          // to open one. It matches GlassMenu's own default.
          menuWidth: menuItem?.menuWidth ?? 200,
          triggerBuilder: (context, _) => _buildCapsule(
            orders: orders,
            widthT: widthT,
            positionT: eased,
            children: children,
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
    required List<Widget> children,
  }) {
    return GlassButton.custom(
      onTap: () {},
      shape: const LiquidRoundedRectangle(
        borderRadius: GlassNavPinnedMetrics.capsuleRadius,
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
