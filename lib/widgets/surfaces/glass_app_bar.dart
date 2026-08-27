import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../src/renderer/liquid_glass_renderer.dart';
import '../../types/glass_quality.dart';
import '../interactive/glass_button.dart';
import '../interactive/glass_button_group.dart';
import '../shared/glass_isolation_scope.dart';
import 'glass_bar_item.dart';
import 'glass_large_title.dart' show GlassLargeTitleController;
import 'glass_navigation_shell.dart';
import 'shared/glass_nav_pinned_host.dart' show GlassNavPinnedMetrics;

/// A navigation bar layout widget following Apple's iOS 26 design patterns.
///
/// [GlassAppBar] renders a solid or transparent bar with leading widget,
/// centered title, and trailing actions. Glass effects belong on the
/// individual interactive elements (buttons, pills) — not the bar surface
/// itself. This matches iOS 26's navigation bar where the bar is a simple
/// layout container and glass is reserved for buttons.
///
/// ## Large-title collapse (iOS 26 pattern)
///
/// Pair with [GlassLargeTitle] and [GlassLargeTitleController] to get
/// automatic cross-fade between the large title (in the scroll view) and the
/// inline bar title — with zero boilerplate:
///
/// ```dart
/// final _titleController = GlassLargeTitleController();
///
/// GlassScaffold(
///   appBar: GlassAppBar(
///     title: Text('Chats'),
///     largeTitleController: _titleController,   // ← fades in as user scrolls
///   ),
///   body: CustomScrollView(
///     controller: _titleController.scrollController,
///     slivers: [
///       GlassLargeTitle(text: 'Chats', controller: _titleController),
///       // ... content slivers
///     ],
///   ),
/// )
/// ```
///
/// ## Transparent (default — iOS 26 style)
///
/// ```dart
/// GlassAppBar(
///   title: Text('Messages'),
///   leading: GlassButton(
///     icon: Icon(CupertinoIcons.back),
///     onTap: () => Navigator.pop(context),
///   ),
/// )
/// ```
///
/// ## Solid background (WhatsApp / Player style)
///
/// ```dart
/// GlassAppBar(
///   backgroundColor: Color(0xFF2C2C2E),
///   title: Text('Now Playing'),
///   leading: GlassButton(
///     icon: Icon(CupertinoIcons.back),
///     onTap: () => Navigator.pop(context),
///   ),
/// )
/// ```
///
/// ## Custom button settings (all buttons inherit)
///
/// ```dart
/// GlassAppBar(
///   buttonSettings: LiquidGlassSettings(
///     glassColor: Color(0x33FFFFFF),
///     thickness: 20,
///   ),
///   leading: GlassButton(...),   // inherits buttonSettings
///   actions: [GlassButton(...)], // inherits buttonSettings
/// )
/// ```
///
/// This widget implements [ObstructingPreferredSizeWidget] for use in both
/// [Scaffold.appBar] and [CupertinoPageScaffold.navigationBar].
class GlassAppBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  /// Creates a glass app bar with widget-based [leading] and [actions].
  ///
  /// The bar itself is a simple layout container with a [backgroundColor].
  /// Glass effects are rendered by individual child widgets (e.g. [GlassButton])
  /// inside the bar — not by the bar surface.
  ///
  /// A bar built this way never participates in navigation pinning: its
  /// widgets live in the route and slide with the page. Use
  /// [GlassAppBar.pinned] for the iOS 26 behaviour where the back button and
  /// actions stay put across route transitions.
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = true,
    // Whitelisted: Structural transparent default, not a Material colour.
    this.backgroundColor = const Color(0x00000000),
    this.toolbarHeight = 44.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.buttonSettings,
    this.largeTitleController,
    this.bottom,
  })  : pinnedActions = null,
        pinnedBackButton = true,
        onBack = null;

  /// Creates a glass app bar whose chrome pins above the [Navigator].
  ///
  /// Inside a [GlassNavigationShell], the automatic back button and the
  /// [actions] capsule stay put while the page slides during push and pop,
  /// morphing in place into the next route's items — the iOS 26 navigation
  /// bar behaviour. Without a shell (or where the effect cannot render) the
  /// same items render inside this bar, so screens work either way.
  ///
  /// [actions] are declared as data ([GlassBarItem]), mirroring
  /// `UIBarButtonItem` — there is no widget-based `leading`/`actions` in this
  /// mode, because arbitrary widgets cannot be hoisted to the shell. Items
  /// sharing an id across routes morph as the same item; see
  /// [GlassBarItem.icon].
  ///
  /// The back button appears whenever the route can be popped and never on a
  /// root route. Set [backButton] to false to suppress it, and [onBack] to
  /// replace the default `Navigator.maybePop()` — for example with
  /// go_router's `context.pop()`.
  const GlassAppBar.pinned({
    super.key,
    this.title,
    List<GlassBarItem> actions = const [],
    bool backButton = true,
    this.onBack,
    this.centerTitle = true,
    // Whitelisted: Structural transparent default, not a Material colour.
    this.backgroundColor = const Color(0x00000000),
    this.toolbarHeight = 44.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.buttonSettings,
    this.largeTitleController,
    this.bottom,
  })  : pinnedActions = actions,
        pinnedBackButton = backButton,
        leading = null,
        actions = null;

  // ===========================================================================
  // Properties
  // ===========================================================================

  /// The primary content of the app bar, typically a [Text] widget.
  final Widget? title;

  /// A widget to display before the title, typically a back button.
  final Widget? leading;

  /// A list of widgets to display after the title.
  final List<Widget>? actions;

  /// Whether the [title] should be centered.
  final bool centerTitle;

  /// The background color of the app bar.
  ///
  /// Defaults to [const Color(0x00000000)] to match iOS 26's transparent
  /// navigation bar pattern. Use an opaque colour for solid bars
  /// (e.g. WhatsApp conversation, music player).
  final Color backgroundColor;

  /// The height of the toolbar row (excluding [bottom]).
  ///
  /// Defaults to `44.0` to match iOS 26 navigation bar height.
  final double toolbarHeight;

  /// A widget to display at the bottom of the app bar, below the title row.
  ///
  /// Typically a [TabBar]. Must implement [PreferredSizeWidget] so the
  /// scaffold can measure the total bar height correctly.
  ///
  /// When non-null, [preferredSize] is `toolbarHeight + bottom.preferredSize.height`.
  final PreferredSizeWidget? bottom;

  /// Trailing bar items declared as data, pinned above the [Navigator] by an
  /// enclosing [GlassNavigationShell].
  ///
  /// Set by [GlassAppBar.pinned] (its `actions` parameter, defaulting to
  /// empty) and always null for the widget-based constructor — the
  /// constructor choice is what decides whether the bar participates in
  /// pinning. When a shell is present these items stay put during push and
  /// pop while the page slides beneath them, morphing in place into the next
  /// route's items; without a shell they render inside this bar as a normal
  /// glass capsule.
  final List<GlassBarItem>? pinnedActions;

  /// Whether a [GlassAppBar.pinned] bar shows the automatic back button when
  /// the route can be popped.
  ///
  /// The button is never shown on a root route, matching
  /// [ModalRoute.impliesAppBarDismissal].
  final bool pinnedBackButton;

  /// Overrides the automatic back button's action on a [GlassAppBar.pinned]
  /// bar.
  ///
  /// Defaults to `Navigator.maybePop`, which routers built on the Pages API
  /// (go_router, auto_route, beamer) handle correctly. Supply this to use a
  /// router-specific pop instead, such as `context.pop()`.
  final VoidCallback? onBack;

  /// The total preferred size of the app bar (toolbar + bottom widget).
  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  /// Whether this app bar fully obstructs the content behind it.
  ///
  /// Returns `true` only when [backgroundColor] is fully opaque (alpha = 1.0).
  /// With the default transparent background, this returns `false`, which
  /// tells [CupertinoPageScaffold] to extend the body behind the bar —
  /// matching the iOS 26 transparent navigation bar pattern.
  @override
  bool shouldFullyObstruct(BuildContext context) => backgroundColor.a >= 1.0;

  /// Padding around the app bar content.
  final EdgeInsetsGeometry padding;

  /// Default glass settings for buttons inside this app bar.
  ///
  /// When provided, all [GlassButton] descendants that don't specify their
  /// own `settings` will inherit these. This avoids repeating the same
  /// settings on every button in the bar.
  ///
  /// Individual buttons can still override this with their own `settings`.
  ///
  /// ```dart
  /// GlassAppBar(
  ///   buttonSettings: LiquidGlassSettings(
  ///     glassColor: Color(0x33FFFFFF),
  ///     thickness: 20,
  ///   ),
  ///   leading: GlassButton(...),   // uses buttonSettings
  ///   actions: [
  ///     GlassButton(
  ///       settings: myCustomSettings, // overrides buttonSettings
  ///       ...
  ///     ),
  ///   ],
  /// )
  /// ```
  final LiquidGlassSettings? buttonSettings;

  /// Optional controller that drives the inline title opacity.
  ///
  /// When provided, the [title] widget is automatically wrapped in a
  /// [ListenableBuilder] that fades it **in** as [GlassLargeTitle]
  /// (the large title in the scroll view) fades **out**.
  ///
  /// This replicates iOS 26's `UINavigationBar.prefersLargeTitles` collapse
  /// behaviour with zero boilerplate. See [GlassLargeTitle] and
  /// [GlassLargeTitleController] for full usage.
  final GlassLargeTitleController? largeTitleController;

  @override
  Widget build(BuildContext context) {
    // Checked here rather than in the const constructor (closures are not
    // potentially-constant), and here rather than in the pinned host so the
    // in-route fallback path reports it too instead of silently dropping it.
    assert(
      pinnedActions == null || !pinnedActions!.any((i) => i is GlassBarSpacer),
      'GlassBarItem.spacer() is not rendered yet: pinned actions render as a '
      'single glass capsule. Multi-capsule grouping is a follow-up.',
    );
    // Pinned items are registered with the shell, which decides whether it can
    // host them. Until then — and whenever there is no shell — this bar draws
    // them itself, so a screen renders correctly either way.
    if (pinnedActions != null) {
      return _GlassNavBarRegistrar(
        actions: pinnedActions!,
        pinnedBackButton: pinnedBackButton,
        onBack: onBack,
        buttonSettings: buttonSettings,
        builder: (context, hoisted) => _buildBar(context, hoisted: hoisted),
      );
    }
    return _buildBar(context, hoisted: false);
  }

  /// Builds the bar itself.
  ///
  /// When [hoisted] the leading and actions slots hold same-sized placeholders
  /// instead of real buttons, so the centred title is constrained exactly as it
  /// would be otherwise and keeps sliding with the page.
  Widget _buildBar(BuildContext context, {required bool hoisted}) {
    Widget? effectiveLeading = leading;
    List<Widget>? effectiveActions = actions;

    if (pinnedActions != null) {
      final items = pinnedActions!.whereType<GlassBarActionItem>().toList();
      final showsBack = pinnedBackButton &&
          (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
      const backSize = GlassNavPinnedMetrics.backDiameter;
      const slot = GlassNavPinnedMetrics.slot;

      if (hoisted) {
        effectiveLeading = showsBack
            ? const SizedBox(width: backSize, height: backSize)
            : null;
        // The placeholder lays out the real content and simply isn't painted,
        // so it measures exactly what the pinned cluster measures — including
        // custom items of arbitrary width. A fixed width per item would only
        // be correct for icons, and would mis-constrain the centred title.
        effectiveActions = items.isEmpty
            ? null
            : [
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
      } else {
        effectiveLeading = showsBack
            ? GlassButton(
                icon: const Icon(CupertinoIcons.back),
                width: backSize,
                height: backSize,
                iconSize: GlassNavPinnedMetrics.iconSize,
                label: 'Back',
                onTap: () {
                  final back = onBack;
                  if (back != null) {
                    back();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
              )
            : null;
        effectiveActions = items.isEmpty
            ? null
            : [
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
    }

    final Widget toolbarRow = SafeArea(
      bottom: false,
      child: Padding(
        padding: padding,
        child: SizedBox(
          height: toolbarHeight,
          child: CustomMultiChildLayout(
            delegate: _ToolbarLayout(
              centerTitle: centerTitle,
              textDirection: Directionality.of(context),
            ),
            children: [
              if (effectiveLeading != null)
                LayoutId(
                  id: _ToolbarSlot.leading,
                  child: effectiveLeading,
                ),
              LayoutId(
                id: _ToolbarSlot.title,
                child: _buildTitle(context),
              ),
              if (effectiveActions != null)
                LayoutId(
                  id: _ToolbarSlot.actions,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: effectiveActions,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    Widget content = ColoredBox(
      color: backgroundColor,
      child: bottom != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [toolbarRow, bottom!],
            )
          : toolbarRow,
    );

    // Wrap with default button settings if provided.
    if (buttonSettings != null) {
      content = DefaultButtonSettings(
        settings: buttonSettings!,
        child: content,
      );
    }

    // Isolate the app bar so that when used in a regular Flutter Scaffold,
    // its glass buttons don't join the page-level blend group (which sits
    // behind the scrolling body), ensuring correct Z-order painting.
    // Premium is the default hint — individual buttons can still override
    // with quality: GlassQuality.standard, and GlassAdaptiveScope will
    // cap to the device ceiling regardless.
    return GlassIsolationScope(
      isolated: true,
      defaultQuality: GlassQuality.premium,
      child: content,
    );
  }

  /// Builds the title widget, optionally driven by [largeTitleController].
  ///
  /// Applies [CupertinoThemeData.navTitleTextStyle] and a [Semantics] header
  /// node — matching [CupertinoNavigationBar]'s internal behaviour so a plain
  /// [Text] widget automatically picks up correct Cupertino typography.
  ///
  /// Alignment (centred vs. leading) is handled by the caller ([build]), not
  /// here. This method is responsible only for styling and the optional
  /// collapse-controller opacity animation.
  ///
  /// With a controller the result is wrapped in a [ListenableBuilder] so only
  /// the title opacity rebuilds on scroll, not the entire bar.
  Widget _buildTitle(BuildContext context) {
    final Widget styledTitle = title == null
        ? const SizedBox.shrink()
        : DefaultTextStyle(
            style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
            // iOS navigation titles are a single truncated line — they never
            // wrap, however little room the bar items leave them.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            child: Semantics(header: true, child: title),
          );

    if (largeTitleController == null) return styledTitle;

    return ListenableBuilder(
      listenable: largeTitleController!,
      builder: (context, _) {
        final progress = largeTitleController!.collapseProgress;
        // iOS 26 bar title behaviour: invisible during the first half of the
        // collapse, then fades in with ease-out over the second half.
        // This matches UIKit's two-phase crossfade where the bar title only
        // appears once the large title is mostly gone.
        final barProgress = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
        final barOpacity = Curves.easeOut.transform(barProgress);
        return Opacity(
          opacity: barOpacity,
          child: styledTitle,
        );
      },
    );
  }
}

/// An [InheritedWidget] that provides default [LiquidGlassSettings] for
/// descendant glass buttons.
///
/// Used by [GlassAppBar] to pass `buttonSettings` down the tree. Buttons
/// that don't specify their own `settings` can inherit these defaults.
///
/// To read the nearest ancestor's settings:
/// ```dart
/// final settings = DefaultButtonSettings.of(context);
/// ```
class DefaultButtonSettings extends InheritedWidget {
  /// Creates a default button settings scope.
  const DefaultButtonSettings({
    super.key,
    required this.settings,
    required super.child,
  });

  /// The default glass settings for descendant buttons.
  final LiquidGlassSettings settings;

  /// Returns the settings from the nearest [DefaultButtonSettings] ancestor,
  /// or `null` if none exists.
  static LiquidGlassSettings? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DefaultButtonSettings>()
        ?.settings;
  }

  @override
  bool updateShouldNotify(DefaultButtonSettings oldWidget) =>
      settings != oldWidget.settings;
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar layout
// ─────────────────────────────────────────────────────────────────────────────

/// Identifies each child slot in [_ToolbarLayout].
enum _ToolbarSlot { leading, title, actions }

/// A [MultiChildLayoutDelegate] that matches Apple's
/// `_CupertinoNavigationBarLayout` semantics:
///
/// * **Leading** — laid out at its natural size, pinned to the logical-start
///   edge (left in LTR, right in RTL).
/// * **Actions** — laid out at their natural size, pinned to the logical-end
///   edge.
/// * **Title (centred)** — constrained to
///   `barWidth − 2 × max(leadingWidth, actionsWidth)`, then positioned so its
///   centre coincides with `barWidth / 2`.  The equal-margin constraint
///   guarantees the title cannot overlap either button even when the sides
///   are asymmetric.
/// * **Title (leading-aligned)** — constrained to the space between the
///   leading widget and the actions widget (with an 8 px logical-start gap),
///   then pinned to the logical-start edge of that space.
///
/// RTL is handled explicitly via [textDirection]; no assumptions are made
/// about screen vs. logical coordinates.
class _ToolbarLayout extends MultiChildLayoutDelegate {
  _ToolbarLayout({
    required this.centerTitle,
    required this.textDirection,
  });

  final bool centerTitle;
  final TextDirection textDirection;

  /// Horizontal gap between the leading widget and the title.
  static const double _titleGap = 8.0;

  bool get _isLTR => textDirection == TextDirection.ltr;

  /// Returns the y-offset that vertically centres [child] inside [parent].
  static double _centreY(Size parent, Size child) =>
      ((parent.height - child.height) / 2.0).clamp(0.0, parent.height);

  @override
  void performLayout(Size size) {
    double leadingWidth = 0.0;
    double actionsWidth = 0.0;

    // ── Leading ──────────────────────────────────────────────────────────────
    if (hasChild(_ToolbarSlot.leading)) {
      final Size ls = layoutChild(
        _ToolbarSlot.leading,
        BoxConstraints.loose(size),
      );
      leadingWidth = ls.width;
      positionChild(
        _ToolbarSlot.leading,
        Offset(
          _isLTR ? 0.0 : size.width - ls.width,
          _centreY(size, ls),
        ),
      );
    }

    // ── Actions ──────────────────────────────────────────────────────────────
    if (hasChild(_ToolbarSlot.actions)) {
      final Size as = layoutChild(
        _ToolbarSlot.actions,
        BoxConstraints.loose(size),
      );
      actionsWidth = as.width;
      positionChild(
        _ToolbarSlot.actions,
        Offset(
          _isLTR ? size.width - as.width : 0.0,
          _centreY(size, as),
        ),
      );
    }

    // ── Title ─────────────────────────────────────────────────────────────────
    if (!hasChild(_ToolbarSlot.title)) return;

    if (centerTitle) {
      // Equal-margin constraint: widen the narrower side so both margins
      // equal the larger one.  This prevents the centred title from ever
      // reaching either button group.
      final double sideWidth = math.max(leadingWidth, actionsWidth);
      final double maxWidth = math.max(0.0, size.width - 2.0 * sideWidth);

      final Size ts = layoutChild(
        _ToolbarSlot.title,
        BoxConstraints(maxWidth: maxWidth, maxHeight: size.height),
      );

      // Centre on the full bar width (not just the constrained zone).
      positionChild(
        _ToolbarSlot.title,
        Offset(
          (size.width - ts.width) / 2.0,
          _centreY(size, ts),
        ),
      );
    } else {
      // Leading-aligned: title occupies the space between the two side widgets
      // with an 8 px logical-start gap.
      //
      // Logical-start side = leadingWidth (LTR) or actionsWidth (RTL).
      // Logical-end side   = actionsWidth (LTR) or leadingWidth (RTL).
      final double startOccupied = _isLTR ? leadingWidth : actionsWidth;
      final double endOccupied = _isLTR ? actionsWidth : leadingWidth;
      final double maxWidth = math.max(
        0.0,
        size.width - startOccupied - _titleGap - endOccupied,
      );

      final Size ts = layoutChild(
        _ToolbarSlot.title,
        BoxConstraints(maxWidth: maxWidth, maxHeight: size.height),
      );

      // Pin to logical-start edge (left in LTR, right in RTL).
      final double titleX = _isLTR
          ? startOccupied + _titleGap
          : size.width - startOccupied - _titleGap - ts.width;

      positionChild(
        _ToolbarSlot.title,
        Offset(titleX, _centreY(size, ts)),
      );
    }
  }

  @override
  bool shouldRelayout(_ToolbarLayout old) =>
      old.centerTitle != centerTitle || old.textDirection != textDirection;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned-chrome registration
// ─────────────────────────────────────────────────────────────────────────────

/// Registers a route's pinned bar chrome with the enclosing
/// [GlassNavigationShell] and reports back whether the shell took it.
///
/// The bar keeps drawing its own buttons until the shell has both accepted the
/// registration and had a frame to render them. Handing over on a later frame
/// means the two never overlap and never both disappear: at the swap both are
/// static and identical, so nothing moves.
class _GlassNavBarRegistrar extends StatefulWidget {
  const _GlassNavBarRegistrar({
    required this.actions,
    required this.pinnedBackButton,
    required this.onBack,
    required this.buttonSettings,
    required this.builder,
  });

  final List<GlassBarItem> actions;
  final bool pinnedBackButton;
  final VoidCallback? onBack;
  final LiquidGlassSettings? buttonSettings;
  final Widget Function(BuildContext context, bool hoisted) builder;

  @override
  State<_GlassNavBarRegistrar> createState() => _GlassNavBarRegistrarState();
}

class _GlassNavBarRegistrarState extends State<_GlassNavBarRegistrar> {
  GlassNavigationShellState? _shell;
  ModalRoute<dynamic>? _route;
  bool _handedOver = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_GlassNavBarRegistrar oldWidget) {
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
    if (shell == null || route == null || !shell.isActive) {
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
        showsBackButton:
            widget.pinnedBackButton && route.impliesAppBarDismissal,
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
  Widget build(BuildContext context) => widget.builder(context, _handedOver);
}
