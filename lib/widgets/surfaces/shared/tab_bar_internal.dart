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

  @override
  void didUpdateWidget(TabBarContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.tabs.length != widget.tabs.length) {
      setState(() {
        _xAlign = _computeXAlignmentForTab(widget.selectedIndex);
      });
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
    setState(() {
      _isDragging = true;
      _xAlign = _getAlignmentFromGlobalPosition(details.globalPosition);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _isDown = false;
    });

    final box = context.findRenderObject()! as RenderBox;
    final currentRelativeX = (_xAlign + 1) / 2;
    final tabWidth = 1.0 / widget.tabs.length;
    final indicatorWidth = 1.0 / widget.tabs.length;
    final draggableRange = 1.0 - indicatorWidth;
    final velocityX =
        (details.velocity.pixelsPerSecond.dx / box.size.width) / draggableRange;

    final targetTabIndex = _computeTargetTab(
      currentRelativeX: currentRelativeX,
      velocityX: velocityX,
      tabWidth: tabWidth,
    );

    _xAlign = _computeXAlignmentForTab(targetTabIndex);

    if (targetTabIndex != widget.selectedIndex) {
      widget.onTabSelected(targetTabIndex);
    }
  }

  double _getAlignmentFromGlobalPosition(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return _xAlign;

    final local = box.globalToLocal(globalPosition);

    // Calculate the effective draggable range accounting for indicator size
    final indicatorWidth = 1.0 / widget.tabs.length;
    final draggableRange = 1.0 - indicatorWidth;
    final padding = indicatorWidth / 2; // Center the indicator on cursor

    // Map drag position to 0-1 range with proper centering
    final rawRelativeX = (local.dx / box.size.width).clamp(0.0, 1.0);
    final normalizedX = (rawRelativeX - padding) / draggableRange;
    final clampedX = normalizedX.clamp(0.0, 1.0);

    // Convert to -1 to 1 alignment range
    return (clampedX * 2) - 1;
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
              // DX1: threshold 0.15 → 0.05 for desktop click visibility
              value: _isDown || (alignment.x - targetAlignment).abs() > 0.05
                  ? 1.0
                  : 0.0,
              builder: (context, thickness, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Unified Glass Indicator with jelly physics
                    // The internal cross-fade in AnimatedGlassIndicator prevents flickering
                    AnimatedGlassIndicator(
                      velocity: velocity,
                      itemCount: widget.tabs.length,
                      alignment: alignment,
                      thickness: thickness,
                      quality: widget.quality,
                      indicatorColor: indicatorColor,
                      isBackgroundIndicator:
                          false, // Internal logic now handles both
                      borderRadius:
                          widget.indicatorBorderRadius?.topLeft.x ?? 16,
                      glassSettings: widget.indicatorSettings,
                      backgroundKey: widget.backgroundKey,
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
        ),
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
        return RepaintBoundary(
          child: TabBarItem(
            tab: tab,
            isSelected: isSelected,
            onTap: () => _onTabTap(index),
            onTapDown: () {
              if (index != widget.selectedIndex) {
                widget.onTabSelected(index);
              }
            },
            labelStyle: isSelected ? selectedStyle : unselectedStyle,
            iconColor: isSelected ? selectedIconColor : unselectedIconColor,
            iconSize: widget.iconSize,
            padding: widget.labelPadding,
          ),
        );
      },
    );

    if (widget.isScrollable) {
      return SingleChildScrollView(
        controller: widget.scrollController,
        scrollDirection: Axis.horizontal,
        child: Row(children: tabWidgets),
      );
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
