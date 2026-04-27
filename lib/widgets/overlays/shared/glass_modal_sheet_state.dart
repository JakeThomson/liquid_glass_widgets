part of '../glass_modal_sheet.dart';

class _GlassModalSheetState extends State<GlassModalSheet>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Animation Controllers ─────────────────────────────────────────────────
  late AnimationController _animationController;
  late AnimationController _saturationController;
  late Animation<double> _saturationAnimation;

  // ── State ─────────────────────────────────────────────────────────────────
  late final ValueNotifier<SheetState> _currentStateNotifier;
  SheetState get _currentState => _currentStateNotifier.value;
  set _currentState(SheetState v) => _currentStateNotifier.value = v;

  double _currentPosition = 0.0;
  double _currentEffectiveHeight = 0.0;

  FrozenState? _frozenState;
  Size _lastPhysicalSize = Size.zero;

  bool _isInteractingWithChild = false;

  // ── Unified Gesture & Scroll ──────────────────────────────────────────────
  final GestureArena _gestureArena = GestureArena();
  final ScrollController _scrollController = ScrollController();

  // ── Geometry & Metrics ────────────────────────────────────────────────────
  late SheetGeometry _geometry;
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _currentStateNotifier = ValueNotifier(widget.initialState);
    _geometry = _buildGeometry();

    _animationController = AnimationController.unbounded(vsync: this);
    _saturationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _saturationAnimation =
        CurvedAnimation(parent: _saturationController, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateScreenSize();
        _lastPhysicalSize = View.of(context).physicalSize;
        _snapToState(_currentState, animate: false);
      }
    });

    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(GlassModalSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }

    final oldGeometry = _geometry;
    _geometry = _buildGeometry();

    // Hot Reload reaction: if dimensions changed, force position recalculation
    if (oldGeometry.halfSize != _geometry.halfSize ||
        oldGeometry.fullSize != _geometry.fullSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _gestureArena.phase == GesturePhase.idle) {
          _snapToState(_currentState, animate: true);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?._detach();
    _animationController.dispose();
    _saturationController.dispose();
    _scrollController.dispose();
    _currentStateNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;

    final view = View.of(context);
    // Filter system call spam: the spring only jitters if the window size actually changes
    if (_lastPhysicalSize != view.physicalSize) {
      if (_lastPhysicalSize != Size.zero) {
        _updateScreenSize();
        _snapToState(_currentState, animate: true);
      }
      _lastPhysicalSize = view.physicalSize;
    }
  }

  SheetGeometry _buildGeometry() => SheetGeometry(
        mode: widget.mode,
        halfSize: widget.halfSize,
        fullSize: widget.fullSize,
        peekSize: widget.peekSize,
      );

  void _updateScreenSize() {
    final view = View.of(context);
    _screenSize = view.physicalSize / view.devicePixelRatio;
  }

  // ════════════════════════════════════════════════════════════════════════
  // Snap & State Management
  // ════════════════════════════════════════════════════════════════════════

  void _snapToState(SheetState state,
      {bool animate = true, double velocity = 0}) {
    if (!mounted) return;

    if (widget.mode == SheetMode.persistent && state == SheetState.hidden) {
      state = SheetState.peek;
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    final targetPosition =
        _geometry.positionForState(state, screenHeight);

    if (animate) {
      final simulation = SpringSimulation(
        const SpringDescription(mass: 1.0, stiffness: 220.0, damping: 30.0),
        _currentPosition,
        targetPosition,
        velocity / screenHeight,
      );
      _animationController.animateWith(simulation);
    } else {
      _animationController.value = targetPosition;
    }

    if (state != _currentState) {
      if (state == SheetState.peek || state == SheetState.hidden) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }

      _currentState = state;
      widget.onStateChanged?.call(state);

      if (state != SheetState.full && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // Gesture Handlers — Handle Drag & Scroll Notification
  // ════════════════════════════════════════════════════════════════════════

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is OverscrollNotification && notification.overscroll < 0) {
      if (_gestureArena.phase == GesturePhase.scrolling || _gestureArena.phase == GesturePhase.idle) {
        _gestureArena.phase = GesturePhase.contentDrag;
        if (notification.dragDetails != null) {
          _gestureArena.dragStartY = notification.dragDetails!.globalPosition.dy;
        }
        _gestureArena.dragStartSheetPosition = _currentPosition;
        
        if (_animationController.isAnimating) {
          _animationController.stop();
        }
      }
    }
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════
  // Gesture Handlers — Pointer Events (Content Zone)
  // ════════════════════════════════════════════════════════════════════════

  void _onPointerDown(PointerDownEvent event) {
    if (_isInteractingWithChild) {
      _isInteractingWithChild = false;
      return;
    }

    _gestureArena.beginPointer(
        event.position.dy, event.position.dx, _currentPosition, event.kind);

    // If the touch is in the top 44 pixels (handle zone), bypass evaluateMove
    // and immediately set phase to handleDrag.
    if (event.localPosition.dy <= 44.0) {
      _gestureArena.phase = GesturePhase.handleDrag;
    }

    if (widget.enableInteractionGlow) {
      HapticFeedback.selectionClick();
    }

    if (widget.enableSaturationGlow) {
      _saturationController.forward();
    }

    _frozenState = null;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isInteractingWithChild) {
      return;
    }

    _gestureArena.velocityTracker.addPosition(event.timeStamp, event.position);

    // If we're already dragging the handle, just apply the drag
    if (_gestureArena.phase == GesturePhase.handleDrag) {
      _applyDrag(event.position.dy);
      return;
    }

    final shouldClaim = _gestureArena.evaluateMove(
      event.position.dy,
      event.position.dx,
      _currentState,
      10.0,
      hasScrollClients: _scrollController.hasClients,
      canScrollListUp: _scrollController.hasClients && _scrollController.offset > 0,
    );

    if (shouldClaim) {
      if (_animationController.isAnimating) {
        _animationController.stop();
        _gestureArena.dragStartY = event.position.dy;
        _gestureArena.dragStartSheetPosition = _currentPosition;
      }

      final dy = event.position.dy - _gestureArena.dragStartY;
      if ((_currentState == SheetState.half ||
              _currentState == SheetState.peek) &&
          dy < 0) {
        _frozenState = FrozenState(
          bottomScale: widget.interactionScale,
          heightAtFreeze: _currentEffectiveHeight,
        );
      }

      _applyDrag(event.position.dy);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _saturationController.reverse();
    _isInteractingWithChild = false;

    final wasDragging = _gestureArena.phase == GesturePhase.contentDrag ||
        _gestureArena.phase == GesturePhase.handleDrag;
    _gestureArena.reset();
    _frozenState = null;

    if (!wasDragging) return;

    final estimate = _gestureArena.velocityTracker.getVelocityEstimate();
    final velocity = -(estimate?.pixelsPerSecond.dy ?? 0.0);

    final snapshot = SheetSnapshot(
      state: _currentState,
      position: _currentPosition,
      velocity: velocity,
      screenSize: _screenSize,
    );
    final target = _geometry.resolveTarget(
      snapshot,
      snapThreshold: widget.snapThreshold,
      velocityThreshold: widget.velocityThreshold,
    );

    _snapToState(target, velocity: velocity);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _saturationController.reverse();
    _isInteractingWithChild = false;
    _gestureArena.reset();
    _frozenState = null;
  }

  // ════════════════════════════════════════════════════════════════════════
  // Drag Application
  // ════════════════════════════════════════════════════════════════════════

  void _applyDrag(double currentY) {
    final delta = currentY - _gestureArena.dragStartY;
    double newPosition =
        _gestureArena.dragStartSheetPosition - delta / _screenSize.height;

    newPosition = _geometry.applyResistance(newPosition, _screenSize.height,
        resistance: widget.resistance);
    _animationController.value = newPosition;

    final snapshot = SheetSnapshot(
      state: _currentState,
      position: newPosition,
      velocity: 0,
      screenSize: _screenSize,
    );
    final target = _geometry.resolveTarget(
      snapshot,
      snapThreshold: widget.snapThreshold,
      velocityThreshold: widget.velocityThreshold,
    );

    if (target != _currentState &&
        (widget.mode != SheetMode.dismissible || target != SheetState.hidden)) {
      _currentState = target;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // Metrics Calculation Helpers
  // ════════════════════════════════════════════════════════════════════════

  double get _expandProgress {
    final halfPos =
        _geometry.positionForState(SheetState.half, _screenSize.height);
    final fullPos =
        _geometry.positionForState(SheetState.full, _screenSize.height);
    if (fullPos <= halfPos) return 0.0;
    return ((_currentPosition - halfPos) / (fullPos - halfPos)).clamp(0.0, 1.0);
  }

  _RenderMetrics _calculateMetrics({
    required double pos,
    required double t,
    required double halfPos,
    required double minPos,
    required double extraHeight,
    required double mqHeight,
    required LiquidGlassSettings baseSettings,
  }) {
    double stretchT = 1.0;
    // Protection against division by zero if halfPos == minPos
    final range = halfPos - minPos;
    if (pos < halfPos && range > 0.0001) {
      stretchT = ((pos - minPos) / range).clamp(0.0, 1.0);
    }

    late double effectiveHeight;
    late double effectiveBottom;
    late double topRadius;
    late double bottomRadius;
    late double hPad;
    late double colorOpacity;
    late double glassOpacity;

    // Ideal target visual height of the window
    final targetVisualHeight = pos * mqHeight;

    // baseSettings is now passed from outside to avoid theme lookups every frame.

    // Calculate state-specific settings interpolation
    late LiquidGlassSettings effectiveSettings;
    final peekPos =
        _geometry.positionForState(SheetState.peek, _screenSize.height);
    final rangePeekHalf = halfPos - peekPos;
    final tPeek = rangePeekHalf > 0.0001
        ? ((pos - peekPos) / rangePeekHalf).clamp(0.0, 1.0)
        : 1.0;

    if (pos < halfPos) {
      final startSettings = widget.peekSettings ?? baseSettings;
      final endSettings = widget.halfSettings ?? baseSettings;
      effectiveSettings =
          LiquidGlassSettings.lerp(startSettings, endSettings, tPeek);

      if (startSettings.blur > 0 && endSettings.blur == 0) {
        colorOpacity = tPeek;
      } else if (startSettings.blur == 0 && endSettings.blur > 0) {
        colorOpacity = 1.0 - tPeek;
      } else if (startSettings.blur == 0 && endSettings.blur == 0) {
        colorOpacity = 1.0;
      } else {
        colorOpacity = 0.0;
      }
      glassOpacity = 1.0 - colorOpacity;
    } else {
      final startSettings = widget.halfSettings ?? baseSettings;
      final endSettings = widget.fullSettings ?? baseSettings;
      effectiveSettings =
          LiquidGlassSettings.lerp(startSettings, endSettings, t);

      if (widget.fullSettings != null) {
        // Use explicit state settings for opacity transition
        if (startSettings.blur > 0 && endSettings.blur == 0) {
          colorOpacity = t;
        } else if (startSettings.blur == 0 && endSettings.blur > 0) {
          colorOpacity = 1.0 - t;
        } else if (startSettings.blur == 0 && endSettings.blur == 0) {
          colorOpacity = 1.0;
        } else {
          colorOpacity = 0.0;
        }
        glassOpacity = 1.0 - colorOpacity;
      } else {
        // Fallback to classic threshold logic
        if (baseSettings.blur == 0) {
          colorOpacity = 1.0;
          glassOpacity = 0.0;
        } else {
          final fadeRange = (1.0 - widget.fillThreshold).clamp(0.01, 1.0);
          switch (widget.fillTransition) {
            case FillTransition.gradual:
              // Add a small plateau at the top (0.96-1.0) where it stays 100% solid.
              // This provides "reverse logic" feel where it doesn't immediately 
              // turn glassy when pulled.
              const plateau = 0.04;
              final rawT = ((t - widget.fillThreshold) / (fadeRange - plateau)).clamp(0.0, 1.0);
              colorOpacity = Curves.easeInOutCubic.transform(rawT);
              break;
            case FillTransition.instant:
              colorOpacity = t >= widget.fillThreshold ? 1.0 : 0.0;
              break;
          }
          glassOpacity = 1.0 - colorOpacity;
        }
      }
    }

    if (pos < halfPos) {
      if (widget.mode == SheetMode.persistent) {
        if (_frozenState != null) {
          final peekPos =
              _geometry.positionForState(SheetState.peek, _screenSize.height);
          final peekHeight = peekPos * mqHeight;
          final frozenBottomOffset =
              peekHeight * (_frozenState!.bottomScale - 1.0) / 2.0;
          effectiveBottom = widget.bottomMargin - frozenBottomOffset;

          final scaledRadius =
              widget.borderRadius * _frozenState!.bottomScale;
          topRadius = lerpDouble(widget.borderRadius, scaledRadius,
              _saturationAnimation.value)!;
          bottomRadius = lerpDouble(widget.borderRadius, scaledRadius,
              _saturationAnimation.value)!;
        } else {
          effectiveBottom = widget.bottomMargin;
          final scaledRadius =
              widget.borderRadius * widget.interactionScale;
          topRadius = lerpDouble(widget.borderRadius, scaledRadius,
              _saturationAnimation.value)!;
          bottomRadius = lerpDouble(widget.borderRadius, scaledRadius,
              _saturationAnimation.value)!;
        }
        hPad = widget.horizontalMargin;

        // Window changes height visually
        effectiveHeight = targetVisualHeight - effectiveBottom;
      } else {
        // Dismissible mode: hiding downwards (hidden -> half)
        final peekPos = _geometry.positionForState(SheetState.peek, mqHeight);
        final peekVisualHeight = peekPos * mqHeight;

        if (pos < peekPos && peekPos > 0.001) {
          // Sliding from hidden up to peek
          final slideProgress = (pos / peekPos).clamp(0.0, 1.0);
          final offscreenBottom = -(peekVisualHeight + 100.0);
          effectiveBottom = lerpDouble(offscreenBottom, widget.bottomMargin, slideProgress)!;
          effectiveHeight = peekVisualHeight - widget.bottomMargin;
        } else {
          // Between peek and half: fixed bottom, growing height
          effectiveBottom = widget.bottomMargin;
          effectiveHeight = targetVisualHeight - effectiveBottom;
        }

        topRadius = widget.borderRadius;
        bottomRadius = widget.borderRadius;
        hPad = widget.horizontalMargin;
      }
    } else {
      // From half to full
      final halfVisualHeight = halfPos * mqHeight;
      final frozenScale = _frozenState?.bottomScale ?? 1.0;

      final halfPhysicalHeight = halfVisualHeight - widget.bottomMargin;
      final frozenBottomOffset =
          (_frozenState?.heightAtFreeze ?? halfPhysicalHeight) *
              (frozenScale - 1.0) /
              2.0;
      final frozenBottom = widget.bottomMargin - frozenBottomOffset;

      const syncThreshold = 0.90;
      final syncProgress =
          ((t - syncThreshold) / (1.0 - syncThreshold)).clamp(0.0, 1.0);

      // Hide bottom rounding beyond the screen bottom when expanding to full
      if (_frozenState != null) {
        effectiveBottom = syncProgress > 0
            ? lerpDouble(frozenBottom, -extraHeight, syncProgress)!
            : frozenBottom;
      } else {
        effectiveBottom = syncProgress > 0
            ? lerpDouble(widget.bottomMargin, -extraHeight, syncProgress)!
            : widget.bottomMargin;
      }

      // Physical height adjusts so the top edge always stays at targetVisualHeight
      effectiveHeight = targetVisualHeight - effectiveBottom;

      hPad = lerpDouble(widget.horizontalMargin, 0.0, (t / 0.8).clamp(0.0, 1.0))!;
      final baseRadius = lerpDouble(widget.borderRadius,
          widget.borderRadius * widget.interactionScale, _saturationAnimation.value)!;
      topRadius = lerpDouble(baseRadius, widget.fullBorderRadius, t)!;
      bottomRadius = syncProgress > 0
          ? lerpDouble(baseRadius, 0.0, syncProgress)!
          : baseRadius;
    }

    return _RenderMetrics(
      stretchT: stretchT,
      effectiveHeight: effectiveHeight,
      effectiveBottom: effectiveBottom,
      topRadius: topRadius,
      bottomRadius: bottomRadius,
      hPad: hPad,
      colorOpacity: colorOpacity,
      glassOpacity: glassOpacity,
      effectiveSettings: effectiveSettings,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Build
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveExpandedColor = widget.expandedColor ??
        (isDark ? const Color(0xFF1C1C1E) : Colors.white);
    final effectiveQuality = GlassThemeHelpers.resolveQuality(
      context,
      widgetQuality: widget.quality,
      fallback: GlassQuality.premium,
    );
    final mqSize = MediaQuery.sizeOf(context);
    final mqHeight = mqSize.height;
    final mqPadding = MediaQuery.paddingOf(context);
    final extraHeight = mqPadding.bottom + widget.borderRadius;

    final baseSettings = GlassThemeHelpers.resolveSettings(
      context,
      explicit: widget.settings ?? _kDefaultSheetSettings,
    );

    final focusBridge = Focus(
      key: GlobalObjectKey(widget.child),
      onFocusChange: (hasFocus) {
        if (hasFocus && _currentState != SheetState.full) {
          _snapToState(SheetState.full);
        }
      },
      child: widget.child,
    );

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final fullPos =
            _geometry.positionForState(SheetState.full, mqHeight);
        final halfPos =
            _geometry.positionForState(SheetState.half, mqHeight);
        final minPos =
            _geometry.positionForState(_geometry.minState, mqHeight);

        double pos = _animationController.value.clamp(0.0, fullPos);

        // Snap to exact positions when not dragging
        if (_gestureArena.phase == GesturePhase.idle) {
          if ((pos - halfPos).abs() < 0.002) pos = halfPos;
          if ((pos - fullPos).abs() < 0.002) pos = fullPos;
          if ((pos - minPos).abs() < 0.002) pos = minPos;
        }

        _currentPosition = pos;
        final t = _expandProgress;

        final metrics = _calculateMetrics(
          pos: pos,
          t: t,
          halfPos: halfPos,
          minPos: minPos,
          extraHeight: extraHeight,
          mqHeight: mqHeight,
          baseSettings: baseSettings,
        );

        _currentEffectiveHeight = metrics.effectiveHeight;

        final fadedSettings = metrics.effectiveSettings.copyWith(
          glassColor: metrics.effectiveSettings.glassColor.withValues(
              alpha: metrics.effectiveSettings.glassColor.a *
                  metrics.glassOpacity),
          blur: metrics.effectiveSettings.blur * metrics.glassOpacity,
          lightIntensity:
              metrics.effectiveSettings.lightIntensity * metrics.glassOpacity,
          ambientStrength:
              metrics.effectiveSettings.ambientStrength * metrics.glassOpacity,
        );

        Widget result = _SheetLayout(
          interactionScale: widget.interactionScale,
          enableInteractionGlow: widget.enableInteractionGlow,
          glowColor: widget.glowColor,
          glowRadius: widget.glowRadius,
          stretch: widget.stretch,
          resistance: widget.resistance,
          hPad: metrics.hPad,
          effectiveBottom: metrics.effectiveBottom,
          effectiveHeight: metrics.effectiveHeight,
          topRadius: metrics.topRadius,
          bottomRadius: metrics.bottomRadius,
          showDragIndicator: widget.showDragIndicator,
          dragIndicatorColor: widget.dragIndicatorColor,
          colorOpacity: metrics.colorOpacity,
          glassOpacity: metrics.glassOpacity,
          effectiveExpandedColor: effectiveExpandedColor,
          fadedSettings: fadedSettings,
          effectiveQuality: effectiveQuality,
          saturationAnimation: _saturationAnimation,
          expandProgress: t,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          padding: widget.padding,
          scrollController: _scrollController,
          currentStateNotifier: _currentStateNotifier,
          expandProgressValue: t,
          maintainContentGlass: widget.maintainContentGlass,
          fullStateContentSettings: widget.fullStateContentSettings,
          forceSpecularRim: widget.forceSpecularRim,
          enableTopFade: widget.enableTopFade,
          topFadeHeight: widget.topFadeHeight,
          onFocusGained: () {
            if (_currentState != SheetState.full) {
              _snapToState(SheetState.full);
            }
          },
          child: focusBridge,
        );

        if (widget.suppressInteractionOnChildren) {
          result = NotificationListener<InteractionNotification>(
            onNotification: (notification) {
              _isInteractingWithChild = true;
              return false;
            },
            child: result,
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: result,
        );
      },
    );
  }
}

