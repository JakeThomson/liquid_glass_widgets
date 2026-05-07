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
  // Two separate springs for open vs close, matching native UIKit spring behaviour:
  //
  // OPEN — "bouncy" underdamped spring (damping ratio ≈ 0.71)
  //   stiffness: 320, damping: 18  →  ~10% overshoot on settle
  //   This gives the characteristic iOS 26 "squishy" feel where the menu
  //   slightly overshoots its final size before settling. The overshoot is
  //   subtle (not cartoonish) — similar to UISpringTimingParameters on iOS.
  //
  // CLOSE — faster overdamped spring (damping ratio ≈ 1.01)
  //   stiffness: 380, damping: 39  →  no bounce, fast clean dismiss
  //   Native iOS context menus close quickly without bouncing back; the fast
  //   settle reinforces the "tap resolves instantly" feel.
  static const _openSpring = SpringDescription(
    mass: 1.0,
    stiffness: 320.0, // Slightly stiffer for quick response
    damping: 18.0, // Underdamped → ~10% overshoot for squishy feel
  );

  static const _closeSpring = SpringDescription(
    mass: 1.0,
    stiffness: 380.0, // Faster close
    damping: 39.0, // Critically-damped → clean dismiss, no bounce
  );

  Alignment _morphAlignment = Alignment.topLeft;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController.unbounded(vsync: this);
    _animationController.addListener(() {
      // Rebuild on each spring physics tick
      if (mounted) setState(() {});

      // Auto-hide when spring settles back to closed state
      if (_overlayController.isShowing &&
          _animationController.value <= 0.001 &&
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
    // iOS 26: Button hides early (0.05) to avoid z-fighting with the morphing glass.
    final isButtonVisible =
        !(_overlayController.isShowing && _animationController.value > 0.05);

    // Interaction lock: Only block taps when the menu is significantly open (>80%).
    // This eliminates the "dead zone" where the menu is closing but the button is still ignoring taps.
    final isMenuBlocking =
        _overlayController.isShowing && _animationController.value > 0.8;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Stack(
        children: [
          // Original trigger button
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
    // Open with a slight upward velocity hint (positive = toward open) so the
    // spring feels like it launches from the button rather than starting from rest.
    _runSpring(1.0, velocityHint: 2.5);
  }

  void _closeMenu() {
    setState(() {
      _hoveredIndex = null;
      _isDragging = false;
    });
    // Close with a downward velocity hint so the dismiss feels immediate and
    // snappy — matching native UIKit context menu dismissal behaviour.
    _runSpring(0.0, velocityHint: -3.0);
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

  /// Calculates the vertical "swoop" offset for iOS 26 liquid glass morphing.
  ///
  /// Uses an asymmetric parabola with the peak shifted to t=0.4 (front-loaded)
  /// so the liquid "droop" is more pronounced at the start of the open animation
  /// and resolves before the content fades in.  The 8px amplitude gives a more
  /// convincing liquid-drop feel without looking like a bounce.
  ///
  /// Opening:  t goes 0 → 1  (peak at t≈0.4, then swoops back to 0)
  /// Closing:  t goes 1 → 0  (same curve, naturally front-loaded on dismiss)
  double _calculateSwoopOffset(double t) {
    // Asymmetric parabola: peak shifted to t=0.4
    // Formula: -A*(t - peak)^2 + peak^2*A, normalised so f(0)=0, f(1)=0
    // Simplified: use (t)(1-t) scaled so the peak is near 0.4
    // We achieve front-loading by weighting t less on the back half:
    //   curve(t) = 4 * t * (1 - t) * (1 + 0.4 * (0.5 - t))
    // This gives peak ≈ 0.40, value ≈ 1.02 at that point, zero at 0 and 1.
    final base = 4.0 * t * (1.0 - t);
    final skew = 1.0 + 0.4 * (0.5 - t); // Push peak toward t=0.4
    return base * skew * 8.0; // 8px amplitude — more liquid, still tasteful
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

    // Calculate menu height by measuring its natural size
    // This is necessary for proper height interpolation during morph
    final menuHeight = _calculateMenuHeight();

    // iOS 26: Width always interpolates smoothly throughout animation
    // Height goes natural at 85% to prevent any overflow from content
    final currentWidth =
        lerpDouble(_triggerSize!.width, widget.menuWidth, value)!;

    final targetHeight = widget.menuHeight ?? menuHeight;
    final currentHeight = value < 0.85
        ? lerpDouble(_triggerSize!.height, targetHeight, value)!
        : widget.menuHeight; // Natural height (null) or fixed height

    // Interpolate border radius: circular button -> rounded menu
    final currentBorderRadius = lerpDouble(
      _triggerBorderRadius ?? 16.0,
      widget.menuBorderRadius,
      value,
    )!;

    // ─── iOS 26 Crossfade Timing ─────────────────────────────────────────────
    // Glass container opacity: fades in during 0→0.3 so there is never an
    // "empty glowing blob" visible as the menu collapses to the button.
    final containerOpacity = (value / 0.3).clamp(0.0, 1.0);

    // ─── iOS 26 Morph-Container Scale Pulse ──────────────────────────────────
    // Native UIKit context menus do a subtle scale overshoot on the container
    // itself as the spring settles: 1.0 → ~1.018 → 1.0.
    // We derive this from the raw (unclamped) animation value so that the
    // spring overshoot (which can briefly exceed 1.0) directly drives the
    // scale, giving it a perfectly physics-synchronised feel.
    final rawValue = _animationController.value;
    // Scale pulse: grows slightly beyond 1.0 when rawValue > 1.0 (overshoot),
    // then settles back.  Clamped below 1 so it never shrinks during open.
    final containerScale = rawValue > 1.0
        ? 1.0 + (rawValue - 1.0) * 0.18 // Amplify overshoot by 18% → ~1.018 max
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
        width: currentWidth,
        height: currentHeight, // Constrained during morph, natural when open
        shape: LiquidRoundedSuperellipse(borderRadius: currentBorderRadius),
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
            shape: LiquidRoundedSuperellipse(borderRadius: currentBorderRadius),
          ),
          child: Transform.scale(
            scale: containerScale,
            alignment: Alignment.center,
            child: Stack(
              alignment: _morphAlignment, // Align internal stack content
              clipBehavior:
                  Clip.none, // Prevent double-clip artifacts during stretch
              children: [
                // Menu content - waits for container to be nearly full width
                if (value > 0.85)
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
                                    final staggerStart = 0.70 + entry.key * 0.04;
                                    final staggerEnd = (staggerStart + 0.20)
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

    return containerOpacity >= 1.0
        ? glassContent
        : Opacity(opacity: containerOpacity, child: glassContent);
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
