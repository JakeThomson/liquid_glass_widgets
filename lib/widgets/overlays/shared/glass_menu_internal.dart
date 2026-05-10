part of '../glass_menu.dart';

class _GlassMenuState extends State<GlassMenu> with TickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();

  late final AnimationController _animationController;
  late final ScrollController _scrollController;
  Size? _triggerSize;
  double? _triggerBorderRadius;
  int? _hoveredIndex;
  bool _isDragging = false;
  bool _hasStretched =
      false; // Prevents closing if we moved into stretch territory
  double _initialScrollOffset = 0.0;
  Offset _initialLocalPosition = Offset.zero;

  // --- Granular Update System (Performance + No flicker) ---
  // We cache the outer list but use notifiers to update selection state
  // without rebuilding the entire menu tree.
  late final ValueNotifier<int?> _hoveredIndexNotifier;
  late final ValueNotifier<bool> _isDraggingNotifier;
  List<Widget>? _cachedWrappedItems;

  @override
  void didUpdateWidget(GlassMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.items, oldWidget.items)) {
      _cachedWrappedItems = null;
      // BUG 12 FIX: Clear hover state if items shrink while menu is open
      // to prevent RangeError when the selection pill tries to measure
      // a now-deleted index.
      if (widget.items.length < oldWidget.items.length) {
        _hoveredIndex = null;
        _hoveredIndexNotifier.value = null;
      }
    }
  }

  // ─── iOS 26 Spring Physics ────────────────────────────────────────────────
  //
  // OPEN — fast and clean (ζ≈0.69): no bounce, ~0.28s settle.
  //   Teardrop forms quickly, content reveals smoothly.
  //   ω₀ = √360 ≈ 19.0 rad/s
  //   ζ  = 26 / (2×19.0) ≈ 0.68 — slightly underdamped, clean settle
  //
  // CLOSE — HEAVILY UNDERDAMPED (ζ≈0.32): strong rubber-band physics.
  //   rawValue oscillates: 1.0 → 0.0 → −0.34 → 0.0 → +0.11 → settles.
  //   Blob squeezes visibly below button size then bounces back — liquid splash.
  //   Overlay stays visible through all bounces via velocity guard on hide.
  //   ω₀ = √350 ≈ 18.7 rad/s → response ≈ 0.34s
  //   ζ  = 12 / (2×18.7) ≈ 0.32 — heavily underdamped: multi-bounce visible
  static const _openSpring = SpringDescription(
    mass: 1.0,
    stiffness: 360.0, // response ≈ 0.28s — fast, clean open
    damping: 26.0,    // ζ ≈ 0.69 — near-critically-damped, no bounce on open
  );

  // CLOSE — heavily underdamped (ζ≈0.32).
  // rawValue trajectory: 1.0 → ~0 (first cross) → −0.34 → ~0 → +0.11 → settle.
  // Blob squeezes to ~81% of button size at first undershoot, pops back out.
  // AnimationController.unbounded handles negative rawValue.
  // Overlay hides ONLY when settled — see velocity guard in initState.
  static const _closeSpring = SpringDescription(
    mass: 1.0,
    stiffness: 350.0, // response ≈ 0.34s — fast collapse with bouncing
    damping: 12.0,    // ζ ≈ 0.32 — HEAVILY underdamped: strong rubber band
  );

  Alignment _morphAlignment = Alignment.topLeft;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController.unbounded(vsync: this);
    _animationController.addListener(() {
      if (mounted) setState(() {});

      // Hide overlay only when the spring has FULLY SETTLED near 0.
      // Velocity guard prevents premature hiding on first zero-crossing
      // during the underdamped close bounce — without this, the overlay
      // disappears at ~165ms and the rubber-band bounces are never seen.
      if (_overlayController.isShowing &&
          _animationController.value <= 0.001 &&
          _animationController.velocity.abs() < 0.5 &&
          _animationController.status != AnimationStatus.forward) {
        _overlayController.hide();
      }
    });
    _scrollController = ScrollController();
    _hoveredIndexNotifier = ValueNotifier(null);
    _isDraggingNotifier = ValueNotifier(false);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _hoveredIndexNotifier.dispose();
    _isDraggingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawValue = _animationController.value;

    // The blob IS the button from frame 0 — same position, same shape,
    // fully opaque. We hide the underlying trigger whenever the overlay is
    // open so it doesn't double-render underneath the morphing blob.
    final isButtonVisible = !_overlayController.isShowing;

    // Block trigger taps while menu is significantly open.
    final isMenuBlocking = _overlayController.isShowing && rawValue > 0.8;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Stack(
        children: [
          // Trigger — hidden while blob is the visual stand-in.
          Opacity(
            opacity: isButtonVisible ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: isMenuBlocking,
              child: widget.triggerBuilder != null
                  ? widget.triggerBuilder!(context, _toggleMenu)
                  : GestureDetector(
                      onTap: _toggleMenu,
                      child: widget.trigger,
                    ),
            ),
          ),

          // Overlay portal for morphing animation
          OverlayPortal(
            controller: _overlayController,
            overlayChildBuilder: _buildMorphingOverlay,
          ),
        ],
      ),
    );
  }

  /// Runs a spring simulation toward [target].
  ///
  /// [velocityHint] is the gesture velocity (in logical pixels/s) that is
  /// injected as the spring's initial velocity, normalised to the 0–1 animation
  /// space.  A positive value means the gesture was moving in the "open"
  /// direction; negative means closing.  Defaults to 0 (tap with no drag).
  void _runSpring(double target, {double velocityHint = 0.0}) {
    // Select spring profile based on direction.
    final spring = target > 0.5 ? _openSpring : _closeSpring;
    final simulation = SpringSimulation(
      spring,
      _animationController.value,
      target,
      velocityHint, // Inject gesture velocity for organic feel
    );
    _animationController.animateWith(simulation);
  }

  void _toggleMenu() {
    if (_overlayController.isShowing && _animationController.value > 0.1) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    // Capture geometry and screen position for morphing
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      // Safety: Cannot open menu if render box is not ready
      return;
    }

    _triggerSize = renderBox.size;
    _triggerBorderRadius = _triggerSize!.height / 2;

    // Determine alignment based on screen position
    // This ensures menu doesn't overflow screen edges
    final position = renderBox.localToGlobal(Offset.zero);
    final mediaQuery = MediaQuery.maybeOf(context);
    final screenWidth = mediaQuery?.size.width ?? double.infinity;
    final screenHeight = mediaQuery?.size.height ?? double.infinity;

    // Calculate menu height for vertical boundary check
    final menuHeight = _calculateMenuHeight();

    // Horizontal alignment: left vs right half
    final isRightHalf = screenWidth.isFinite && position.dx > screenWidth / 2;

    // Vertical alignment: check if menu would overflow bottom
    final spaceBelow = screenHeight.isFinite
        ? screenHeight - (position.dy + _triggerSize!.height)
        : double.infinity;
    final spaceAbove = screenHeight.isFinite ? position.dy : double.infinity;

    // Prefer downward opening unless insufficient space
    final shouldFlipVertical =
        spaceBelow < menuHeight && spaceAbove > menuHeight;

    // Determine final alignment based on both axes
    if (shouldFlipVertical) {
      _morphAlignment =
          isRightHalf ? Alignment.bottomRight : Alignment.bottomLeft;
    } else {
      _morphAlignment = isRightHalf ? Alignment.topRight : Alignment.topLeft;
    }

    _overlayController.show();
    // No velocity hint: overdamped spring starts from rest for a clean,
    // smooth teardrop expansion with no artificial kick.
    _runSpring(1.0, velocityHint: 0.0);
  }

  void _closeMenu() {
    setState(() {
      _hoveredIndex = null;
      _isDragging = false;
    });
    // Strong initial kick: immediately drives the blob into fast collapse,
    // maximising the visible rubber-band bounce amplitude at the end.
    _runSpring(0.0, velocityHint: -2.5);
  }

  Widget _buildMorphingOverlay(BuildContext context) {
    if (_triggerSize == null) return const SizedBox.shrink();

    // Clamp animation value to prevent overshoot artifacts
    final value = _animationController.value.clamp(0.0, 1.0);

    return Stack(
      children: [
        // Backdrop barrier (only active when menu is significantly open)
        if (value > 0.3)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeMenu,
              child: Container(
                color: Colors.black
                    .withValues(alpha: 0.0), // Invisible but tappable
              ),
            ),
          ),

        // Morphing glass container
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          // anchor based on calculated alignment
          targetAnchor: _morphAlignment,
          followerAnchor: _morphAlignment,
          // iOS 26 "liquid swoop" offset:
          // - Parabolic curve creates smooth, gravity-like arc
          // - Subtle 5px vertical displacement at peak (t=0.5)
          // - Seamless in both directions (opening and closing)
          offset: Offset(0, _calculateSwoopOffset(value)),
          child: IgnorePointer(
            ignoring: value < 0.8,
            child: _buildMorphingContainer(value),
          ),
        ),
      ],
    );
  }

  /// Parabolic downward swoop — blob physically drops during the teardrop
  /// phase then rises back to its anchor. 14px amplitude makes the drop
  /// clearly visible before the menu settles into its rectangle shape.
  double _calculateSwoopOffset(double t) {
    return 4.0 * t * (1.0 - t) * 14.0; // 14px max drop, peak at t=0.5
  }

  /// Calculates the total height of the menu content.
  ///
  /// Sums up all menu item heights plus padding to determine the target height
  /// for the morphing animation.
  double _calculateMenuHeight() {
    // Sum all menu item heights (each defaults to 44.0)
    final itemHeights = widget.items.fold<double>(
      0.0,
      (sum, item) => sum + _getItemHeight(item),
    );

    // Add vertical padding (12px top + 12px bottom = 24px total)
    // plus vertical gaps between items (2px each)
    final gaps = (widget.items.length - 1) * 2.0;
    return itemHeights + 24.0 + gaps;
  }

  Widget _buildMorphingContainer(double value) {
    // Inherit quality from parent layer if not explicitly set
    final effectiveQuality = GlassThemeHelpers.resolveQuality(
      context,
      widgetQuality: widget.quality,
    );

    // Raw (unclamped) value — drives overshoot/undershoot scale and opacity.
    // Can exceed 1.0 (open overshoot) or go below 0.0 (close undershoot bounce).
    final rawValue = _animationController.value;

    // Calculate menu height by measuring its natural size
    // This is necessary for proper height interpolation during morph
    final menuHeight = _calculateMenuHeight();

    // ─── iOS 26 Liquid Drop Morph Curves ──────────────────────────────────────
    //
    // Frame-by-frame analysis of native iOS 26 Photos app (30fps):
    //
    // OPEN (frames 43→47, ~130ms):
    //   Early frames show a blob that is taller than wide → HEIGHT LEADS.
    //   Frame 43 is clearly taller than wide (teardrop falling downward).
    //   → HEIGHT uses easeOutCubic (front-loaded, drops down fast)
    //   → WIDTH uses easeInOutCubic (surface tension holds; releases mid-morph)
    //   → High border-radius makes the narrow-tall shape look like a droplet.
    //
    // CLOSE (frames 91→95, ~100ms):
    //   Frames 92→93 are clearly taller than wide → WIDTH collapses first.
    //   → WIDTH uses easeInCubic (collapses fast to button width)
    //   → HEIGHT uses easeInOutCubic (lingers, creating the narrow tall pill)
    //   → This makes the droplet look like it's being sucked back upward.

    final targetHeight = widget.menuHeight ?? menuHeight;
    final isClosing = _animationController.velocity <= 0;

    double heightT;
    double widthT;

    if (!isClosing) {
      // OPEN: height races ahead (easeOutQuart — very front-loaded),
      // width is held back (easeInQuart — barely moves until t>0.7).
      // At t=0.4: height≈76%, width≈2.6% → pronounced water-droplet shape.
      // At t=0.7: height≈99%, width≈24% → long narrow teardrop before widening.
      heightT = Curves.easeOutQuart.transform(value);
      widthT = Curves.easeInQuart.transform(value);
    } else {
      // CLOSE: width collapses ultra-fast (easeInQuart),
      // height lingers (easeInCubic) → narrow vertical pill before final snap.
      widthT = Curves.easeInQuart.transform(value);
      heightT = Curves.easeInCubic.transform(value);
    }

    final currentHeight = value < 0.92
        ? lerpDouble(_triggerSize!.height, targetHeight, heightT)!
        : widget.menuHeight; // Let content breathe at full open

    final currentWidth =
        lerpDouble(_triggerSize!.width, widget.menuWidth, widthT)!;

    // ─── Asymmetric Teardrop Border Radii ────────────────────────────────────────
    //
    // The water-droplet teardrop shape requires DIFFERENT radii top vs bottom:
    //
    //   TOP corners: large radius (close to buttonRadius) — stays round and
    //     narrow like the button for most of the animation. Visually the top
    //     of the blob looks narrow/pinched (like the neck of a hanging droplet).
    //
    //   BOTTOM corners: smaller radius (transitions to menuRadius faster) —
    //     the bottom becomes flatter/wider-looking earlier, giving the shape
    //     the classic "bulge at the bottom" of a falling water droplet.
    //
    // At t=0.4 during open:
    //   topRadius ≈ buttonR (very round, narrow-looking top)
    //   bottomRadius ≈ menuR (squarer, wider-looking bottom)
    //   height ≈ 76% of menu height (tall)
    //   width ≈ 2.6% of menu width (narrow)
    //   → Result: a tall narrow shape, round at top, squarer at bottom = droplet
    final triggerR = _triggerBorderRadius ?? 16.0;
    // Top stays at buttonR until late (cubic easing — very slow to leave buttonR)
    final topRadius = lerpDouble(triggerR, widget.menuBorderRadius,
        math.pow(value, 3.0).toDouble())!;
    // Bottom transitions faster (linear — immediately starts moving toward menuR)
    final bottomRadius = lerpDouble(triggerR, widget.menuBorderRadius, value)!;
    // Add sinusoidal boost at midpoint for extra organic roundness
    final radiusBoost = 8.0 * math.sin(math.pi * value);
    final effectiveTopRadius = topRadius + radiusBoost;
    final effectiveBottomRadius = bottomRadius;

    // Build the asymmetric teardrop shape
    final teardropShape = LiquidVerticalRoundedSuperellipse(
      topRadius: effectiveTopRadius,
      bottomRadius: effectiveBottomRadius,
    );


    // ─── Jelly / Squash-and-Stretch ─────────────────────────────────────────
    //
    // Driven by the spring's own instantaneous velocity — same physics as the
    // LiquidStretch bottom bar. High velocity → stretch in direction of travel.
    // Low velocity (settling) → squash back. Creates rubber-band feel.
    //
    // OPEN (positive velocity):
    //   • Height stretches TALLER (+45% of jelly) — falling-drop elongation
    //   • Width squashes NARROWER (−30% of jelly) — surface tension hold
    //
    // CLOSE (negative velocity → jelly is negative):
    //   • Height squashes shorter  → (-jelly)*stretch so it gets taller again? No:
    //     jellyHeight = h * (1.0 + jelly*0.45) — jelly<0 → shorter on close ✓
    //   • Width bulges wider:
    //     jellyWidth = w * (1.0 - jelly*0.30) — jelly<0 → +term → wider ✓
    //     Creates the bottom-heavy splash as the droplet collapses.
    //
    // Coefficient 0.022 — at peak close velocity (~−14 units/s): jelly≈−0.22,
    // clamped to −0.22. Width bulges ×1.066. Height squashes ×0.90.
    final rawVelocity = _animationController.velocity;
    final jelly = (rawVelocity * 0.022).clamp(-0.22, 0.22);

    // Squash-and-stretch (area approximately conserved: 1.10 × 0.934 ≈ 1.03)
    final jellyWidth = currentWidth * (1.0 - jelly * 0.30);
    final jellyHeight =
        currentHeight != null ? currentHeight * (1.0 + jelly * 0.45) : null;



    // ─── Container Scale Pulse ───────────────────────────────────────────────
    //
    // Open overshoot (rawValue > 1.0): not triggered — spring is overdamped.
    //
    // Close undershoot (rawValue < 0.0): blob squeezes visibly BELOW button
    //   size. Factor 0.55 means at rawValue=-0.34: scale = 1 - 0.34*0.55 = 0.81.
    //   Blob squeezes to 81% of button size. On second bounce (rawValue=+0.11):
    //   value=0.11, blob briefly expands toward menu size — genuine rubber band.
    final containerScale = rawValue > 1.0
        ? 1.0 + (rawValue - 1.0) * 0.10   // open overshoot (overdamped, won't fire)
        : rawValue < 0.0
            ? 1.0 + rawValue * 0.55        // close undershoot → strong squeeze
            : 1.0;

    // ─── Item Stagger ─────────────────────────────────────────────────────────
    // Pre-compute per-item stagger offsets (used in _buildMorphingContainer
    // via the items list length).  Each item is offset by 20ms relative to
    // the previous one so they cascade in smoothly from top-to-bottom.

    // Inherit settings from context (like GlassCard/GlassContainer)
    // If user provides custom settings, use those. Otherwise, check for inherited
    // settings from parent layer. If none, use subtle overlay defaults.
    // This matches the pattern used by all other glass widgets.
    final inheritedSettings = InheritedLiquidGlass.of(context);
    final effectiveSettings = widget.glassSettings ??
        inheritedSettings ??
        const LiquidGlassSettings(
          blur: 10,
          thickness: 10,
          glassColor: Color.fromRGBO(255, 255, 255, 0.12),
          lightAngle: GlassDefaults.lightAngle, // Apple iOS 26 standard
          lightIntensity: 0.7,
          ambientStrength: 0.4,
          saturation: 1.2,
          refractiveIndex: 0.7, // Thin rim - iOS 26 delicate aesthetic
          chromaticAberration: 0.0,
        );

    final glassContent = LiquidStretch(
      stretch: widget.stretch,
      interactionScale: widget.interactionScale,
      resistance: widget.stretchResistance,
      axis: widget.stretchAxis,
      suppressInteractionOnChildren: false,
      // Constrain stretch to 'Down' and 'Away from screen edge' by default,
      // but allow explicit user overrides.
      allowPositiveX: widget.allowPositiveX ?? (_morphAlignment.x < 0),
      allowNegativeX: widget.allowNegativeX ?? (_morphAlignment.x > 0),
      allowPositiveY: widget.allowPositiveY ?? (_morphAlignment.y < 0),
      allowNegativeY: widget.allowNegativeY ?? (_morphAlignment.y > 0),
      child: GlassContainer(
        useOwnLayer: true,
        settings: effectiveSettings,
        quality: effectiveQuality,
        allowElevation:
            false, // Menu is overlay - don't darken when outside parent
        width: jellyWidth,
        height: jellyHeight, // Constrained during morph, natural when open
        shape: teardropShape,
        clipBehavior:
            Clip.antiAlias, // Clip items at the edges for edge-to-edge feel
        glowIntensity: widget.glowIntensity,
        child: GlassGlow(
          enabled: widget.enableInteractionGlow,
          glowOnTapOnly: widget.glowOnTapOnly,
          glowColor: widget.glowColor ?? Colors.white.withValues(alpha: 0.15),
          glowRadius: widget.glowRadius,
          glowBlurRadius: 40,
          clipper: ShapeBorderClipper(
            shape: teardropShape,
          ),
          child: Transform.scale(
            scale: containerScale,
            alignment: Alignment.center,
            child: Stack(
              alignment: _morphAlignment, // Align internal stack content
              clipBehavior:
                  Clip.none, // Prevent double-clip artifacts during stretch
              children: [
                // Menu content — only appears when container is nearly at
                // full size (0.94+), so the teardrop morph is fully visible
                // first. Items stagger in rapidly in the last 6% of animation.
                if (value > 0.94)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Sliding selection pill (background)
                      ValueListenableBuilder<int?>(
                        valueListenable: _hoveredIndexNotifier,
                        builder: (context, hoveredIndex, _) {
                          if (hoveredIndex == null) {
                            return const SizedBox.shrink();
                          }
                          return AnimatedPositioned(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutCubic,
                            left: 12,
                            right: 12,
                            top: _getItemOffset(hoveredIndex) -
                                (_scrollController.hasClients
                                    ? _scrollController.offset
                                    : 0.0),
                            height: _getItemHeight(widget.items[hoveredIndex]),
                            child: Container(
                              decoration: BoxDecoration(
                                color: widget.selectionColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0x0DFFFFFF), // 5% white border
                                  width: 0.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Listener(
                        onPointerDown: (event) {
                          _isDragging = true;
                          _isDraggingNotifier.value = true;
                          _hasStretched = false;
                          _initialLocalPosition = event.localPosition;
                          _initialScrollOffset = _scrollController.hasClients
                              ? _scrollController.offset
                              : 0.0;
                          _updateHoveredIndex(event.localPosition);
                        },
                        onPointerMove: (event) {
                          if (_isDragging) {
                            _updateHoveredIndex(event.localPosition);
                          }
                        },
                        onPointerUp: (event) {
                          if (_isDragging) {
                            if (_hoveredIndex != null) {
                              final currentOffset = _scrollController.hasClients
                                  ? _scrollController.offset
                                  : 0.0;
                              final scrollDisplacement =
                                  (currentOffset - _initialScrollOffset).abs();
                              final dragDisplacement =
                                  (event.localPosition - _initialLocalPosition)
                                      .distance;

                              if (scrollDisplacement < 10 &&
                                  dragDisplacement < 10) {
                                final item = widget.items[_hoveredIndex!];
                                if (item is GlassMenuItem) {
                                  if (item.enabled) {
                                    item.onTap();
                                    _closeMenu();
                                  }
                                }
                              }
                            }
                            _isDragging = false;
                            _isDraggingNotifier.value = false;
                            _hoveredIndex = null;
                            _hoveredIndexNotifier.value = null;
                            _hasStretched = false;
                          }
                        },
                        onPointerCancel: (_) {
                          _isDragging = false;
                          _isDraggingNotifier.value = false;
                          _hoveredIndex = null;
                          _hoveredIndexNotifier.value = null;
                        },
                        child: SizedBox(
                          width: currentWidth,
                          height: widget.menuHeight, // Apply fixed height
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const ClampingScrollPhysics(), // iOS-style
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 12), // Top padding
                                  ..._buildWrappedItems()
                                      .asMap()
                                      .entries
                                      .expand((entry) {
                                    // Center-out stagger: items in the
                                    // MIDDLE of the menu appear first, then
                                    // top and bottom items fade in together.
                                    // Creates the "reveal upward AND downward"
                                    // splash effect from the drop center.
                                    final itemCount = widget.items.length;
                                    final midPoint = (itemCount - 1) / 2.0;
                                    final distFromCenter = midPoint == 0
                                        ? 0.0
                                        : ((entry.key.toDouble() - midPoint) / midPoint).abs();
                                    // Center items at 0.94, edge items at 0.985
                                    final staggerStart = 0.94 + distFromCenter * 0.045;
                                    final staggerEnd = (staggerStart + 0.06)
                                        .clamp(0.0, 1.0);
                                    final itemOpacity = ((value - staggerStart) /
                                            (staggerEnd - staggerStart))
                                        .clamp(0.0, 1.0);
                                    return [
                                      Opacity(
                                        opacity: itemOpacity,
                                        child: entry.value,
                                      ),
                                      if (entry.key < widget.items.length - 1)
                                        const SizedBox(height: 2),
                                    ];
                                  }),
                                  const SizedBox(height: 12), // Bottom padding
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ), // outer Stack
          ), // Transform.scale
        ), // GlassGlow
      ), // GlassContainer
    ); // LiquidStretch (glassContent)

    // The blob is always fully opaque — shape morph is the only animation.
    return glassContent;
  }

  List<Widget> _buildWrappedItems() {
    return _cachedWrappedItems ??= widget.items.asMap().entries.map((entry) {
      final item = entry.value;

      if (item is GlassMenuItem) {
        return _SelectionItemWrapper(
          index: entry.key,
          hoverNotifier: _hoveredIndexNotifier,
          dragNotifier: _isDraggingNotifier,
          builder: (context, isSelected, isPressed) {
            return GlassMenuItem(
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
              isSelected: isSelected,
              isPressed: isPressed,
              onTap:
                  () {}, // Provide empty callback to enable GestureDetector feedback
            );
          },
        );
      }
      return item;
    }).toList();
  }

  double _getItemHeight(Widget item) {
    if (item is GlassMenuItem) return item.height;
    if (item is GlassMenuDivider) return item.height;
    if (item is GlassMenuLabel) return item.height;
    return 44.0;
  }

  double _getItemOffset(int index) {
    double offset = 12.0; // Top padding
    for (int i = 0; i < index; i++) {
      offset += _getItemHeight(widget.items[i]) + 2.0; // height + 2px gap
    }
    return offset;
  }

  void _updateHoveredIndex(Offset localPosition) {
    // Detect if we've moved into "stretch territory" (outside visible menu bounds)
    // We use the visible container height if fixed, otherwise the natural height.
    final visibleHeight = widget.menuHeight ?? _calculateMenuHeight();
    final x = localPosition.dx;
    final dy = localPosition.dy;

    // We add a 100px buffer to allow for intense liquid stretching without accidental closure.
    // We also allow cancelling the stretch if the user moves their finger back.
    final outsideBounds = dy < -100 ||
        dy > visibleHeight + 100 ||
        x < -100 ||
        x > widget.menuWidth + 100;

    if (_hasStretched != outsideBounds) {
      setState(() => _hasStretched = outsideBounds);
    }
    final y =
        dy + (_scrollController.hasClients ? _scrollController.offset : 0.0);

    double currentOffset = 12.0;
    int? detectedIndex;

    // Only allow selecting items if we are within a small "active" buffer (20px)
    // This prevents triggering items while intentionally stretching the menu.
    final isWithinActiveZone = x > -20 &&
        x < widget.menuWidth + 20 &&
        dy > -20 &&
        dy < visibleHeight + 20;

    if (isWithinActiveZone) {
      // In scrollable menus, we disable pill tracking during significant movement
      // to prevent visual noise and overlapping highlights during scrolling.
      final isScrollable = widget.menuHeight != null;
      final hasMoved =
          _isDragging && (localPosition - _initialLocalPosition).distance > 10;

      if (!isScrollable || !hasMoved) {
        for (int i = 0; i < widget.items.length; i++) {
          final item = widget.items[i];
          final itemHeight = _getItemHeight(item);

          if (y >= currentOffset && y <= currentOffset + itemHeight) {
            // Only select interactive items
            if (item is GlassMenuItem && item.enabled) {
              detectedIndex = i;
            }
            break;
          }
          currentOffset += itemHeight + 2.0; // height + 2px gap
        }
      }
    }

    _hoveredIndex = detectedIndex;
    _hoveredIndexNotifier.value = detectedIndex;
  }
}

/// Internal helper to update selection state for cached items.
class _SelectionItemWrapper extends StatelessWidget {
  final int index;
  final ValueNotifier<int?> hoverNotifier;
  final ValueNotifier<bool> dragNotifier;
  final Widget Function(BuildContext context, bool isSelected, bool isPressed)
      builder;

  const _SelectionItemWrapper({
    required this.index,
    required this.hoverNotifier,
    required this.dragNotifier,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: hoverNotifier,
      builder: (context, hoveredIndex, _) {
        final isSelected = hoveredIndex == index;
        return ValueListenableBuilder<bool>(
          valueListenable: dragNotifier,
          builder: (context, isDragging, _) {
            return builder(context, isSelected, isDragging && isSelected);
          },
        );
      },
    );
  }
}
