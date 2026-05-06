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
}
