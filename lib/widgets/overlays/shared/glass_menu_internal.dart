part of '../glass_menu.dart';

class _GlassMenuState extends State<GlassMenu>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();

  late final AnimationController _animationController;
  late final ScrollController _scrollController;

  Size? _triggerSize;
  double? _triggerBorderRadius;
  Alignment _morphAlignment = Alignment.topLeft;

  final _springDescription = const SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 24.0,
  );

  // --- Selection Pill ---
  int? _hoveredIndex;
  Offset? _pointerDownPos;
  bool _isScrolling = false;
  double _scrollOffset = 0.0;

  // --- Wrapped-items cache (BUG 5: prevents GlassMenuItem remount per setState) ---
  List<Widget>? _cachedWrappedItems;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        if (mounted) setState(() => _scrollOffset = _scrollController.offset);
      });

    _animationController = AnimationController.unbounded(vsync: this);
    _animationController.addListener(() {
      if (mounted) setState(() {});
      if (_overlayController.isShowing &&
          _animationController.value <= 0.001 &&
          _animationController.status != AnimationStatus.forward) {
        _overlayController.hide();
      }
    });
  }

  @override
  void didUpdateWidget(GlassMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    // BUG 5: Invalidate wrapped-items cache when items list changes.
    if (!identical(widget.items, oldWidget.items)) {
      _cachedWrappedItems = null;
    }
    // BUG 4: Guard _hoveredIndex against RangeError when items are mutated.
    if (widget.items.length != oldWidget.items.length &&
        _hoveredIndex != null &&
        _hoveredIndex! >= widget.items.length) {
      _hoveredIndex = null;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Menu Control
  // ---------------------------------------------------------------------------

  void _runSpring(double target) {
    _animationController.animateWith(
      SpringSimulation(
          _springDescription, _animationController.value, target, 0.0),
    );
  }

  void _toggleMenu() {
    if (_overlayController.isShowing && _animationController.value > 0.1) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    _triggerSize = renderBox.size;
    _triggerBorderRadius = _triggerSize!.height / 2;

    final position = renderBox.localToGlobal(Offset.zero);
    final mq = MediaQuery.maybeOf(context);
    final screenWidth = mq?.size.width ?? double.infinity;
    final screenHeight = mq?.size.height ?? double.infinity;
    final menuH = _calculateMenuHeight();

    final isRightHalf = screenWidth.isFinite && position.dx > screenWidth / 2;
    final spaceBelow = screenHeight.isFinite
        ? screenHeight - (position.dy + _triggerSize!.height)
        : double.infinity;
    final spaceAbove = screenHeight.isFinite ? position.dy : double.infinity;

    _morphAlignment = (spaceBelow < menuH && spaceAbove > menuH)
        ? (isRightHalf ? Alignment.bottomRight : Alignment.bottomLeft)
        : (isRightHalf ? Alignment.topRight : Alignment.topLeft);

    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      _hoveredIndex = null;
      _isScrolling = false;
      _scrollOffset = 0.0;
    });

    _overlayController.show();
    _runSpring(1.0);
  }

  void _closeMenu() {
    setState(() => _hoveredIndex = null);
    _runSpring(0.0);
  }

  // ---------------------------------------------------------------------------
  // Height / Layout Helpers
  // ---------------------------------------------------------------------------

  double _getItemHeight(Widget item) {
    if (item is GlassMenuItem) {
      return (item.subtitle != null && item.height == 44.0)
          ? 58.0
          : item.height;
    }
    // QUALITY 3: GlassMenuLabel now exposes .height so custom fonts work.
    if (item is GlassMenuDivider) return item.height + 8.0;
    if (item is GlassMenuLabel) return item.height;
    return 44.0;
  }

  double _calculateMenuHeight() {
    if (widget.menuHeight != null) return widget.menuHeight! + 16.0;
    return widget.items.fold<double>(0.0, (s, i) => s + _getItemHeight(i)) +
        16.0;
  }

  double _calculateSwoopOffset(double t) =>
      (1.0 - 4.0 * (t - 0.5) * (t - 0.5)) * 5.0;

  // ---------------------------------------------------------------------------
  // Wrapped Items Cache (BUG 5)
  // ---------------------------------------------------------------------------

  /// Returns [GlassMenuItem] instances with [_closeMenu] wired in.
  ///
  /// Cached so that element identity is stable across the frequent [setState]
  /// calls driven by the spring animation ticker, preventing [_GlassMenuItemState]
  /// from remounting (which resets its pressed/hover state on every frame).
  List<Widget> _buildWrappedItems() {
    return _cachedWrappedItems ??= widget.items.map((item) {
      if (item is GlassMenuItem) {
        return GlassMenuItem(
          // Stable key prevents element reconciliation confusion.
          key: item.key ?? ValueKey(item.title),
          title: item.title,
          subtitle: item.subtitle,
          icon: item.icon,
          isDestructive: item.isDestructive,
          enabled: item.enabled,
          trailing: item.trailing,
          height: item.height,
          titleStyle: item.titleStyle,
          subtitleStyle: item.subtitleStyle,
          iconColor: item.iconColor,
          iconSize: item.iconSize,
          onTap: () {
            item.onTap();
            _closeMenu();
          },
        );
      }
      return item;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Selection Pill Helpers
  // ---------------------------------------------------------------------------

  /// Y-start of each item in the full (unscrolled) content column.
  List<double> _computeItemTops() {
    double y = 0.0;
    return widget.items.map((item) {
      final top = y;
      y += _getItemHeight(item);
      return top;
    }).toList();
  }

  /// [widget.items] index of the enabled [GlassMenuItem] under [contentY],
  /// adjusted for the current scroll offset.
  int? _indexAtContentY(double contentY) {
    final scrolledY = contentY + _scrollOffset;
    double y = 0.0;
    for (int i = 0; i < widget.items.length; i++) {
      final h = _getItemHeight(widget.items[i]);
      if (scrolledY >= y && scrolledY < y + h) {
        final item = widget.items[i];
        if (item is GlassMenuItem && item.enabled) return i;
        return null;
      }
      y += h;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Pointer Handlers
  // ---------------------------------------------------------------------------

  void _onMenuPointerDown(PointerDownEvent e) {
    _pointerDownPos = e.localPosition;
    _isScrolling = false;
    setState(() => _hoveredIndex = _indexAtContentY(e.localPosition.dy - 8));
  }

  void _onMenuPointerMove(PointerMoveEvent e) {
    if (_isScrolling) return;
    final dist = (e.localPosition - (_pointerDownPos ?? Offset.zero)).distance;
    if (dist > 10.0) {
      setState(() => _hoveredIndex = null);
      return;
    }
    setState(() => _hoveredIndex = _indexAtContentY(e.localPosition.dy - 8));
  }

  void _onMenuPointerUp(PointerUpEvent e) {
    _pointerDownPos = null;
    setState(() => _hoveredIndex = null);
  }

  void _onMenuPointerCancel(PointerCancelEvent e) {
    _pointerDownPos = null;
    setState(() => _hoveredIndex = null);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _isScrolling = true;
      setState(() => _hoveredIndex = null);
    } else if (notification is ScrollEndNotification) {
      _isScrolling = false;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isMenuOpen =
        _overlayController.isShowing && _animationController.value > 0.05;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Stack(
        children: [
          Opacity(
            opacity: isMenuOpen ? 0.0 : 1.0,
            child: IgnorePointer(
              ignoring: isMenuOpen,
              child: widget.triggerBuilder != null
                  ? widget.triggerBuilder!(context, _toggleMenu)
                  : GestureDetector(
                      onTap: _toggleMenu,
                      child: widget.trigger,
                    ),
            ),
          ),
          OverlayPortal(
            controller: _overlayController,
            overlayChildBuilder: _buildMorphingOverlay,
          ),
        ],
      ),
    );
  }

  Widget _buildMorphingOverlay(BuildContext context) {
    if (_triggerSize == null) return const SizedBox.shrink();
    final value = _animationController.value.clamp(0.0, 1.0);

    return Stack(
      children: [
        if (value > 0.3)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeMenu,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: _morphAlignment,
          followerAnchor: _morphAlignment,
          offset: Offset(0, _calculateSwoopOffset(value)),
          child: LiquidStretch(
            interactionScale: widget.interactionScale,
            stretch: widget.stretch,
            resistance: widget.stretchResistance,
            axis: widget.stretchAxis,
            allowPositiveX: widget.allowPositiveX,
            allowNegativeX: widget.allowNegativeX,
            allowPositiveY: widget.allowPositiveY,
            allowNegativeY: widget.allowNegativeY,
            hitTestBehavior: HitTestBehavior.translucent,
            child: _buildMorphingContainer(value),
          ),
        ),
      ],
    );
  }

  Widget _buildMorphingContainer(double value) {
    final effectiveQuality = GlassThemeHelpers.resolveQuality(
      context,
      widgetQuality: widget.quality,
    );

    final menuHeight = _calculateMenuHeight();
    final currentWidth =
        lerpDouble(_triggerSize!.width, widget.menuWidth, value)!;
    final currentHeight = value < 0.85
        ? lerpDouble(_triggerSize!.height, menuHeight, value)!
        : null;
    final currentBorderRadius = lerpDouble(
      _triggerBorderRadius ?? 16.0,
      widget.menuBorderRadius,
      value,
    )!;

    // Content fade-in starts only once the container has reached its natural
    // (unconstrained) height at value >= 0.85. Showing content earlier caused
    // a tight-height cascade: GlassContainer(height: currentHeight) constrained
    // its subtree tightly, the Column inside Positioned.fill received that
    // tight height, and overflowed its items by ~18px.
    // By waiting until currentHeight == null the container wraps its content
    // naturally and no overflow is possible.
    final menuOpacity = ((value - 0.85) / 0.15).clamp(0.0, 1.0);
    final containerOpacity = (value / 0.3).clamp(0.0, 1.0);

    final inheritedSettings = InheritedLiquidGlass.of(context);
    final effectiveSettings = widget.glassSettings ??
        inheritedSettings ??
        const LiquidGlassSettings(
          blur: 10,
          thickness: 10,
          glassColor: Color.fromRGBO(255, 255, 255, 0.12),
          lightAngle: GlassDefaults.lightAngle,
          lightIntensity: 0.7,
          ambientStrength: 0.4,
          saturation: 1.2,
          refractiveIndex: 0.7,
          chromaticAberration: 0.0,
        );

    // BUG 1 FIX: GlassContainer already applies BackdropFilter internally via
    // LightweightLiquidGlass. Adding a second BackdropFilter here doubled the
    // blur sigma, producing a visually incorrect "over-frosted ring" around the
    // menu inconsistent with all other glass surfaces in the package.
    //
    // DETACHED-LAYER FIX: The outer RepaintBoundary was removed. When
    // GlassContainer(useOwnLayer: true) creates a BackdropFilter layer, it
    // forces compositing on the entire subtree. A wrapping RepaintBoundary
    // would fight the compositor for layer ownership, leaving its OffsetLayer
    // DETACHED from the scene — causing GlassMenuItem RepaintBoundary nodes to
    // be painted but never wired into the render tree. GlassGlow and
    // GlassContainer already own their compositing layers; no extra boundary
    // is needed.
    //
    // Also avoid instantiating an Opacity widget when fully opaque — an Opacity
    // at 1.0 still creates an OpacityLayer when compositing is forced by a
    // BackdropFilter descendant, which is wasteful and can mis-sequence layers.
    // GLOW CLIP FIX: GlassGlow must sit INSIDE GlassContainer's clip so the
    // radial gradient is confined to the menu's glass shape. When GlassGlow
    // wrapped GlassContainer from the outside, _RenderGlassGlowLayer.paint()
    // drew canvas.drawCircle() over the full overlay canvas with no shape
    // boundary, causing the glow to bleed onto the background behind the menu.
    // GlassButton avoids this by keeping GlassGlow inside AdaptiveGlass's clip.
    final glassContent = GlassContainer(
      useOwnLayer: true,
      settings: effectiveSettings,
      quality: effectiveQuality,
      allowElevation: false,
      width: currentWidth,
      height: currentHeight,
      shape: LiquidRoundedSuperellipse(borderRadius: currentBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: GlassGlow(
        enabled: widget.enableInteractionGlow,
        glowOnTapOnly: widget.glowOnTapOnly,
        glowColor: widget.glowColor ?? Colors.white.withValues(alpha: 0.15),
        glowRadius: widget.glowRadius,
        hitTestBehavior: HitTestBehavior.translucent,
        child: Stack(
          alignment: _morphAlignment,
          clipBehavior: Clip.antiAlias,
          children: [
            // Render content only when value >= 0.85 — at that point
            // currentHeight is null and GlassContainer sizes naturally,
            // so the Column never fights a tight height constraint.
            if (value >= 0.85)
              menuOpacity >= 1.0
                  ? SizedBox(
                      width: currentWidth,
                      child: _buildMenuContent(currentBorderRadius),
                    )
                  : Opacity(
                      opacity: menuOpacity,
                      child: SizedBox(
                        width: currentWidth,
                        child: _buildMenuContent(currentBorderRadius),
                      ),
                    ),
          ],
        ),
      ),
    );

    // Only wrap in Opacity during the fade-in phase; once fully opaque skip
    // the widget entirely so no OpacityLayer is inserted into the layer tree.
    return containerOpacity >= 1.0
        ? glassContent
        : Opacity(opacity: containerOpacity, child: glassContent);
  }

  Widget _buildMenuContent(double borderRadius) {
    final pillRadius = (borderRadius - 8).clamp(4.0, double.infinity);
    final selectionColor =
        widget.selectionColor ?? Colors.white.withValues(alpha: 0.12);

    final wrappedItems = _buildWrappedItems();
    final tops = _computeItemTops();

    // Total unscrolled content height — needed to give the Stack a fixed size
    // so AnimatedPositioned has a bounded parent (BUG 2 FIX).
    final totalH =
        widget.items.fold<double>(0.0, (s, i) => s + _getItemHeight(i));

    // BUG 2 FIX: AnimatedPositioned requires a bounded Stack. We give the Stack
    // an explicit height via SizedBox(height: totalH). This also ensures the
    // pill position (tops[i]) is always within [0, totalH), preventing overflow.
    // The pill and items are siblings in the same Stack, so they scroll together
    // when inside SingleChildScrollView — NO _scrollOffset subtraction needed.
    Widget content = SizedBox(
      height: totalH,
      child: Stack(
        // OVERFLOW FIX: Clip the items stack so that during the wide→menu morph
        // transition the Column children (and any AnimatedScale transforms that
        // retain their pre-scale layout size) cannot report overflow to the
        // framework. The outer GlassContainer already clips visually; this just
        // suppresses the spurious debug overflow banner during resize.
        clipBehavior: Clip.hardEdge,
        children: [
          // Selection pill is drawn first so it sits BEHIND the items.
          // BUG 4 FIX: bounds-check _hoveredIndex before indexing.
          if (_hoveredIndex != null &&
              !_isScrolling &&
              _hoveredIndex! < widget.items.length)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutCubic,
              top: tops[_hoveredIndex!].clamp(
                0.0,
                (totalH - _getItemHeight(widget.items[_hoveredIndex!]))
                    .clamp(0.0, double.infinity),
              ),
              left: 0,
              right: 0,
              height: _getItemHeight(widget.items[_hoveredIndex!]),
              child: Container(
                decoration: BoxDecoration(
                  color: selectionColor,
                  borderRadius: BorderRadius.circular(pillRadius),
                ),
              ),
            ),
          // Items drawn on top of the pill.
          Positioned.fill(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: wrappedItems,
            ),
          ),
        ],
      ),
    );

    // Wrap in scrollable when menuHeight is set.
    if (widget.menuHeight != null) {
      content = SizedBox(
        height: widget.menuHeight! - 16,
        child: ClipRect(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              child: content,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Listener(
        onPointerDown: _onMenuPointerDown,
        onPointerMove: _onMenuPointerMove,
        onPointerUp: _onMenuPointerUp,
        onPointerCancel: _onMenuPointerCancel,
        child: content,
      ),
    );
  }
}
