import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:flutter/widgets.dart';

import '../../src/renderer/liquid_glass_settings.dart';
import '../../theme/glass_theme_helpers.dart';
import '../../types/glass_quality.dart';
import 'glass_bar_item.dart';
import 'shared/glass_nav_pinned_host.dart';

/// What a single route contributes to the pinned navigation chrome.
///
/// Created by [GlassAppBar] when `pinnedActions` is used, and handed to the
/// enclosing [GlassNavigationShell]. Consumers never construct this directly.
@immutable
class GlassNavBarRegistration {
  /// Creates a registration describing one route's pinned bar chrome.
  const GlassNavBarRegistration({
    required this.actions,
    required this.showsBackButton,
    this.onBack,
    this.buttonSettings,
  });

  /// The trailing cluster items for this route.
  final List<GlassBarItem> actions;

  /// Whether this route shows the pinned back button.
  final bool showsBackButton;

  /// Overrides the default back action (`Navigator.maybePop`).
  final VoidCallback? onBack;

  /// Glass settings applied to this route's pinned chrome.
  final LiquidGlassSettings? buttonSettings;

  /// The tappable items in [actions], with spacers removed.
  List<GlassBarActionItem> get actionItems =>
      actions.whereType<GlassBarActionItem>().toList(growable: false);
}

/// Hosts navigation-bar glass chrome **above** the [Navigator], so it stays
/// pinned while route content slides during a push or pop.
///
/// This reproduces the iOS 26 navigation bar model, where bar items belong to
/// the navigation stack rather than to any one screen. Apple documents the
/// behaviour on `UIBarButtonItem.identifier`: *"When the set of bar button
/// items in a navigation bar or toolbar changes (for example, when pushing or
/// popping view controllers), UIKit automatically animates the transition
/// between the different sets of items."*
///
/// Install it once, wrapping whatever [Navigator] your app builds. This works
/// with the imperative [Navigator] and with any router built on the Pages API
/// (go_router, auto_route, beamer), because the shell only ever reads
/// [ModalRoute] animations — it never intercepts navigation:
///
/// ```dart
/// CupertinoApp(
///   builder: (context, child) => GlassNavigationShell(child: child!),
///   home: const HomeScreen(),
/// );
///
/// // Or with a router:
/// CupertinoApp.router(
///   routerConfig: router,
///   builder: (context, child) => GlassNavigationShell(child: child!),
/// );
/// ```
///
/// Screens opt in via [GlassAppBar.pinnedActions]. Screens that don't opt in
/// are unaffected, and when no shell is present (or the device can't render
/// the effect) those screens fall back to rendering the same buttons inside
/// their own app bar.
class GlassNavigationShell extends StatefulWidget {
  /// Creates a navigation shell around [child].
  const GlassNavigationShell({
    super.key,
    required this.child,
    this.enabled = true,
  });

  /// The subtree containing the [Navigator], typically the `child` handed to
  /// `CupertinoApp.builder`.
  final Widget child;

  /// Whether pinning is enabled at all.
  ///
  /// When false the shell is inert and every screen renders its bar chrome
  /// in-route, exactly as if no shell were installed.
  final bool enabled;

  /// The nearest enclosing shell, or null if there is none.
  static GlassNavigationShellState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_GlassNavigationShellScope>()
        ?.state;
  }

  @override
  State<GlassNavigationShell> createState() => GlassNavigationShellState();
}

/// Registry and animation clock for a [GlassNavigationShell].
///
/// Routes register through [register] and are ranked by how covered they are,
/// so the shell always knows which route is on top and which sits beneath it
/// mid-transition.
class GlassNavigationShellState extends State<GlassNavigationShell> {
  /// Registrations keyed by route, in registration order.
  final Map<ModalRoute<dynamic>, GlassNavBarRegistration> _registry =
      <ModalRoute<dynamic>, GlassNavBarRegistration>{};

  /// Routes whose animations this shell currently listens to.
  final Set<Animation<double>> _listened = <Animation<double>>{};

  /// Fires whenever the rendered chrome may have changed.
  final _TickNotifier _tick = _TickNotifier();

  /// Whether a deferred notification is already queued for this frame.
  bool _notifyQueued = false;

  bool _pinningSupported = false;

  /// Whether pinning is currently active.
  ///
  /// False when the shell is disabled or the resolved glass quality can't
  /// render the effect, in which case registrants render in-route instead.
  bool get isActive => widget.enabled && _pinningSupported;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mirrors the gate used by the modal sheet morph: the effect needs real
    // glass, so minimal quality falls back to in-route rendering.
    final quality = GlassThemeHelpers.resolveQuality(
      context,
      fallback: GlassQuality.premium,
    );
    final supported = debugPinningSupported ?? quality != GlassQuality.minimal;
    if (supported != _pinningSupported) {
      _pinningSupported = supported;
    }
  }

  /// Overrides the capability gate in tests, where no GPU is available.
  @visibleForTesting
  static bool? debugPinningSupported;

  // ---------------------------------------------------------------------------
  // Registry
  // ---------------------------------------------------------------------------

  /// Registers or updates [route]'s pinned chrome.
  void register(
    ModalRoute<dynamic> route,
    GlassNavBarRegistration registration,
  ) {
    final existing = _registry[route];
    _registry[route] = registration;
    if (existing == null) {
      _listenTo(route.animation);
      _listenTo(route.secondaryAnimation);
    }
    _scheduleNotify();
  }

  /// Removes [route] from the registry.
  void unregister(ModalRoute<dynamic> route) {
    if (_registry.remove(route) == null) return;
    _unlisten(route.animation);
    _unlisten(route.secondaryAnimation);
    _scheduleNotify();
  }

  void _listenTo(Animation<double>? animation) {
    if (animation == null || !_listened.add(animation)) return;
    animation.addListener(_onAnimationTick);
  }

  void _unlisten(Animation<double>? animation) {
    if (animation == null || !_listened.remove(animation)) return;
    animation.removeListener(_onAnimationTick);
  }

  void _onAnimationTick() => _tick.notify();

  /// Notifies listeners, deferring past build/layout when necessary.
  ///
  /// Registration happens during a descendant's build, so notifying inline
  /// would mutate the tree mid-frame. This mirrors the deferral used by the
  /// modal sheet morph's anchor.
  void _scheduleNotify() {
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      // Several routes can register in one frame (first build after a hot
      // reload, a popUntil); queue a single deferred notification for all.
      if (_notifyQueued) return;
      _notifyQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyQueued = false;
        if (mounted) _tick.notify();
      });
    } else {
      _tick.notify();
    }
  }

  // ---------------------------------------------------------------------------
  // Ordering
  // ---------------------------------------------------------------------------

  /// The registered routes ordered from topmost to bottom-most.
  ///
  /// Rank comes from `secondaryAnimation`, which measures how much a route is
  /// covered by whatever sits above it: the top route is uncovered (0), and a
  /// route being covered by a push animates toward 1. This derives stack order
  /// from the routes themselves, so no [NavigatorObserver] is needed and any
  /// Pages-API router works unchanged.
  List<MapEntry<ModalRoute<dynamic>, GlassNavBarRegistration>>
      get _orderedEntries {
    final entries =
        _registry.entries.where((e) => e.key.isActive).toList(growable: false);
    final insertionIndex = <ModalRoute<dynamic>, int>{};
    var i = 0;
    for (final route in _registry.keys) {
      insertionIndex[route] = i++;
    }
    entries.sort((a, b) {
      final byCoverage = _coverageOf(a.key).compareTo(_coverageOf(b.key));
      if (byCoverage != 0) return byCoverage;
      // Equally covered: the more recently pushed route is on top.
      return insertionIndex[b.key]!.compareTo(insertionIndex[a.key]!);
    });
    return entries;
  }

  static double _coverageOf(ModalRoute<dynamic> route) =>
      route.secondaryAnimation?.value ?? 0.0;

  /// The chrome to render right now, or null when nothing should be shown.
  GlassNavPinnedState? resolveState() {
    if (!isActive) return null;
    final ordered = _orderedEntries;
    if (ordered.isEmpty) return null;

    final top = ordered.first;
    final below = ordered.length > 1 ? ordered[1] : null;

    // Progress of the top route's own entrance: 1 at rest, 0 when it has just
    // been pushed, and scrubbed by the interactive back-swipe during a pop.
    final progress = top.key.animation?.value ?? 1.0;

    // Retreat only when something *unregistered* sits above the top route —
    // a plain route or a modal sheet. `isCurrent` is what distinguishes that
    // from a pop still unwinding this route's secondaryAnimation: anything
    // registered above would have sorted above it instead, so a non-current
    // top route is covered by something this shell doesn't manage.
    final coverage = top.key.isCurrent ? 0.0 : _coverageOf(top.key);

    return GlassNavPinnedState(
      from: below?.value ??
          const GlassNavBarRegistration(
            actions: <GlassBarItem>[],
            showsBackButton: false,
          ),
      to: top.value,
      progress: progress.clamp(0.0, 1.0),
      coverage: coverage.clamp(0.0, 1.0),
      topRoute: top.key,
    );
  }

  @override
  void dispose() {
    for (final animation in _listened) {
      animation.removeListener(_onAnimationTick);
    }
    _listened.clear();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassNavigationShellScope(
      state: this,
      child: Stack(
        children: [
          widget.child,
          if (widget.enabled)
            ListenableBuilder(
              listenable: _tick,
              builder: (context, _) {
                final state = resolveState();
                if (state == null) return const SizedBox.shrink();
                return GlassNavPinnedHost(state: state);
              },
            ),
        ],
      ),
    );
  }
}

/// Exposes the shell state to descendant registrants.
class _GlassNavigationShellScope extends InheritedWidget {
  const _GlassNavigationShellScope({
    required this.state,
    required super.child,
  });

  final GlassNavigationShellState state;

  @override
  bool updateShouldNotify(_GlassNavigationShellScope oldWidget) =>
      state != oldWidget.state;
}

/// A [ChangeNotifier] whose notification is callable by its owner.
class _TickNotifier extends ChangeNotifier {
  /// Notifies listeners that the pinned chrome may have changed.
  void notify() => notifyListeners();
}
