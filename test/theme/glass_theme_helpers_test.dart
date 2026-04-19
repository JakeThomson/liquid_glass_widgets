import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/theme/glass_theme_helpers.dart';

void main() {
  // ── GlassThemeHelpers.resolveQuality ────────────────────────────────────────

  group('GlassThemeHelpers.resolveQuality', () {
    testWidgets('returns widgetQuality when explicitly set (priority 1)',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            // Even inside an AdaptiveLiquidGlassLayer (ancestor quality),
            // the widget-level override wins.
            result = GlassThemeHelpers.resolveQuality(
              context,
              widgetQuality: GlassQuality.minimal,
            );
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(result, GlassQuality.minimal);
    });

    testWidgets('returns ancestor InheritedLiquidGlass quality (priority 2)',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveLiquidGlassLayer(
            quality: GlassQuality.premium, // ancestor sets premium
            child: Builder(builder: (context) {
              // widgetQuality is null — should fall through to ancestor
              result = GlassThemeHelpers.resolveQuality(
                context,
                widgetQuality: null,
              );
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(result, GlassQuality.premium);
    });

    testWidgets(
        'returns standard fallback when no ancestor and no theme (priority 4)',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            // No InheritedLiquidGlass ancestor, no GlassTheme, no widgetQuality
            result = GlassThemeHelpers.resolveQuality(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(result, GlassQuality.standard);
    });

    testWidgets('respects custom fallback (premium for surface widgets)',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            // No ancestor, no theme → uses the passed fallback
            result = GlassThemeHelpers.resolveQuality(
              context,
              fallback: GlassQuality.premium,
            );
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(result, GlassQuality.premium);
    });

    testWidgets('widgetQuality overrides ancestor quality', (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveLiquidGlassLayer(
            quality: GlassQuality.premium,
            child: Builder(builder: (context) {
              // Widget explicitly wants minimal despite premium ancestor
              result = GlassThemeHelpers.resolveQuality(
                context,
                widgetQuality: GlassQuality.minimal,
              );
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(result, GlassQuality.minimal);
    });
  });
}
