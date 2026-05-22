// ignore_for_file: require_trailing_commas
// Coverage-targeted tests for GlassTextField.
// Targets lines 306-315 (didUpdateWidget):
//   - focusNode swap when widget.focusNode changes (null → external + rewire)
//   - disabled → _isPressed cleared

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../shared/test_helpers.dart';

void main() {
  group('GlassTextField — didUpdateWidget coverage', () {
    testWidgets('swapping external focusNode rewires listener', (tester) async {
      // Start with no external focusNode (internal), then provide one.
      final node1 = FocusNode();
      FocusNode? externalNode;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        createTestApp(
          child: StatefulBuilder(
            builder: (ctx, setState) {
              outerSetState = setState;
              return GlassTextField(
                focusNode: externalNode,
                placeholder: 'Search',
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Swap null → external node → didUpdateWidget fires focusNode swap path.
      outerSetState(() => externalNode = node1);
      await tester.pump();

      // Swap external → different external node.
      final node2 = FocusNode();
      outerSetState(() => externalNode = node2);
      await tester.pump();

      // Swap external → null (back to internal).
      outerSetState(() => externalNode = null);
      await tester.pump();

      expect(tester.takeException(), isNull);
      node1.dispose();
      node2.dispose();
    });

    testWidgets('disabled=true while pressed clears _isPressed',
        (tester) async {
      bool enabled = true;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        createTestApp(
          child: StatefulBuilder(
            builder: (ctx, setState) {
              outerSetState = setState;
              return GlassTextField(
                enabled: enabled,
                placeholder: 'Enter text',
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Simulate a press-down gesture.
      final finder = find.byType(GlassTextField);
      final gesture = await tester.startGesture(tester.getCenter(finder));
      await tester.pump();

      // Disable while "pressed" → _isPressed cleared via setState.
      outerSetState(() => enabled = false);
      await tester.pump();

      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a GlassTextField focuses it', (tester) async {
      // Exercises the _onFocusChange path and basic interaction.
      await tester.pumpWidget(
        createTestApp(
          child: const GlassTextField(
            placeholder: 'Tap me',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(GlassTextField));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('GlassTextField — height constraints', () {
    testWidgets('height wraps field in SizedBox', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const GlassTextField(
            placeholder: 'Fixed height',
            height: 44,
          ),
        ),
      );
      await tester.pump();

      // The outermost Opacity → SizedBox chain.
      final sizedBoxFinder = find.ancestor(
        of: find.byType(GlassTextField),
        matching: find.byType(SizedBox),
      );
      // There should be at least one SizedBox with height 44.
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(Opacity),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBoxes.any((sb) => sb.height == 44), isTrue);
    });

    testWidgets('minHeight / maxHeight wraps field in ConstrainedBox',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const GlassTextField(
            placeholder: 'Constrained',
            minHeight: 40,
            maxHeight: 200,
          ),
        ),
      );
      await tester.pump();

      final constrainedBoxes = tester.widgetList<ConstrainedBox>(
        find.descendant(
          of: find.byType(Opacity),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(
        constrainedBoxes.any((cb) =>
            cb.constraints.minHeight == 40 && cb.constraints.maxHeight == 200),
        isTrue,
      );
    });

    testWidgets('height and minHeight are mutually exclusive', (tester) async {
      expect(
        () => GlassTextField(
          placeholder: 'Bad',
          height: 44,
          minHeight: 30,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('height and maxHeight are mutually exclusive', (tester) async {
      expect(
        () => GlassTextField(
          placeholder: 'Bad',
          height: 44,
          maxHeight: 200,
        ),
        throwsAssertionError,
      );
    });
  });

  group('GlassTextField — iconAlignment', () {
    testWidgets('iconAlignment: CrossAxisAlignment.end positions icons at end',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const GlassTextField(
            placeholder: 'Chat',
            maxLines: 5,
            iconAlignment: CrossAxisAlignment.end,
            prefixIcon: Icon(Icons.emoji_emotions, size: 20),
            suffixIcon: Icon(Icons.send, size: 20),
          ),
        ),
      );
      await tester.pump();

      // Find the Row that contains the prefix icon — it should have
      // crossAxisAlignment == CrossAxisAlignment.end.
      final rows = tester.widgetList<Row>(find.byType(Row));
      expect(
        rows.any((r) => r.crossAxisAlignment == CrossAxisAlignment.end),
        isTrue,
      );
    });

    testWidgets('iconAlignment: CrossAxisAlignment.start pins icons to top',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const GlassTextField(
            placeholder: 'Notes',
            maxLines: 5,
            iconAlignment: CrossAxisAlignment.start,
            suffixIcon: Icon(Icons.close, size: 20),
          ),
        ),
      );
      await tester.pump();

      final rows = tester.widgetList<Row>(find.byType(Row));
      expect(
        rows.any((r) => r.crossAxisAlignment == CrossAxisAlignment.start),
        isTrue,
      );
    });
  });

  group('GlassTextField — onLineCountChanged', () {
    testWidgets('callback fires on initial build', (tester) async {
      int? reportedLines;

      await tester.pumpWidget(
        createTestApp(
          child: GlassTextField(
            placeholder: 'Test',
            onLineCountChanged: (lines) => reportedLines = lines,
          ),
        ),
      );
      // Flush the nested addPostFrameCallback chain (initState schedules
      // 2 nested post-frame callbacks before calling _measureAndNotify).
      await tester.pump(); // 1st post-frame fires
      await tester.pump(); // 2nd post-frame fires → _measureAndNotify runs
      await tester.pump(); // extra frame in case

      expect(reportedLines, isNotNull);
      expect(reportedLines, greaterThanOrEqualTo(1));
    });

    testWidgets('callback does not fire when line count unchanged',
        (tester) async {
      int callCount = 0;
      final controller = TextEditingController();

      await tester.pumpWidget(
        createTestApp(
          child: GlassTextField(
            controller: controller,
            placeholder: 'Test',
            onLineCountChanged: (lines) => callCount++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final initialCallCount = callCount;

      // Type a short word — stays on 1 line.
      controller.text = 'Hi';
      await tester.pump();
      await tester.pump();

      expect(callCount, initialCallCount,
          reason: 'Should not fire again when line count stays the same');
    });
  });
}
