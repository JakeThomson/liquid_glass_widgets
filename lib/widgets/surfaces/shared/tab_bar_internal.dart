// Shared internal widgets for GlassTabBar.
//
// NOT part of the public API — do not export from liquid_glass_widgets.dart.
library;

import 'package:flutter/material.dart';
import '../../../src/renderer/liquid_glass_renderer.dart';
import '../../../types/glass_quality.dart';
import '../../../utils/draggable_indicator_physics.dart';
import '../../../utils/glass_spring.dart';
import '../../shared/animated_glass_indicator.dart';
import '../glass_tab_bar.dart' show GlassTab;

// =============================================================================
// TabBarContent — draggable indicator + tab layout
// =============================================================================

/// Internal stateful widget managing the draggable pill indicator and tab
/// items for [GlassTabBar].
///
/// Extracted from [GlassTabBar] to keep the public widget focused on
/// configuration and glass-layer wrapping, while this widget owns all gesture,
/// spring, and rendering logic.
class TabBarContent extends StatefulWidget {
  const TabBarContent({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.isScrollable,
    required this.scrollController,
    required this.indicatorColor,
    required this.selectedLabelStyle,
    required this.unselectedLabelStyle,
    required this.selectedIconColor,
    required this.unselectedIconColor,
    required this.iconSize,
    required this.labelPadding,
    required this.quality,
    this.indicatorBorderRadius,
    this.indicatorSettings,
    this.backgroundKey,
    super.key,
  });

  final List<GlassTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final bool isScrollable;
  final ScrollController scrollController;
  final Color? indicatorColor;
  final TextStyle? selectedLabelStyle;
  final TextStyle? unselectedLabelStyle;
  final Color? selectedIconColor;
  final Color? unselectedIconColor;
  final double iconSize;
  final EdgeInsetsGeometry labelPadding;
  final GlassQuality quality;
  final BorderRadius? indicatorBorderRadius;
  final LiquidGlassSettings? indicatorSettings;
  final GlobalKey? backgroundKey;

  @override
  State<TabBarContent> createState() => TabBarContentState();
}

/// State for [TabBarContent]. Public for testing via `@visibleForTesting`.
@visibleForTesting
class TabBarContentState extends State<TabBarContent> {
  // Cache default colors to avoid allocations
  static const _defaultIndicatorColor =
      Color(0x33FFFFFF); // white.withValues(alpha: 0.2)
  static const _defaultUnselectedTextColor =
      Color(0x99FFFFFF); // white.withValues(alpha: 0.6)
  static const _defaultUnselectedIconColor =
      Color(0x99FFFFFF); // white.withValues(alpha: 0.6)

  bool _isDown = false;
  bool _isDragging = false;
  late double _xAlign = _computeXAlignmentForTab(widget.selectedIndex);

  late List<GlobalKey> _tabKeys;
  List<double> _tabWidths = [];
  List<double> _tabOffsets = [];

  @override
  void initState() {
    super.initState();
    _initKeys();
    if (widget.isScrollable) {
      widget.scrollController.addListener(_onScroll);
    }
  }

  void _onScroll() {
    // Rebuild to update the screen-relative indicator position during scroll.
    if (mounted) setState(() {});
  }

  void _initKeys() {
    _tabKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTabs());
  }

  void _measureTabs() {
    if (!mounted) return;
    double offset = 0;
    List<double> widths = [];
    List<double> offsets = [];
    bool allMeasured = true;
    for (final key in _tabKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        allMeasured = false;
        break;
      }
      final width = box.size.width;
      offsets.add(offset);
      widths.add(width);
      offset += width;
    }
    if (allMeasured) {
      setState(() {
        _tabWidths = widths;
        _tabOffsets = offsets;
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureTabs());
    }
  }

  @override
  void dispose() {
    if (widget.isScrollable) {
      widget.scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(TabBarContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle scrollController swap (e.g., parent provides a new controller).
    if (widget.isScrollable &&
        oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }

    // Handle isScrollable toggling (unlikely in practice, but safe).
    if (!oldWidget.isScrollable && widget.isScrollable) {
      widget.scrollController.addListener(_onScroll);
    } else if (oldWidget.isScrollable && !widget.isScrollable) {
      oldWidget.scrollController.removeListener(_onScroll);
    }

    if (oldWidget.selectedIndex != widget.selectedIndex && !_isDragging) {
      setState(() {
        _xAlign = _computeXAlignmentForTab(widget.selectedIndex);
      });
      // Programmatic selection change — ensure the new tab scrolls into view.
      if (widget.isScrollable) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToEnsureVisible(widget.selectedIndex),
        );
      }
    }
    if (oldWidget.tabs.length != widget.tabs.length) {
      // Tab count changed — recompute alignment for the current selected index
      // using the new tab count, and re-measure tab widths.
      setState(() {
        _xAlign = _computeXAlignmentForTab(widget.selectedIndex);
        _tabWidths = [];
        _tabOffsets = [];
      });
      _initKeys();
    }
  }

  double _computeXAlignmentForTab(int tabIndex) {
    return DraggableIndicatorPhysics.computeAlignment(
      tabIndex,
      widget.tabs.length,
    );
  }

  void _onDragDown(DragDownDetails details) {
    setState(() {
      _isDown = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.width <= 0) return;
    final dx = details.delta.dx / box.size.width * 2;
    setState(() {
      _isDragging = true;
      _xAlign = (_xAlign + dx).clamp(-1.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final currentRelativeX = (_xAlign + 1) / 2;
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 1.0;
    final velocityX = details.velocity.pixelsPerSecond.dx / width;

    final targetTabIndex = _computeTargetTab(
      currentRelativeX: currentRelativeX,
      velocityX: velocityX,
      tabWidth: 1.0 / widget.tabs.length,
    );

    setState(() {
      _isDragging = false;
      _isDown = false;
      _xAlign = _computeXAlignmentForTab(targetTabIndex);
    });

    if (targetTabIndex != widget.selectedIndex) {
      widget.onTabSelected(targetTabIndex);
    }
  }

  int _computeTargetTab({
    required double currentRelativeX,
    required double velocityX,
    required double tabWidth,
  }) {
    return DraggableIndicatorPhysics.computeTargetIndex(
      currentRelativeX: currentRelativeX,
      velocityX: velocityX,
      itemWidth: tabWidth,
      itemCount: widget.tabs.length,
    );
  }

  void _onTabTap(int index) {
    if (index != widget.selectedIndex) {
      widget.onTabSelected(index);
    }
    // Scroll the tapped tab fully into view in case it was partially visible.
    if (widget.isScrollable) {
      _scrollToEnsureVisible(index);
    }
  }

  /// Smoothly scrolls the [SingleChildScrollView] so that [tabIndex] is
  /// fully visible, with a small breathing-room edge padding.
  ///
  /// Called on tap and on programmatic selection changes. Only fires when
  /// measurements are ready and the controller has an attached position.
  void _scrollToEnsureVisible(int tabIndex) {
    if (!widget.scrollController.hasClients) return;
    if (tabIndex >= _tabOffsets.length || tabIndex >= _tabWidths.length) return;

    final position = widget.scrollController.position;
    final viewportWidth = position.viewportDimension;
    final currentOffset = position.pixels;
    const edgePadding = 12.0; // breathing room from the left/right edge

    final tabLeft = _tabOffsets[tabIndex];
    final tabRight = tabLeft + _tabWidths[tabIndex];

    double targetOffset = currentOffset;

    if (tabLeft - currentOffset < edgePadding) {
      // Tab is partially or fully off-screen to the left.
      targetOffset = tabLeft - edgePadding;
    } else if (tabRight - currentOffset > viewportWidth - edgePadding) {
      // Tab is partially or fully off-screen to the right.
      targetOffset = tabRight - viewportWidth + edgePadding;
    }

    targetOffset = targetOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if ((targetOffset - currentOffset).abs() > 0.5) {
      widget.scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final indicatorColor = widget.indicatorColor ?? _defaultIndicatorColor;
    final targetAlignment = _computeXAlignmentForTab(widget.selectedIndex);

    final selectedLabelStyle = widget.selectedLabelStyle ??
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        );

    final unselectedLabelStyle = widget.unselectedLabelStyle ??
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _defaultUnselectedTextColor,
        );

    final selectedIconColor = widget.selectedIconColor ?? Colors.white;
    final unselectedIconColor =
        widget.unselectedIconColor ?? _defaultUnselectedIconColor;

    Widget buildContent() {
      return VelocitySpringBuilder(
        value: _xAlign,
        springWhenActive: GlassSpring.interactive(),
        springWhenReleased: GlassSpring.snappy(
          duration: const Duration(milliseconds: 350),
        ),
        active: _isDragging,
        builder: (context, value, velocity, child) {
          final alignment = Alignment(value, 0);

          double? exactWidth;
          double? exactOffset;

          final bool measuredReady = _tabWidths.length == widget.tabs.length;

          if (widget.isScrollable && measuredReady) {
            // Exact inverse of DraggableIndicatorPhysics.computeAlignment:
            //   forward:  value = (index / (n-1)) * 2 - 1
            //   inverse:  index = (value + 1) / 2 * (n-1)
            // Clamped so spring overshoot doesn't extrapolate past last tab.
            final double fractionalIndex =
                ((value + 1.0) / 2.0 * (widget.tabs.length - 1))
                    .clamp(0.0, widget.tabs.length - 1.0);
            final int indexFloor =
                fractionalIndex.floor().clamp(0, widget.tabs.length - 1);
            final int indexCeil =
                fractionalIndex.ceil().clamp(0, widget.tabs.length - 1);
            final double t = (fractionalIndex - indexFloor).clamp(0.0, 1.0);

            exactWidth = _tabWidths[indexFloor] +
                (_tabWidths[indexCeil] - _tabWidths[indexFloor]) * t;
            exactOffset = _tabOffsets[indexFloor] +
                (_tabOffsets[indexCeil] - _tabOffsets[indexFloor]) * t;
          }

          // In scrollable mode, the Stack spans the full scroll content width,
          // so FractionallySizedBox would divide that full width (not viewport)
          // giving a wrong indicator size. Skip the indicator entirely until
          // _measureTabs has accurate data.
          final bool skipIndicator = widget.isScrollable && !measuredReady;

          return SpringBuilder(
            spring: GlassSpring.snappy(
              duration: const Duration(milliseconds: 300),
            ),
            // DX1: threshold 0.15 → 0.05 for desktop click visibility
            value: _isDown || (alignment.x - targetAlignment).abs() > 0.05
                ? 1.0
                : 0.0,
            builder: (context, thickness, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (!skipIndicator)
                    AnimatedGlassIndicator(
                      // No jelly squash/stretch in scrollable mode — tap
                      // velocity is irrelevant. Full expansion preserved for
                      // the iOS 26 glass bloom effect on press.
                      velocity: widget.isScrollable ? 0.0 : velocity,
                      itemCount: widget.tabs.length,
                      alignment: alignment,
                      thickness: thickness,
                      quality: widget.quality,
                      indicatorColor: indicatorColor,
                      isBackgroundIndicator: false,
                      borderRadius:
                          widget.indicatorBorderRadius?.topLeft.x ?? 16,
                      glassSettings: widget.indicatorSettings,
                      backgroundKey: widget.backgroundKey,
                      exactWidth: exactWidth,
                      exactOffset: exactOffset,
                    ),
                  child!,
                ],
              );
            },
            child: _buildTabLabels(
              selectedLabelStyle,
              unselectedLabelStyle,
              selectedIconColor,
              unselectedIconColor,
            ),
          );
        },
      );
    }

    if (widget.isScrollable) {
      // Overlay architecture: indicator lives OUTSIDE SingleChildScrollView
      // as a sibling in an outer Stack. No clip layer can touch it.
      //
      // SingleChildScrollView is NON-positioned → sizes the outer Stack to
      // the viewport width. AnimatedGlassIndicator returns Positioned.fill
      // and uses exactOffset=screenLeft (viewport coords) to place the pill.
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // Non-positioned: sizes the outer Stack to viewport width.
          // NotificationListener cancels the pressed bloom (_isDown) the
          // moment Flutter confirms a scroll gesture has started. Without this,
          // onPointerDown fires for both taps and scrolls, causing the
          // indicator to bloom during scrolling of the tab bar content.
          NotificationListener<ScrollStartNotification>(
            onNotification: (_) {
              if (_isDown) setState(() => _isDown = false);
              return false; // don't absorb — let scroll proceed normally
            },
            child: SingleChildScrollView(
              controller: widget.scrollController,
              scrollDirection: Axis.horizontal,
              child: Listener(
                onPointerDown: (_) => setState(() => _isDown = true),
                onPointerUp: (_) => setState(() => _isDown = false),
                onPointerCancel: (_) => setState(() => _isDown = false),
                child: _buildTabLabels(
                  selectedLabelStyle,
                  unselectedLabelStyle,
                  selectedIconColor,
                  unselectedIconColor,
                ),
              ),
            ),
          ),

          // AnimatedGlassIndicator returns Positioned.fill — it registers
          // with the outer Stack via StackParentData and positions itself
          // using exactOffset (= viewport-relative screenLeft) + exactWidth.
          // No extra Positioned wrapper needed or wanted.
          VelocitySpringBuilder(
            value: _xAlign,
            springWhenActive: GlassSpring.interactive(),
            springWhenReleased: GlassSpring.snappy(
              duration: const Duration(milliseconds: 350),
            ),
            active: _isDragging,
            builder: (context, value, velocity, child) {
              final bool measuredReady =
                  _tabWidths.length == widget.tabs.length;
              if (!measuredReady) return const SizedBox.shrink();

              final double fractionalIndex =
                  ((value + 1.0) / 2.0 * (widget.tabs.length - 1))
                      .clamp(0.0, widget.tabs.length - 1.0);
              final int iFloor =
                  fractionalIndex.floor().clamp(0, widget.tabs.length - 1);
              final int iCeil =
                  fractionalIndex.ceil().clamp(0, widget.tabs.length - 1);
              final double t = (fractionalIndex - iFloor).clamp(0.0, 1.0);

              final double contentOffset = _tabOffsets[iFloor] +
                  (_tabOffsets[iCeil] - _tabOffsets[iFloor]) * t;
              final double tabWidth = _tabWidths[iFloor] +
                  (_tabWidths[iCeil] - _tabWidths[iFloor]) * t;

              final double scrollOffset = widget.scrollController.hasClients
                  ? widget.scrollController.offset
                  : 0.0;

              // Viewport-relative position.
              final double screenLeft = contentOffset - scrollOffset;

              return SpringBuilder(
                spring: GlassSpring.snappy(
                  duration: const Duration(milliseconds: 300),
                ),
                // Same formula as the non-scrollable path: alignment-unit
                // threshold of 0.05 (~9px) is crossed only once by the
                // spring's end-of-animation overshoot, not multiple times
                // like the 0.5px pixel threshold was.
                value: _isDown ||
                        (value - _computeXAlignmentForTab(widget.selectedIndex))
                                .abs() >
                            0.05
                    ? 1.0
                    : 0.0,
                builder: (context, thickness, _) {
                  return AnimatedGlassIndicator(
                    velocity: 0.0,
                    itemCount: widget.tabs.length,
                    alignment: Alignment(value, 0),
                    thickness: thickness,
                    quality: widget.quality,
                    indicatorColor: indicatorColor,
                    isBackgroundIndicator: false,
                    borderRadius: widget.indicatorBorderRadius?.topLeft.x ?? 16,
                    glassSettings: widget.indicatorSettings,
                    backgroundKey: widget.backgroundKey,
                    exactWidth: tabWidth,
                    exactOffset: screenLeft,
                  );
                },
              );
            },
          ),
        ],
      );
    }

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
        onHorizontalDragDown: _onDragDown,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: () {
          if (_isDragging) {
            final currentRelativeX = (_xAlign + 1) / 2;
            final targetTabIndex = _computeTargetTab(
              currentRelativeX: currentRelativeX,
              velocityX: 0,
              tabWidth: 1.0 / widget.tabs.length,
            );
            setState(() {
              _isDragging = false;
              _isDown = false;
              _xAlign = _computeXAlignmentForTab(targetTabIndex);
            });
            if (targetTabIndex != widget.selectedIndex) {
              widget.onTabSelected(targetTabIndex);
            }
          } else {
            setState(
                () => _xAlign = _computeXAlignmentForTab(widget.selectedIndex));
          }
        },
        child: buildContent(),
      ),
    );
  }

  Widget _buildTabLabels(
    TextStyle selectedStyle,
    TextStyle unselectedStyle,
    Color selectedIconColor,
    Color unselectedIconColor,
  ) {
    final tabWidgets = List.generate(
      widget.tabs.length,
      (index) {
        final tab = widget.tabs[index];
        final isSelected = index == widget.selectedIndex;
        return KeyedSubtree(
          key: _tabKeys[index],
          child: RepaintBoundary(
            child: TabBarItem(
              tab: tab,
              isSelected: isSelected,
              onTap: () => _onTabTap(index),
              // onTapDown must NOT call onTabSelected — it fires at the start
              // of every touch including scrolls. Flutter cancels onTap when
              // a scroll gesture wins, but onTapDown has already fired.
              // Visual press state (_isDown) is handled by the parent Listener.
              onTapDown: () {},
              labelStyle: isSelected ? selectedStyle : unselectedStyle,
              iconColor: isSelected ? selectedIconColor : unselectedIconColor,
              iconSize: widget.iconSize,
              padding: widget.labelPadding,
            ),
          ),
        );
      },
    );

    if (widget.isScrollable) {
      return Row(children: tabWidgets);
    }

    return Row(
      children: tabWidgets.map((tab) => Expanded(child: tab)).toList(),
    );
  }
}

// =============================================================================
// TabBarItem — single tab label/icon widget
// =============================================================================

/// Renders a single tab label and/or icon for [GlassTabBar].
///
/// Handles tap gestures, semantics, and animated text style transitions.
class TabBarItem extends StatelessWidget {
  const TabBarItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
    required this.onTapDown,
    required this.labelStyle,
    required this.iconColor,
    required this.iconSize,
    required this.padding,
    super.key,
  });

  final GlassTab tab;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onTapDown;
  final TextStyle labelStyle;
  final Color iconColor;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    Widget? iconWidget;
    if (tab.icon != null) {
      iconWidget = IconTheme(
        data: IconThemeData(color: iconColor, size: iconSize),
        child: tab.icon!,
      );
    }

    Widget? labelWidget;
    if (tab.label != null) {
      labelWidget = Text(
        tab.label!,
        style: labelStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    Widget content;
    if (iconWidget != null && labelWidget != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(height: 4),
          labelWidget,
        ],
      );
    } else if (iconWidget != null) {
      content = iconWidget;
    } else if (labelWidget != null) {
      content = labelWidget;
    } else {
      content = const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      onTapDown: (_) => onTapDown(),
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: tab.semanticLabel ?? tab.label,
        child: Container(
          padding: padding,
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: labelStyle,
            child: content,
          ),
        ),
      ),
    );
  }
}
