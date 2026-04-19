import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../shared/test_helpers.dart';

void main() {
  group('GlassTextField', () {
    testWidgets('can be instantiated with default parameters', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextField(),
          ),
        ),
      );

      expect(find.byType(GlassTextField), findsOneWidget);
    });

    testWidgets('displays placeholder text', (tester) async {
      const placeholder = 'Enter email';

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextField(
              placeholder: placeholder,
            ),
          ),
        ),
      );

      expect(find.text(placeholder), findsOneWidget);
    });

    testWidgets('displays prefix icon when provided', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextField(
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('displays suffix icon when provided', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextField(
              suffixIcon: Icon(Icons.clear),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('calls onChanged when text changes', (tester) async {
      var text = '';

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassTextField(
              onChanged: (value) => text = value,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'flutter');

      expect(text, equals('flutter'));
    });

    testWidgets('calls onSubmitted when submitted', (tester) async {
      var submitted = '';

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassTextField(
              onSubmitted: (value) => submitted = value,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'test');
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(submitted, equals('test'));
    });

    testWidgets('calls onSuffixTap when suffix is tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassTextField(
              suffixIcon: const Icon(Icons.clear),
              onSuffixTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('respects obscureText for password fields', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextField(
              obscureText: true,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.obscureText, isTrue);
    });

    testWidgets('respects enabled state', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextField(
              enabled: false,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.enabled, isFalse);
    });

    testWidgets('works in standalone mode', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const GlassTextField(
            useOwnLayer: true,
            settings: defaultTestGlassSettings,
          ),
        ),
      );

      expect(find.byType(GlassTextField), findsOneWidget);
    });

    test('defaults are correct', () {
      const textField = GlassTextField();

      expect(textField.obscureText, isFalse);
      expect(textField.maxLines, equals(1));
      expect(textField.enabled, isTrue);
      expect(textField.readOnly, isFalse);
      expect(textField.autofocus, isFalse);
      expect(textField.useOwnLayer, isFalse);
      expect(textField.quality, isNull);
    });

    // ── _effectiveBorderRadius shape paths (lines 349-352) ──────────────────
    testWidgets('LiquidRoundedRectangle shape gives correct border radius',
        (tester) async {
      // Line 349: shape is LiquidRoundedRectangle → BorderRadius.circular(shape.borderRadius)
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextField(
              shape: LiquidRoundedRectangle(borderRadius: 20),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassTextField), findsOneWidget);
    });

    testWidgets('LiquidOval shape falls back to default border radius',
        (tester) async {
      // Line 352: fallback → BorderRadius.circular(10)
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextField(
              shape: LiquidOval(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassTextField), findsOneWidget);
    });
  });
}
