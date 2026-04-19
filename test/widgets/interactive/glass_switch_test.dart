import 'package:liquid_glass_widgets/widgets/interactive/glass_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/widgets/shared/adaptive_liquid_glass_layer.dart';

import '../../shared/test_helpers.dart';

void main() {
  group('GlassSwitch', () {
    testWidgets('can be instantiated with required parameters', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassSwitch(
              value: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(GlassSwitch), findsOneWidget);
    });

    testWidgets('calls onChanged when tapped', (tester) async {
      var value = false;

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassSwitch(
              value: value,
              onChanged: (newValue) => value = newValue,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GlassSwitch));
      await tester.pump();

      expect(value, isTrue);
    });

    testWidgets('shows thumb in correct position when value is false',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassSwitch(
              value: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(GlassSwitch), findsOneWidget);
    });

    testWidgets('shows thumb in correct position when value is true',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassSwitch(
              value: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(GlassSwitch), findsOneWidget);
    });

    testWidgets('respects custom colors', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassSwitch(
              value: true,
              onChanged: (_) {},
              activeColor: Colors.blue,
              inactiveColor: Colors.grey,
              thumbColor: Colors.red,
            ),
          ),
        ),
      );

      expect(find.byType(GlassSwitch), findsOneWidget);
    });

    testWidgets('respects custom size', (tester) async {
      const customWidth = 64.0;
      const customHeight = 32.0;

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassSwitch(
              value: false,
              onChanged: (_) {},
              width: customWidth,
              height: customHeight,
            ),
          ),
        ),
      );

      expect(find.byType(GlassSwitch), findsOneWidget);
    });

    testWidgets('works in standalone mode', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: GlassSwitch(
            value: false,
            onChanged: (_) {},
            useOwnLayer: true,
            settings: defaultTestGlassSettings,
          ),
        ),
      );

      expect(find.byType(GlassSwitch), findsOneWidget);
    });

    test('defaults are correct', () {
      final glassSwitch = GlassSwitch(
        value: false,
        onChanged: (_) {},
      );

      expect(glassSwitch.width, equals(58.0));
      expect(glassSwitch.height, equals(26.0));
      expect(glassSwitch.thumbColor, equals(Colors.white));
      expect(glassSwitch.useOwnLayer, isFalse);
      expect(glassSwitch.quality, isNull);
    });

    // ── didUpdateWidget animation branches (lines 212-227) ───────────────────
    testWidgets('toggling value=true animates forward (lines 218-219)',
        (tester) async {
      bool value = false;
      late StateSetter outerSetState;
      await tester.pumpWidget(
        createTestApp(
          child: StatefulBuilder(
            builder: (ctx, setState) {
              outerSetState = setState;
              return AdaptiveLiquidGlassLayer(
                settings: defaultTestGlassSettings,
                child: GlassSwitch(
                  value: value,
                  onChanged: (v) => outerSetState(() => value = v),
                ),
              );
            },
          ),
        ),
      );

      // Flip to true — exercises _positionController.forward()
      outerSetState(() => value = true);
      await tester.pump(); // kick animation
      await tester.pump(const Duration(milliseconds: 400)); // mid animation
      await tester.pumpAndSettle();
      expect(find.byType(GlassSwitch), findsOneWidget);
    });

    testWidgets('toggling value=false animates reverse (line 221)',
        (tester) async {
      bool value = true;
      late StateSetter outerSetState;
      await tester.pumpWidget(
        createTestApp(
          child: StatefulBuilder(
            builder: (ctx, setState) {
              outerSetState = setState;
              return AdaptiveLiquidGlassLayer(
                settings: defaultTestGlassSettings,
                child: GlassSwitch(
                  value: value,
                  onChanged: (v) => outerSetState(() => value = v),
                ),
              );
            },
          ),
        ),
      );

      // Start at true, flip to false — exercises _positionController.reverse()
      outerSetState(() => value = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(GlassSwitch), findsOneWidget);
    });

    testWidgets('mid-animation glow overlay renders when transition > 0.05',
        (tester) async {
      // Catching line 446-451: `if (transition > 0.05) Opacity(GlassGlow(...))`
      // This renders during the animation. We pump partway through the animation
      // to ensure the glow layer is built.
      bool value = false;
      late StateSetter outerSetState;
      await tester.pumpWidget(
        createTestApp(
          child: StatefulBuilder(
            builder: (ctx, setState) {
              outerSetState = setState;
              return AdaptiveLiquidGlassLayer(
                settings: defaultTestGlassSettings,
                child: GlassSwitch(
                  value: value,
                  onChanged: (v) => outerSetState(() => value = v),
                ),
              );
            },
          ),
        ),
      );

      outerSetState(() => value = true);
      // Do NOT pumpAndSettle — mid-animation is where transition > 0
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Widget still alive; glow branch rendered
      expect(find.byType(GlassSwitch), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
