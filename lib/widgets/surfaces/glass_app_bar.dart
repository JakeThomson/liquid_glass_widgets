import 'package:flutter/material.dart';
import '../../src/renderer/liquid_glass_renderer.dart';
import '../../theme/glass_theme_helpers.dart';
import '../../types/glass_quality.dart';
import '../shared/adaptive_glass.dart';

/// A navigation bar layout widget following Apple's iOS 26 design patterns.
///
/// By default, [GlassAppBar] renders a **transparent** bar with leading widget,
/// centered title, and trailing actions — matching iOS 26's navigation bar where
/// the glass effect is on the individual buttons, not the bar itself.
///
/// ## Scroll-Driven Glass (iOS 26 scrollEdgeAppearance)
///
/// Pass a [scrollController] and [settings] to enable the scroll-edge glass
/// transition. At scroll offset 0, the bar is fully transparent. As content
/// scrolls behind the bar, the glass material smoothly fades in:
///
/// ```dart
/// final _scrollController = ScrollController();
///
/// Scaffold(
///   extendBodyBehindAppBar: true,
///   appBar: GlassAppBar(
///     title: Text('Messages'),
///     scrollController: _scrollController,
///     settings: LiquidGlassSettings(blur: 15, thickness: 10),
///   ),
///   body: ListView.builder(
///     controller: _scrollController,
///     itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
///   ),
/// )
/// ```
///
/// ## Static Glass (opt-in, no scroll)
///
/// Pass [settings] without a [scrollController] for a permanently visible
/// glass background:
///
/// ```dart
/// GlassAppBar(
///   settings: LiquidGlassSettings(blur: 15, thickness: 10),
///   title: Text('Always Glass'),
/// )
/// ```
///
/// ## Default (Transparent — iOS 26 style)
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
/// This widget implements [PreferredSizeWidget] for use in [Scaffold.appBar].
class GlassAppBar extends StatefulWidget implements PreferredSizeWidget {
  /// Creates a glass app bar.
  ///
  /// By default renders a transparent navigation bar (no glass surface).
  /// Pass [settings] to opt in to a glass background. Add [scrollController]
  /// to enable scroll-driven glass transitions matching iOS 26.
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.backgroundColor = Colors.transparent,
    this.preferredSize = const Size.fromHeight(44.0),
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.settings,
    this.useOwnLayer = false,
    this.quality,
    this.scrollController,
    this.scrollEdgeThreshold = 50.0,
  });

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
  /// Defaults to [Colors.transparent] to match iOS 26's transparent
  /// navigation bar pattern.
  final Color backgroundColor;

  /// The preferred height of the app bar.
  @override
  final Size preferredSize;

  /// Padding around the app bar content.
  final EdgeInsetsGeometry padding;

  /// Glass effect settings for the glass background.
  ///
  /// When `null` (default), the app bar renders with a transparent background
  /// matching iOS 26's navigation bar pattern where glass effects are on
  /// individual buttons, not the bar itself.
  ///
  /// When provided without [scrollController], the glass is always visible.
  ///
  /// When provided with [scrollController], the glass transitions from
  /// transparent to fully visible as content scrolls behind the bar —
  /// matching iOS 26's scrollEdgeAppearance behaviour.
  final LiquidGlassSettings? settings;

  /// Whether to create its own layer or use grouped glass within an existing
  /// layer. Only used when [settings] is provided.
  ///
  /// - `false` (default): Uses [LiquidGlass.grouped], rendering within the
  ///   parent [GlassPage] or [AdaptiveLiquidGlassLayer].
  ///
  /// - `true`: Uses [LiquidGlass.withOwnLayer], creating an independent glass
  ///   rendering context.
  ///
  /// Defaults to false. Ignored when [settings] is null.
  final bool useOwnLayer;

  /// Rendering quality for the glass effect. Only used when [settings] is
  /// provided.
  ///
  /// If null, inherits from the ambient glass quality scope.
  final GlassQuality? quality;

  /// Scroll controller to drive the glass transition.
  ///
  /// When provided alongside [settings], the glass background fades in as
  /// the scroll offset increases from 0 to [scrollEdgeThreshold].
  ///
  /// This matches iOS 26's scrollEdgeAppearance where the navigation bar
  /// is transparent when content is at the top and gains a glass material
  /// when content scrolls behind it.
  ///
  /// The [GlassAppBar] does NOT own this controller — the caller is
  /// responsible for creating, attaching (to a [ScrollView]), and disposing
  /// it.
  final ScrollController? scrollController;

  /// The scroll offset (in logical pixels) at which the glass is fully
  /// visible.
  ///
  /// At offset 0, the glass is fully transparent. At [scrollEdgeThreshold],
  /// the glass is fully opaque. Values between are linearly interpolated.
  ///
  /// Defaults to 50.0 logical pixels.
  final double scrollEdgeThreshold;

  static const _appBarShape = LiquidRoundedRectangle(borderRadius: 0);

  @override
  State<GlassAppBar> createState() => _GlassAppBarState();
}

class _GlassAppBarState extends State<GlassAppBar> {
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
    // Read initial position if the controller is already attached.
    _syncScrollProgress();
  }

  @override
  void didUpdateWidget(GlassAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
      _syncScrollProgress();
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    _syncScrollProgress();
  }

  void _syncScrollProgress() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) {
      if (_scrollProgress != 0.0) setState(() => _scrollProgress = 0.0);
      return;
    }
    final offset = controller.offset;
    final threshold = widget.scrollEdgeThreshold;
    final progress = threshold > 0 ? (offset / threshold).clamp(0.0, 1.0) : 1.0;
    if (progress != _scrollProgress) {
      setState(() => _scrollProgress = progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build the app bar content layout.
    final appBarContent = SafeArea(
      bottom: false,
      child: Padding(
        padding: widget.padding,
        child: SizedBox(
          height: widget.preferredSize.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading widget
              if (widget.leading != null) widget.leading!,

              // Flexible title
              Expanded(
                child: widget.centerTitle
                    ? Center(child: widget.title ?? const SizedBox.shrink())
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: widget.title ?? const SizedBox.shrink(),
                        ),
                      ),
              ),

              // Trailing actions
              if (widget.actions != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: widget.actions!,
                ),
            ],
          ),
        ),
      ),
    );

    // ── No glass settings → simple transparent bar ──────────────────────
    if (widget.settings == null) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: appBarContent,
      );
    }

    // ── Resolve quality ─────────────────────────────────────────────────
    final effectiveQuality = GlassThemeHelpers.resolveQuality(
      context,
      widgetQuality: widget.quality,
      fallback: GlassQuality.premium,
    );

    // ── Static glass (no scroll controller) ─────────────────────────────
    if (widget.scrollController == null) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: AdaptiveGlass(
          shape: GlassAppBar._appBarShape,
          settings: widget.settings!,
          quality: effectiveQuality,
          useOwnLayer: widget.useOwnLayer,
          allowElevation: false,
          child: appBarContent,
        ),
      );
    }

    // ── Scroll-driven glass transition ──────────────────────────────────
    // iOS 26 renders content once on top, with the glass material as a
    // separate layer behind that fades in based on scroll offset.
    // When progress is 0, we skip building the glass widget entirely
    // to avoid unnecessary GPU work (shader, backdrop capture).
    return ColoredBox(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          // Glass surface behind content — fades in on scroll.
          // Not built at all when fully transparent (performance).
          if (_scrollProgress > 0)
            Positioned.fill(
              child: Opacity(
                opacity: _scrollProgress,
                child: AdaptiveGlass(
                  shape: GlassAppBar._appBarShape,
                  settings: widget.settings!,
                  quality: effectiveQuality,
                  useOwnLayer: widget.useOwnLayer,
                  allowElevation: false,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          // Content always on top — rendered exactly once.
          appBarContent,
        ],
      ),
    );
  }
}
