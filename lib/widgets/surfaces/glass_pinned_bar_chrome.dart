import 'package:flutter/widgets.dart';

import '../../src/renderer/liquid_glass_settings.dart';
import 'glass_bar_item.dart';
import 'glass_navigation_shell.dart';

/// Builds a bar that has handed its chrome to a [GlassNavigationShell].
///
/// `hoisted` is false while the bar still draws its own leading and actions,
/// and true once the shell has taken them over.
typedef GlassPinnedBarChromeBuilder = Widget Function(
  BuildContext context,
  bool hoisted,
);

/// Hands a route's bar chrome to the enclosing [GlassNavigationShell], and
/// reports back whether the shell took it.
///
/// This is the registration [GlassAppBar.pinned] performs internally, exposed
/// for bars this package does not build — a Material `AppBar` carrying its own
/// backdrop, a collapsing large-title sliver, or anything else an existing
/// design system already owns. Wrap the bar, declare its items as data, and
/// the shell pins them above the [Navigator] exactly as it does for a
/// [GlassAppBar.pinned] bar.
///
/// ```dart
/// GlassPinnedBarChrome(
///   actions: [
///     GlassBarItem.icon(icon: const Icon(CupertinoIcons.add), onTap: _add),
///   ],
///   builder: (context, hoisted) => AppBar(
///     title: const Text('Inbox'),
///     // Same-sized placeholders once hoisted, so the title keeps the layout
///     // it had and nothing shifts at the hand-over.
///     leading: hoisted ? const SizedBox(width: 44) : const BackButton(),
///     actions: hoisted ? null : [IconButton(icon: addIcon, onPressed: _add)],
///   ),
/// )
/// ```
///
/// The hand-over is deliberately a frame late: [builder] keeps reporting
/// `hoisted: false` until the shell has both accepted the registration and had
/// a frame to render it. At the swap both copies are static and identical, so
/// they never overlap and never both disappear.
///
/// Where there is no shell — or the device cannot render the effect — `hoisted`
/// stays false, so a bar written this way works either way.
class GlassPinnedBarChrome extends StatefulWidget {
  /// Creates a registrant that pins [actions] and an automatic back button.
  const GlassPinnedBarChrome({
    super.key,
    required this.builder,
    this.actions = const <GlassBarItem>[],
    this.backButton = true,
    this.onBack,
    this.buttonSettings,
    this.enabled = true,
  });

  /// Builds the bar itself, told whether the shell has taken the chrome.
  final GlassPinnedBarChromeBuilder builder;

  /// The trailing bar items to pin, declared as data.
  ///
  /// Defaults to empty, which still pins: an empty list opts the route into
  /// the shell with a back button and no capsule, it does not opt out.
  final List<GlassBarItem> actions;

  /// Whether the automatic back button is offered to the shell.
  ///
  /// It only appears where the route can actually be popped
  /// ([ModalRoute.impliesAppBarDismissal]), so a root route never shows one.
  final bool backButton;

  /// Overrides the back button's default `Navigator.maybePop()`.
  ///
  /// Set this for router-specific semantics such as go_router's
  /// `context.pop()`.
  final VoidCallback? onBack;

  /// Glass settings applied to this route's pinned chrome.
  final LiquidGlassSettings? buttonSettings;

  /// Whether this bar participates in pinning at all.
  ///
  /// When false the widget behaves as if no shell were installed: any existing
  /// registration is dropped and [builder] is called with `hoisted: false`.
  ///
  /// The shell ranks registered routes against one another, which only has
  /// meaning inside a single [Navigator]. An app with a nested navigator — a
  /// go_router `ShellRoute` for tabs, say — should therefore keep the nested
  /// stack's roots out of the shell:
  ///
  /// ```dart
  /// enabled: ModalRoute.of(context)?.impliesAppBarDismissal ?? false,
  /// ```
  final bool enabled;

  @override
  State<GlassPinnedBarChrome> createState() => _GlassPinnedBarChromeState();
}

class _GlassPinnedBarChromeState extends State<GlassPinnedBarChrome> {
  GlassNavigationShellState? _shell;
  ModalRoute<dynamic>? _route;
  bool _handedOver = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GlassPinnedBarChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final shell = GlassNavigationShell.maybeOf(context);
    final route = ModalRoute.of(context);

    if (shell != _shell || route != _route) {
      _release();
      _shell = shell;
      _route = route;
      _handedOver = false;
    }

    // Deliberately no offstage or TickerMode guard here. Flutter builds a newly
    // pushed route offstage once before the transition starts, and neither
    // `offstage` nor a muted ticker notifies dependents when it flips back — so
    // skipping those builds would strand the route unregistered for the whole
    // transition. Which route is on top is decided by the shell's ordering
    // instead. (Inactive branches of a nested navigator are a known gap.)
    if (!widget.enabled || shell == null || route == null || !shell.isActive) {
      // Drop any stale registration, then draw the chrome in-route again.
      _release();
      if (_handedOver) {
        setState(() => _handedOver = false);
      }
      return;
    }

    shell.register(
      route,
      GlassNavBarRegistration(
        actions: widget.actions,
        showsBackButton: widget.backButton && route.impliesAppBarDismissal,
        onBack: widget.onBack,
        buttonSettings: widget.buttonSettings,
      ),
    );

    if (!_handedOver) {
      // The shell renders the chrome on the next frame; hand over then, so the
      // bar and the shell swap in the same frame rather than one before the
      // other.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _shell != null && _shell!.isActive) {
          setState(() => _handedOver = true);
        }
      });
    }
  }

  void _release() {
    final shell = _shell;
    final route = _route;
    if (shell != null && route != null) {
      shell.unregister(route);
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Checked here rather than in the pinned host so the in-route fallback
    // path reports it too instead of silently dropping it.
    assert(
      !widget.actions.any((i) => i is GlassBarSpacer),
      'GlassBarItem.spacer() is not rendered yet: pinned actions render as a '
      'single glass capsule. Multi-capsule grouping is a follow-up.',
    );
    return widget.builder(context, _handedOver);
  }
}
