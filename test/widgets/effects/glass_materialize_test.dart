import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/src/renderer/internal/glass_materialize_scope.dart';
import 'package:liquid_glass_widgets/widgets/effects/shared/glass_materialize_effect.dart';

/// Resolves the settings a glass surface below [child] would render with.
Future<LiquidGlassSettings> _resolvedSettings(
  WidgetTester tester,
  Widget Function(Widget probe) build,
) async {
  late LiquidGlassSettings resolved;
  await tester.pumpWidget(
    CupertinoApp(
      home: build(
        Builder(
          builder: (context) {
            resolved = GlassMaterializeScope.resolveSettings(
              context,
              const LiquidGlassSettings(blur: 5, thickness: 20),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return resolved;
}

void main() {
  group('settings transform', () {
    const base = LiquidGlassSettings(blur: 5, thickness: 20);

    /// The settings a glass surface actually resolves under a scope at [t].
    Future<LiquidGlassSettings> at(
      WidgetTester tester,
      double t, {
      double blobSigma = 12.0,
      LiquidGlassSettings settings = base,
    }) async {
      late LiquidGlassSettings resolved;
      await tester.pumpWidget(
        CupertinoApp(
          home: GlassMaterializeScope(
            glassProgress: t,
            contentOpacity: t,
            contentSigma: 0,
            blobSigma: blobSigma,
            child: Builder(
              builder: (context) {
                resolved =
                    GlassMaterializeScope.resolveSettings(context, settings);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return resolved;
    }

    testWidgets('at rest the very same instance comes back', (tester) async {
      // Identity matters beyond cost: a new instance every frame would defeat
      // the render object's settings equality check and repaint resting glass.
      expect(identical(await at(tester, 1.0), base), isTrue);
    });

    testWidgets('fully dematerialized glass skips its render pass',
        (tester) async {
      final settings = await at(tester, 0.0);
      // The render object early-outs on exactly this condition.
      expect(settings.effectiveThickness, 0.0);
      expect(settings.effectiveBlur, 0.0);
    });

    testWidgets('the blob is frostier mid-transition than the settled glass',
        (tester) async {
      final mid = await at(tester, 0.5);
      expect(mid.blur, greaterThan(base.blur));
      expect(mid.effectiveBlur, greaterThan(base.blur * 0.5));
    });

    testWidgets('a heavily frosted surface never sharpens on the way out',
        (tester) async {
      // A blobSigma below the configured blur must not pull it down.
      final mid = await at(tester, 0.5, blobSigma: 2.0);
      expect(mid.blur, base.blur);
    });

    testWidgets('widget-level decorations fade with the glass', (tester) async {
      const decorated = LiquidGlassSettings(
        blur: 5,
        shadowElevation: 1.0,
        whitenStrength: 0.4,
        backerColor: Color(0x59000000),
      );
      final half = await at(tester, 0.5, settings: decorated);
      expect(half.shadowElevation, closeTo(0.5, 1e-9));
      expect(half.whitenStrength, closeTo(0.2, 1e-9));
      expect(
        half.backerColor!.a,
        closeTo(decorated.backerColor!.a * 0.5, 1e-6),
      );
    });
  });

  group('scope plumbing', () {
    testWidgets('a running effect scales the visibility a surface sees',
        (tester) async {
      final settings = await _resolvedSettings(
        tester,
        (probe) => GlassMaterializeScope(
          glassProgress: 0.5,
          contentOpacity: 0.5,
          contentSigma: 4,
          blobSigma: 12,
          child: probe,
        ),
      );
      expect(settings.visibility, closeTo(0.5, 1e-9));
    });

    testWidgets('no scope leaves settings untouched', (tester) async {
      final settings = await _resolvedSettings(tester, (probe) => probe);
      expect(settings.visibility, 1.0);
      expect(settings.blur, 5);
    });
  });

  group('choreography', () {
    testWidgets('an entrance resolves the glass before the content',
        (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: GlassMaterializeEffect(
            progress: 0.35,
            profile: GlassMaterializeProfile.entrance,
            child: SizedBox.shrink(),
          ),
        ),
      );
      final scope = tester.widget<GlassMaterializeScope>(
        find.byType(GlassMaterializeScope),
      );
      expect(scope.glassProgress, greaterThan(scope.contentOpacity));
    });

    testWidgets('an exit empties the content before the glass dissolves',
        (tester) async {
      // Late in the exit axis (low progress) the content must already be gone
      // while the shell is still visible — the briefly empty circle.
      await tester.pumpWidget(
        const CupertinoApp(
          home: GlassMaterializeEffect(
            progress: 0.3,
            profile: GlassMaterializeProfile.exit,
            child: SizedBox.shrink(),
          ),
        ),
      );
      final scope = tester.widget<GlassMaterializeScope>(
        find.byType(GlassMaterializeScope),
      );
      expect(scope.contentOpacity, 0.0);
      expect(scope.glassProgress, greaterThan(0.0));
    });

    testWidgets('the glass emerges gradually instead of popping in',
        (tester) async {
      // Regression: an ease-out alone has a slope of 3 at zero, which put the
      // glass a fifth of the way present on the first frame of the window —
      // it read as the surface appearing instantly and then drifting. The
      // first frames must be barely visible.
      const frames = 17; // the entrance window, at 60fps
      double glassAt(double phase) =>
          GlassMaterializeChoreography.entranceGlass.transform(phase);

      expect(glassAt(1 / frames), lessThan(0.05));
      expect(glassAt(2 / frames), lessThan(0.10));

      // And it must still finish: half-way through the window it is well
      // under way, and it reaches full before the window closes.
      expect(glassAt(0.5), greaterThan(0.2));
      expect(glassAt(1.0), 1.0);
    });

    testWidgets('the glass sheds its last frames gradually too',
        (tester) async {
      // The exit walks the same axis toward zero, so a bare ease-in would
      // drop the remaining glass in a single frame.
      const frames = 17;
      double glassAt(double phase) =>
          GlassMaterializeChoreography.exitGlass.transform(phase);

      expect(glassAt(1 / frames), lessThan(0.05));
      expect(glassAt(2 / frames), lessThan(0.10));
    });

    testWidgets('the tree shape is the same at rest as mid-transition',
        (tester) async {
      // A shell that remounts as a transition starts or settles pops its
      // backdrop, so the wrappers must be present at every progress.
      for (final progress in <double>[1.0, 0.5, 0.0]) {
        await tester.pumpWidget(
          CupertinoApp(
            home: GlassMaterializeEffect(
              progress: progress,
              profile: GlassMaterializeProfile.entrance,
              child: const SizedBox.shrink(),
            ),
          ),
        );
        expect(find.byType(GlassMaterializeScope), findsOneWidget);
        expect(find.byType(Transform), findsWidgets);
      }
    });

    testWidgets('at rest the effect is paint-neutral', (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: GlassMaterializeEffect(
            progress: 1.0,
            profile: GlassMaterializeProfile.entrance,
            scaleFrom: 0.85,
            child: SizedBox.shrink(),
          ),
        ),
      );
      final scope = tester.widget<GlassMaterializeScope>(
        find.byType(GlassMaterializeScope),
      );
      expect(scope.glassProgress, 1.0);
      expect(scope.contentOpacity, 1.0);
      expect(scope.contentSigma, 0.0);
    });
  });

  group('reduce motion', () {
    testWidgets('collapses to a cross-dissolve with no scale or blur',
        (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: GlassAccessibilityScope(
            reduceMotion: true,
            child: GlassMaterializeEffect(
              progress: 0.4,
              profile: GlassMaterializeProfile.entrance,
              scaleFrom: 0.85,
              contentSigma: 8,
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );
      final scope = tester.widget<GlassMaterializeScope>(
        find.byType(GlassMaterializeScope),
      );
      // Both channels track progress directly — a fade, not motion.
      expect(scope.glassProgress, closeTo(0.4, 1e-9));
      expect(scope.contentOpacity, closeTo(0.4, 1e-9));
      expect(scope.contentSigma, 0.0);
    });
  });

  group('GlassMaterialize', () {
    testWidgets('animates between hidden and shown', (tester) async {
      Widget build(bool visible) => CupertinoApp(
            home: GlassMaterialize(
              visible: visible,
              child: const SizedBox.shrink(),
            ),
          );

      await tester.pumpWidget(build(false));
      var scope = tester.widget<GlassMaterializeScope>(
        find.byType(GlassMaterializeScope),
      );
      expect(scope.glassProgress, 0.0);

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 120));
      scope = tester.widget<GlassMaterializeScope>(
        find.byType(GlassMaterializeScope),
      );
      expect(scope.glassProgress, greaterThan(0.0));
      expect(scope.glassProgress, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(find.byType(GlassMaterializeScope), findsOneWidget);
    });

    testWidgets('maintainState: false releases the subtree once hidden',
        (tester) async {
      Widget build(bool visible) => CupertinoApp(
            home: GlassMaterialize(
              visible: visible,
              maintainState: false,
              child: const Text('glass', textDirection: TextDirection.ltr),
            ),
          );

      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle();
      expect(find.text('glass'), findsOneWidget);

      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('glass'), findsOneWidget, reason: 'still dissolving');

      await tester.pumpAndSettle();
      expect(find.text('glass'), findsNothing);
    });

    testWidgets('onEnd fires when a transition settles', (tester) async {
      var ends = 0;
      Widget build(bool visible) => CupertinoApp(
            home: GlassMaterialize(
              visible: visible,
              onEnd: () => ends++,
              child: const SizedBox.shrink(),
            ),
          );

      await tester.pumpWidget(build(false));
      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle();
      expect(ends, 1);
    });
  });

  group('AnimatedSwitcher', () {
    testWidgets('switcherBuilder materializes each child', (tester) async {
      Widget build(String label) => CupertinoApp(
            home: AnimatedSwitcher(
              duration: GlassDefaults.materializeDuration,
              transitionBuilder: GlassMaterializeTransition.switcherBuilder,
              child: Text(label, key: ValueKey(label)),
            ),
          );

      await tester.pumpWidget(build('one'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build('two'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(GlassMaterializeTransition), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
    });
  });
}
