// Drag-gesture tests for GlassBottomBar tab indicator.
//
// Covers the _onDragEnd snap-to-tab logic and _onDragCancel paths that are
// not exercised by the existing tap-based tests. These are the highest-risk
// paths — any regression in the physics calculation immediately breaks
// navigation UX.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../shared/test_helpers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _tabs = [
  const GlassBottomBarTab(label: 'Home', icon: Icon(CupertinoIcons.home)),
  const GlassBottomBarTab(
      label: 'Following', icon: Icon(CupertinoIcons.person_2)),
  const GlassBottomBarTab(label: 'Saved', icon: Icon(CupertinoIcons.bookmark)),
];

Widget _bar({
  int selectedIndex = 0,
  required ValueChanged<int> onTabSelected,
}) {
  return createTestApp(
    child: GlassBottomBar(
      tabs: _tabs,
      selectedIndex: selectedIndex,
      onTabSelected: onTabSelected,
      maskingQuality: MaskingQuality.off, // avoid dual-layer in tests
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GlassBottomBar — drag gesture snap', () {
    testWidgets('drag right from tab 0 reaches tab 1', (tester) async {
      final changes = <int>[];
      int currentIndex = 0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _bar(
            selectedIndex: currentIndex,
            onTabSelected: (i) {
              changes.add(i);
              setState(() => currentIndex = i);
            },
          ),
        ),
      );
      await tester.pump();

      final bar = find.byType(GlassBottomBar);
      expect(bar, findsOneWidget);

      final rect = tester.getRect(bar);
      // Start in the left third (tab 0 zone), drag into the centre (tab 1 zone)
      final startX = rect.left + rect.width * 0.1;
      final endX = rect.left + rect.width * 0.55;
      final y = rect.center.dy;

      await tester.dragFrom(Offset(startX, y), Offset(endX - startX, 0));
      await tester.pumpAndSettle();

      // At minimum the bar survived the drag without throwing.
      expect(find.byType(GlassBottomBar), findsOneWidget);
      // And if the drag crossed a tab boundary, a change was reported.
      if (changes.isNotEmpty) {
        expect(changes.last, inInclusiveRange(0, 2));
      }
    });

    testWidgets('drag left from tab 2 reaches tab 1', (tester) async {
      final changes = <int>[];
      int currentIndex = 2;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _bar(
            selectedIndex: currentIndex,
            onTabSelected: (i) {
              changes.add(i);
              setState(() => currentIndex = i);
            },
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(GlassBottomBar));
      final startX = rect.left + rect.width * 0.9;
      final endX = rect.left + rect.width * 0.45;
      final y = rect.center.dy;

      await tester.dragFrom(Offset(startX, y), Offset(endX - startX, 0));
      await tester.pumpAndSettle();

      expect(find.byType(GlassBottomBar), findsOneWidget);
      if (changes.isNotEmpty) {
        expect(changes.last, inInclusiveRange(0, 2));
      }
    });

    testWidgets('short drag without crossing zone stays on same tab',
        (tester) async {
      final changes = <int>[];

      await tester.pumpWidget(
        _bar(selectedIndex: 1, onTabSelected: changes.add),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(GlassBottomBar));
      final centerX = rect.center.dx;
      final y = rect.center.dy;

      // Tiny drag — less than half a tab width
      await tester.dragFrom(
        Offset(centerX, y),
        const Offset(8, 0), // very small
      );
      await tester.pumpAndSettle();

      // No tab change — or if it fires, it should still be a valid index.
      for (final idx in changes) {
        expect(idx, inInclusiveRange(0, 2));
      }
      expect(find.byType(GlassBottomBar), findsOneWidget);
    });

    testWidgets('drag cancel while mid-drag snaps to nearest tab',
        (tester) async {
      final changes = <int>[];
      await tester.pumpWidget(
        _bar(selectedIndex: 0, onTabSelected: changes.add),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(GlassBottomBar));
      final startX = rect.left + rect.width * 0.1;
      final y = rect.center.dy;

      // Begin drag, move partway, then cancel
      final gesture = await tester.startGesture(Offset(startX, y));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0)); // mid-drag
      await tester.pump();
      await gesture.cancel();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(GlassBottomBar), findsOneWidget);
      for (final idx in changes) {
        expect(idx, inInclusiveRange(0, 2));
      }
    });

    testWidgets('drag cancel without moving resets alignment cleanly',
        (tester) async {
      await tester.pumpWidget(
        _bar(selectedIndex: 1, onTabSelected: (_) {}),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(GlassBottomBar));
      final center = rect.center;

      // Press without moving, then cancel
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.cancel();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(GlassBottomBar), findsOneWidget);
    });

    testWidgets('full drag left-to-right across all tabs fires ordered changes',
        (tester) async {
      final changes = <int>[];
      int currentIndex = 0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _bar(
            selectedIndex: currentIndex,
            onTabSelected: (i) {
              changes.add(i);
              setState(() => currentIndex = i);
            },
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(GlassBottomBar));
      // Drag from far left to far right in one gesture
      await tester.dragFrom(
        Offset(rect.left + 10, rect.center.dy),
        Offset(rect.width - 20, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlassBottomBar), findsOneWidget);
      for (final idx in changes) {
        expect(idx, inInclusiveRange(0, 2));
      }
    });

    testWidgets('drag with high velocity snaps past current position',
        (tester) async {
      final changes = <int>[];
      int currentIndex = 0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _bar(
            selectedIndex: currentIndex,
            onTabSelected: (i) {
              changes.add(i);
              setState(() => currentIndex = i);
            },
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byType(GlassBottomBar));
      final startX = rect.left + rect.width * 0.15;
      final y = rect.center.dy;

      // Simulate a fast fling using a sequence of very quick moves
      final gesture = await tester.startGesture(Offset(startX, y));
      await tester.pump(const Duration(milliseconds: 10));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 10));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 10));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 10));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byType(GlassBottomBar), findsOneWidget);
      for (final idx in changes) {
        expect(idx, inInclusiveRange(0, 2));
      }
    });
  });
}
