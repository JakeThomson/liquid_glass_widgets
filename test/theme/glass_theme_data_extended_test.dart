import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Extended unit tests for [GlassThemeData], [GlassThemeVariant],
/// [GlassGlowColors] and [GlassThemeHelpers] — covering fields and paths
/// not yet exercised by glass_theme_test.dart.
void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // GlassGlowColors
  // ──────────────────────────────────────────────────────────────────────────

  group('GlassGlowColors', () {
    group('copyWith — each colour field', () {
      const original = GlassGlowColors(
        primary: Colors.red,
        secondary: Colors.blue,
        success: Colors.green,
        warning: Colors.orange,
        danger: Colors.pink,
        info: Colors.cyan,
      );

      test('copyWith primary', () {
        final copy = original.copyWith(primary: Colors.purple);
        expect(copy.primary, Colors.purple);
        expect(copy.secondary, Colors.blue);
      });

      test('copyWith secondary', () {
        final copy = original.copyWith(secondary: Colors.yellow);
        expect(copy.secondary, Colors.yellow);
        expect(copy.primary, Colors.red);
      });

      test('copyWith success', () {
        final copy = original.copyWith(success: Colors.teal);
        expect(copy.success, Colors.teal);
        expect(copy.danger, Colors.pink);
      });

      test('copyWith warning', () {
        final copy = original.copyWith(warning: Colors.amber);
        expect(copy.warning, Colors.amber);
        expect(copy.info, Colors.cyan);
      });

      test('copyWith danger', () {
        final copy = original.copyWith(danger: Colors.red);
        expect(copy.danger, Colors.red);
        expect(copy.success, Colors.green);
      });

      test('copyWith info', () {
        final copy = original.copyWith(info: Colors.indigo);
        expect(copy.info, Colors.indigo);
        expect(copy.primary, Colors.red);
      });

      test('copy with no changes equals original', () {
        expect(original.copyWith(), equals(original));
        expect(original.copyWith().hashCode, equals(original.hashCode));
      });

      test('copyWith multiple fields', () {
        final copy =
            original.copyWith(primary: Colors.white, danger: Colors.black);
        expect(copy.primary, Colors.white);
        expect(copy.danger, Colors.black);
        expect(copy.secondary, Colors.blue);
      });
    });

    group('equality and hashCode', () {
      test('same fields are equal', () {
        const a = GlassGlowColors(primary: Colors.red);
        const b = GlassGlowColors(primary: Colors.red);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different primary are not equal', () {
        const a = GlassGlowColors(primary: Colors.red);
        const b = GlassGlowColors(primary: Colors.blue);
        expect(a, isNot(equals(b)));
      });

      test('all-null instances are equal', () {
        const a = GlassGlowColors();
        const b = GlassGlowColors();
        expect(a, equals(b));
      });
    });

    group('fallback constant', () {
      test('primary is null (runtime-injected by glowColorsFor)', () {
        expect(GlassGlowColors.fallback.primary, isNull);
      });

      test('secondary is iOS purple', () {
        expect(GlassGlowColors.fallback.secondary, const Color(0xFF5856D6));
      });

      test('success is iOS green', () {
        expect(GlassGlowColors.fallback.success, const Color(0xFF34C759));
      });

      test('warning is iOS orange', () {
        expect(GlassGlowColors.fallback.warning, const Color(0xFFFF9500));
      });

      test('danger is iOS red', () {
        expect(GlassGlowColors.fallback.danger, const Color(0xFFFF3B30));
      });

      test('info is iOS light blue', () {
        expect(GlassGlowColors.fallback.info, const Color(0xFF5AC8FA));
      });
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GlassThemeVariant static presets
  // ──────────────────────────────────────────────────────────────────────────

  group('GlassThemeVariant static presets', () {
    test('light quality is null (widget defaults respected)', () {
      expect(GlassThemeVariant.light.quality, isNull);
    });

    test('dark quality is null (widget defaults respected)', () {
      expect(GlassThemeVariant.dark.quality, isNull);
    });

    test('minimal quality is GlassQuality.minimal', () {
      expect(GlassThemeVariant.minimal.quality, GlassQuality.minimal);
    });

    test('minimal has non-null settings', () {
      expect(GlassThemeVariant.minimal.settings, isNotNull);
    });

    test('light settings has non-null thickness', () {
      expect(GlassThemeVariant.light.settings?.thickness, isNotNull);
    });

    test('dark settings has non-null thickness', () {
      expect(GlassThemeVariant.dark.settings?.thickness, isNotNull);
    });

    test('dark thickness is >= light thickness (dark glass is thicker)', () {
      final lightThickness = GlassThemeVariant.light.settings?.thickness ?? 0;
      final darkThickness = GlassThemeVariant.dark.settings?.thickness ?? 0;
      expect(darkThickness, greaterThanOrEqualTo(lightThickness));
    });

    test('all presets have non-null glowColors', () {
      expect(GlassThemeVariant.light.glowColors, isNotNull);
      expect(GlassThemeVariant.dark.glowColors, isNotNull);
      expect(GlassThemeVariant.minimal.glowColors, isNotNull);
    });
  });

  group('GlassThemeVariant copyWith', () {
    const base = GlassThemeVariant(
      settings: GlassThemeSettings(thickness: 30.0),
      quality: GlassQuality.standard,
      glowColors: GlassGlowColors(primary: Colors.blue),
    );

    test('copy with no args equals original', () {
      expect(base.copyWith(), equals(base));
    });

    test('copyWith quality', () {
      final copy = base.copyWith(quality: GlassQuality.premium);
      expect(copy.quality, GlassQuality.premium);
      expect(copy.settings, base.settings);
    });

    test('copyWith settings', () {
      final copy = base.copyWith(
        settings: const GlassThemeSettings(blur: 12.0),
      );
      expect(copy.settings?.blur, 12.0);
      expect(copy.quality, base.quality);
    });

    test('copyWith glowColors', () {
      final copy = base.copyWith(
        glowColors: const GlassGlowColors(primary: Colors.red),
      );
      expect(copy.glowColors?.primary, Colors.red);
    });
  });

  group('GlassThemeVariant equality and hashCode', () {
    test('identical variants are equal', () {
      const a = GlassThemeVariant(quality: GlassQuality.standard);
      const b = GlassThemeVariant(quality: GlassQuality.standard);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different quality are not equal', () {
      const a = GlassThemeVariant(quality: GlassQuality.standard);
      const b = GlassThemeVariant(quality: GlassQuality.premium);
      expect(a, isNot(equals(b)));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GlassThemeData
  // ──────────────────────────────────────────────────────────────────────────

  group('GlassThemeData', () {
    group('fallback()', () {
      test('returns non-null instance', () {
        expect(GlassThemeData.fallback(), isNotNull);
      });

      test('light variant equals GlassThemeVariant.light', () {
        expect(GlassThemeData.fallback().light, GlassThemeVariant.light);
      });

      test('dark variant equals GlassThemeVariant.dark', () {
        expect(GlassThemeData.fallback().dark, GlassThemeVariant.dark);
      });

      test('light and dark quality are null in fallback', () {
        final f = GlassThemeData.fallback();
        expect(f.light.quality, isNull);
        expect(f.dark.quality, isNull);
      });
    });

    group('copyWith', () {
      const original = GlassThemeData(
        light: GlassThemeVariant(quality: GlassQuality.standard),
        dark: GlassThemeVariant(quality: GlassQuality.premium),
      );

      test('copy with no args equals original', () {
        expect(original.copyWith(), equals(original));
      });

      test('copyWith light', () {
        final copy = original.copyWith(
          light: const GlassThemeVariant(quality: GlassQuality.minimal),
        );
        expect(copy.light.quality, GlassQuality.minimal);
        expect(copy.dark.quality, GlassQuality.premium);
      });

      test('copyWith dark', () {
        final copy = original.copyWith(
          dark: const GlassThemeVariant(quality: GlassQuality.standard),
        );
        expect(copy.dark.quality, GlassQuality.standard);
        expect(copy.light.quality, GlassQuality.standard);
      });
    });

    group('equality and hashCode', () {
      test('identical instances are equal', () {
        const a = GlassThemeData(
          light: GlassThemeVariant(quality: GlassQuality.standard),
        );
        const b = GlassThemeData(
          light: GlassThemeVariant(quality: GlassQuality.standard),
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different light quality are not equal', () {
        const a = GlassThemeData(
          light: GlassThemeVariant(quality: GlassQuality.standard),
        );
        const b = GlassThemeData(
          light: GlassThemeVariant(quality: GlassQuality.premium),
        );
        expect(a, isNot(equals(b)));
      });
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GlassThemeData.glowColorsFor — adaptive primary injection
  // ──────────────────────────────────────────────────────────────────────────

  group('GlassThemeData.glowColorsFor adaptive primary', () {
    testWidgets('injects bright primary in light mode (primary was null)',
        (tester) async {
      const data = GlassThemeData(
        light: GlassThemeVariant(
          glowColors: GlassGlowColors(), // primary is null
        ),
      );

      Color? injected;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.light),
          child: MaterialApp(
            home: GlassTheme(
              data: data,
              child: Builder(builder: (context) {
                injected = data.glowColorsFor(context).primary;
                return const SizedBox.shrink();
              }),
            ),
          ),
        ),
      );

      // Light mode → 0x59FFFFFF (35% white)
      expect(injected, isNotNull);
      expect(injected, const Color(0x59FFFFFF));
    });

    testWidgets('injects dimmer primary in dark mode (primary was null)',
        (tester) async {
      const data = GlassThemeData(
        dark: GlassThemeVariant(
          glowColors: GlassGlowColors(), // primary is null
        ),
      );

      Color? injected;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.dark),
          child: MaterialApp(
            home: GlassTheme(
              data: data,
              child: Builder(builder: (context) {
                injected = data.glowColorsFor(context).primary;
                return const SizedBox.shrink();
              }),
            ),
          ),
        ),
      );

      // Dark mode → 0x38FFFFFF (22% white)
      expect(injected, isNotNull);
      expect(injected, const Color(0x38FFFFFF));
    });

    testWidgets('does NOT inject when caller already set primary',
        (tester) async {
      const explicitPrimary = Colors.purple;
      const data = GlassThemeData(
        light: GlassThemeVariant(
          glowColors: GlassGlowColors(primary: explicitPrimary),
        ),
      );

      Color? resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: data,
            child: Builder(builder: (context) {
              resolved = data.glowColorsFor(context).primary;
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(resolved, explicitPrimary);
    });

    testWidgets('secondary color is preserved during injection',
        (tester) async {
      const data = GlassThemeData(
        light: GlassThemeVariant(
          glowColors: GlassGlowColors(
            // primary is null so injection kicks in
            secondary: Colors.orange,
          ),
        ),
      );

      Color? secondary;
      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: data,
            child: Builder(builder: (context) {
              secondary = data.glowColorsFor(context).secondary;
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(secondary, Colors.orange);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GlassThemeHelpers.of — fallback when no ancestor
  // ──────────────────────────────────────────────────────────────────────────

  group('GlassThemeHelpers / GlassThemeData.of', () {
    testWidgets('returns fallback when no GlassTheme in tree', (tester) async {
      GlassThemeData? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            captured = GlassThemeData.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(captured, isNotNull);
      expect(captured, equals(GlassThemeData.fallback()));
    });

    testWidgets('returns provided theme when GlassTheme is present',
        (tester) async {
      const custom = GlassThemeData(
        light: GlassThemeVariant(quality: GlassQuality.minimal),
      );

      GlassThemeData? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: custom,
            child: Builder(builder: (context) {
              captured = GlassThemeData.of(context);
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(captured, equals(custom));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // variantFor / settingsFor / qualityFor
  // ──────────────────────────────────────────────────────────────────────────

  group('variantFor / settingsFor / qualityFor', () {
    testWidgets('variantFor picks light in light mode', (tester) async {
      const data = GlassThemeData(
        light: GlassThemeVariant(quality: GlassQuality.standard),
        dark: GlassThemeVariant(quality: GlassQuality.premium),
      );

      GlassThemeVariant? variant;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.light),
          child: MaterialApp(
            home: Builder(builder: (context) {
              variant = data.variantFor(context);
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(variant?.quality, GlassQuality.standard);
    });

    testWidgets('variantFor picks dark in dark mode', (tester) async {
      const data = GlassThemeData(
        light: GlassThemeVariant(quality: GlassQuality.standard),
        dark: GlassThemeVariant(quality: GlassQuality.premium),
      );

      GlassThemeVariant? variant;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.dark),
          child: MaterialApp(
            home: Builder(builder: (context) {
              variant = data.variantFor(context);
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(variant?.quality, GlassQuality.premium);
    });

    testWidgets('settingsFor returns the variant settings', (tester) async {
      const data = GlassThemeData(
        light: GlassThemeVariant(
          settings: GlassThemeSettings(thickness: 42.0),
        ),
      );

      GlassThemeSettings? settings;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.light),
          child: MaterialApp(
            home: Builder(builder: (context) {
              settings = data.settingsFor(context);
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(settings?.thickness, 42.0);
    });

    testWidgets('qualityFor returns the variant quality', (tester) async {
      const data = GlassThemeData(
        light: GlassThemeVariant(quality: GlassQuality.minimal),
      );

      GlassQuality? quality;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.light),
          child: MaterialApp(
            home: Builder(builder: (context) {
              quality = data.qualityFor(context);
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(quality, GlassQuality.minimal);
    });

    testWidgets('settingsFor returns null when variant has no settings',
        (tester) async {
      const data = GlassThemeData(
        light: GlassThemeVariant(), // no settings
      );

      GlassThemeSettings? settings;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            settings = data.settingsFor(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(settings, isNull);
    });
  });
}
