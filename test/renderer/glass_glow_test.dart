import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/src/renderer/glass_glow.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // GlassGlowLayer construction
  // ──────────────────────────────────────────────────────────────────────────

  group('GlassGlowLayer', () {
    testWidgets('renders child without glow when no touch', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassGlowLayer(
            child: SizedBox(width: 200, height: 200, child: Text('content')),
          ),
        ),
      );
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('maybeOf returns null when no layer ancestor', (tester) async {
      GlassGlowLayerState? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = GlassGlowLayer.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(result, isNull);
    });

    testWidgets('maybeOf returns state when layer is present', (tester) async {
      GlassGlowLayerState? result;
      await tester.pumpWidget(
        MaterialApp(
          home: GlassGlowLayer(
            child: Builder(
              builder: (context) {
                result = GlassGlowLayer.maybeOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(result, isNotNull);
    });

    testWidgets('disposes cleanly when removed from tree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassGlowLayer(
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );
      // Remove from tree
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GlassGlow within layer
  // ──────────────────────────────────────────────────────────────────────────

  group('GlassGlow', () {
    testWidgets('renders child within a GlassGlowLayer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassGlowLayer(
            child: GlassGlow(
              child: SizedBox(
                width: 100,
                height: 100,
                child: Text('glow child'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('glow child'), findsOneWidget);
    });

    testWidgets('responds to pointer down and move events', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassGlowLayer(
            child: GlassGlow(
              child: SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(GlassGlow));
      final gesture = await tester.startGesture(center);
      await tester.pump();

      await gesture.moveBy(const Offset(10, 10));
      await tester.pump();

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('pointer cancel removes touch', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassGlowLayer(
            child: GlassGlow(
              child: SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(GlassGlow));
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();
    });

    testWidgets('custom glowColor and glowRadius are stored', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassGlowLayer(
            child: GlassGlow(
              glowColor: Colors.blue,
              glowRadius: 0.5,
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      final glow = tester.widget<GlassGlow>(find.byType(GlassGlow));
      expect(glow.glowColor, Colors.blue);
      expect(glow.glowRadius, 0.5);
    });

    testWidgets('GlassGlow without GlassGlowLayer does not throw',
        (tester) async {
      // _handlePointer should silently return when layerState == null
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassGlow(
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(GlassGlow));
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.up();
      await tester.pump();
    });

    testWidgets('GlassGlowLayerState.updateTouch updates on subsequent call',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassGlowLayer(
            child: GlassGlow(
              child: SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(GlassGlow));
      final gesture = await tester.startGesture(center);
      await tester.pump();

      // Second move — exercises the already-dragging branch
      await gesture.moveBy(const Offset(5, 5));
      await tester.pump();
      await gesture.moveBy(const Offset(-5, 10));
      await tester.pump();

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('removeTouch is idempotent – calling twice does not crash',
        (tester) async {
      GlassGlowLayerState? state;
      await tester.pumpWidget(
        MaterialApp(
          home: GlassGlowLayer(
            child: Builder(
              builder: (context) {
                state = GlassGlowLayer.maybeOf(context);
                return const SizedBox(width: 100, height: 100);
              },
            ),
          ),
        ),
      );

      expect(state, isNotNull);
      state!.removeTouch(); // no-op (not dragging)
      state!.removeTouch(); // should not throw
    });
  });
}
