import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  group('GlassTheme', () {
    testWidgets('provides theme data to descendants', (tester) async {
      const themeData = GlassThemeData(
        light: GlassThemeVariant(
          settings: LiquidGlassSettings(thickness: 50),
          quality: GlassQuality.premium,
        ),
      );

      GlassThemeData? capturedTheme;

      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: themeData,
            child: Builder(
              builder: (context) {
                capturedTheme = GlassThemeData.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(capturedTheme, equals(themeData));
    });

    testWidgets('returns fallback when no theme in tree', (tester) async {
      GlassThemeData? capturedTheme;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedTheme = GlassThemeData.of(context);
              return Container();
            },
          ),
        ),
      );

      expect(capturedTheme, isNotNull);
      expect(capturedTheme, equals(GlassThemeData.fallback()));
    });

    testWidgets('updates when theme data changes', (tester) async {
      const initialTheme = GlassThemeData(
        light: GlassThemeVariant(
          settings: LiquidGlassSettings(thickness: 30),
        ),
      );

      const updatedTheme = GlassThemeData(
        light: GlassThemeVariant(
          settings: LiquidGlassSettings(thickness: 50),
        ),
      );

      final themeNotifier = ValueNotifier<GlassThemeData>(initialTheme);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<GlassThemeData>(
            valueListenable: themeNotifier,
            builder: (context, theme, child) {
              return GlassTheme(
                data: theme,
                child: Builder(
                  builder: (context) {
                    final capturedTheme = GlassThemeData.of(context);
                    return Text('${capturedTheme.light.settings?.thickness}');
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('30.0'), findsOneWidget);

      themeNotifier.value = updatedTheme;
      await tester.pump();

      expect(find.text('50.0'), findsOneWidget);
    });
  });

  group('GlassThemeData', () {
    test('equality works correctly', () {
      const theme1 = GlassThemeData(
        light: GlassThemeVariant(quality: GlassQuality.standard),
      );
      const theme2 = GlassThemeData(
        light: GlassThemeVariant(quality: GlassQuality.standard),
      );
      const theme3 = GlassThemeData(
        light: GlassThemeVariant(quality: GlassQuality.premium),
      );

      expect(theme1, equals(theme2));
      expect(theme1, isNot(equals(theme3)));
    });

    test('copyWith works correctly', () {
      const original = GlassThemeData(
        light: GlassThemeVariant(quality: GlassQuality.standard),
        dark: GlassThemeVariant(quality: GlassQuality.premium),
      );

      final copied = original.copyWith(
        light: const GlassThemeVariant(quality: GlassQuality.premium),
      );

      expect(copied.light.quality, equals(GlassQuality.premium));
      expect(copied.dark.quality, equals(GlassQuality.premium));
    });

    testWidgets('variantFor selects correct variant based on brightness',
        (tester) async {
      const themeData = GlassThemeData(
        light: GlassThemeVariant(
          settings: LiquidGlassSettings(thickness: 30),
        ),
        dark: GlassThemeVariant(
          settings: LiquidGlassSettings(thickness: 50),
        ),
      );

      // Test light mode
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.light),
          child: MaterialApp(
            home: GlassTheme(
              data: themeData,
              child: Builder(
                builder: (context) {
                  final variant = themeData.variantFor(context);
                  return Text('${variant.settings?.thickness}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('30.0'), findsOneWidget);

      // Test dark mode
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.dark),
          child: MaterialApp(
            home: GlassTheme(
              data: themeData,
              child: Builder(
                builder: (context) {
                  final variant = themeData.variantFor(context);
                  return Text('${variant.settings?.thickness}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('50.0'), findsOneWidget);
    });

    testWidgets('settingsFor returns correct settings', (tester) async {
      const themeData = GlassThemeData(
        light: GlassThemeVariant(
          settings: LiquidGlassSettings(thickness: 30),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: themeData,
            child: Builder(
              builder: (context) {
                final settings = themeData.settingsFor(context);
                return Text('${settings?.thickness}');
              },
            ),
          ),
        ),
      );

      expect(find.text('30.0'), findsOneWidget);
    });

    testWidgets('qualityFor returns correct quality', (tester) async {
      const themeData = GlassThemeData(
        light: GlassThemeVariant(quality: GlassQuality.premium),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: themeData,
            child: Builder(
              builder: (context) {
                final quality = themeData.qualityFor(context);
                return Text('$quality');
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('premium'), findsOneWidget);
    });

    testWidgets('glowColorsFor returns correct colors', (tester) async {
      const themeData = GlassThemeData(
        light: GlassThemeVariant(
          glowColors: GlassGlowColors(
            primary: Colors.blue,
            secondary: Colors.purple,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: themeData,
            child: Builder(
              builder: (context) {
                final glowColors = themeData.glowColorsFor(context);
                return Text('${glowColors.primary}');
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('MaterialColor'), findsOneWidget);
    });
  });

  group('GlassThemeVariant', () {
    test('equality works correctly', () {
      const variant1 = GlassThemeVariant(
        settings: LiquidGlassSettings(thickness: 30),
        quality: GlassQuality.standard,
      );
      const variant2 = GlassThemeVariant(
        settings: LiquidGlassSettings(thickness: 30),
        quality: GlassQuality.standard,
      );
      const variant3 = GlassThemeVariant(
        settings: LiquidGlassSettings(thickness: 50),
        quality: GlassQuality.standard,
      );

      expect(variant1, equals(variant2));
      expect(variant1, isNot(equals(variant3)));
    });

    test('copyWith works correctly', () {
      const original = GlassThemeVariant(
        settings: LiquidGlassSettings(thickness: 30),
        quality: GlassQuality.standard,
      );

      final copied = original.copyWith(
        quality: GlassQuality.premium,
      );

      expect(copied.settings?.thickness, equals(30));
      expect(copied.quality, equals(GlassQuality.premium));
    });
  });

  group('GlassGlowColors', () {
    test('equality works correctly', () {
      const colors1 = GlassGlowColors(
        primary: Colors.blue,
        secondary: Colors.purple,
      );
      const colors2 = GlassGlowColors(
        primary: Colors.blue,
        secondary: Colors.purple,
      );
      const colors3 = GlassGlowColors(
        primary: Colors.red,
        secondary: Colors.purple,
      );

      expect(colors1, equals(colors2));
      expect(colors1, isNot(equals(colors3)));
    });

    test('copyWith works correctly', () {
      const original = GlassGlowColors(
        primary: Colors.blue,
        secondary: Colors.purple,
      );

      final copied = original.copyWith(
        primary: Colors.red,
      );

      expect(copied.primary, equals(Colors.red));
      expect(copied.secondary, equals(Colors.purple));
    });

    test('fallback has sensible defaults', () {
      expect(GlassGlowColors.fallback.primary, isNotNull);
      expect(GlassGlowColors.fallback.secondary, isNotNull);
      expect(GlassGlowColors.fallback.success, isNotNull);
      expect(GlassGlowColors.fallback.warning, isNotNull);
      expect(GlassGlowColors.fallback.danger, isNotNull);
      expect(GlassGlowColors.fallback.info, isNotNull);
    });
  });

  group('AdaptiveLiquidGlassLayer with theme', () {
    testWidgets('uses theme settings when not explicitly provided',
        (tester) async {
      const themeData = GlassThemeData(
        light: GlassThemeVariant(
          settings: LiquidGlassSettings(thickness: 50),
          quality: GlassQuality.premium,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: themeData,
            child: const AdaptiveLiquidGlassLayer(
              child: Text('Test'),
            ),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('explicit settings override theme', (tester) async {
      const themeData = GlassThemeData(
        light: GlassThemeVariant(
          settings: LiquidGlassSettings(thickness: 50),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: themeData,
            child: const AdaptiveLiquidGlassLayer(
              settings: LiquidGlassSettings(thickness: 100),
              child: Text('Test'),
            ),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
    });
  });

  group('GlassButton with theme', () {
    testWidgets('uses theme glow color when not explicitly provided',
        (tester) async {
      const themeData = GlassThemeData(
        light: GlassThemeVariant(
          glowColors: GlassGlowColors(
            primary: Colors.blue,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: themeData,
            child: AdaptiveLiquidGlassLayer(
              child: GlassButton(
                icon: Icons.star,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GlassButton), findsOneWidget);
    });

    testWidgets('explicit glow color overrides theme', (tester) async {
      const themeData = GlassThemeData(
        light: GlassThemeVariant(
          glowColors: GlassGlowColors(
            primary: Colors.blue,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GlassTheme(
            data: themeData,
            child: AdaptiveLiquidGlassLayer(
              child: GlassButton(
                icon: Icons.star,
                glowColor: Colors.red,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GlassButton), findsOneWidget);
    });
  });
}
