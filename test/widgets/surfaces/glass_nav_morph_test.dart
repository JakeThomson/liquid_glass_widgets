// Iteration harness for the pinned capsule's morph choreography.
//
// The morph is a pure function of route progress, so the whole animation can
// be verified headless: pump a push frame by frame and read the cluster's
// interpolated width straight off its render object. Run with
// `--dart-define=GLASS_NAV_MORPH_TRACE=true` to print the per-frame trace
// while tuning against the native reference recording.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/widgets/surfaces/shared/glass_nav_pinned_host.dart';

const bool _trace = bool.fromEnvironment('GLASS_NAV_MORPH_TRACE');

void main() {
  setUp(() {
    GlassNavigationShellState.debugPinningSupported = true;
  });

  tearDown(() {
    GlassNavigationShellState.debugPinningSupported = null;
  });

  Widget shellApp(Widget home) {
    return CupertinoApp(
      builder: (context, child) => GlassNavigationShell(child: child!),
      home: home,
    );
  }

  Finder cluster() => find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_PinnedCluster',
      );

  /// The uniform gel scale currently applied to the capsule.
  ///
  /// The gel is real geometry — the cluster's box inflates — so the scale is
  /// simply its height over the resting slot height.
  double capsuleScale(WidgetTester tester) =>
      tester.getSize(cluster()).height / GlassNavPinnedMetrics.slot;

  /// Pumps a full push in fixed steps, sampling cluster width and shell
  /// scale each frame.
  Future<List<(double, double, double)>> trace(WidgetTester tester) async {
    await tester.tap(find.text('go'));
    // Two build frames before sampling: the outgoing route's registration is
    // handed over post-frame, so the very first frame still reports the
    // settled configuration.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    final samples = <(double, double, double)>[];
    const step = Duration(milliseconds: 10);
    for (var ms = 10; ms <= 600; ms += 10) {
      final w = tester.getSize(cluster()).width;
      final s = capsuleScale(tester);
      samples.add((ms / 500, w, s));
      if (_trace) {
        debugPrint('t=${ms}ms p=${ms / 500} W=$w '
            'scale=${s.toStringAsFixed(4)}');
      }
      await tester.pump(step);
    }
    return samples;
  }

  group('morph curve shape', () {
    test('springs from zero, overshoots past one, lands exactly at one', () {
      const curve = GlassNavMorphCurve.instance;
      expect(curve.transform(0.0), 0.0);
      expect(curve.transform(1.0), 1.0);
      // Overshoots the target on the way in.
      final peak = List.generate(100, (i) => curve.transform(i / 100))
          .reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(1.02), reason: 'the bounce must be visible');
      if (_trace) {
        for (var i = 0; i <= 40; i++) {
          debugPrint('t=${(i / 40).toStringAsFixed(3)} '
              'w=${curve.transform(i / 40).toStringAsFixed(4)}');
        }
      }
    });

    test('the swell pulse rises, peaks and returns to zero', () {
      expect(GlassNavPinnedMetrics.swellPulseAt(0.0), 0.0);
      expect(GlassNavPinnedMetrics.swellPulseAt(1.0), closeTo(0.0, 1e-9));
      final peak = List.generate(101,
              (i) => GlassNavPinnedMetrics.swellPulseAt(i / 100))
          .reduce((a, b) => a > b ? a : b);
      expect(peak, closeTo(GlassNavPinnedMetrics.swellAmount, 1e-6));
    });
  });

  group('capsule width over a push', () {
    testWidgets('inflates, contracts past the target, bounces and settles',
        (tester) async {
      await tester.pumpWidget(shellApp(_Screen(
        title: 'From',
        actions: [
          GlassBarItem.icon(icon: const Icon(CupertinoIcons.add), onTap: () {}),
          GlassBarItem.icon(
              icon: const Icon(CupertinoIcons.ellipsis), onTap: () {}),
        ],
        next: _Screen(
          title: 'To',
          actions: [
            GlassBarItem.icon(
                icon: const Icon(CupertinoIcons.share), onTap: () {}),
          ],
        ),
      )));
      await tester.pumpAndSettle();
      await tester.pump();

      const rest = 2 * GlassNavPinnedMetrics.slot;
      const target = GlassNavPinnedMetrics.slot;
      expect(tester.getSize(cluster()).width, rest);

      final samples = await trace(tester);
      final scales = samples.map((s) => s.$3).toList();
      // The measured box inflates with the gel; divide it out to get the
      // cluster's travelling width.
      final widths =
          [for (final s in samples) s.$2 / (s.$3 == 0 ? 1.0 : s.$3)];

      // The cluster's width walks monotonically to the target — the gel is
      // a uniform scale on top of that travel.
      for (var i = 1; i < widths.length; i++) {
        expect(widths[i], lessThanOrEqualTo(widths[i - 1] + 0.01));
      }
      expect(widths.last, closeTo(target, 0.01));

      // Gel swell: the whole shell inflates past its resting size first…
      final peak = scales.reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(1.1),
          reason: 'the pill must puff up as the morph starts');
      // …then squeezes past its final size on the bounce…
      final dip = scales.reduce((a, b) => a < b ? a : b);
      expect(dip, lessThan(0.98),
          reason: 'the pill must squeeze past its final size and relax');
      // …in that order, and lands at exactly 1.
      expect(scales.indexOf(peak), lessThan(scales.indexOf(dip)));
      expect(scales.last, 1.0);
    });

    testWidgets('a pop leads with the swell, not the settle', (tester) async {
      await tester.pumpWidget(shellApp(_Screen(
        title: 'From',
        actions: [
          GlassBarItem.icon(icon: const Icon(CupertinoIcons.add), onTap: () {}),
          GlassBarItem.icon(
              icon: const Icon(CupertinoIcons.ellipsis), onTap: () {}),
        ],
        next: _Screen(
          title: 'To',
          actions: [
            GlassBarItem.icon(
                icon: const Icon(CupertinoIcons.share), onTap: () {}),
          ],
        ),
      )));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.pump();

      // Pop from the pinned back button and trace the return morph.
      await tester.tap(find.byIcon(CupertinoIcons.back));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final scales = <double>[];
      for (var ms = 10; ms <= 600; ms += 10) {
        scales.add(capsuleScale(tester));
        await tester.pump(const Duration(milliseconds: 10));
      }

      // The pop is the same forward choreography toward the other cluster:
      // the swell must lead — its peak sits in the first half of the
      // transition — and the shell must land settled at exactly 1.
      final peak = scales.reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(1.1),
          reason: 'the pop must swell like the push does');
      expect(scales.indexOf(peak), lessThan(scales.length ~/ 2),
          reason: 'the swell must lead the pop, not trail it');
      expect(scales.last, 1.0);
      expect(
        tester.getSize(cluster()).width,
        2 * GlassNavPinnedMetrics.slot,
      );
    });

    testWidgets('the back button gels in on the first push off the root',
        (tester) async {
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: const [],
        next: const _Screen(title: 'Detail', actions: []),
      )));
      await tester.pumpAndSettle();
      await tester.pump();

      Finder back() => find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_PinnedBackButton');
      double backScale() => tester
          .widget<Transform>(find
              .descendant(of: back(), matching: find.byType(Transform))
              .first)
          .transform
          .storage[0];

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final scales = <double>[];
      for (var ms = 10; ms <= 600; ms += 10) {
        scales.add(
            find.byIcon(CupertinoIcons.back).evaluate().isEmpty
                ? 0.0
                : backScale());
        if (_trace) debugPrint('t=${ms}ms back=${scales.last}');
        await tester.pump(const Duration(milliseconds: 10));
      }

      // Waits out the swell, springs in past full size, settles at 1.
      expect(scales.first, lessThan(0.05));
      expect(scales.reduce((a, b) => a > b ? a : b), greaterThan(1.02),
          reason: 'the back button must bounce past full size on its way in');
      expect(scales.last, 1.0);
    });
  });
}

class _Screen extends StatelessWidget {
  const _Screen({required this.title, required this.actions, this.next});

  final String title;
  final List<GlassBarItem> actions;
  final Widget? next;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar.pinned(title: Text(title), actions: actions),
      body: Center(
        child: next == null
            ? const SizedBox.shrink()
            : CupertinoButton(
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(builder: (_) => next!),
                ),
                child: const Text('go'),
              ),
      ),
    );
  }
}
