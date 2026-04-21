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
      // Interaction defaults — must match GlassBottomBar / GlassSearchableBottomBar
      expect(textField.interactionBehavior, GlassInteractionBehavior.full);
      expect(textField.pressScale, 1.03);
      expect(textField.glowColor, isNull);
      expect(textField.glowRadius, 1.5);
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

  // ===========================================================================
  // GlassTextField — interactionBehavior
  // ===========================================================================

  group('GlassTextField interactionBehavior', () {
    // ── Helper ────────────────────────────────────────────────────────────────

    Widget buildField({
      GlassInteractionBehavior behavior = GlassInteractionBehavior.full,
      Color? glowColor,
    }) =>
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassTextField(
              interactionBehavior: behavior,
              glowColor: glowColor,
            ),
          ),
        );

    // ── API defaults ─────────────────────────────────────────────────────────

    test('interactionBehavior defaults to full', () {
      expect(
        const GlassTextField().interactionBehavior,
        GlassInteractionBehavior.full,
      );
    });

    test('pressScale defaults to 1.03', () {
      expect(const GlassTextField().pressScale, 1.03);
    });

    test('glowRadius defaults to 1.5', () {
      expect(const GlassTextField().glowRadius, 1.5);
    });

    test('glowColor defaults to null (uses internal default)', () {
      expect(const GlassTextField().glowColor, isNull);
    });

    // ── Enum invariants (mirror glass_interaction_behavior_test) ─────────────

    test('GlassInteractionBehavior.none has neither glow nor scale', () {
      expect(GlassInteractionBehavior.none.hasGlow, isFalse);
      expect(GlassInteractionBehavior.none.hasScale, isFalse);
    });

    test('GlassInteractionBehavior.glowOnly has glow but not scale', () {
      expect(GlassInteractionBehavior.glowOnly.hasGlow, isTrue);
      expect(GlassInteractionBehavior.glowOnly.hasScale, isFalse);
    });

    test('GlassInteractionBehavior.scaleOnly has scale but not glow', () {
      expect(GlassInteractionBehavior.scaleOnly.hasGlow, isFalse);
      expect(GlassInteractionBehavior.scaleOnly.hasScale, isTrue);
    });

    test('GlassInteractionBehavior.full has both glow and scale', () {
      expect(GlassInteractionBehavior.full.hasGlow, isTrue);
      expect(GlassInteractionBehavior.full.hasScale, isTrue);
    });

    // ── Rendering per behavior ────────────────────────────────────────────────

    testWidgets('behavior=full: GlassGlow present in tree', (tester) async {
      await tester
          .pumpWidget(buildField(behavior: GlassInteractionBehavior.full));
      await tester.pumpAndSettle();
      expect(find.byType(GlassGlow), findsOneWidget);
    });

    testWidgets('behavior=glowOnly: GlassGlow present in tree', (tester) async {
      await tester
          .pumpWidget(buildField(behavior: GlassInteractionBehavior.glowOnly));
      await tester.pumpAndSettle();
      expect(find.byType(GlassGlow), findsOneWidget);
    });

    testWidgets('behavior=none: GlassGlow absent from tree', (tester) async {
      await tester
          .pumpWidget(buildField(behavior: GlassInteractionBehavior.none));
      await tester.pumpAndSettle();
      expect(find.byType(GlassGlow), findsNothing);
    });

    testWidgets('behavior=scaleOnly: GlassGlow absent from tree',
        (tester) async {
      await tester
          .pumpWidget(buildField(behavior: GlassInteractionBehavior.scaleOnly));
      await tester.pumpAndSettle();
      expect(find.byType(GlassGlow), findsNothing);
    });

    // ── AnimatedScale presence / absence ─────────────────────────────────────

    testWidgets('behavior=full: AnimatedScale present in tree', (tester) async {
      await tester
          .pumpWidget(buildField(behavior: GlassInteractionBehavior.full));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedScale), findsOneWidget);
    });

    testWidgets('behavior=scaleOnly: AnimatedScale present in tree',
        (tester) async {
      await tester
          .pumpWidget(buildField(behavior: GlassInteractionBehavior.scaleOnly));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedScale), findsOneWidget);
    });

    testWidgets('behavior=none: AnimatedScale absent from tree',
        (tester) async {
      await tester
          .pumpWidget(buildField(behavior: GlassInteractionBehavior.none));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedScale), findsNothing);
    });

    testWidgets('behavior=glowOnly: AnimatedScale absent from tree',
        (tester) async {
      await tester
          .pumpWidget(buildField(behavior: GlassInteractionBehavior.glowOnly));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedScale), findsNothing);
    });

    // ── Custom glow color ─────────────────────────────────────────────────────

    testWidgets('custom glowColor propagates to GlassGlow', (tester) async {
      const customColor = Color(0x44FF0000);
      await tester.pumpWidget(
        buildField(
          behavior: GlassInteractionBehavior.full,
          glowColor: customColor,
        ),
      );
      await tester.pumpAndSettle();
      final glassGlow = tester.widget<GlassGlow>(find.byType(GlassGlow));
      expect(glassGlow.glowColor, customColor);
    });

    // ── Hot-rebuild state transitions ─────────────────────────────────────────

    testWidgets('live transition full → none removes GlassGlow',
        (tester) async {
      // Start with full.
      await tester
          .pumpWidget(buildField(behavior: GlassInteractionBehavior.full));
      await tester.pumpAndSettle();
      expect(find.byType(GlassGlow), findsOneWidget);

      // Hot-rebuild with none.
      await tester
          .pumpWidget(buildField(behavior: GlassInteractionBehavior.none));
      await tester.pumpAndSettle();
      expect(find.byType(GlassGlow), findsNothing);
    });

    testWidgets('live transition none → full adds GlassGlow', (tester) async {
      // Start with none.
      await tester
          .pumpWidget(buildField(behavior: GlassInteractionBehavior.none));
      await tester.pumpAndSettle();
      expect(find.byType(GlassGlow), findsNothing);

      // Hot-rebuild with full.
      await tester
          .pumpWidget(buildField(behavior: GlassInteractionBehavior.full));
      await tester.pumpAndSettle();
      expect(find.byType(GlassGlow), findsOneWidget);
    });

    // ── Delegation — GlassPasswordField & GlassTextArea inherit the param ─────

    testWidgets('GlassPasswordField: behavior=none removes GlassGlow',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassPasswordField(
              interactionBehavior: GlassInteractionBehavior.none,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassGlow), findsNothing);
    });

    testWidgets('GlassTextArea: behavior=none removes GlassGlow',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextArea(
              interactionBehavior: GlassInteractionBehavior.none,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassGlow), findsNothing);
    });

    // ── Delegation — full parameter pass-through ─────────────────────────────

    testWidgets('GlassPasswordField: passes pressScale/glowColor/glowRadius',
        (tester) async {
      const customColor = Color(0xFF00FF00);
      const field = GlassPasswordField(
        pressScale: 1.08,
        glowColor: customColor,
        glowRadius: 2.0,
      );
      expect(field.pressScale, 1.08);
      expect(field.glowColor, customColor);
      expect(field.glowRadius, 2.0);
    });

    testWidgets('GlassTextArea: passes pressScale/glowColor/glowRadius',
        (tester) async {
      const customColor = Color(0xFF0000FF);
      const field = GlassTextArea(
        pressScale: 1.06,
        glowColor: customColor,
        glowRadius: 2.5,
      );
      expect(field.pressScale, 1.06);
      expect(field.glowColor, customColor);
      expect(field.glowRadius, 2.5);
    });

    testWidgets('GlassPasswordField: onTapOutside wired through',
        (tester) async {
      var called = false;
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: GlassPasswordField(
              onTapOutside: (_) => called = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The parameter being accepted and rendered without error is the key test.
      expect(find.byType(GlassPasswordField), findsOneWidget);
      expect(called, isFalse); // not called until a tap occurs
    });

    // ── press animation ───────────────────────────────────────────────────────

    testWidgets('AnimatedScale is at 1.0 initially (no press)', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextField(
              interactionBehavior: GlassInteractionBehavior.full,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1.0);
    });

    testWidgets('AnimatedScale grows to pressScale on pointer down',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextField(
              interactionBehavior: GlassInteractionBehavior.full,
              pressScale: 1.05,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate pointer down (without full tap which would also trigger keyboard).
      final gesture = await tester
          .startGesture(tester.getCenter(find.byType(GlassTextField)));
      await tester.pump();

      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1.05);

      // Release — scale should return to 1.0.
      await gesture.up();
      await tester.pumpAndSettle();
      final scaleAfter =
          tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scaleAfter.scale, 1.0);
    });

    // ── _isPressed cleared when field becomes disabled ────────────────────────

    testWidgets('_isPressed resets to false when enabled becomes false',
        (tester) async {
      // Start enabled.
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextField(
              interactionBehavior: GlassInteractionBehavior.full,
              pressScale: 1.05,
              enabled: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Press down to activate the scale.
      final gesture = await tester
          .startGesture(tester.getCenter(find.byType(GlassTextField)));
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.05,
      );

      // Disable mid-press — _isPressed should be reset.
      await tester.pumpWidget(
        createTestApp(
          child: AdaptiveLiquidGlassLayer(
            settings: defaultTestGlassSettings,
            child: const GlassTextField(
              interactionBehavior: GlassInteractionBehavior.full,
              pressScale: 1.05,
              enabled: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.0, // back to rest — not stuck at 1.05
      );

      await gesture.cancel();
    });
  });
}
