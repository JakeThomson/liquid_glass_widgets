// Internal sub-widgets for GlassSearchableBottomBar.
//
// Extracted from glass_searchable_bottom_bar.dart to keep that file focused on
// the public API and layout orchestration. Mirrors the pattern established by
// bottom_bar_internal.dart for GlassBottomBar.
//
// None of these widgets are part of the public API.
// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../src/renderer/liquid_glass_renderer.dart';
import '../../../types/glass_quality.dart';
import '../../../utils/draggable_indicator_physics.dart';
import '../../../utils/glass_spring.dart';
import '../../interactive/glass_button.dart';
import '../../shared/adaptive_glass.dart';
import '../../shared/animated_glass_indicator.dart';
import '../glass_bottom_bar.dart' show MaskingQuality, JellyClipper;
import 'glass_search_bar_config.dart';

// =============================================================================
// _DismissPill
// =============================================================================
// Rendered inside the parent [AdaptiveLiquidGlassLayer] (same layer as the
// search pill and tab pill) so that all three glass surfaces share the identical
// shader context. This gives perfect colour, blur, and lighting parity with no
// additional configuration required.
//
// Hit-testing works because the parent [SizedBox] expands its height by
// [keyboardH] while the pill is visible, keeping the pill inside the widget's
// layout bounds even when it floats above the keyboard.

class DismissPill extends StatelessWidget {
  const DismissPill({
    required this.onTap,
    required this.pillSize,
    required this.barBorderRadius,
    required this.quality,
    this.cancelButtonColor,
    this.indicatorColor,
    this.glassSettings,
    super.key,
  });

  final VoidCallback onTap;
  final double pillSize;
  final double barBorderRadius;
  final GlassQuality quality;
  final Color? cancelButtonColor;
  final Color? indicatorColor;
  final LiquidGlassSettings? glassSettings;

  @override
  Widget build(BuildContext context) {
    final safeColor = indicatorColor;
    return GlassButton(
      onTap: onTap,
      width: pillSize,
      height: pillSize,
      quality: quality,
      // useOwnLayer defaults to false — the pill participates in the parent
      // AdaptiveLiquidGlassLayer so glass colour, blur and lighting are
      // identical to the adjacent search pill.
      settings: glassSettings?.copyWith(
              glassColor: safeColor ?? glassSettings?.glassColor) ??
          (safeColor != null
              ? LiquidGlassSettings(glassColor: safeColor)
              : null),
      shape: LiquidRoundedSuperellipse(borderRadius: barBorderRadius),
      icon: Icon(
        CupertinoIcons.xmark,
        color: cancelButtonColor ?? const Color(0xE6FFFFFF),
        size: 16,
      ),
      iconColor: cancelButtonColor ?? const Color(0xE6FFFFFF),
    );
  }
}

// =============================================================================
// SearchableTabIndicator
// =============================================================================

/// Draggable glass indicator for [GlassSearchableBottomBar].
///
/// Uses identical spring physics and masking to [GlassBottomBar]'s internal
/// `_TabIndicator`. When [isSearchActive] is `true`, it collapses to show only
/// the [collapsedLogoBuilder] and a tap dismisses search.
class SearchableTabIndicator extends StatefulWidget {
  const SearchableTabIndicator({
    required this.childUnselected,
    required this.selectedTabBuilder,
    required this.tabIndex,
    required this.tabCount,
    required this.onTabChanged,
    required this.visible,
    required this.quality,
    required this.barHeight,
    required this.barBorderRadius,
    required this.tabPadding,
    required this.magnification,
    required this.innerBlur,
    required this.maskingQuality,
    required this.isSearchActive,
    required this.onDismissSearch,
    this.indicatorColor,
    this.indicatorSettings,
    this.backgroundKey,
    this.collapsedLogoBuilder,
    super.key,
  });

  final int tabIndex;
  final int tabCount;
  final bool visible;
  final Widget childUnselected;
  final Widget Function(BuildContext, double, Alignment) selectedTabBuilder;
  final Color? indicatorColor;
  final LiquidGlassSettings? indicatorSettings;
  final ValueChanged<int> onTabChanged;
  final GlassQuality quality;
  final double barHeight;
  final double barBorderRadius;
  final EdgeInsetsGeometry tabPadding;
  final double magnification;
  final double innerBlur;
  final MaskingQuality maskingQuality;
  final GlobalKey? backgroundKey;
  final bool isSearchActive;
  final VoidCallback onDismissSearch;
  final WidgetBuilder? collapsedLogoBuilder;

  @override
  State<SearchableTabIndicator> createState() => SearchableTabIndicatorState();
}

class SearchableTabIndicatorState extends State<SearchableTabIndicator> {
  static const _fallbackIndicatorColor = Color(0x1AFFFFFF);

  bool _isDown = false;
  bool _isDragging = false;
  late double _xAlign = _alignFor(widget.tabIndex);
  late LiquidRoundedSuperellipse _barShape =
      LiquidRoundedSuperellipse(borderRadius: widget.barBorderRadius);

  @override
  void didUpdateWidget(covariant SearchableTabIndicator old) {
    super.didUpdateWidget(old);
    if (old.tabIndex != widget.tabIndex || old.tabCount != widget.tabCount) {
      setState(() => _xAlign = _alignFor(widget.tabIndex));
    }
    if (old.barBorderRadius != widget.barBorderRadius) {
      _barShape =
          LiquidRoundedSuperellipse(borderRadius: widget.barBorderRadius);
    }
  }

  double _alignFor(int i) =>
      DraggableIndicatorPhysics.computeAlignment(i, widget.tabCount);

  double _alignFromGlobal(Offset g) =>
      DraggableIndicatorPhysics.getAlignmentFromGlobalPosition(
          g, context, widget.tabCount);

  void _onDragDown(DragDownDetails d) {
    setState(() => _isDown = true);
  }

  void _onBarTapDown(TapDownDetails d) {
    final relX = (_alignFromGlobal(d.globalPosition) + 1) / 2;
    final idx = (relX * widget.tabCount).floor().clamp(0, widget.tabCount - 1);
    if (idx != widget.tabIndex) widget.onTabChanged(idx);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _isDragging = true;
      _xAlign = _alignFromGlobal(d.globalPosition);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    setState(() {
      _isDragging = false;
      _isDown = false;
    });
    final box = context.findRenderObject()! as RenderBox;
    final relX = (_xAlign + 1) / 2;
    final tabW = 1.0 / widget.tabCount;
    final draggableRange = 1.0 - tabW;
    final velX =
        (d.velocity.pixelsPerSecond.dx / box.size.width) / draggableRange;
    final target = DraggableIndicatorPhysics.computeTargetIndex(
      currentRelativeX: relX,
      velocityX: velX,
      itemWidth: tabW,
      itemCount: widget.tabCount,
    );
    setState(() => _xAlign = _alignFor(target));
    if (target != widget.tabIndex) widget.onTabChanged(target);
  }

  void _onDragCancel() {
    if (_isDragging) {
      final relX = (_xAlign + 1) / 2;
      final tabW = 1.0 / widget.tabCount;
      final target = DraggableIndicatorPhysics.computeTargetIndex(
        currentRelativeX: relX,
        velocityX: 0,
        itemWidth: tabW,
        itemCount: widget.tabCount,
      );
      setState(() {
        _isDragging = false;
        _isDown = false;
        _xAlign = _alignFor(target);
      });
      if (target != widget.tabIndex) widget.onTabChanged(target);
    } else {
      setState(() => _xAlign = _alignFor(widget.tabIndex));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Collapsed / search-active state ─────────────────────────────────────
    if (widget.isSearchActive) {
      return GlassButton(
        onTap: widget.onDismissSearch,
        width: double.infinity,
        height: widget.barHeight,
        quality: widget.quality,
        shape: _barShape,
        // Logo or empty — shown inside the glass button body.
        icon: widget.collapsedLogoBuilder != null
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) =>
                    FadeTransition(opacity: a, child: c),
                child: SizedBox.expand(
                  key: const ValueKey('logo'),
                  child: widget.collapsedLogoBuilder!(context),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('empty')),
      );
    }

    // ── Normal draggable tab bar — identical logic to GlassBottomBar ─────────
    final theme = CupertinoTheme.of(context);
    final indicatorColor = widget.indicatorColor ??
        theme.textTheme.textStyle.color?.withValues(alpha: .1) ??
        _fallbackIndicatorColor;
    final targetAlignment = _alignFor(widget.tabIndex);
    final backgroundRadius = widget.barBorderRadius * 2;
    final glassRadius = widget.barBorderRadius;

    return Listener(
      onPointerDown: (_) {
        setState(() => _isDown = true);
      },
      onPointerUp: (_) {
        if (!_isDragging) {
          setState(() => _isDown = false);
        }
      },
      onPointerCancel: (_) {
        if (!_isDragging) {
          setState(() => _isDown = false);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragDown: _onDragDown,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: _onDragCancel,
        onTapDown: _onBarTapDown,
        child: VelocitySpringBuilder(
          value: _xAlign,
          springWhenActive: GlassSpring.interactive(),
          springWhenReleased: GlassSpring.snappy(
            duration: const Duration(milliseconds: 350),
          ),
          active: _isDragging,
          builder: (context, value, velocity, child) {
            final alignment = Alignment(value, 0);
            return SpringBuilder(
              spring: GlassSpring.snappy(
                duration: const Duration(milliseconds: 300),
              ),
              value: widget.visible &&
                      (_isDown || (alignment.x - targetAlignment).abs() > 0.05)
                  ? 1.0
                  : 0.0,
              builder: (context, thickness, _) {
                if (thickness < 0.01 &&
                    !widget.visible &&
                    widget.maskingQuality == MaskingQuality.high) {
                  return Container(
                    height: widget.barHeight,
                    decoration: ShapeDecoration(shape: _barShape),
                    child: AdaptiveGlass.grouped(
                      quality: widget.quality,
                      shape: _barShape,
                      child: Container(
                        padding: widget.tabPadding,
                        child: widget.childUnselected,
                      ),
                    ),
                  );
                }

                final jellyTransform =
                    DraggableIndicatorPhysics.buildJellyTransform(
                  velocity: Offset(velocity, 0),
                  maxDistortion: 0.8,
                  velocityScale: 10,
                );

                switch (widget.maskingQuality) {
                  case MaskingQuality.off:
                    return _buildSimple(
                      alignment: alignment,
                      thickness: thickness,
                      velocity: velocity,
                      backgroundRadius: backgroundRadius,
                      glassRadius: glassRadius,
                      indicatorColor: indicatorColor,
                    );
                  case MaskingQuality.high:
                    return _buildHighQuality(
                      alignment: alignment,
                      thickness: thickness,
                      velocity: velocity,
                      jellyTransform: jellyTransform,
                      backgroundRadius: backgroundRadius,
                      glassRadius: glassRadius,
                      indicatorColor: indicatorColor,
                    );
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSimple({
    required Alignment alignment,
    required double thickness,
    required double velocity,
    required double backgroundRadius,
    required double glassRadius,
    required Color indicatorColor,
  }) {
    return SizedBox(
      height: widget.barHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glass background (Cached to prevent blur re-rasterization on pill drag)
          Positioned.fill(
            child: RepaintBoundary(
              child: AdaptiveGlass.grouped(
                quality: widget.quality,
                shape: _barShape,
                child: const SizedBox.expand(),
              ),
            ),
          ),

          // Unselected icons above background
          Positioned.fill(
            child: Container(
              padding: widget.tabPadding,
              child: widget.childUnselected,
            ),
          ),
          if (widget.visible && thickness > 0.05)
            AnimatedGlassIndicator(
              velocity: velocity,
              itemCount: widget.tabCount,
              alignment: alignment,
              thickness: thickness,
              quality: widget.quality,
              indicatorColor: indicatorColor,
              isBackgroundIndicator: false,
              borderRadius: thickness < 1 ? backgroundRadius : glassRadius,
              padding: const EdgeInsets.all(4),
              expansion: 14,
              glassSettings: widget.indicatorSettings,
              backgroundKey: widget.backgroundKey,
            ),
        ],
      ),
    );
  }

  Widget _buildHighQuality({
    required Alignment alignment,
    required double thickness,
    required double velocity,
    required Matrix4 jellyTransform,
    required double backgroundRadius,
    required double glassRadius,
    required Color indicatorColor,
  }) {
    final effRadius = thickness < 1 ? backgroundRadius : glassRadius;
    return SizedBox(
      height: widget.barHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Static Blur Background (Cached)
          Positioned.fill(
            child: RepaintBoundary(
              child: AdaptiveGlass.grouped(
                quality: widget.quality,
                shape: _barShape,
                child: const SizedBox.expand(),
              ),
            ),
          ),

          // 2. Unselected Content Layer (inverse clipped)
          Positioned.fill(
            child: ClipPath(
              clipper: JellyClipper(
                itemCount: widget.tabCount,
                alignment: alignment,
                thickness: thickness,
                expansion: 14,
                transform: jellyTransform,
                borderRadius: effRadius,
                inverse: true,
              ),
              child: Container(
                padding: widget.tabPadding,
                height: widget.barHeight,
                child: widget.childUnselected,
              ),
            ),
          ),
          AnimatedGlassIndicator(
            velocity: velocity,
            itemCount: widget.tabCount,
            alignment: alignment,
            thickness: thickness,
            quality: widget.quality,
            indicatorColor: indicatorColor,
            isBackgroundIndicator: false,
            borderRadius: effRadius,
            padding: const EdgeInsets.all(4),
            expansion: 14,
            glassSettings: widget.indicatorSettings,
            backgroundKey: widget.backgroundKey,
          ),
          Positioned.fill(
            child: widget.quality == GlassQuality.minimal
                ? IgnorePointer(
                    child: ClipPath(
                      clipper: JellyClipper(
                        itemCount: widget.tabCount,
                        alignment: alignment,
                        thickness: thickness,
                        expansion: 14,
                        transform: jellyTransform,
                        borderRadius: effRadius,
                      ),
                      child: Container(
                        padding: widget.tabPadding,
                        height: widget.barHeight,
                        child: widget.selectedTabBuilder(
                            context, thickness, alignment),
                      ),
                    ),
                  )
                : RepaintBoundary(
                    child: IgnorePointer(
                      child: ClipPath(
                        clipper: JellyClipper(
                          itemCount: widget.tabCount,
                          alignment: alignment,
                          thickness: thickness,
                          expansion: 14,
                          transform: jellyTransform,
                          borderRadius: effRadius,
                        ),
                        child: Container(
                          padding: widget.tabPadding,
                          height: widget.barHeight,
                          child: widget.selectedTabBuilder(
                              context, thickness, alignment),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SearchPill
// =============================================================================

/// The morphing search pill. Collapses to a square icon; expands to a
/// real [TextField] with autofocus. Lives inside the parent
/// [AdaptiveLiquidGlassLayer] so its glass rendering blends with the tab pill.
class SearchPill extends StatefulWidget {
  const SearchPill({
    required this.config,
    required this.isActive,
    required this.barBorderRadius,
    required this.quality,
    this.onFocusChanged,
    super.key,
  });

  final GlassSearchBarConfig config;
  final bool isActive;
  final double barBorderRadius;
  final GlassQuality quality;

  /// Called when the search field gains or loses focus.
  /// Used by the parent bar to drive the dismiss pill visibility.
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<SearchPill> createState() => SearchPillState();
}

class SearchPillState extends State<SearchPill> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;

  // Tracks whether the × clear button should be visible.
  bool _hasText = false;
  // Tracks focus so the outer bar can show/hide the dismiss pill.
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    if (widget.config.controller != null) {
      _controller = widget.config.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    if (widget.config.focusNode != null) {
      _focusNode = widget.config.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }

    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);

    if (widget.isActive && widget.config.autoFocusOnExpand) {
      // Already active on first build — request focus after one frame so the
      // AnimatedContainer has committed its initial expanded layout.
      // 60 ms is enough for a single vsync cycle at 60-120 Hz while still
      // feeling instant to the user (well under the ~100 ms perception threshold).
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted && widget.isActive) _focusNode.requestFocus();
      });
    }
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  void didUpdateWidget(covariant SearchPill old) {
    super.didUpdateWidget(old);
    if (!old.isActive && widget.isActive && widget.config.autoFocusOnExpand) {
      // Became active and auto-focus is enabled — request focus after one
      // render frame so the pill has committed its first expanded layout
      // before the IME is attached.
      //
      // 60 ms sits comfortably above a single 120 Hz vsync (~8 ms) and is
      // well below the ~100 ms human-perception threshold for "immediate".
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted && widget.isActive) _focusNode.requestFocus();
      });
    } else if (old.isActive && !widget.isActive) {
      // Dismissed — unfocus and clear.
      _focusNode.unfocus();
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final hasFocus = _focusNode.hasFocus;
    if (hasFocus != _hasFocus) {
      setState(() => _hasFocus = hasFocus);
      widget.onFocusChanged?.call(hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.config.searchIconColor ?? Colors.white60;
    final micColor = widget.config.micIconColor ?? iconColor;
    final shape =
        LiquidRoundedSuperellipse(borderRadius: widget.barBorderRadius);

    // LayoutBuilder reads the ACTUAL rendered width on every frame.
    // When isActive flips true, AnimatedContainer starts at compact width
    // (barHeight ≈ 64 px) and animates outward. The expanded Row needs at
    // least 84 px (padding 32 + icons 52). We gate on 90 px so the Row is
    // never built at compact width → no layout overflow, no content bleed.
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const kExpandThreshold = 90.0;

        if (!widget.isActive || w < kExpandThreshold) {
          return Stack(
            fit: StackFit.expand,
            children: [
              GlassButton(
                key: const ValueKey('pill-collapsed'),
                icon: Icon(CupertinoIcons.search, color: iconColor),
                // No-op while mid-animation to avoid double-toggling.
                onTap: widget.isActive
                    ? () {}
                    : () => widget.config.onSearchToggle(true),
                width: double.infinity,
                height: double.infinity,
                quality: widget.quality,
                iconColor: iconColor,
                shape: shape,
              ),
              // IgnorePointer+Opacity(0): forces Dart to JIT-compile the
              // expanded widget tree on first frame. Unlike Offstage, this
              // does NOT interact with the focus/IME system so there is no
              // risk of hidden TextFields stealing keyboard input.
              IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: _buildExpanded(iconColor, micColor),
                ),
              ),
            ],
          );
        }

        // Wrap with an opaque GestureDetector so taps anywhere inside the
        // glass pill — including the 16 px horizontal padding zones — focus
        // the search field instead of passing through to background content.
        // Without this, AdaptiveGlass.grouped defers hit-testing to its
        // children, leaving the padding area as a transparent pass-through.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusNode.requestFocus,
          child: AdaptiveGlass.grouped(
            shape: shape,
            quality: widget.quality,
            child: _buildExpanded(iconColor, micColor),
          ),
        );
      },
    );
  }

  void _handleClear() {
    _controller.clear();
    widget.config.onChanged?.call('');
  }

  Widget _buildExpanded(Color iconColor, Color micColor) {
    final config = widget.config;
    final textColor = config.textColor ?? Colors.white;

    // Trailing slot priority:
    //   1. trailingBuilder — caller has full control.
    //   2. Animated × clear when _hasText (iOS 26 pattern — clears without dismissing).
    //   3. Default mic icon.
    // Note: the dismiss (close-search) × is a SEPARATE sibling pill in the
    // outer bar Row — it is NOT rendered here. This matches the real iOS 26
    // Apple News layout where the × is its own glass button outside the search pill.
    Widget trailing;
    if (config.trailingBuilder != null) {
      trailing = config.trailingBuilder!(context);
    } else {
      trailing = AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: _hasText
            ? GestureDetector(
                key: const ValueKey('clear'),
                behavior: HitTestBehavior.opaque,
                onTap: _handleClear,
                child: Icon(
                  CupertinoIcons.clear_circled_solid,
                  color: iconColor,
                  size: 18,
                ),
              )
            : GestureDetector(
                key: const ValueKey('mic'),
                behavior: HitTestBehavior.opaque,
                onTap: config.onMicTap,
                child: config.onMicTap != null
                    ? Icon(CupertinoIcons.mic_fill, color: micColor, size: 18)
                    : const SizedBox.shrink(),
              ),
      );
    }

    // The expanded pill content.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.search, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: false,
              onChanged: config.onChanged,
              onSubmitted: config.onSubmitted,
              onTapOutside: config.onTapOutside,
              textInputAction: config.textInputAction,
              keyboardType: config.keyboardType,
              autocorrect: config.autocorrect,
              enableSuggestions: config.enableSuggestions,
              style: config.hintStyle ??
                  TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                  ),
              cursorColor: textColor,
              decoration: InputDecoration(
                hintText: config.hintText,
                hintStyle: (config.hintStyle ??
                        const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w400))
                    .copyWith(color: iconColor),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
