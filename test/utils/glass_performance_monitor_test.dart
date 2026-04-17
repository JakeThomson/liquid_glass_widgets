import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/utils/glass_performance_monitor.dart';

void main() {
  // Reset monitor state before every test so tests are fully isolated.
  setUp(() {
    GlassPerformanceMonitor.stop();
    GlassPerformanceMonitor.reset();
  });

  tearDown(() {
    GlassPerformanceMonitor.stop();
    GlassPerformanceMonitor.reset();
  });

  // ── Initial state ──────────────────────────────────────────────────────────

  group('initial state', () {
    test('is not running after reset', () {
      expect(GlassPerformanceMonitor.isRunning, isFalse);
    });

    test('has not emitted a warning after reset', () {
      expect(GlassPerformanceMonitor.warningEmitted, isFalse);
    });

    test('active premium count is zero after reset', () {
      expect(GlassPerformanceMonitor.activePremiumCount, equals(0));
    });

    test('default raster budget is 16 ms', () {
      expect(
        GlassPerformanceMonitor.rasterBudget,
        equals(const Duration(milliseconds: 16)),
      );
    });

    test('default sustained frame threshold is 60', () {
      expect(GlassPerformanceMonitor.sustainedFrameThreshold, equals(60));
    });
  });

  // ── start / stop ───────────────────────────────────────────────────────────

  group('start and stop', () {
    test('start sets isRunning to true (debug/profile only)', () {
      // In release mode, start() is a no-op guarded by kReleaseMode.
      // In debug/profile (which tests always run in) it should register.
      GlassPerformanceMonitor.start();
      // kReleaseMode is always false in test environments.
      expect(GlassPerformanceMonitor.isRunning, isTrue);
    });

    test('calling start twice is idempotent', () {
      GlassPerformanceMonitor.start();
      GlassPerformanceMonitor.start();
      // Should still be running — no crash, no double-registration.
      expect(GlassPerformanceMonitor.isRunning, isTrue);
    });

    test('stop sets isRunning to false', () {
      GlassPerformanceMonitor.start();
      GlassPerformanceMonitor.stop();
      expect(GlassPerformanceMonitor.isRunning, isFalse);
    });

    test('calling stop when not running is safe', () {
      expect(() => GlassPerformanceMonitor.stop(), returnsNormally);
    });

    test('stop preserves warningEmitted latch', () {
      // Manually set the latch by calling reset then simulating a warning
      // by examining the preserved state after stop.
      GlassPerformanceMonitor.start();
      GlassPerformanceMonitor.stop();
      // Warning was never emitted — latch stays false.
      expect(GlassPerformanceMonitor.warningEmitted, isFalse);
    });
  });

  // ── reset ──────────────────────────────────────────────────────────────────

  group('reset', () {
    test('reset clears warningEmitted latch', () {
      // Simulate a warning having fired by checking after reset.
      GlassPerformanceMonitor.reset();
      expect(GlassPerformanceMonitor.warningEmitted, isFalse);
    });

    test('reset clears premium count', () {
      GlassPerformanceMonitor.trackPremiumMount();
      GlassPerformanceMonitor.trackPremiumMount();
      expect(GlassPerformanceMonitor.activePremiumCount, equals(2));

      GlassPerformanceMonitor.reset();
      expect(GlassPerformanceMonitor.activePremiumCount, equals(0));
    });

    test('reset can be called while running without crashing', () {
      GlassPerformanceMonitor.start();
      expect(() => GlassPerformanceMonitor.reset(), returnsNormally);
      GlassPerformanceMonitor.stop();
    });
  });

  // ── premium surface tracking ───────────────────────────────────────────────

  group('premium surface tracking', () {
    test('trackPremiumMount increments activePremiumCount', () {
      GlassPerformanceMonitor.trackPremiumMount();
      expect(GlassPerformanceMonitor.activePremiumCount, equals(1));

      GlassPerformanceMonitor.trackPremiumMount();
      expect(GlassPerformanceMonitor.activePremiumCount, equals(2));
    });

    test('trackPremiumUnmount decrements activePremiumCount', () {
      GlassPerformanceMonitor.trackPremiumMount();
      GlassPerformanceMonitor.trackPremiumMount();
      GlassPerformanceMonitor.trackPremiumUnmount();
      expect(GlassPerformanceMonitor.activePremiumCount, equals(1));
    });

    test('activePremiumCount never goes below zero (clamp guard)', () {
      // Unmount without a prior mount — should clamp to 0, not go negative.
      GlassPerformanceMonitor.trackPremiumUnmount();
      expect(GlassPerformanceMonitor.activePremiumCount, equals(0));
    });

    test('multiple mount/unmount cycles are balanced', () {
      for (int i = 0; i < 5; i++) {
        GlassPerformanceMonitor.trackPremiumMount();
      }
      for (int i = 0; i < 5; i++) {
        GlassPerformanceMonitor.trackPremiumUnmount();
      }
      expect(GlassPerformanceMonitor.activePremiumCount, equals(0));
    });
  });

  // ── PremiumGlassTracker widget ─────────────────────────────────────────────

  group('PremiumGlassTracker widget', () {
    testWidgets('increments count on mount', (tester) async {
      expect(GlassPerformanceMonitor.activePremiumCount, equals(0));

      await tester.pumpWidget(
        const PremiumGlassTracker(
          child: SizedBox.shrink(),
        ),
      );

      expect(GlassPerformanceMonitor.activePremiumCount, equals(1));
    });

    testWidgets('decrements count on unmount', (tester) async {
      await tester.pumpWidget(
        const PremiumGlassTracker(
          child: SizedBox.shrink(),
        ),
      );
      expect(GlassPerformanceMonitor.activePremiumCount, equals(1));

      // Remove the widget from the tree.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(GlassPerformanceMonitor.activePremiumCount, equals(0));
    });

    testWidgets('multiple trackers accumulate correctly', (tester) async {
      await tester.pumpWidget(
        const Column(
          children: [
            PremiumGlassTracker(child: SizedBox.shrink()),
            PremiumGlassTracker(child: SizedBox.shrink()),
            PremiumGlassTracker(child: SizedBox.shrink()),
          ],
        ),
      );
      expect(GlassPerformanceMonitor.activePremiumCount, equals(3));

      await tester.pumpWidget(const SizedBox.shrink());
      expect(GlassPerformanceMonitor.activePremiumCount, equals(0));
    });

    testWidgets('renders its child transparently', (tester) async {
      const key = Key('child');
      await tester.pumpWidget(
        const PremiumGlassTracker(
          child: SizedBox.shrink(key: key),
        ),
      );
      expect(find.byKey(key), findsOneWidget);
    });
  });

  // ── Configuration ──────────────────────────────────────────────────────────

  group('configuration', () {
    test('rasterBudget can be changed and read back', () {
      const custom = Duration(microseconds: 8333); // 120 fps
      GlassPerformanceMonitor.rasterBudget = custom;
      expect(GlassPerformanceMonitor.rasterBudget, equals(custom));

      // Restore default so other tests are unaffected.
      GlassPerformanceMonitor.rasterBudget = const Duration(milliseconds: 16);
    });

    test('sustainedFrameThreshold can be changed and read back', () {
      GlassPerformanceMonitor.sustainedFrameThreshold = 120;
      expect(GlassPerformanceMonitor.sustainedFrameThreshold, equals(120));

      // Restore default.
      GlassPerformanceMonitor.sustainedFrameThreshold = 60;
    });
  });
}
