import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart' show ScrollController;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

GlassTabBarScrollSample _sample(
  double pixels, {
  ScrollDirection direction = ScrollDirection.reverse,
  double min = 0,
  double max = 2000,
  double viewport = 800,
  bool outOfRange = false,
}) =>
    GlassTabBarScrollSample(
      pixels: pixels,
      minScrollExtent: min,
      maxScrollExtent: max,
      viewportDimension: viewport,
      direction: direction,
      outOfRange: outOfRange,
    );

GlassTabBarMinimizeController _controller([
  GlassBarMinimizeBehavior behavior = GlassBarMinimizeBehavior.onScrollDown,
]) =>
    GlassTabBarMinimizeController(behavior: behavior);

/// Feeds a run of samples starting from [from], stepping by [step].
void _scroll(
  GlassTabBarMinimizeController c, {
  required double from,
  required double step,
  required int count,
  ScrollDirection direction = ScrollDirection.reverse,
}) {
  for (var i = 0; i <= count; i++) {
    c.handleSample(_sample(from + i * step, direction: direction));
  }
}

void main() {
  group('GlassTabBarMinimizeController — frame-rate invariance', () {
    // The regression test for the failure that got the tab bar's previous
    // scroll-collapse removed in 1.0.0 ("unreliable on 120 Hz ProMotion
    // displays"). The same physical gesture — 200 px/s for 120 ms — sampled at
    // both refresh rates must produce the same outcome, and the per-sample
    // delta is under the old 12.0 gate at BOTH rates, so this also proves the
    // old gate was not ported forward.
    for (final (label, hz) in [('60 Hz', 60.0), ('120 Hz ProMotion', 120.0)]) {
      test('a slow deliberate scroll minimizes at $label', () {
        final c = _controller();
        const velocity = 200.0; // px/s — an ordinary reading scroll
        final perSample = velocity / hz;

        expect(
          perSample,
          lessThan(12.0),
          reason: 'the removed per-sample gate would never have fired',
        );

        _scroll(c, from: 0, step: perSample, count: (hz * 0.12).round());

        expect(c.minimized, isTrue);
      });
    }

    test('a dropped frame fires at the same distance, not sooner', () {
      final smooth = _controller();
      _scroll(smooth, from: 100, step: 4, count: 4); // 100 -> 116, 16px

      final janky = _controller();
      janky.handleSample(_sample(100));
      janky.handleSample(_sample(112)); // one sample carrying three frames
      janky.handleSample(_sample(116));

      expect(smooth.minimized, isFalse);
      expect(janky.minimized, isFalse,
          reason: '16px of travel is 16px however it was sampled');

      smooth.handleSample(_sample(121));
      janky.handleSample(_sample(121));
      expect(smooth.minimized, isTrue);
      expect(janky.minimized, isTrue);
    });
  });

  group('GlassTabBarMinimizeController — direction detection', () {
    test('minimizes once accumulated travel passes the threshold', () {
      final c = _controller();
      c.handleSample(_sample(100));
      c.handleSample(_sample(115)); // 15px — under 20
      expect(c.minimized, isFalse);
      c.handleSample(_sample(122)); // 22px total
      expect(c.minimized, isTrue);
    });

    test('jitter never minimizes', () {
      final c = _controller();
      c.handleSample(_sample(100));
      for (var i = 0; i < 50; i++) {
        c.handleSample(_sample(102, direction: ScrollDirection.reverse));
        c.handleSample(_sample(100, direction: ScrollDirection.forward));
      }
      expect(c.minimized, isFalse);
    });

    test('a direction reversal zeroes the accumulator', () {
      final c = _controller();
      c.handleSample(_sample(100));
      c.handleSample(_sample(118)); // +18, just under
      c.handleSample(_sample(110, direction: ScrollDirection.forward)); // flip
      c.handleSample(_sample(128)); // +18 again from a zeroed accumulator
      expect(c.minimized, isFalse,
          reason: 'the two +18 runs must not sum across the reversal');
    });

    test('expands on upward travel past the smaller expand threshold', () {
      final c = _controller()..minimize();
      expect(c.minimized, isTrue);
      c.handleSample(_sample(500));
      c.handleSample(_sample(494, direction: ScrollDirection.forward)); // -6
      expect(c.minimized, isTrue);
      c.handleSample(_sample(486, direction: ScrollDirection.forward)); // -14
      expect(c.minimized, isFalse);
    });

    test('momentum keeps accumulating — the direction survives the lift-off',
        () {
      final c = _controller();
      c.handleSample(_sample(100));
      // Finger lifts after 8px; ballistic frames carry the rest, and
      // userScrollDirection is not reset by goBallistic.
      c.handleSample(_sample(108));
      c.handleSample(_sample(140));
      expect(c.minimized, isTrue);
    });
  });

  group('GlassTabBarMinimizeController — guards', () {
    test('a restored scroll offset does not minimize on the first sample', () {
      final c = _controller();
      c.handleSample(_sample(4000)); // PageStorage restore, nothing before it
      expect(c.minimized, isFalse);
    });

    test('idle offset changes are ignored (jumpTo, keyboard inset)', () {
      final c = _controller();
      c.handleSample(_sample(500));
      c.handleSample(_sample(800, direction: ScrollDirection.idle));
      expect(c.minimized, isFalse);
    });

    test('a teleport is ignored even with a stale non-idle direction', () {
      final c = _controller();
      c.handleSample(_sample(100));
      // animateTo across 60% of the viewport keeps direction == reverse.
      c.handleSample(_sample(580));
      expect(c.minimized, isFalse);
    });

    test('overscroll does not minimize, and the bounce back does not expand',
        () {
      final c = _controller()..minimize();
      c.handleSample(_sample(1990));
      c.handleSample(_sample(2030, outOfRange: true));
      expect(c.minimized, isTrue);
      // Bounce-back: pixels fall while the direction is still `reverse`.
      c.handleSample(_sample(2000, outOfRange: true));
      expect(c.minimized, isTrue);
    });

    test('non-scrollable content never minimizes', () {
      final c = _controller();
      c.handleSample(_sample(0, max: 20));
      c.handleSample(_sample(15, max: 20));
      expect(c.minimized, isFalse);
    });

    test('content shrinking below the scrollable floor expands a minimized bar',
        () {
      final c = _controller()..minimize();
      expect(c.minimized, isTrue);
      c.handleSample(_sample(0, max: 10));
      expect(c.minimized, isFalse);
    });

    test('reaching the top expands with no threshold', () {
      final c = _controller()..minimize();
      c.handleSample(_sample(0));
      expect(c.minimized, isFalse);
    });

    test('top overscroll counts as being at the top', () {
      final c = _controller()..minimize();
      c.handleSample(_sample(-30, outOfRange: true));
      expect(c.minimized, isFalse);
    });
  });

  group('GlassTabBarMinimizeController — behaviour', () {
    test('automatic resolves to never and decides nothing', () {
      final c = _controller(GlassBarMinimizeBehavior.automatic);
      expect(c.resolvedBehavior, GlassBarMinimizeBehavior.never);
      _scroll(c, from: 100, step: 10, count: 20);
      expect(c.minimized, isFalse);
    });

    test('never decides nothing', () {
      final c = _controller(GlassBarMinimizeBehavior.never);
      _scroll(c, from: 100, step: 10, count: 20);
      expect(c.minimized, isFalse);
    });

    test('minimize() is a no-op unless the behaviour minimizes', () {
      expect((_controller(GlassBarMinimizeBehavior.never)..minimize()).minimized,
          isFalse);
      expect((_controller()..minimize()).minimized, isTrue);
    });

    test('switching to a non-minimizing behaviour expands immediately', () {
      final c = _controller()..minimize();
      expect(c.minimized, isTrue);
      c.behavior = GlassBarMinimizeBehavior.never;
      expect(c.minimized, isFalse);
    });

    test('onScrollUp mirrors onScrollDown', () {
      final c = _controller(GlassBarMinimizeBehavior.onScrollUp);
      c.handleSample(_sample(500, direction: ScrollDirection.forward));
      c.handleSample(_sample(478, direction: ScrollDirection.forward));
      expect(c.minimized, isTrue,
          reason: 'scrolling up minimizes under onScrollUp');

      c.handleSample(_sample(492));
      expect(c.minimized, isFalse,
          reason: 'scrolling back down expands under onScrollUp');
    });

    test('onScrollUp rests at the end of the content, not the start', () {
      final c = _controller(GlassBarMinimizeBehavior.onScrollUp)..minimize();
      c.handleSample(_sample(0));
      expect(c.minimized, isTrue, reason: 'the top is not the resting edge');

      c.handleSample(_sample(2000));
      expect(c.minimized, isFalse, reason: 'the end is');
    });
  });

  group('GlassTabBarMinimizeController — notifications and lifecycle', () {
    test('notifies exactly once across a run of samples in one direction', () {
      final c = _controller();
      var notifications = 0;
      c.addListener(() => notifications++);
      _scroll(c, from: 100, step: 5, count: 20);
      expect(c.minimized, isTrue);
      expect(notifications, 1);
    });

    test('expand() on an already-expanded bar does not notify', () {
      final c = _controller();
      var notifications = 0;
      c.addListener(() => notifications++);
      c.expand();
      expect(notifications, 0);
    });

    test('dispose() while attached does not throw, and stops deciding', () {
      final c = _controller();
      c.handleSample(_sample(100));
      c.dispose();
      expect(c.minimized, isFalse);
    });

    test('attach() is idempotent on identity', () {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final c = _controller();
      addTearDown(c.dispose);
      c
        ..attach(scroll)
        ..attach(scroll);
      expect(c.scrollController, same(scroll));
    });

    test('attach() does not dispose the borrowed ScrollController', () {
      final first = ScrollController();
      addTearDown(first.dispose);
      final second = ScrollController();
      addTearDown(second.dispose);
      final c = _controller();
      addTearDown(c.dispose);

      c
        ..attach(first)
        ..attach(second);

      // Still usable — proves it was not disposed out from under the app.
      expect(() => first.hasClients, returnsNormally);
      expect(c.scrollController, same(second));
    });

    test('detach() stops observing but keeps the current state', () {
      final c = _controller()..minimize();
      c.detach();
      expect(c.minimized, isTrue);
      expect(c.scrollController, isNull);
    });
  });
}
