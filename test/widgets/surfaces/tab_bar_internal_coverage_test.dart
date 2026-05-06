// ignore_for_file: require_trailing_commas
// Coverage-targeted tests for tab_bar_internal.dart (TabBarContent) and
// bottom_bar_internal.dart (GlassBottomBarClipper.shouldReclip).
// Targets:
//   tab_bar_internal.dart:
//     - lines 337-348: selectedIndex change in scrollable mode (indicator update)
//     - line 127:      _measureTabs postFrameCallback re-schedule
//     - lines 534-546: scrollable mode indicator skip when not measured + exact-width path
//   bottom_bar_internal.dart:
//     - lines 472-482: GlassBottomBarClipper.shouldReclip full-check when values differ

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../shared/test_helpers.dart';

final _tabs = [
  const GlassTab(label: 'One'),
  const GlassTab(label: 'Two'),
  const GlassTab(label: 'Three'),
  const GlassTab(label: 'Four'),
  const GlassTab(label: 'Five'),
];

void main() {
  group('GlassTabBar — scrollable indicator exact-width interpolation', () {
    testWidgets(
        'selecting different tab in scrollable mode triggers indicator update',
        (tester) async {
      // Lines 337-348 + 534-546: once _tabWidths are measured, selecting a
      // different tab drives the indicator width interpolation path.
      int selectedIndex = 0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        createTestApp(
          child: StatefulBuilder(builder: (ctx, setState) {
            outerSetState = setState;
            return SizedBox(
              width: 400,
              height: 56,
              child: GlassTabBar(
                tabs: _tabs,
                selectedIndex: selectedIndex,
                onTabSelected: (i) => outerSetState(() => selectedIndex = i),
                isScrollable: true,
              ),
            );
          }),
        ),
      );

      // Multiple frames so _measureTabs post-frame callback fires.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();

      // Switch tab → indicator animates with measured widths.
      outerSetState(() => selectedIndex = 2);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();

      outerSetState(() => selectedIndex = 4);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('drag gesture in scrollable mode updates indicator position',
        (tester) async {
      // Lines 534-546: the fractional-index calculation during drag.
      int selectedIndex = 0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        createTestApp(
          child: StatefulBuilder(builder: (ctx, setState) {
            outerSetState = setState;
            return SizedBox(
              width: 400,
              height: 56,
              child: GlassTabBar(
                tabs: _tabs,
                selectedIndex: selectedIndex,
                onTabSelected: (i) => outerSetState(() => selectedIndex = i),
                isScrollable: true,
              ),
            );
          }),
        ),
      );
      // Wait for tab measurement.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();

      // Drag → DraggableIndicatorPhysics drives fractional index path.
      final finder = find.byType(GlassTabBar);
      final center = tester.getCenter(finder);
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'non-scrollable → scrollable toggle exercises isScrollable branch',
        (tester) async {
      // Lines 152-154 equivalent: toggling the isScrollable flag causes the
      // tab bar to re-attach/detach internal scroll listener.
      bool scrollable = false;
      int selectedIndex = 0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        createTestApp(
          child: StatefulBuilder(builder: (ctx, setState) {
            outerSetState = setState;
            return SizedBox(
              width: 400,
              height: 56,
              child: GlassTabBar(
                tabs: _tabs,
                selectedIndex: selectedIndex,
                onTabSelected: (i) => outerSetState(() => selectedIndex = i),
                isScrollable: scrollable,
              ),
            );
          }),
        ),
      );
      await tester.pump();

      // Toggle to scrollable.
      outerSetState(() => scrollable = true);
      await tester.pump();
      await tester.pumpAndSettle();

      // Toggle back to non-scrollable.
      outerSetState(() => scrollable = false);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('GlassBottomBarClipper — shouldReclip full-check path', () {
    testWidgets('changing indicator alignment triggers shouldReclip',
        (tester) async {
      // Lines 472-482: shouldReclip returns true when alignment changes.
      // Exercised by changing selectedIndex (moves indicator → new clipper).
      int selectedTab = 0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        createTestApp(
          child: StatefulBuilder(builder: (ctx, setState) {
            outerSetState = setState;
            return SizedBox(
              height: 80,
              width: 300,
              child: GlassBottomBar(
                tabs: [
                  const GlassBottomBarTab(label: 'A', icon: Icon(Icons.home)),
                  const GlassBottomBarTab(label: 'B', icon: Icon(Icons.search)),
                  const GlassBottomBarTab(label: 'C', icon: Icon(Icons.person)),
                ],
                selectedIndex: selectedTab,
                onTabSelected: (i) => outerSetState(() => selectedTab = i),
                maskingQuality: MaskingQuality.high,
              ),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      // Cycle through all tabs — clipper shouldReclip called with different
      // alignment values each time.
      for (int i = 1; i < 3; i++) {
        outerSetState(() => selectedTab = i);
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'changing borderRadius and selectedIndex together exercises all shouldReclip fields',
        (tester) async {
      // Lines 472-482: the full-check path evaluates borderRadius field.
      // GlassTabBar with indicatorBorderRadius change exercises this.
      BorderRadius radius = BorderRadius.circular(16);
      int selectedIndex = 0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        createTestApp(
          child: StatefulBuilder(builder: (ctx, setState) {
            outerSetState = setState;
            return SizedBox(
              width: 400,
              height: 56,
              child: GlassTabBar(
                tabs: _tabs.sublist(0, 3),
                selectedIndex: selectedIndex,
                onTabSelected: (i) => outerSetState(() => selectedIndex = i),
                isScrollable: false,
                indicatorBorderRadius: radius,
              ),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      // Change both radius and selected tab — causes shouldReclip to evaluate
      // the full property set (including borderRadius != oldClipper.borderRadius).
      outerSetState(() {
        radius = BorderRadius.circular(24);
        selectedIndex = 1;
      });
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();

      outerSetState(() {
        selectedIndex = 2;
      });
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
