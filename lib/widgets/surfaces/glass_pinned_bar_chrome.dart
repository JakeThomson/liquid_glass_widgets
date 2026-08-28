import 'package:flutter/cupertino.dart';

import '../../src/renderer/liquid_glass_renderer.dart';
import '../interactive/glass_button.dart';
import '../interactive/glass_button_group.dart';
import 'glass_app_bar.dart' show DefaultButtonSettings, GlassAppBar;
import 'glass_bar_item.dart';
import 'glass_navigation_shell.dart';
import 'shared/glass_nav_pinned_host.dart' show GlassNavPinnedMetrics;

/// The bar chrome to render this frame, handed to a
/// [GlassPinnedBarChrome.builder].
///
/// Drop [leading] and [actions] straight into your bar's slots. They already
/// hold the right thing for the current state: the real glass buttons while
/// the bar still owns its chrome, and same-sized unpainted placeholders once
/// the shell has taken it. Reading [hoisted] is only necessary to draw
/// something other than the package's own chrome.
@immutable
class GlassPinnedBarChromeData {
  /// Creates the chrome for one frame.
  const GlassPinnedBarChromeData({
    required this.leading,
    required this.actions,
    required this.hoisted,
  });

  /// The leading slot: the automatic back button, its placeholder, or null
  /// where the route shows no back button.
  final Widget? leading;

  /// The trailing slot: the actions capsule, its placeholder, or empty where
  /// the route declares no actions.
  ///
  /// A [List] rather than a single widget so it drops into `AppBar.actions`
  /// and [GlassAppBar.actions] unchanged; it never holds more than one entry,
  /// because the items render as one capsule.
  final List<Widget> actions;

  /// Whether the shell has taken this route's chrome.
  ///
  /// False while the bar still draws it, and true once the shell has both
  /// accepted the registration and had a frame to render its copy. [leading]
  /// and [actions] already account for this — read it only to substitute your
  /// own chrome for the package's.
  final bool hoisted;
}

/// Builds a bar from the chrome resolved for the current frame.
typedef GlassPinnedBarChromeBuilder = Widget Function(
  BuildContext context,
  GlassPinnedBarChromeData chrome,
);

/// Hands a route's bar chrome to the enclosing [GlassNavigationShell], and
/// builds whatever the bar should render in the meantime.
///
/// This is the registration [GlassAppBar.pinned] performs internally, exposed
/// for bars this package does not build — a Material `AppBar` carrying its own
/// backdrop, a collapsing large-title sliver, or anything else an existing
/// design system already owns. Declare the items as data once and drop the
/// resolved slots into your bar:
///
/// ```dart
/// GlassPinnedBarChrome(
///   actions: [
///     GlassBarItem.icon(icon: const Icon(CupertinoIcons.add), onTap: _create),
///   ],
///   builder: (context, chrome) => AppBar(
///     automaticallyImplyLeading: false,
///     leading: chrome.leading,
///     actions: chrome.actions,
///     title: const Text('Repository'),
///   ),
/// )
/// ```
///
/// The slots swap themselves at the right moment. Until the shell has both
/// accepted the registration and had a frame to render its copy, they hold the
/// real glass back button and actions capsule — the same widgets the shell
/// will draw. After, they hold unpainted placeholders that lay out the real
/// content, so the bar keeps the layout it had and the title never shifts. The
/// hand-over is deliberately a frame late: at the swap both copies are static
/// and identical, so they never overlap and never both disappear.
///
/// Where there is no shell — or the device cannot render the effect — the
/// slots simply keep the real buttons, so a bar written this way works either
/// way with no fallback of its own.
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

  /// Builds the bar from the chrome resolved for this frame.
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
  ///
  /// Applied to the in-route buttons as well as the pinned ones, so the two
  /// look identical across the hand-over.
  final LiquidGlassSettings? buttonSettings;

  /// Whether this bar participates in pinning at all.
  ///
  /// When false the widget behaves as if no shell were installed: any existing
  /// registration is dropped and the bar keeps drawing its own chrome.
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

  /// Whether this route shows the automatic back button at all.
  bool get _showsBack =>
      widget.backButton && (_route?.impliesAppBarDismissal ?? false);

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
        showsBackButton: _showsBack,
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

  /// The back button, or the space it occupied once the shell has it.
  Widget? _buildLeading() {
    if (!_showsBack) return null;
    const backSize = GlassNavPinnedMetrics.backDiameter;
    if (_handedOver) {
      return const SizedBox(width: backSize, height: backSize);
    }
    return GlassButton(
      icon: const Icon(CupertinoIcons.back),
      width: backSize,
      height: backSize,
      iconSize: GlassNavPinnedMetrics.iconSize,
      label: 'Back',
      onTap: () {
        final back = widget.onBack;
        if (back != null) {
          back();
        } else {
          Navigator.of(context).maybePop();
        }
      },
    );
  }

  /// The actions capsule, or the space it occupied once the shell has it.
  List<Widget> _buildActions() {
    final items = widget.actions.whereType<GlassBarActionItem>().toList();
    if (items.isEmpty) return const <Widget>[];
    const slot = GlassNavPinnedMetrics.slot;

    if (_handedOver) {
      // The placeholder lays out the real content and simply isn't painted,
      // so it measures exactly what the pinned cluster measures — including
      // custom items of arbitrary width. A fixed width per item would only
      // be correct for icons, and would mis-constrain a centred title.
      return [
        IgnorePointer(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0.0,
              child: SizedBox(
                height: slot,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in items)
                      if (item is GlassBarCustomItem)
                        item.child
                      else
                        SizedBox(
                          width: slot,
                          child: Center(child: item.content),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      GlassButtonGroup.icons(
        items: [
          for (final item in items)
            if (item is GlassBarMenuItem)
              GlassButtonGroupItem.menu(
                icon: item.icon,
                menuItems: item.menuItems,
                menuAlignment: item.menuAlignment,
                menuWidth: item.menuWidth,
                label: item.label,
              )
            else
              GlassButtonGroupItem(
                icon: item.content,
                onTap: item.onTap,
                label: item.label,
                enabled: item.enabled,
              ),
        ],
      ),
    ];
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

    Widget bar = widget.builder(
      context,
      GlassPinnedBarChromeData(
        leading: _buildLeading(),
        actions: _buildActions(),
        hoisted: _handedOver,
      ),
    );

    final settings = widget.buttonSettings;
    if (settings != null) {
      bar = DefaultButtonSettings(settings: settings, child: bar);
    }
    return bar;
  }
}
