import 'package:liquid_glass_widgets/widgets/interactive/glass_button.dart';
import 'package:liquid_glass_widgets/widgets/surfaces/glass_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/widgets/shared/adaptive_liquid_glass_layer.dart';

import '../../shared/test_helpers.dart';

void main() {
  group('GlassAppBar', () {
    testWidgets('can be instantiated with default parameters', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const Scaffold(
              appBar: GlassAppBar(),
            ),
          ),
        ),
      );

      expect(find.byType(GlassAppBar), findsOneWidget);
    });

    testWidgets('displays title', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const Scaffold(
              appBar: GlassAppBar(
                title: Text('App Title'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('App Title'), findsOneWidget);
    });

    testWidgets('displays leading widget', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: Scaffold(
              appBar: GlassAppBar(
                leading: GlassButton(
                  icon: Icon(Icons.menu),
                  onTap: () {},
                ),
                title: const Text('Title'),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('displays actions', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: Scaffold(
              appBar: GlassAppBar(
                title: const Text('Title'),
                actions: [
                  GlassButton(icon: Icon(Icons.search), onTap: () {}),
                  GlassButton(icon: Icon(Icons.more_horiz), onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('centers title by default', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const Scaffold(
              appBar: GlassAppBar(
                title: Text('Centered'),
              ),
            ),
          ),
        ),
      );

      final center = tester.widget<Center>(
        find.descendant(
          of: find.byType(GlassAppBar),
          matching: find.byType(Center),
        ),
      );

      expect(center, isNotNull);
    });

    testWidgets('left-aligns title when centerTitle is false', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const Scaffold(
              appBar: GlassAppBar(
                title: Text('Left'),
                centerTitle: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GlassAppBar), findsOneWidget);
    });

    testWidgets('works in standalone mode', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const Scaffold(
            appBar: GlassAppBar(
              useOwnLayer: true,
              settings: defaultTestGlassSettings,
              title: Text('Standalone'),
            ),
          ),
        ),
      );

      expect(find.byType(GlassAppBar), findsOneWidget);
    });

    testWidgets('implements PreferredSizeWidget', (tester) async {
      const appBar = GlassAppBar();
      expect(appBar, isA<PreferredSizeWidget>());
    });

    test('defaults are correct', () {
      const appBar = GlassAppBar();

      expect(appBar.centerTitle, isTrue);
      expect(appBar.backgroundColor, equals(Colors.transparent));
      expect(appBar.preferredSize, equals(const Size.fromHeight(44.0)));
      expect(appBar.useOwnLayer, isFalse);
      expect(appBar.quality, isNull);
      expect(appBar.scrollController, isNull);
      expect(appBar.scrollEdgeThreshold, equals(50.0));
    });

    // ── Scroll-driven glass tests ───────────────────────────────────────

    group('scroll-driven glass', () {
      testWidgets('is transparent at scroll offset 0', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          createTestApp(
            child: AdaptiveLiquidGlassLayer(
              settings: defaultTestGlassSettings,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: GlassAppBar(
                  title: const Text('Title'),
                  scrollController: controller,
                  settings: defaultTestGlassSettings,
                ),
                body: ListView.builder(
                  controller: controller,
                  itemBuilder: (_, i) => SizedBox(height: 50, child: Text('Item $i')),
                  itemCount: 100,
                ),
              ),
            ),
          ),
        );

        // At offset 0, the glass widget is not built at all (performance).
        expect(
          find.descendant(
            of: find.byType(GlassAppBar),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
      });

      testWidgets('is fully visible at scroll offset >= threshold',
          (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          createTestApp(
            child: AdaptiveLiquidGlassLayer(
              settings: defaultTestGlassSettings,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: GlassAppBar(
                  title: const Text('Title'),
                  scrollController: controller,
                  scrollEdgeThreshold: 50.0,
                  settings: defaultTestGlassSettings,
                ),
                body: ListView.builder(
                  controller: controller,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 50, child: Text('Item $i')),
                  itemCount: 100,
                ),
              ),
            ),
          ),
        );

        // Scroll past threshold
        controller.jumpTo(100);
        await tester.pump();

        final opacity = tester.widget<Opacity>(
          find.descendant(
            of: find.byType(GlassAppBar),
            matching: find.byType(Opacity),
          ),
        );
        expect(opacity.opacity, equals(1.0));
      });

      testWidgets('intermediate scroll shows partial opacity',
          (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          createTestApp(
            child: AdaptiveLiquidGlassLayer(
              settings: defaultTestGlassSettings,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: GlassAppBar(
                  title: const Text('Title'),
                  scrollController: controller,
                  scrollEdgeThreshold: 100.0,
                  settings: defaultTestGlassSettings,
                ),
                body: ListView.builder(
                  controller: controller,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 50, child: Text('Item $i')),
                  itemCount: 100,
                ),
              ),
            ),
          ),
        );

        // Scroll to 50% of threshold
        controller.jumpTo(50);
        await tester.pump();

        final opacity = tester.widget<Opacity>(
          find.descendant(
            of: find.byType(GlassAppBar),
            matching: find.byType(Opacity),
          ),
        );
        expect(opacity.opacity, closeTo(0.5, 0.01));
      });

      testWidgets('works without scrollController (backward compatible)',
          (tester) async {
        await tester.pumpWidget(
          createTestApp(
            child: AdaptiveLiquidGlassLayer(
              settings: defaultTestGlassSettings,
              child: const Scaffold(
                appBar: GlassAppBar(
                  title: Text('No Scroll'),
                  settings: defaultTestGlassSettings,
                ),
              ),
            ),
          ),
        );

        // Should render without Opacity wrapper (static glass)
        expect(find.byType(GlassAppBar), findsOneWidget);
        // No Opacity widget should be used for static glass
        expect(
          find.descendant(
            of: find.byType(GlassAppBar),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
      });

      testWidgets('handles scrollController swap', (tester) async {
        final controller1 = ScrollController();
        final controller2 = ScrollController();
        addTearDown(controller1.dispose);
        addTearDown(controller2.dispose);

        // Build with controller1
        await tester.pumpWidget(
          createTestApp(
            child: AdaptiveLiquidGlassLayer(
              settings: defaultTestGlassSettings,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: GlassAppBar(
                  title: const Text('Title'),
                  scrollController: controller1,
                  settings: defaultTestGlassSettings,
                ),
                body: ListView.builder(
                  controller: controller1,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 50, child: Text('Item $i')),
                  itemCount: 100,
                ),
              ),
            ),
          ),
        );

        // Scroll controller1
        controller1.jumpTo(100);
        await tester.pump();

        var opacity = tester.widget<Opacity>(
          find.descendant(
            of: find.byType(GlassAppBar),
            matching: find.byType(Opacity),
          ),
        );
        expect(opacity.opacity, equals(1.0));

        // Swap to controller2 (at offset 0)
        await tester.pumpWidget(
          createTestApp(
            child: AdaptiveLiquidGlassLayer(
              settings: defaultTestGlassSettings,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: GlassAppBar(
                  title: const Text('Title'),
                  scrollController: controller2,
                  settings: defaultTestGlassSettings,
                ),
                body: ListView.builder(
                  controller: controller2,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 50, child: Text('Item $i')),
                  itemCount: 100,
                ),
              ),
            ),
          ),
        );

        // At offset 0, no Opacity widget is built.
        expect(
          find.descendant(
            of: find.byType(GlassAppBar),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
      });
    });
  });
}
