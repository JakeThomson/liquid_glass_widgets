import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/utils/glass_spring.dart';

/// Selection stability for [GlassSegmentedControl.scrollable]:
///  1. the initial selection mounts scrolled into view, with no residual
///     indicator animation (no slide-in from the track edge),
///  2. a list-length change keeps the indicator mounted through the
///     remeasure and lands it with no travel,
///  3. segments with a surviving identity keep their elements across list
///     changes instead of remounting,
///  4. [VelocitySpringBuilder.teleportEpoch] snaps discontinuous values.
void main() {
  Widget harness(Widget child) => MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 300, child: child)),
        ),
      );

  List<GlassSegment> segments(int n, {String prefix = 'S'}) =>
      [for (var i = 0; i < n; i++) GlassSegment(label: '$prefix$i')];

  testWidgets('initial selection is in view with no residual animation',
      (tester) async {
    final ctl = ScrollController();
    addTearDown(ctl.dispose);
    await tester.pumpWidget(harness(GlassSegmentedControl.scrollable(
      segments: segments(30),
      selectedIndex: 20,
      onSegmentSelected: (_) {},
      scrollController: ctl,
    )));
    // Frame 2: post-frame measurement has run and snapped everything.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(ctl.offset, greaterThan(0),
        reason: 'selection 20 of 30 cannot be visible at offset 0');
    expect(find.text('S20').hitTestable(), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0,
        reason: 'nothing may still be animating after the mount snap');
  });

  testWidgets('length change keeps the indicator and lands without travel',
      (tester) async {
    final ctl = ScrollController();
    addTearDown(ctl.dispose);
    Widget build(int n) => harness(GlassSegmentedControl.scrollable(
          segments: segments(n),
          selectedIndex: 5,
          onSegmentSelected: (_) {},
          scrollController: ctl,
        ));
    await tester.pumpWidget(build(10));
    await tester.pumpAndSettle();

    bool indicatorShown() => find
        .byWidgetPredicate(
            (w) => w.runtimeType.toString() == 'AnimatedGlassIndicator')
        .evaluate()
        .isNotEmpty;
    expect(indicatorShown(), isTrue);

    await tester.pumpWidget(build(20));
    // The remeasure gap: indicator must survive it.
    expect(indicatorShown(), isTrue,
        reason: 'indicator blinked out during the remeasure gap');
    await tester.pump();
    expect(indicatorShown(), isTrue);
    await tester.pump(const Duration(milliseconds: 32));
    expect(tester.binding.transientCallbackCount, 0,
        reason: 'the indicator must snap to the new geometry, not travel');
  });

  testWidgets('surviving identities keep their elements across list changes',
      (tester) async {
    Widget build(List<String> labels) => harness(
          GlassSegmentedControl.scrollable(
            segments: [for (final l in labels) GlassSegment(label: l)],
            selectedIndex: 0,
            onSegmentSelected: (_) {},
          ),
        );
    await tester.pumpWidget(build(['A', 'B', 'C']));
    await tester.pumpAndSettle();
    final before = tester.element(find.text('B'));
    await tester.pumpWidget(build(['A0', 'A', 'B', 'C', 'D']));
    await tester.pumpAndSettle();
    expect(identical(before, tester.element(find.text('B'))), isTrue,
        reason: "segment 'B' survived the change and must keep its element");
  });

  testWidgets('teleportEpoch snaps; unchanged epoch animates', (tester) async {
    double seen = -1;
    Widget build(double value, int epoch) => MaterialApp(
          home: VelocitySpringBuilder(
            value: value,
            teleportEpoch: epoch,
            springWhenActive: GlassSpring.interactive(),
            springWhenReleased:
                GlassSpring.snappy(duration: const Duration(milliseconds: 350)),
            active: false,
            builder: (context, v, _, __) {
              seen = v;
              return const SizedBox();
            },
          ),
        );
    await tester.pumpWidget(build(0, 0));
    expect(seen, 0);
    // Epoch bump: lands instantly, nothing left animating.
    await tester.pumpWidget(build(100, 1));
    await tester.pump();
    expect(seen, 100);
    expect(tester.binding.transientCallbackCount, 0);
    // Same epoch: animates through intermediate values.
    await tester.pumpWidget(build(200, 1));
    await tester.pump(const Duration(milliseconds: 40));
    expect(seen, greaterThan(100));
    expect(seen, lessThan(200), reason: 'must travel, not snap');
    await tester.pumpAndSettle();
    expect(seen, moreOrLessEquals(200, epsilon: 0.5));
  });
}
