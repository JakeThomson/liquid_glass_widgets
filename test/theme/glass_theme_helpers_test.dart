import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/theme/glass_theme_helpers.dart';

void main() {
  // ── GlassThemeHelpers.resolveQuality ────────────────────────────────────────

  group('GlassThemeHelpers.resolveQuality', () {
    testWidgets(
        'explicit widgetQuality wins over theme and inherited (no scope)',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            result = GlassThemeHelpers.resolveQuality(
              context,
              widgetQuality: GlassQuality.minimal,
            );
            return const SizedBox.shrink();
          }),
        ),
      );

      // No adaptive scope present — explicit quality is returned as-is.
      expect(result, GlassQuality.minimal);
    });

    testWidgets(
        'adaptive scope caps explicit widgetQuality when ceiling is lower',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: _FakeAdaptiveScope(
            ceiling: GlassQuality.standard, // scope decided: standard
            child: Builder(builder: (context) {
              // Widget asks for premium, but device can only do standard.
              result = GlassThemeHelpers.resolveQuality(
                context,
                widgetQuality: GlassQuality.premium,
              );
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      // Adaptive scope wins — premium capped to standard.
      expect(result, GlassQuality.standard);
    });

    testWidgets(
        'explicit minimal is NOT raised by adaptive scope ceiling at standard',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: _FakeAdaptiveScope(
            ceiling: GlassQuality.standard,
            child: Builder(builder: (context) {
              // Developer explicitly chose minimal (e.g. a list card).
              // Scope ceiling is standard — must NOT raise minimal to standard.
              result = GlassThemeHelpers.resolveQuality(
                context,
                widgetQuality: GlassQuality.minimal,
              );
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      // Ceiling only lowers, never raises.
      expect(result, GlassQuality.minimal);
    });

    testWidgets('explicit widgetQuality equal to scope ceiling is unchanged',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: _FakeAdaptiveScope(
            ceiling: GlassQuality.premium,
            child: Builder(builder: (context) {
              result = GlassThemeHelpers.resolveQuality(
                context,
                widgetQuality: GlassQuality.premium,
              );
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(result, GlassQuality.premium);
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
              // Widget explicitly wants minimal despite premium ancestor.
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

    // ── Theme-level quality (Level 4) ──────────────────────────────────────

    testWidgets('GlassTheme quality applies when no widget or ancestor quality',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: GlassThemeData(
              light: const GlassThemeVariant(quality: GlassQuality.minimal),
              dark: const GlassThemeVariant(quality: GlassQuality.minimal),
            ),
            child: Builder(builder: (context) {
              // No widgetQuality, no ancestor — falls through to theme.
              result = GlassThemeHelpers.resolveQuality(context);
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(result, GlassQuality.minimal);
    });

    testWidgets(
        'widgetQuality wins over GlassTheme quality (explicit beats theme)',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: GlassThemeData(
              light: const GlassThemeVariant(quality: GlassQuality.minimal),
              dark: const GlassThemeVariant(quality: GlassQuality.minimal),
            ),
            child: Builder(builder: (context) {
              // Developer explicitly sets premium despite theme saying minimal.
              result = GlassThemeHelpers.resolveQuality(
                context,
                widgetQuality: GlassQuality.premium,
              );
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      // No adaptive scope → explicit widget quality is returned as-is.
      expect(result, GlassQuality.premium);
    });

    testWidgets('scope caps theme quality (Level 4 subject to ceiling)',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: _FakeAdaptiveScope(
            ceiling: GlassQuality.standard,
            child: GlassTheme(
              data: GlassThemeData(
                light: const GlassThemeVariant(quality: GlassQuality.premium),
                dark: const GlassThemeVariant(quality: GlassQuality.premium),
              ),
              child: Builder(builder: (context) {
                // Theme says premium, scope ceiling is standard.
                result = GlassThemeHelpers.resolveQuality(context);
                return const SizedBox.shrink();
              }),
            ),
          ),
        ),
      );

      expect(result, GlassQuality.standard);
    });

    // ── Widget-class default / fallback (Level 5) ─────────────────────────

    testWidgets('surface widget premium fallback applies when no theme set',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            // Simulates e.g. GlassAppBar which passes fallback: premium.
            // No theme, no ancestor, no explicit quality → widget-class default.
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

    testWidgets('scope caps widget-class default (Level 5 subject to ceiling)',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: _FakeAdaptiveScope(
            ceiling: GlassQuality.standard,
            child: Builder(builder: (context) {
              // Surface widget default is premium, scope ceiling is standard.
              result = GlassThemeHelpers.resolveQuality(
                context,
                fallback: GlassQuality.premium,
              );
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(result, GlassQuality.standard);
    });

    testWidgets('scope does NOT raise minimal fallback to higher scope ceiling',
        (tester) async {
      late GlassQuality result;

      await tester.pumpWidget(
        MaterialApp(
          home: _FakeAdaptiveScope(
            ceiling: GlassQuality.premium, // high ceiling — should not raise
            child: Builder(builder: (context) {
              result = GlassThemeHelpers.resolveQuality(
                context,
                fallback: GlassQuality.minimal,
              );
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      // Scope never raises, only lowers.
      expect(result, GlassQuality.minimal);
    });

    // ── Full 5-level interaction ─────────────────────────────────────────────

    testWidgets(
        'full hierarchy: widget > theme > fallback, all subject to scope ceiling',
        (tester) async {
      // Scope ceiling = standard.
      // Theme = premium (which would normally be applied to no-explicit-quality widgets).
      // Widget A has explicit premium → capped to standard.
      // Widget B has no explicit quality → theme says premium → capped to standard.
      // Widget C has explicit minimal → stays minimal (ceiling never raises).
      late GlassQuality resultA, resultB, resultC;

      await tester.pumpWidget(
        MaterialApp(
          home: _FakeAdaptiveScope(
            ceiling: GlassQuality.standard,
            child: GlassTheme(
              data: GlassThemeData(
                light: const GlassThemeVariant(quality: GlassQuality.premium),
                dark: const GlassThemeVariant(quality: GlassQuality.premium),
              ),
              child: Builder(builder: (context) {
                resultA = GlassThemeHelpers.resolveQuality(context,
                    widgetQuality: GlassQuality.premium); // explicit → capped
                resultB =
                    GlassThemeHelpers.resolveQuality(context); // theme → capped
                resultC = GlassThemeHelpers.resolveQuality(context,
                    widgetQuality:
                        GlassQuality.minimal); // explicit → not raised
                return const SizedBox.shrink();
              }),
            ),
          ),
        ),
      );

      expect(resultA, GlassQuality.standard); // premium explicit → capped
      expect(resultB, GlassQuality.standard); // theme premium → capped
      expect(resultC, GlassQuality.minimal); // minimal explicit → unchanged
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Injects a fake [GlassAdaptiveScopeData] into the widget tree so tests can
/// exercise the adaptive ceiling path without a real [GlassAdaptiveScope]
/// running a benchmark.
class _FakeAdaptiveScope extends StatelessWidget {
  const _FakeAdaptiveScope({required this.ceiling, required this.child});

  final GlassQuality ceiling;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassAdaptiveScope(
      // Lock the scope at the desired ceiling with no adaptation.
      initialQuality: ceiling,
      minQuality: ceiling,
      maxQuality: ceiling,
      child: child,
    );
  }
}
