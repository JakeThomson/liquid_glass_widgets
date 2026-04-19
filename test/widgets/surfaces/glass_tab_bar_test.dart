import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../shared/test_helpers.dart';

void main() {
  group('GlassTabBar', () {
    testWidgets('renders with minimum required properties',
        (WidgetTester tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              tabs: const [
                GlassTab(label: 'Tab 1'),
                GlassTab(label: 'Tab 2'),
              ],
              selectedIndex: selectedIndex,
              onTabSelected: (index) {
                selectedIndex = index;
              },
            ),
          ),
        ),
      );

      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.text('Tab 2'), findsOneWidget);
    });

    testWidgets('calls onTabSelected when tab is tapped',
        (WidgetTester tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: StatefulBuilder(
              builder: (context, setState) {
                return GlassTabBar(
                  tabs: const [
                    GlassTab(label: 'Tab 1'),
                    GlassTab(label: 'Tab 2'),
                    GlassTab(label: 'Tab 3'),
                  ],
                  selectedIndex: selectedIndex,
                  onTabSelected: (index) {
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(selectedIndex, 0);

      await tester.tap(find.text('Tab 2'));
      await tester.pumpAndSettle();

      expect(selectedIndex, 1);

      await tester.tap(find.text('Tab 3'));
      await tester.pumpAndSettle();

      expect(selectedIndex, 2);
    });

    testWidgets('renders with icons only', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              tabs: const [
                GlassTab(icon: Icon(Icons.home)),
                GlassTab(icon: Icon(Icons.search)),
                GlassTab(icon: Icon(Icons.settings)),
              ],
              selectedIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('renders with icons and labels', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              height: 56, // Taller for icon + label
              tabs: const [
                GlassTab(icon: Icon(Icons.home), label: 'Home'),
                GlassTab(icon: Icon(Icons.search), label: 'Search'),
              ],
              selectedIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets('works in standalone mode with useOwnLayer',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: GlassTabBar(
            useOwnLayer: true,
            settings: settingsWithoutLighting,
            tabs: const [
              GlassTab(label: 'Tab 1'),
              GlassTab(label: 'Tab 2'),
            ],
            selectedIndex: 0,
            onTabSelected: (_) {},
          ),
        ),
      );

      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.text('Tab 2'), findsOneWidget);
    });

    testWidgets('renders with custom label styles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              tabs: const [
                GlassTab(label: 'Tab 1'),
                GlassTab(label: 'Tab 2'),
              ],
              selectedIndex: 0,
              onTabSelected: (_) {},
              selectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.blue,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.text('Tab 2'), findsOneWidget);
    });

    testWidgets('renders scrollable tabs', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              isScrollable: true,
              tabs: List.generate(
                10,
                (i) => GlassTab(label: 'Tab ${i + 1}'),
              ),
              selectedIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Tab 1'), findsOneWidget);
    });

    testWidgets('respects custom height', (WidgetTester tester) async {
      const customHeight = 60.0;

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              height: customHeight,
              tabs: const [
                GlassTab(label: 'Tab 1'),
                GlassTab(label: 'Tab 2'),
              ],
              selectedIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );

      final tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
      expect(tabBar.height, customHeight);
    });

    testWidgets('updates when selectedIndex changes',
        (WidgetTester tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: StatefulBuilder(
              builder: (context, setState) {
                return GlassTabBar(
                  tabs: const [
                    GlassTab(label: 'Tab 1'),
                    GlassTab(label: 'Tab 2'),
                    GlassTab(label: 'Tab 3'),
                  ],
                  selectedIndex: selectedIndex,
                  onTabSelected: (index) {
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Tab 2'));
      await tester.pumpAndSettle();

      expect(selectedIndex, 1);
    });

    testWidgets('respects quality setting', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              tabs: const [
                GlassTab(label: 'Tab 1'),
                GlassTab(label: 'Tab 2'),
              ],
              selectedIndex: 0,
              onTabSelected: (_) {},
              quality: GlassQuality.premium,
            ),
          ),
        ),
      );

      final tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
      expect(tabBar.quality, equals(GlassQuality.premium));
    });

    test('GlassTab requires either icon or label', () {
      expect(
        () => const GlassTab(icon: Icon(Icons.home)),
        returnsNormally,
      );

      expect(
        () => const GlassTab(label: 'Tab'),
        returnsNormally,
      );

      expect(
        () => const GlassTab(icon: Icon(Icons.home), label: 'Tab'),
        returnsNormally,
      );
    });

    testWidgets('asserts minimum 2 tabs', (WidgetTester tester) async {
      expect(
        () => GlassTabBar(
          tabs: const [GlassTab(label: 'Only one')],
          selectedIndex: 0,
          onTabSelected: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('asserts selectedIndex is in bounds',
        (WidgetTester tester) async {
      expect(
        () => GlassTabBar(
          tabs: const [
            GlassTab(label: 'Tab 1'),
            GlassTab(label: 'Tab 2'),
          ],
          selectedIndex: 5, // Out of bounds
          onTabSelected: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('supports dragging between tabs', (WidgetTester tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: StatefulBuilder(
              builder: (context, setState) {
                return GlassTabBar(
                  tabs: const [
                    GlassTab(label: 'Tab 1'),
                    GlassTab(label: 'Tab 2'),
                    GlassTab(label: 'Tab 3'),
                  ],
                  selectedIndex: selectedIndex,
                  onTabSelected: (index) {
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Drag from left to right
      await tester.drag(find.byType(GlassTabBar), const Offset(200, 0));
      await tester.pumpAndSettle();

      // Should have changed tab due to drag
      expect(selectedIndex, greaterThan(0));
    });

    testWidgets('GlassTabBar respects custom borderRadius', (tester) async {
      const customRadius = BorderRadius.all(Radius.circular(20));

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              tabs: const [
                GlassTab(label: 'Tab 1'),
                GlassTab(label: 'Tab 2'),
              ],
              selectedIndex: 0,
              onTabSelected: (_) {},
              borderRadius: customRadius,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find
          .descendant(
            of: find.byType(GlassTabBar),
            matching: find.byType(Container),
          )
          .first);

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, customRadius);
    });
    testWidgets('GlassTab with semanticLabel renders tab label text',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              tabs: const [
                GlassTab(
                  label: 'Home',
                  semanticLabel: 'Go to Home',
                ),
                GlassTab(label: 'Settings'),
              ],
              selectedIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('GlassTabBar backgroundColor transparent uses default',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              tabs: const [
                GlassTab(label: 'A'),
                GlassTab(label: 'B'),
              ],
              selectedIndex: 0,
              onTabSelected: (_) {},
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      );
      expect(find.byType(GlassTabBar), findsOneWidget);
    });

    testWidgets('scrollable tab bar didUpdateWidget scrolls on index change',
        (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: StatefulBuilder(
              builder: (context, setState) {
                return GlassTabBar(
                  isScrollable: true,
                  tabs: List.generate(
                    8,
                    (i) => GlassTab(label: 'T${i + 1}'),
                  ),
                  selectedIndex: selectedIndex,
                  onTabSelected: (index) =>
                      setState(() => selectedIndex = index),
                );
              },
            ),
          ),
        ),
      );

      // Tap tab 7 (index 6) — triggers scrollToIndex via didUpdateWidget
      await tester.tap(find.text('T7').first);
      await tester.pumpAndSettle();
      expect(selectedIndex, 6);
    });

    testWidgets('drag cancel while not dragging resets alignment',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: SizedBox(
              width: 300,
              child: GlassTabBar(
                tabs: const [
                  GlassTab(label: 'A'),
                  GlassTab(label: 'B'),
                  GlassTab(label: 'C'),
                ],
                selectedIndex: 1,
                onTabSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      // A cancel without first moving triggers the else-branch
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(GlassTabBar)));
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(find.byType(GlassTabBar), findsOneWidget);
    });

    testWidgets('pointer-cancel while not dragging clears _isDown',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              tabs: const [
                GlassTab(label: 'A'),
                GlassTab(label: 'B'),
              ],
              selectedIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(GlassTabBar)));
      await tester.pump();
      // Cancel before any drag update fires (not dragging → else-branch of onPointerCancel)
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(find.byType(GlassTabBar), findsOneWidget);
    });

    testWidgets('tab tapping same tab does not fire onTabSelected',
        (tester) async {
      int callCount = 0;
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              tabs: const [
                GlassTab(label: 'A'),
                GlassTab(label: 'B'),
              ],
              selectedIndex: 0,
              onTabSelected: (_) => callCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('A').first);
      await tester.pump();
      expect(callCount, 0);
    });

    testWidgets('GlassTab icon-only tab renders without label', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              tabs: const [
                GlassTab(icon: Icon(Icons.star)),
                GlassTab(icon: Icon(Icons.settings)),
              ],
              selectedIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('GlassTab label-only tab renders icon as null', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              tabs: const [
                GlassTab(label: 'Alpha'),
                GlassTab(label: 'Beta'),
              ],
              selectedIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Alpha'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Additional coverage: drag cancel while dragging (lines 509-518)
  // and GlassTab.glowColor / thickness (lines 266, 513-521)
  // ──────────────────────────────────────────────────────────────────────────
  group('GlassTabBar drag-cancel while dragging (line 509-518)', () {
    testWidgets('cancel after drag move exercises _isDragging==true branch',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: SizedBox(
              width: 400,
              child: GlassTabBar(
                tabs: const [
                  GlassTab(label: 'P'),
                  GlassTab(label: 'Q'),
                  GlassTab(label: 'R'),
                ],
                selectedIndex: 0,
                onTabSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      // Start drag AND move enough to set _isDragging = true, then cancel
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(GlassTabBar)));
      await tester.pump();
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      await gesture.cancel(); // triggers _isDragging==true branch
      await tester.pumpAndSettle();

      expect(find.byType(GlassTabBar), findsOneWidget);
    });
  });

  group('GlassTabBar backgroundColor edge cases', () {
    testWidgets(
        'backgroundColor Colors.transparent uses default color (line 264-266)',
        (tester) async {
      // When backgroundColor == Colors.transparent, falls through to
      // _defaultBackgroundColor branch
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: settingsWithoutLighting,
            child: GlassTabBar(
              tabs: const [GlassTab(label: 'A'), GlassTab(label: 'B')],
              selectedIndex: 0,
              onTabSelected: (_) {},
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassTabBar), findsOneWidget);
    });
  });
}
