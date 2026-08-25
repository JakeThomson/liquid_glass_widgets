part of '../glass_modal_sheet.dart';

// ===========================================================================
// Liquid Morph presentation for GlassModalSheet
// ===========================================================================
//
// The second consumer of the Liquid Morph Engine (docs/LIQUID_MORPH_ENGINE.md),
// after GlassMenu. Where GlassMenu morphs a trigger button into a floating menu,
// this morphs a trigger button into a presented modal sheet: the trigger empties,
// a glass droplet detaches and inflates while travelling down the J-curve, and
// lands exactly on the sheet's resting frame. Dismissal reverses it.
//
// ─── Why the sheet is not itself Blob B ──────────────────────────────────────
//
// The teardrop "neck" is drawn by the SDF metaball shader, which only bridges
// shapes that share ONE glass layer's blend group. The real sheet owns its own
// AdaptiveGlass layer (see _SheetLayout), so it structurally cannot merge with
// the trigger ghost. The morph therefore renders its own two-blob droplet and
// hands off to the real sheet at the settled instant — when both are motionless
// and share the exact same frame, so the swap is invisible.
//
// That handoff is also why SheetMorphGeometry derives the destination from
// SheetGeometry.positionForState — the same call the sheet's own metrics use —
// instead of a parallel calculation that could drift out of agreement.

/// The widget a [GlassModalSheet] morphs out of, and the channel that empties
/// it while the morph is in flight.
///
/// An opaque token: it carries no members a caller can use. [GlassMorphTrigger]
/// creates one, hands it to its builder, and disposes it; callers pass it
/// straight to [GlassModalSheet.show] as `morphFrom` and never touch it
/// otherwise. The constructor is private so one cannot be made by hand — an
/// anchor with no trigger behind it has nothing to empty.
///
/// ## Why a token rather than a bare [GlobalKey]
///
/// A key can only *locate* the trigger. Reading its rect is enough to aim the
/// morph, but not to make the trigger look like it empties — and a trigger that
/// stays painted while a glass droplet inflates on top of it reads as a
/// duplicated button, not a morph. Nothing in Flutter lets one widget hide
/// another it does not own, so the trigger has to cooperate: [GlassMorphTrigger]
/// owns the key *and* the opacity, and this token is how the presented sheet
/// reaches back to it.
///
/// `GlassMenu` does the same thing internally with its own trigger; this is that
/// arrangement made available to a trigger the sheet does not own.
class GlassMorphAnchor {
  GlassMorphAnchor._();

  /// Identifies the trigger's subtree so its global rect can be resolved at
  /// `show()` time.
  final GlobalKey _key = GlobalKey();

  /// Broadcasts state changes to the owning [GlassMorphTrigger].
  ///
  /// Held rather than inherited so this type stays a plain token: extending
  /// [ChangeNotifier] would put `addListener` and `dispose` on the public
  /// surface, and a caller disposing their own anchor would strand the morph.
  final _AnchorNotifier _notifier = _AnchorNotifier();

  bool _emptied = false;
  _MorphHandback? _handback;
  bool _disposed = false;

  /// The trigger's rect in global coordinates, or null when it is not currently
  /// laid out.
  Rect? get _rect {
    final renderObject = _key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  /// Hides the trigger so the morph's anchor blob can stand in for it.
  void _empty() {
    if (_disposed) return;
    _handback = null;
    if (_emptied) return;
    _emptied = true;
    _notify();
  }

  /// Hands the trigger back at the moment the droplet is caught, passing the
  /// spring's live state so the trigger can carry the bounce the rest of the
  /// way itself.
  ///
  /// The presented route is torn down as soon as the droplet lands — otherwise
  /// its modal barrier would keep swallowing taps on a button that is visibly
  /// back — so the tail of the bounce cannot be driven from there. [travel] is
  /// the trigger-centre → sheet-centre vector the droplet came home along;
  /// [value] and [velocity] are the closing spring's state at the catch, so the
  /// trigger's own simulation continues it without a seam.
  void _handBack({
    required Offset travel,
    required double value,
    required double velocity,
  }) {
    if (_disposed || !_emptied) return;
    _emptied = false;
    _handback = _MorphHandback(travel, value, velocity);
    _notify();
  }

  /// Restores the trigger with no bounce.
  ///
  /// The safety net for a route torn down without the closing morph ever
  /// running — a Navigator reset, a hot restart. Leaving the trigger emptied
  /// would erase a live button.
  void _restore() {
    if (_disposed || !_emptied) return;
    _emptied = false;
    _handback = null;
    _notify();
  }

  void _dispose() {
    _disposed = true;
    _notifier.dispose();
  }

  /// Notifies the trigger without ever marking it dirty mid-build.
  ///
  /// The presenter drives this from its own lifecycle — `didChangeDependencies`
  /// on the way in, `dispose` on the way out — both of which run while the tree
  /// is being built or is locked, where `setState` on the listening trigger is
  /// illegal. Deferring to the end of the frame in those phases costs the
  /// trigger one frame, during which the droplet is still exactly on top of it,
  /// so nothing shows.
  void _notify() {
    final binding = WidgetsBinding.instance;
    final phase = binding.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      binding.addPostFrameCallback((_) {
        if (!_disposed) _notifier.notify();
      });
      return;
    }
    _notifier.notify();
  }
}

/// Minimal [ChangeNotifier] subclass exposing [notifyListeners] as [notify], so
/// [GlassMorphAnchor] can hold one instead of being one.
///
/// Mirrors `_ProgressNotifier` in `glass_modal_sheet_state.dart`.
class _AnchorNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// The closing spring's state at the instant the trigger catches the droplet.
class _MorphHandback {
  const _MorphHandback(this.travel, this.value, this.velocity);

  /// Trigger centre → sheet centre. The bounce is along this vector.
  final Offset travel;

  /// Spring position at the catch — near zero, heading into the undershoot.
  final double value;

  /// Spring velocity at the catch, so the trigger's simulation continues it.
  final double velocity;
}

/// Wraps the widget a [GlassModalSheet] morphs out of, so the trigger can empty
/// itself while the morph runs and take the hit when the droplet comes home.
///
/// The builder receives a [GlassMorphAnchor] to pass to
/// [GlassModalSheet.show] as `morphFrom`:
///
/// ```dart
/// GlassMorphTrigger(
///   builder: (context, anchor) => GlassButton(
///     onTap: () => GlassModalSheet.show(
///       context: context,
///       morphFrom: anchor,
///       builder: (context) => const MySheetBody(),
///     ),
///     child: const Icon(CupertinoIcons.add),
///   ),
/// )
/// ```
///
/// While the sheet is presented the child paints nothing — the morph's anchor
/// blob stands in for it, so the two never appear at once. When the droplet
/// lands, the child is restored and *this widget* runs the rest of the closing
/// bounce on its own ticker, so it keeps easing home after the presented route
/// is gone. The button is tappable throughout that tail, exactly as `GlassMenu`'s
/// trigger is: grabbing it cancels the bounce and opens again.
///
/// Without this wrapper `GlassModalSheet.show` still morphs (pass
/// `morphFromRect`), but it blooms from a point instead of stretching a
/// teardrop, because the anchor blob would otherwise duplicate a trigger it
/// cannot hide.
class GlassMorphTrigger extends StatefulWidget {
  /// Creates a new [GlassMorphTrigger].
  const GlassMorphTrigger({super.key, required this.builder});

  /// Builds the trigger, given the [GlassMorphAnchor] to present with.
  final Widget Function(BuildContext context, GlassMorphAnchor anchor) builder;

  @override
  State<GlassMorphTrigger> createState() => _GlassMorphTriggerState();
}

class _GlassMorphTriggerState extends State<GlassMorphTrigger>
    with SingleTickerProviderStateMixin {
  final GlassMorphAnchor _anchor = GlassMorphAnchor._();

  /// Drives the tail of the closing bounce, after the presented route — and the
  /// controller that started the spring — has been torn down.
  late final AnimationController _bounce =
      AnimationController.unbounded(vsync: this);

  /// Built once, not per build: [AnimatedBuilder] compares listenables by
  /// identity, so merging inline would resubscribe on every rebuild.
  late final Listenable _repaint =
      Listenable.merge([_anchor._notifier, _bounce]);

  /// Vector the current bounce swings along; zero when nothing is bouncing.
  Offset _travel = Offset.zero;

  @override
  void initState() {
    super.initState();
    _anchor._notifier.addListener(_onAnchorChanged);
  }

  @override
  void dispose() {
    _anchor._notifier.removeListener(_onAnchorChanged);
    _anchor._dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _onAnchorChanged() {
    if (!mounted) return;
    final handback = _anchor._handback;
    if (_anchor._emptied ||
        handback == null ||
        handback.travel == Offset.zero) {
      // A fresh open cancels any bounce still running — including one the user
      // interrupted by tapping the button mid-swing — and so does a plain
      // restore, which carries no momentum to continue.
      _bounce.stop();
      if (_travel != Offset.zero) setState(() => _travel = Offset.zero);
      return;
    }

    // Continue the closing spring from exactly where the presenter left it, so
    // the catch has no seam. The tail always runs the native-parity profile;
    // across the speed profiles this is a sub-pixel difference over a bounce
    // this small, and it keeps the trigger from having to know the speed.
    setState(() => _travel = handback.travel);
    _bounce.animateWith(
      SpringSimulation(
        LiquidMorphPhysics.closeSpring,
        handback.value,
        0.0,
        handback.velocity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _repaint,
      // The consumer's trigger is built here, not inside the builder below, so
      // the bounce repaints it without rebuilding their subtree every frame.
      child: KeyedSubtree(
        key: _anchor._key,
        child: widget.builder(context, _anchor),
      ),
      builder: (context, child) {
        // Opacity is toggled between 0 and 1 outright, never animated: a glass
        // surface's backdrop pass renders fully or not at all, so a partial
        // fade pops. The morph's anchor blob covers the visual transition.
        final emptied = _anchor._emptied;
        return Transform.translate(
          offset: _travel * _bounce.value,
          child: Opacity(
            opacity: emptied ? 0.0 : 1.0,
            child: IgnorePointer(ignoring: emptied, child: child),
          ),
        );
      },
    );
  }
}

/// Pure geometry for presenting a [GlassModalSheet] with a liquid morph.
///
/// Stateless and free of `BuildContext`, so every value the morph renders can
/// be unit-tested without a widget tree — the same contract
/// [LiquidMorphPhysics] follows.
///
/// [LiquidMorphPhysics] answers *how far along* the morph is; this answers
/// *where the sheet actually sits*, so the droplet can be aimed at it.
class SheetMorphGeometry {
  // Pure utility class — no instances.
  const SheetMorphGeometry._();

  /// The frame the sheet comes to rest in for [state], in global coordinates.
  ///
  /// Mirrors the resting output of the sheet's own per-frame metrics (see
  /// `_calculateMetrics` in `glass_modal_sheet_state.dart`) for the case that
  /// matters here: no drag in flight, no frozen pivot, no interaction pulse.
  /// The vertical position comes from [SheetGeometry.positionForState] rather
  /// than a re-derivation, so the droplet and the sheet cannot disagree about
  /// where the sheet is.
  ///
  /// The sheet's top edge is always `(1 - pos) * screenSize.height`; only the
  /// horizontal inset and the bottom overhang differ per detent:
  ///
  ///   • [GlassSheetState.full] — edge to edge, sunk past the bottom by
  ///     [bottomInset] + [bottomRadius] so its lower corners leave the screen.
  ///   • [GlassSheetState.half] — inset by [horizontalMargin] / [bottomMargin].
  ///   • [GlassSheetState.peek] — inset by the `peek*` overrides, falling back
  ///     to the base margins; [peekWidth] centres a fixed-width floor.
  ///   • [GlassSheetState.hidden] — collapses to a zero-height line at the
  ///     bottom edge; never a morph destination, but kept total for callers.
  static Rect restingRect({
    required GlassSheetState state,
    required SheetGeometry geometry,
    required Size screenSize,
    required double horizontalMargin,
    required double bottomMargin,
    required double bottomInset,
    required double bottomRadius,
    double? peekHorizontalMargin,
    double? peekBottomMargin,
    double? peekWidth,
  }) {
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    final pos = geometry.positionForState(state, screenHeight);

    // Every detent parks its top edge at the same place: the visual height is
    // measured down from the top, so `bottom`/`height` only redistribute the
    // remainder below it.
    final top = (1.0 - pos) * screenHeight;

    late final double hPad;
    late final double bottom;

    switch (state) {
      case GlassSheetState.full:
        // Expanded: margins are gone and the sheet sinks by `extraHeight` so
        // its bottom corners run off screen instead of floating.
        hPad = 0.0;
        bottom = -(bottomInset + bottomRadius);
        break;
      case GlassSheetState.peek:
        hPad = _peekHorizontalPad(
          screenWidth: screenWidth,
          horizontalMargin: horizontalMargin,
          peekHorizontalMargin: peekHorizontalMargin,
          peekWidth: peekWidth,
        );
        bottom = peekBottomMargin ?? bottomMargin;
        break;
      case GlassSheetState.half:
      case GlassSheetState.hidden:
        hPad = horizontalMargin;
        bottom = bottomMargin;
        break;
    }

    // A sheet narrower than its own margins (tiny test surfaces, extreme
    // margins) would invert the rect; clamp so the frame stays well-formed.
    final safeHPad = hPad.clamp(0.0, screenWidth / 2.0);
    return Rect.fromLTRB(
      safeHPad,
      top,
      screenWidth - safeHPad,
      math.max(top, screenHeight - bottom),
    );
  }

  /// Horizontal inset of the peek floor.
  ///
  /// [peekWidth] wins when set — a fixed-width floor is centred rather than
  /// inset — matching the sheet's own peek resolution.
  static double _peekHorizontalPad({
    required double screenWidth,
    required double horizontalMargin,
    double? peekHorizontalMargin,
    double? peekWidth,
  }) {
    if (peekWidth != null) {
      return ((screenWidth - peekWidth) / 2.0).clamp(0.0, screenWidth / 2.0);
    }
    return peekHorizontalMargin ?? horizontalMargin;
  }

  /// The frame of the travelling droplet (Blob B) for one morph frame.
  ///
  /// Size follows [LiquidMorphState.sizeT] and position follows
  /// [LiquidMorphState.pathT]; keeping them on separate curves is what opens
  /// the gap the metaball neck stretches across. Both are clamped to a
  /// non-negative size because the closing undershoot drives `sizeT` slightly
  /// below zero, which would otherwise trip a negative-constraint assert.
  static Rect blobRect({
    required Rect trigger,
    required Rect destination,
    required double pathT,
    required double sizeT,
  }) {
    final width =
        lerpDouble(trigger.width, destination.width, sizeT)!.clamp(0.0, 1e6);
    final height =
        lerpDouble(trigger.height, destination.height, sizeT)!.clamp(0.0, 1e6);

    final centerX =
        lerpDouble(trigger.center.dx, destination.center.dx, pathT)!;
    final centerY =
        lerpDouble(trigger.center.dy, destination.center.dy, pathT)!;

    return Rect.fromLTWH(
      centerX - width / 2.0,
      centerY - height / 2.0,
      width,
      height,
    );
  }

  /// Corner radius of the droplet as it inflates from [trigger] into the sheet.
  ///
  /// Starts fully rounded (a pill/circle the size of the trigger) and resolves
  /// to [target] late — `easeInExpo` holds the droplet round through the travel
  /// and only squares it off as it lands, which is what reads as *liquid*
  /// rather than a rectangle growing. The same curve GlassMenu uses.
  static double blobRadius({
    required Size blobSize,
    required double target,
    required double sizeT,
  }) {
    final maxRadius = math.min(blobSize.width, blobSize.height) / 2.0;
    final t = Curves.easeInExpo.transform(sizeT.clamp(0.0, 1.0));
    return lerpDouble(maxRadius, math.min(target, maxRadius), t)!;
  }

  /// Opacity of the droplet's solid fill, ramping in over the last 30 % of the
  /// size curve so the glass droplet has already arrived before it takes on the
  /// sheet's opaque surface.
  ///
  /// Fading the *fill* is safe; fading the glass itself is not — a shader
  /// backdrop pass renders fully or not at all, so an animated `Opacity` over
  /// it pops. The droplet's glass therefore stays at full strength for the
  /// whole morph and only this plain colour layer crossfades.
  static double fillReveal(double sizeT) =>
      ((sizeT - 0.7) / 0.3).clamp(0.0, 1.0);

  /// Opacity the sheet's solid fill rests at in [state].
  ///
  /// Mirrors the fill branches of `_calculateMetrics` at rest so the droplet
  /// lands wearing the surface the sheet is about to show: a glass half detent
  /// hands off to glass, an opaque full detent hands off to opaque colour.
  /// Returning the wrong value here would show as a one-frame flash at the
  /// handoff, which is exactly what the unit tests pin down.
  static double restingFillOpacity({
    required GlassSheetState state,
    required LiquidGlassSettings baseSettings,
    required bool enablePeek,
    LiquidGlassSettings? peekSettings,
    LiquidGlassSettings? halfSettings,
    LiquidGlassSettings? fullSettings,
  }) {
    final sPeek = peekSettings ?? baseSettings;
    final sHalf = halfSettings ?? baseSettings;
    final sFull = fullSettings ?? baseSettings;

    switch (state) {
      case GlassSheetState.full:
        // t == 1: the crossfade is complete whichever route got us here, so
        // only the explicit full-state settings can keep the surface glassy.
        if (fullSettings == null) return 1.0;
        return _fillFor(from: sHalf, to: sFull, t: 1.0);
      case GlassSheetState.half:
        // t == 0: the half→full crossfade hasn't started. Without explicit
        // full settings the sheet is opaque only when its own surface has no
        // blur to show through.
        if (fullSettings == null) {
          return (sHalf.blur == 0 || baseSettings.blur == 0) ? 1.0 : 0.0;
        }
        return _fillFor(from: sHalf, to: sFull, t: 0.0);
      case GlassSheetState.peek:
        if (!enablePeek) return sHalf.blur == 0 ? 1.0 : 0.0;
        return _fillFor(from: sPeek, to: sHalf, t: 0.0);
      case GlassSheetState.hidden:
        return 0.0;
    }
  }

  /// Resolves the fill opacity for a crossfade between two surfaces at [t].
  ///
  /// A surface with `blur == 0` is a solid colour, so the fill is whichever
  /// side of the crossfade is currently solid.
  static double _fillFor({
    required LiquidGlassSettings from,
    required LiquidGlassSettings to,
    required double t,
  }) {
    if (from.blur > 0 && to.blur == 0) return t;
    if (from.blur == 0 && to.blur > 0) return 1.0 - t;
    if (from.blur == 0 && to.blur == 0) return 1.0;
    return 0.0;
  }

  /// The glass settings the sheet rests on in [state], before the solid fill is
  /// composited over them. Mirrors the settings interpolation in
  /// `_calculateMetrics` at rest.
  static LiquidGlassSettings restingSettings({
    required GlassSheetState state,
    required LiquidGlassSettings baseSettings,
    required bool enablePeek,
    LiquidGlassSettings? peekSettings,
    LiquidGlassSettings? halfSettings,
    LiquidGlassSettings? fullSettings,
  }) {
    switch (state) {
      case GlassSheetState.full:
        return fullSettings ?? baseSettings;
      case GlassSheetState.peek:
        if (!enablePeek) return halfSettings ?? baseSettings;
        return peekSettings ?? baseSettings;
      case GlassSheetState.half:
      case GlassSheetState.hidden:
        return halfSettings ?? baseSettings;
    }
  }
}

/// Drives the liquid morph that presents [child] (a [GlassModalSheetScaffold]).
///
/// Owns a [GlassMorphController] and renders the two-blob droplet while the
/// morph is in flight, swapping to the real sheet at the settled instant.
///
/// The route's own animation is used only as a *signal* — its reverse status
/// starts the closing morph — never as the morph's clock. Mapping the engine
/// onto a linear route animation would discard the J-curve and the underdamped
/// catch, which are the whole effect.
///
/// Inserted by [GlassModalSheet.show] when a trigger is supplied; it is not
/// part of the package's public surface, but is left constructible so the morph
/// can be driven directly in tests (headless test runs report no Impeller, so
/// `show()` itself always takes the slide fallback there).
class GlassSheetMorphPresenter extends StatefulWidget {
  /// Creates a new [GlassSheetMorphPresenter].
  const GlassSheetMorphPresenter({
    super.key,
    required this.routeAnimation,
    required this.triggerRect,
    required this.anchor,
    required this.speed,
    required this.restingState,
    required this.geometry,
    required this.horizontalMargin,
    required this.bottomMargin,
    required this.topBorderRadius,
    required this.fullTopBorderRadius,
    required this.bottomBorderRadius,
    required this.fullBottomBorderRadius,
    required this.settings,
    required this.peekSettings,
    required this.halfSettings,
    required this.fullSettings,
    required this.expandedColor,
    required this.quality,
    required this.peekHorizontalMargin,
    required this.peekBottomMargin,
    required this.peekWidth,
    required this.peekTopBorderRadius,
    required this.platformViewBackdrop,
    required this.child,
  });

  /// The presenting route's animation. Watched for [AnimationStatus.reverse]
  /// so the closing morph starts the moment the route begins popping.
  final Animation<double> routeAnimation;

  /// Global rect of the widget the sheet morphs out of.
  final Rect triggerRect;

  /// The trigger this morph can empty, when there is one.
  ///
  /// Present: the anchor blob stands in for the hidden trigger and the teardrop
  /// neck stretches between them. Null: the trigger stays painted — so no
  /// anchor blob is drawn (it would duplicate the button) and the droplet
  /// blooms from [triggerRect]'s centre instead.
  final GlassMorphAnchor? anchor;

  /// Speed profile forwarded to the [GlassMorphController].
  final MorphSpeed speed;

  /// The detent the sheet comes to rest at — the morph's destination.
  final GlassSheetState restingState;

  /// Detent configuration, shared with the sheet so both resolve the same
  /// resting position.
  final SheetGeometry geometry;

  /// Sheet margins and radii, forwarded so the droplet lands on the sheet's
  /// exact frame.
  final double horizontalMargin;

  /// See [GlassModalSheet.bottomMargin].
  final double bottomMargin;

  /// See [GlassModalSheet.topBorderRadius].
  final double? topBorderRadius;

  /// See [GlassModalSheet.fullTopBorderRadius].
  final double? fullTopBorderRadius;

  /// See [GlassModalSheet.bottomBorderRadius].
  final double? bottomBorderRadius;

  /// See [GlassModalSheet.fullBottomBorderRadius].
  final double? fullBottomBorderRadius;

  /// See [GlassModalSheet.settings].
  final LiquidGlassSettings? settings;

  /// See [GlassModalSheet.peekSettings].
  final LiquidGlassSettings? peekSettings;

  /// See [GlassModalSheet.halfSettings].
  final LiquidGlassSettings? halfSettings;

  /// See [GlassModalSheet.fullSettings].
  final LiquidGlassSettings? fullSettings;

  /// See [GlassModalSheet.expandedColor].
  final Color? expandedColor;

  /// See [GlassModalSheet.quality].
  final GlassQuality? quality;

  /// See [GlassModalSheet.peekHorizontalMargin].
  final double? peekHorizontalMargin;

  /// See [GlassModalSheet.peekBottomMargin].
  final double? peekBottomMargin;

  /// See [GlassModalSheet.peekWidth].
  final double? peekWidth;

  /// See [GlassModalSheet.peekTopBorderRadius].
  final double? peekTopBorderRadius;

  /// See [GlassModalSheet.platformViewBackdrop]. Suppresses the metaball blend
  /// group, exactly as it does in the sheet and in `GlassMenu`.
  final bool platformViewBackdrop;

  /// The real sheet. Mounted for the whole morph — never remounted at the
  /// handoff — so its glass layers and springs are already seeded when it is
  /// revealed.
  final Widget child;

  @override
  State<GlassSheetMorphPresenter> createState() =>
      _GlassSheetMorphPresenterState();
}

class _GlassSheetMorphPresenterState extends State<GlassSheetMorphPresenter>
    with TickerProviderStateMixin {
  late final GlassMorphController _morph;

  /// Latches once the droplet has landed and the real sheet has taken over.
  ///
  /// Without the latch the underdamped spring dipping back below the settle
  /// threshold would flip the sheet back to a droplet for a frame.
  bool _handedOffToSheet = false;

  /// True once the closing morph has started, so the reverse listener and the
  /// settle latch don't fight over the same transition.
  bool _isClosing = false;

  /// Whether the pointer that is dismissing the sheet dragged it first.
  ///
  /// A drag-dismiss throws the sheet down with the finger's own momentum and
  /// releases it anywhere between detents; morphing back from the sheet's
  /// *resting* frame at that point would visibly jump. So a dragged dismissal
  /// keeps the sheet's native slide-away and skips the morph, while a barrier
  /// tap, a back gesture, or a controller close — all of which leave the sheet
  /// sitting at rest — morph back into the trigger.
  bool _draggedSincePointerDown = false;

  /// Where the active pointer went down, for the slop comparison above.
  Offset? _dragOrigin;

  /// Whether the opening morph has been started. See [didChangeDependencies].
  bool _opened = false;

  /// Trigger-centre → destination-centre delta from the last build, handed to
  /// the trigger at the catch as the vector its bounce swings along.
  Offset _finalDelta = Offset.zero;

  /// Latches when the trigger has taken the bounce over, so the handoff fires
  /// exactly once per close.
  bool _handedBackToTrigger = false;

  @override
  void initState() {
    super.initState();
    _morph = GlassMorphController(vsync: this, speed: widget.speed);
    _morph.addListener(_onMorphTick);
    widget.routeAnimation.addStatusListener(_onRouteStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion: swaps in the engine's instant spring. GlassMenu can set
    // this in didChangeDependencies and open later on a tap; a presented sheet
    // opens the moment it mounts, so the flag has to land BEFORE the spring
    // starts — otherwise the first presentation of every session animates at
    // full length with Reduce Motion on.
    _morph.setDisableAnimations(MediaQuery.of(context).disableAnimations);
    if (!_opened) {
      _opened = true;
      // Empty the trigger before the first morph frame paints, so the button
      // and the anchor blob standing in for it are never both on screen.
      widget.anchor?._empty();
      _morph.open();
    }
  }

  @override
  void dispose() {
    widget.routeAnimation.removeStatusListener(_onRouteStatus);
    _morph.removeListener(_onMorphTick);
    _morph.dispose();
    // The route can be torn down without the closing morph ever running (a
    // Navigator reset, a hot restart). Leaving the trigger emptied would erase
    // a live button, so restoring here is the safety net.
    widget.anchor?._restore();
    super.dispose();
  }

  void _onMorphTick() {
    if (!mounted) return;
    // Hand off to the real sheet only at the settled instant, when the droplet
    // and the sheet occupy the identical frame and nothing is moving — the one
    // moment a glass surface can be swapped without a glitch frame.
    if (!_isClosing && !_handedOffToSheet && _morph.value >= 0.999) {
      _handedOffToSheet = true;
    }
    _syncTrigger();
    setState(() {});
  }

  /// Hands the trigger back at the moment the droplet is caught.
  ///
  /// [GlassMorphController.hasHandedOff] latches on the spring's first
  /// zero-crossing during a close, which is exactly when the droplet has
  /// arrived — so the real button reappears there rather than after the
  /// underdamped bounce has finished. Same latch GlassMenu hands off on.
  ///
  /// Fires once, and passes the spring's live state rather than driving the
  /// bounce frame by frame: this route is torn down moments later (its barrier
  /// would otherwise keep swallowing taps on a button that is visibly back), so
  /// the trigger continues the simulation itself from exactly here.
  void _syncTrigger() {
    final anchor = widget.anchor;
    if (anchor == null || !_isClosing || _handedBackToTrigger) return;
    if (!_morph.hasHandedOff) return;
    _handedBackToTrigger = true;
    anchor._handBack(
      travel: _finalDelta,
      value: _morph.value,
      velocity: _morph.velocity,
    );
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.reverse || _isClosing) return;
    if (_draggedSincePointerDown) return; // the sheet slides itself away
    setState(() {
      _isClosing = true;
      _handedOffToSheet = false;
      _handedBackToTrigger = false;
    });
    _morph.close();
  }

  void _onPointerDown(PointerDownEvent event) {
    _dragOrigin = event.position;
    _draggedSincePointerDown = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    // Slop, not any movement at all: a tap on the dismiss barrier routinely
    // wobbles a pixel or two, and mistaking that for a drag would cost the
    // morph on the most common way of closing the sheet.
    final origin = _dragOrigin;
    if (origin == null || _draggedSincePointerDown) return;
    if ((event.position - origin).distance > kTouchSlop) {
      _draggedSincePointerDown = true;
    }
  }

  void _onPointerRelease(PointerEvent event) {
    _dragOrigin = null;
    // Cleared after the frame, not during it: a drag that ends in a dismissal
    // pops the route synchronously from this same pointer-up, and the flag has
    // to still be set when [_onRouteStatus] reads it. By the next frame the
    // gesture is over, so a later back gesture or controller close still
    // morphs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _draggedSincePointerDown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final adaptiveRadius = GlassThemeHelpers.resolveAdaptiveRadius(context);
    final topRadiusBase = widget.topBorderRadius ?? adaptiveRadius;
    final bottomRadiusBase = widget.bottomBorderRadius ?? adaptiveRadius;

    final destination = SheetMorphGeometry.restingRect(
      state: widget.restingState,
      geometry: widget.geometry,
      screenSize: screenSize,
      horizontalMargin: widget.horizontalMargin,
      bottomMargin: widget.bottomMargin,
      bottomInset: bottomInset,
      bottomRadius: bottomRadiusBase,
      peekHorizontalMargin: widget.peekHorizontalMargin,
      peekBottomMargin: widget.peekBottomMargin,
      peekWidth: widget.peekWidth,
    );

    // The real sheet stays mounted underneath for the whole morph so its
    // post-frame snap, glass layers and springs are already settled by the time
    // it is revealed; only painting and hit-testing are gated.
    final sheet = Visibility(
      visible: _handedOffToSheet,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerRelease,
        onPointerCancel: _onPointerRelease,
        child: widget.child,
      ),
    );

    // The sheet is always slot 0 of the same Stack, whether the droplet is
    // present or not. Returning `sheet` bare at the handoff would change its
    // depth in the element tree, and Flutter answers a depth change by tearing
    // the subtree down and rebuilding it — remounting every glass layer and
    // re-seeding every spring inside the sheet, at the exact moment the morph
    // is trying to look seamless.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        sheet,
        if (!_handedOffToSheet)
          _buildDroplet(
            context: context,
            destination: destination,
            topRadiusBase: topRadiusBase,
            bottomRadiusBase: bottomRadiusBase,
          ),
      ],
    );
  }

  Widget _buildDroplet({
    required BuildContext context,
    required Rect destination,
    required double topRadiusBase,
    required double bottomRadiusBase,
  }) {
    final trigger = widget.triggerRect;

    // The anchor blob only earns its place when the real trigger is hidden.
    // Drawn over a trigger that is still painted it reads as a duplicated
    // button rather than a morph, so without an anchor the droplet blooms from
    // the trigger's centre instead — no second button-sized shape at any point,
    // at the cost of the teardrop neck, which needs two blobs to stretch
    // between. Mirrors GlassMenu's `morphFromZero`.
    final showAnchorBlob = widget.anchor != null;
    final source = showAnchorBlob
        ? trigger
        : Rect.fromCenter(center: trigger.center, width: 0, height: 0);

    // The engine works in displacement-from-trigger-centre terms; the sheet's
    // destination is an absolute rect, so hand it the delta between centres.
    _finalDelta = destination.center - trigger.center;
    final state = _morph.computeState(
      finalDx: _finalDelta.dx,
      finalDy: _finalDelta.dy,
    );

    final blob = SheetMorphGeometry.blobRect(
      trigger: source,
      destination: destination,
      pathT: state.pathT,
      sizeT: state.sizeT,
    );

    final enablePeek = widget.geometry.enablePeek;
    final baseSettings = GlassThemeHelpers.resolveSettings(
      context,
      explicit: widget.settings,
      fallback: kDefaultSheetSettings,
    );
    final dropletSettings = SheetMorphGeometry.restingSettings(
      state: widget.restingState,
      baseSettings: baseSettings,
      enablePeek: enablePeek,
      peekSettings: widget.peekSettings,
      halfSettings: widget.halfSettings,
      fullSettings: widget.fullSettings,
    );
    final fillOpacity = SheetMorphGeometry.restingFillOpacity(
          state: widget.restingState,
          baseSettings: baseSettings,
          enablePeek: enablePeek,
          peekSettings: widget.peekSettings,
          halfSettings: widget.halfSettings,
          fullSettings: widget.fullSettings,
        ) *
        SheetMorphGeometry.fillReveal(state.sizeT);

    final quality = GlassThemeHelpers.resolveQuality(
      context,
      widgetQuality: widget.quality,
      fallback: GlassQuality.premium,
    );

    final isDark = GlassTheme.brightnessOf(context) == Brightness.dark;
    final fillColor = widget.expandedColor ??
        (isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white);

    // Radii the droplet resolves to: the sheet's own resting corners.
    final targetTopRadius = switch (widget.restingState) {
      GlassSheetState.full => widget.fullTopBorderRadius ?? topRadiusBase,
      GlassSheetState.peek => widget.peekTopBorderRadius ?? topRadiusBase,
      _ => topRadiusBase,
    };
    final targetBottomRadius = widget.restingState == GlassSheetState.full
        ? (widget.fullBottomBorderRadius ?? bottomRadiusBase)
        : bottomRadiusBase;

    final blobSize = blob.size;
    final topRadius = SheetMorphGeometry.blobRadius(
      blobSize: blobSize,
      target: targetTopRadius,
      sizeT: state.sizeT,
    );
    final bottomRadius = SheetMorphGeometry.blobRadius(
      blobSize: blobSize,
      target: targetBottomRadius,
      sizeT: state.sizeT,
    );

    // Blob A — the trigger ghost. Shrinks to nothing over the first 40 % of the
    // opening so the liquid bridge snaps, and grows back on close so the real
    // button "catches" the returning droplet.
    final anchorRadius = trigger.shortestSide / 2.0;
    final Widget? blobA = !showAnchorBlob
        ? null
        : Positioned(
            left: trigger.left + state.pushDx,
            top: trigger.top + state.pushDy,
            child: Transform.scale(
              scale: state.anchorScale,
              child: AdaptiveGlass(
                shape: LiquidRoundedRectangle(borderRadius: anchorRadius),
                settings: dropletSettings,
                quality: quality,
                platformViewBackdrop: widget.platformViewBackdrop,
                useOwnLayer: false,
                child: SizedBox(width: trigger.width, height: trigger.height),
              ),
            ),
          );

    // Blob B — the travelling body. Scaled by the engine's squeeze pulse so the
    // closing undershoot reads as a physical compression rather than a slide.
    final blobB = Positioned(
      left: blob.left,
      top: blob.top,
      child: IgnorePointer(
        child: Transform.scale(
          scale: state.containerScale,
          child: AdaptiveGlass(
            shape: LiquidVerticalRoundedSuperellipse(
              topRadius: topRadius,
              bottomRadius: bottomRadius,
            ),
            settings: dropletSettings,
            quality: quality,
            useOwnLayer: false,
            child: SizedBox(
              width: blobSize.width,
              height: blobSize.height,
              child: fillOpacity <= 0.0
                  ? null
                  : ColoredBox(
                      color: fillColor.withValues(alpha: fillOpacity),
                    ),
            ),
          ),
        ),
      ),
    );

    final Widget blobs = Stack(
      clipBehavior: Clip.none,
      children: [if (blobA != null) blobA, blobB],
    );

    // LiquidGlassBlendGroup needs the InheritedGeometryRenderLink that only a
    // full LiquidGlassLayer provides. AdaptiveLiquidGlassLayer skips that layer
    // in minimal quality and in platformViewBackdrop mode, so the blend group
    // has to be skipped in exactly those cases too (issue #214).
    final useBlendGroup =
        quality != GlassQuality.minimal && !widget.platformViewBackdrop;

    // Once the droplet has been caught, the real trigger is back on screen and
    // the droplet is standing in front of a button that is already there — two
    // shapes where there should be one. GlassMenu hides its overlay at exactly
    // this latch for the same reason; without it the last frames read as a
    // duplicated button that vanishes when the route unmounts, rather than a
    // droplet settling into the trigger.
    //
    // Toggled outright, never faded: a glass surface's backdrop pass renders
    // fully or not at all.
    final handedBack = _morph.isClosing && _morph.hasHandedOff;

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: handedBack ? 0.0 : 1.0,
          child: AdaptiveLiquidGlassLayer(
            settings: dropletSettings,
            quality: quality,
            blendAmount: state.blend,
            platformViewBackdrop: widget.platformViewBackdrop,
            child: useBlendGroup
                ? LiquidGlassBlendGroup(blend: state.blend, child: blobs)
                : blobs,
          ),
        ),
      ),
    );
  }
}
