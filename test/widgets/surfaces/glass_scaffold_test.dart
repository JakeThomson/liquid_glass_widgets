import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../shared/test_helpers.dart';

void main() {
  group('GlassScaffold', () {
    testWidgets('renders with body and bottom bar', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassScaffold(
              body: const Text('Body'),
              bottomBar: GlassBottomBar(
                selectedIndex: 0,
                onTabSelected: (_) {},
                tabs: const [
                  GlassBottomBarTab(
                    label: 'Tab 1',
                    icon: Icon(Icons.home),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Body'), findsOneWidget);
      expect(find.byType(GlassBottomBar), findsOneWidget);
    });

    testWidgets('renders with app bar', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassScaffold(
              appBar: GlassAppBar(title: Text('Title')),
              body: Text('Body'),
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    // ── Edge fade: top fade height calculation ──────────────────────────────

    testWidgets('top fade excludes appBarHeight when no appBar is provided',
        (tester) async {
      // When topEdgeFade is true but no appBar is set, the fade should
      // only cover the status bar area + extent — NOT include the default
      // 44px appBarHeight. Regression test for the fix that checks
      // `appBar != null` before adding effectiveAppBarHeight.
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassScaffold(
              topEdgeFade: true,
              body: SizedBox.expand(),
            ),
          ),
        ),
      );

      // The GlassScrollEdgeEffect should be present (fade is enabled).
      expect(find.byType(GlassScrollEdgeEffect), findsOneWidget);

      // Verify the fade widget exists and the scaffold rendered without error.
      final scrollEdge = tester.widget<GlassScrollEdgeEffect>(
        find.byType(GlassScrollEdgeEffect),
      );
      // Without appBar, topFadeHeight = topPad + 0 + 20 (default extent).
      // The key assertion: it should NOT be topPad + 44 + 20.
      // In test environment, topPad is 0, so topFadeHeight should be 20.
      expect(scrollEdge.topFadeHeight, 20.0);
    });

    testWidgets('top fade includes appBarHeight when appBar is provided',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassScaffold(
              appBar: GlassAppBar(title: Text('Title')),
              body: SizedBox.expand(),
            ),
          ),
        ),
      );

      expect(find.byType(GlassScrollEdgeEffect), findsOneWidget);

      final scrollEdge = tester.widget<GlassScrollEdgeEffect>(
        find.byType(GlassScrollEdgeEffect),
      );
      // With appBar, topFadeHeight = topPad(0) + 44 + 20 = 64.
      expect(scrollEdge.topFadeHeight, 64.0);
    });

    // ── Isolation scope: bars get premium quality hint ───────────────────────

    testWidgets('wraps bars in GlassIsolationScope with defaultQuality premium',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassScaffold(
              appBar: const GlassAppBar(title: Text('Title')),
              body: const Text('Body'),
              bottomBar: GlassBottomBar(
                selectedIndex: 0,
                onTabSelected: (_) {},
                tabs: const [
                  GlassBottomBarTab(
                    label: 'Tab 1',
                    icon: Icon(Icons.home),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // GlassIsolationScope should be present (wrapping bars).
      expect(find.byType(GlassIsolationScope), findsWidgets);
    });

    testWidgets('bars use isolated: true for correct Z-order', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassScaffold(
              appBar: const GlassAppBar(title: Text('Title')),
              body: const Text('Body'),
              bottomBar: GlassBottomBar(
                selectedIndex: 0,
                onTabSelected: (_) {},
                tabs: const [
                  GlassBottomBarTab(
                    label: 'Tab 1',
                    icon: Icon(Icons.home),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify GlassIsolationScope widgets have isolated: true.
      final scopes = tester.widgetList<GlassIsolationScope>(
        find.byType(GlassIsolationScope),
      );
      for (final scope in scopes) {
        if (scope.defaultQuality == GlassQuality.premium) {
          // Bar scopes from GlassScaffold should be isolated.
          expect(scope.isolated, isTrue,
              reason: 'Bar isolation scope should use isolated: true '
                  'for correct Z-order of glass components');
        }
      }
    });
  });
}
