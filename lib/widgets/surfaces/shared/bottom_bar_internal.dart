// ignore_for_file: deprecated_member_use
// Shared internal widgets for GlassBottomBar and GlassSearchableBottomBar.
//
// NOT part of the public API — do not export from liquid_glass_widgets.dart.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../src/renderer/liquid_glass_renderer.dart';
import '../../../types/glass_quality.dart';
import '../../interactive/glass_button.dart';
import '../glass_bottom_bar.dart'
    show GlassBottomBarExtraButton, GlassBottomBarTab;

// =============================================================================
// BottomBarTabItem — shared tab item widget
// =============================================================================

/// Renders a single tab item for [GlassBottomBar] and [GlassSearchableBottomBar].
///
/// Previously duplicated as `_BottomBarTab` and `_TabItem`. Single source of truth.
class BottomBarTabItem extends StatelessWidget {
  const BottomBarTabItem({
    required this.tab,
    required this.selected,
    required this.selectedIconColor,
    required this.unselectedIconColor,
    required this.iconSize,
    required this.textStyle,
    required this.labelFontSize,
    required this.iconLabelSpacing,
    required this.glowDuration,
    required this.glowBlurRadius,
    required this.glowSpreadRadius,
    required this.glowOpacity,
    required this.onTap,
    super.key,
  });

  final GlassBottomBarTab tab;
  final bool selected;
  final Color selectedIconColor;
  final Color unselectedIconColor;
  final double iconSize;
  final TextStyle? textStyle;

  /// Font size for tab labels when [textStyle] is null.
  ///
  /// Mirrors [iconSize] as an explicit sizing knob. Defaults to 11.
  /// Reduce to 10 for bars with 4+ tabs or long label text.
  final double labelFontSize;
  final double iconLabelSpacing;
  final Duration glowDuration;
  final double glowBlurRadius;
  final double glowSpreadRadius;
  final double glowOpacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? selectedIconColor : unselectedIconColor;
    final iconWidget = selected ? (tab.activeIcon ?? tab.icon) : tab.icon;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.label ?? 'Tab',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            spacing: iconLabelSpacing,
            children: [
              ExcludeSemantics(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (tab.glowColor != null)
                      Positioned(
                        top: -24,
                        right: -24,
                        left: -24,
                        bottom: -24,
                        child: RepaintBoundary(
                          child: AnimatedContainer(
                            duration: glowDuration,
                            transformAlignment: Alignment.center,
                            curve: Curves.easeOutCirc,
                            transform: selected
                                ? Matrix4.identity()
                                : (Matrix4.identity()
                                  ..scale(0.4)
                                  ..rotateZ(-math.pi)),
                            child: AnimatedOpacity(
                              duration: glowDuration,
                              opacity: selected ? 1 : 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: tab.glowColor!.withOpacity(
                                        selected ? glowOpacity : 0,
                                      ),
                                      blurRadius: glowBlurRadius,
                                      spreadRadius: glowSpreadRadius,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    IconTheme(
                      data: IconThemeData(
                        color: iconColor,
                        size: iconSize,
                        shadows: _buildIconShadows(iconColor),
                      ),
                      child: DefaultTextStyle(
                        style: DefaultTextStyle.of(context)
                            .style
                            .copyWith(color: iconColor),
                        child: iconWidget,
                      ),
                    ),
                  ],
                ),
              ),
              if (tab.label != null)
                Text(
                  tab.label!,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle ??
                      TextStyle(
                        color: iconColor,
                        fontSize: labelFontSize,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Shadow>? _buildIconShadows(Color iconColor) {
    if (tab.thickness == null || (selected && tab.activeIcon != null)) {
      return null;
    }
    final shadows = <Shadow>[];
    const step = math.pi / 4;
    for (double a = 0; a < math.pi * 2; a += step) {
      shadows.add(Shadow(
        color: iconColor,
        offset: Offset.fromDirection(a, tab.thickness!),
      ));
    }
    return shadows;
  }
}

// =============================================================================
// BottomBarExtraBtn — shared extra button widget
// =============================================================================

/// Renders the extra action button using [GlassButton].
///
/// Previously duplicated as `_ExtraButton` and `_ExtraBtn`. Single source of truth.
class BottomBarExtraBtn extends StatelessWidget {
  const BottomBarExtraBtn({
    required this.config,
    required this.quality,
    required this.iconColor,
    this.borderRadius,
    super.key,
  });

  final GlassBottomBarExtraButton config;
  final GlassQuality quality;
  final Color iconColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return GlassButton(
      icon: config.icon,
      onTap: config.onTap,
      label: config.label,
      width: config.size,
      height: config.size,
      quality: quality,
      iconColor: iconColor,
      shape: borderRadius == null
          ? const LiquidOval()
          : LiquidRoundedRectangle(borderRadius: borderRadius!),
    );
  }
}
