import 'package:flutter/cupertino.dart';

import '../../../src/renderer/liquid_glass_renderer.dart';
import '../../../types/glass_quality.dart';
import '../../../widgets/interactive/glass_button.dart';
import '../../../widgets/surfaces/glass_tab_bar.dart';
import '../../../widgets/surfaces/glass_vertical_bar.dart';
import 'vertical_bar_reservation.dart';

/// [GlassTabBar] in iPhone Duo's vertical bar strip.
///
/// Natively the tab bar becomes an icon-only capsule at the bottom of the
/// strip, one control wide: labels are dropped, the tabs stack top to bottom,
/// and the selected tab sits on a rounded indicator. Four tabs make a 48×212
/// capsule, ending [GlassVerticalBarData.bottom] above the screen's bottom
/// edge.
///
/// The bar is handed whatever box its parent gives a bottom bar — the full
/// width of a [GlassScaffold] — and aligns itself into the strip, so it lands
/// in the same column as the pinned chrome above it.
///
/// Where the strip is too short for it ([GlassVerticalBarData.collapsesTabBar])
/// it collapses to a circle holding the selected tab. A tap on the circle
/// opens the capsule again, and choosing a tab collapses it.
class TabBarVerticalLayout extends StatefulWidget {
  /// Creates the vertical layout of a tab bar.
  const TabBarVerticalLayout({
    super.key,
    required this.bar,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.settings,
    this.quality,
    this.indicatorColor,
    this.selectedIconColor,
    this.unselectedIconColor,
    this.iconSize = 24,
    this.platformViewBackdrop = false,
  });

  /// The strip to lay out in.
  final GlassVerticalBarData bar;

  /// The tabs, top to bottom.
  final List<GlassTab> tabs;

  /// The index of the selected tab.
  final int selectedIndex;

  /// Called with a tab's index when it is tapped.
  final ValueChanged<int> onTabSelected;

  /// Glass settings for the capsule.
  final LiquidGlassSettings? settings;

  /// Rendering quality for the capsule.
  final GlassQuality? quality;

  /// Colour of the selected tab's indicator.
  final Color? indicatorColor;

  /// Colour of the selected tab's icon.
  final Color? selectedIconColor;

  /// Colour of the other tabs' icons.
  final Color? unselectedIconColor;

  /// Size of the tab icons.
  final double iconSize;

  /// Whether the capsule floats over a native platform view.
  final bool platformViewBackdrop;

  /// Space above the first tab and below the last, inside the capsule.
  static const double _padding = 6.0;

  /// Width and height of the selected tab's indicator.
  ///
  /// Natively it fills the capsule's width less 2pt a side and overhangs its
  /// tab's slot by 4pt at each end.
  static const Size _indicatorSize = Size(44, 58);

  /// The capsule's height for [count] tabs.
  static double heightFor(int count) =>
      2 * _padding + count * GlassVerticalBarMetrics.itemExtent;

  @override
  State<TabBarVerticalLayout> createState() => _TabBarVerticalLayoutState();
}

class _TabBarVerticalLayoutState extends State<TabBarVerticalLayout> {
  /// Whether a collapsed bar has been tapped open.
  bool _expanded = false;

  void _select(int index) {
    setState(() => _expanded = false);
    widget.onTabSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    const width = GlassVerticalBarMetrics.controlExtent;
    const itemExtent = GlassVerticalBarMetrics.itemExtent;
    const padding = TabBarVerticalLayout._padding;
    const indicatorSize = TabBarVerticalLayout._indicatorSize;
    final bar = widget.bar;
    final tabs = widget.tabs;
    final selectedIndex = widget.selectedIndex;
    final label = CupertinoColors.label.resolveFrom(context);
    final selectedColor = widget.selectedIconColor ?? label;
    final unselectedColor = widget.unselectedIconColor ?? label;
    final indicatorTop = padding +
        selectedIndex * itemExtent -
        (indicatorSize.height - itemExtent) / 2;
    // The capsule sits in the strip's column: its inner edge
    // GlassVerticalBarMetrics.inset from the content, the rest of the strip
    // between it and the screen edge.
    final outerInset = bar.width - GlassVerticalBarMetrics.inset - width;
    final trailingStrip = bar.edge == GlassVerticalBarEdge.trailing;
    final collapsed = bar.collapsesTabBar && !_expanded;

    final Widget capsule = collapsed
        ? GlassButton.custom(
            onTap: () => setState(() => _expanded = true),
            shape: const LiquidRoundedRectangle(borderRadius: width / 2),
            settings: widget.settings,
            quality: widget.quality,
            platformViewBackdrop: widget.platformViewBackdrop,
            label: tabs[selectedIndex].semanticLabel ??
                tabs[selectedIndex].label ??
                '',
            width: width,
            height: width,
            child: _VerticalTab(
              tab: tabs[selectedIndex],
              selected: true,
              color: selectedColor,
              iconSize: widget.iconSize,
              extent: width,
              onTap: null,
            ),
          )
        : GlassButton.custom(
            onTap: () {}, // The tabs handle their own taps.
            shape: const LiquidRoundedRectangle(borderRadius: width / 2),
            settings: widget.settings,
            quality: widget.quality,
            platformViewBackdrop: widget.platformViewBackdrop,
            canRequestFocus: false,
            excludeFromSemantics: true,
            width: width,
            height: TabBarVerticalLayout.heightFor(tabs.length),
            stretch: 0.15,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  top: indicatorTop,
                  left: (width - indicatorSize.width) / 2,
                  width: indicatorSize.width,
                  height: indicatorSize.height,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: widget.indicatorColor ??
                          CupertinoColors.secondarySystemFill
                              .resolveFrom(context),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: padding),
                  child: Column(
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        _VerticalTab(
                          tab: tabs[i],
                          selected: i == selectedIndex,
                          color: i == selectedIndex
                              ? selectedColor
                              : unselectedColor,
                          iconSize: widget.iconSize,
                          onTap: () => _select(i),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );

    return Align(
      alignment: trailingStrip
          ? AlignmentDirectional.bottomEnd
          : AlignmentDirectional.bottomStart,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: bar.bottom,
          start: trailingStrip ? 0 : outerInset,
          end: trailingStrip ? outerInset : 0,
        ),
        child: VerticalBarBottomReservation(child: capsule),
      ),
    );
  }
}

/// One tab in the vertical capsule: its icon alone, with the label kept for
/// semantics.
class _VerticalTab extends StatelessWidget {
  const _VerticalTab({
    required this.tab,
    required this.selected,
    required this.color,
    required this.iconSize,
    required this.onTap,
    this.extent = GlassVerticalBarMetrics.itemExtent,
  });

  final GlassTab tab;
  final bool selected;
  final Color color;
  final double iconSize;

  /// Called on a tap; null where the enclosing control handles it.
  final VoidCallback? onTap;

  /// Height of the tab's slot.
  final double extent;

  @override
  Widget build(BuildContext context) {
    final icon = selected ? (tab.activeIcon ?? tab.icon) : tab.icon;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.semanticLabel ?? tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: GlassVerticalBarMetrics.controlExtent,
          height: extent,
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(color: color, size: iconSize),
              // A label-only tab keeps its label, shrunk to the slot.
              child: icon ??
                  FittedBox(
                    child: Text(
                      tab.label!,
                      style: TextStyle(color: color, fontSize: 11),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
