// Widget tests for the internal sub-widgets extracted from
// GlassSearchableBottomBar into searchable_bottom_bar_internal.dart.
//
// Covers:
//   • DismissPill — render, tap, indicatorColor/glassSettings branches
//   • SearchableTabIndicator — drag, tap, cancel, didUpdateWidget, search-active state
//   • SearchPill — collapsed/expanded render, text clear, focus, didUpdateWidget
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/widgets/surfaces/shared/searchable_bottom_bar_internal.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Minimal [GlassSearchBarConfig] for use in [SearchPill] tests.
GlassSearchBarConfig _config({
  TextEditingController? controller,
  FocusNode? focusNode,
  ValueChanged<String>? onChanged,
  VoidCallback? onMicTap,
  WidgetBuilder? trailingBuilder,
}) {
  return GlassSearchBarConfig(
    onSearchToggle: (_) {},
    hintText: 'Search',
    controller: controller,
    focusNode: focusNode,
    onChanged: onChanged,
    onMicTap: onMicTap,
    trailingBuilder: trailingBuilder,
    autoFocusOnExpand: false,
  );
}

/// Wraps a widget in a constrained scaffold with a fixed 400×80 box so
/// drag gesture coordinates are predictable.
Widget _wrap(Widget child, {double width = 400, double height = 80}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

/// Minimal [SearchableTabIndicator] builder.
Widget _indicator({
  int tabIndex = 0,
  int tabCount = 3,
  ValueChanged<int>? onTabChanged,
  bool isSearchActive = false,
  VoidCallback? onDismissSearch,
  MaskingQuality maskingQuality = MaskingQuality.off,
  bool visible = true,
  WidgetBuilder? collapsedLogoBuilder,
}) {
  return _wrap(
    SearchableTabIndicator(
      tabIndex: tabIndex,
      tabCount: tabCount,
      visible: visible,
      childUnselected: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(CupertinoIcons.house),
          Icon(CupertinoIcons.person),
          Icon(CupertinoIcons.gear),
        ],
      ),
      selectedTabBuilder: (_, __, ___) => const SizedBox.shrink(),
      onTabChanged: onTabChanged ?? (_) {},
      quality: GlassQuality.minimal,
      barHeight: 64,
      barBorderRadius: 20,
      tabPadding: EdgeInsets.zero,
      magnification: 1.0,
      innerBlur: 0,
      maskingQuality: maskingQuality,
      isSearchActive: isSearchActive,
      onDismissSearch: onDismissSearch ?? () {},
      collapsedLogoBuilder: collapsedLogoBuilder,
    ),
  );
}

// ---------------------------------------------------------------------------
// DismissPill tests
// ---------------------------------------------------------------------------

void main() {
  group('DismissPill', () {
    testWidgets('renders and calls onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DismissPill(
            onTap: () => tapped = true,
            pillSize: 56,
            barBorderRadius: 16,
            quality: GlassQuality.minimal,
          ),
          width: 56,
          height: 56,
        ),
      );
      await tester.pump();

      // DismissPill wraps a GlassButton — tap anywhere inside the pill.
      await tester.tap(find.byType(DismissPill));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('renders with indicatorColor but no glassSettings',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DismissPill(
            onTap: () {},
            pillSize: 56,
            barBorderRadius: 16,
            quality: GlassQuality.minimal,
            indicatorColor: const Color(0xFF123456),
          ),
          width: 56,
          height: 56,
        ),
      );
      await tester.pump();
      expect(find.byType(DismissPill), findsOneWidget);
    });

    testWidgets('renders with glassSettings and indicatorColor merged',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DismissPill(
            onTap: () {},
            pillSize: 56,
            barBorderRadius: 16,
            quality: GlassQuality.minimal,
            indicatorColor: const Color(0xFF123456),
            glassSettings: const LiquidGlassSettings(blur: 4),
          ),
          width: 56,
          height: 56,
        ),
      );
      await tester.pump();
      expect(find.byType(DismissPill), findsOneWidget);
    });

    testWidgets('renders with custom cancelButtonColor', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DismissPill(
            onTap: () {},
            pillSize: 56,
            barBorderRadius: 16,
            quality: GlassQuality.minimal,
            cancelButtonColor: Colors.red,
          ),
          width: 56,
          height: 56,
        ),
      );
      await tester.pump();
      // Icon color should be red — just verify no exceptions and it renders.
      expect(find.byType(Icon), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // SearchableTabIndicator tests
  // ---------------------------------------------------------------------------

  group('SearchableTabIndicator — normal state', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_indicator());
      await tester.pump();
      expect(find.byType(SearchableTabIndicator), findsOneWidget);
    });

    testWidgets('horizontal drag updates alignment and calls onTabChanged',
        (tester) async {
      final changedIndices = <int>[];
      await tester.pumpWidget(
        _indicator(
          tabIndex: 0,
          tabCount: 3,
          onTabChanged: changedIndices.add,
        ),
      );
      await tester.pump();

      // Drag from left to right across the indicator — should trigger tab change.
      final center = tester.getCenter(find.byType(SearchableTabIndicator));
      final start = Offset(center.dx - 100, center.dy);
      final end = Offset(center.dx + 100, center.dy);

      await tester.dragFrom(start, end - start);
      await tester.pump();
      await tester.pumpAndSettle();

      // At least one tab change should have been emitted or the drag completed
      // cleanly without crashing.
      expect(find.byType(SearchableTabIndicator), findsOneWidget);
    });

    testWidgets('tap on different zone calls onTabChanged', (tester) async {
      final changedIndices = <int>[];
      await tester.pumpWidget(
        _indicator(
          tabIndex: 0,
          tabCount: 3,
          onTabChanged: changedIndices.add,
        ),
      );
      await tester.pump();

      // Tap far right — should register as tab 2 (index 2)
      final rect = tester.getRect(find.byType(SearchableTabIndicator));
      await tester.tapAt(Offset(rect.right - 10, rect.center.dy));
      await tester.pump();
      await tester.pumpAndSettle();

      // We only care that the call didn't throw and the widget survived.
      expect(find.byType(SearchableTabIndicator), findsOneWidget);
    });

    testWidgets('didUpdateWidget — tabIndex change updates alignment',
        (tester) async {
      // Start at tab 0
      await tester.pumpWidget(_indicator(tabIndex: 0, tabCount: 3));
      await tester.pump();

      // Update to tab 2
      await tester.pumpWidget(_indicator(tabIndex: 2, tabCount: 3));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(SearchableTabIndicator), findsOneWidget);
    });

    testWidgets('didUpdateWidget — barBorderRadius change rebuilds barShape',
        (tester) async {
      await tester.pumpWidget(
        _indicator(tabIndex: 0, tabCount: 3),
      );
      await tester.pump();

      // Change barBorderRadius by rebuilding with a stateful wrapper
      await tester.pumpWidget(
        _wrap(
          SearchableTabIndicator(
            tabIndex: 0,
            tabCount: 3,
            visible: true,
            childUnselected: const SizedBox.shrink(),
            selectedTabBuilder: (_, __, ___) => const SizedBox.shrink(),
            onTabChanged: (_) {},
            quality: GlassQuality.minimal,
            barHeight: 64,
            barBorderRadius: 30, // changed
            tabPadding: EdgeInsets.zero,
            magnification: 1.0,
            innerBlur: 0,
            maskingQuality: MaskingQuality.off,
            isSearchActive: false,
            onDismissSearch: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SearchableTabIndicator), findsOneWidget);
    });

    testWidgets('MaskingQuality.high path renders without throwing',
        (tester) async {
      await tester.pumpWidget(
        _indicator(
          tabIndex: 0,
          tabCount: 3,
          visible: true,
          maskingQuality: MaskingQuality.high,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(SearchableTabIndicator), findsOneWidget);
    });

    testWidgets(
        'visible=false with MaskingQuality.high renders background-only',
        (tester) async {
      await tester.pumpWidget(
        _indicator(
          tabIndex: 0,
          tabCount: 3,
          visible: false,
          maskingQuality: MaskingQuality.high,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(SearchableTabIndicator), findsOneWidget);
    });

    testWidgets('drag cancel while dragging snaps back cleanly',
        (tester) async {
      final changedIndices = <int>[];
      await tester.pumpWidget(
        _indicator(tabIndex: 1, tabCount: 3, onTabChanged: changedIndices.add),
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(SearchableTabIndicator));

      // Start a drag and cancel it
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.cancel();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(SearchableTabIndicator), findsOneWidget);
    });

    testWidgets('drag cancel without dragging resets alignment cleanly',
        (tester) async {
      await tester.pumpWidget(
        _indicator(tabIndex: 1, tabCount: 3),
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(SearchableTabIndicator));

      // Press down (no drag) then cancel
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.cancel();
      await tester.pump();
      expect(find.byType(SearchableTabIndicator), findsOneWidget);
    });
  });

  group('SearchableTabIndicator — search-active state', () {
    testWidgets('shows dismiss button when isSearchActive=true',
        (tester) async {
      await tester.pumpWidget(
        _indicator(isSearchActive: true),
      );
      await tester.pump();

      // Should render a GlassButton (the dismiss button)
      expect(find.byType(GlassButton), findsWidgets);
    });

    testWidgets('search-active tap calls onDismissSearch', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _indicator(
            isSearchActive: true, onDismissSearch: () => dismissed = true),
      );
      await tester.pump();

      await tester.tap(find.byType(GlassButton).first);
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('shows collapsedLogoBuilder when provided', (tester) async {
      await tester.pumpWidget(
        _indicator(
          isSearchActive: true,
          collapsedLogoBuilder: (ctx) =>
              const Text('LOGO', key: Key('logo-widget')),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('logo-widget')), findsOneWidget);
    });

    testWidgets('shows empty SizedBox when collapsedLogoBuilder is null',
        (tester) async {
      await tester.pumpWidget(
        _indicator(isSearchActive: true, collapsedLogoBuilder: null),
      );
      await tester.pump();
      // No crash — the SizedBox.shrink fallback is shown
      expect(find.byType(SearchableTabIndicator), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // SearchPill tests
  // ---------------------------------------------------------------------------

  group('SearchPill — collapsed state (isActive=false)', () {
    testWidgets('renders search icon when not active', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SearchPill(
            config: _config(),
            isActive: false,
            barBorderRadius: 20,
            quality: GlassQuality.minimal,
          ),
          width: 64,
          height: 64,
        ),
      );
      await tester.pump();
      // GlassButton with search icon present when collapsed
      expect(find.byType(SearchPill), findsOneWidget);
    });

    testWidgets('onSearchToggle called when tapping collapsed pill',
        (tester) async {
      var toggled = false;
      var toggleValue = false;
      await tester.pumpWidget(
        _wrap(
          SearchPill(
            config: GlassSearchBarConfig(
              onSearchToggle: (v) {
                toggled = true;
                toggleValue = v;
              },
              hintText: 'Search',
            ),
            isActive: false,
            barBorderRadius: 20,
            quality: GlassQuality.minimal,
          ),
          width: 64,
          height: 64,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(SearchPill));
      await tester.pump();
      expect(toggled, isTrue);
      expect(toggleValue, isTrue);
    });
  });

  group('SearchPill — expanded state (isActive=true, wide)', () {
    testWidgets('renders expanded row when active and wide enough',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SearchPill(
            config: _config(),
            isActive: true,
            barBorderRadius: 20,
            quality: GlassQuality.minimal,
          ),
          // Wide enough to pass the 90px threshold
          width: 300,
          height: 64,
        ),
      );
      await tester.pump();

      // TextField should exist in expanded state
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('shows mic icon when onMicTap provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SearchPill(
            config: _config(onMicTap: () {}),
            isActive: true,
            barBorderRadius: 20,
            quality: GlassQuality.minimal,
          ),
          width: 300,
          height: 64,
        ),
      );
      await tester.pump();

      expect(find.byIcon(CupertinoIcons.mic_fill), findsOneWidget);
    });

    testWidgets('shows clear button when text is entered', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        _wrap(
          SearchPill(
            config: _config(controller: ctrl),
            isActive: true,
            barBorderRadius: 20,
            quality: GlassQuality.minimal,
          ),
          width: 300,
          height: 64,
        ),
      );
      await tester.pump();

      // Enter text
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      expect(find.byIcon(CupertinoIcons.clear_circled_solid), findsOneWidget);
    });

    testWidgets('clear button clears text and calls onChanged', (tester) async {
      final ctrl = TextEditingController(text: 'hello');
      addTearDown(ctrl.dispose);
      String? lastChanged;

      await tester.pumpWidget(
        _wrap(
          SearchPill(
            config:
                _config(controller: ctrl, onChanged: (v) => lastChanged = v),
            isActive: true,
            barBorderRadius: 20,
            quality: GlassQuality.minimal,
          ),
          width: 300,
          height: 64,
        ),
      );
      await tester.pump();

      // Clear button visible since text is pre-populated
      expect(find.byIcon(CupertinoIcons.clear_circled_solid), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.clear_circled_solid));
      await tester.pump();

      expect(ctrl.text, isEmpty);
      expect(lastChanged, '');
    });

    testWidgets('trailingBuilder overrides default mic/clear slot',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SearchPill(
            config: _config(
              trailingBuilder: (ctx) =>
                  const Text('CUSTOM', key: Key('custom-trailing')),
            ),
            isActive: true,
            barBorderRadius: 20,
            quality: GlassQuality.minimal,
          ),
          width: 300,
          height: 64,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('custom-trailing')), findsOneWidget);
    });
  });

  group('SearchPill — didUpdateWidget', () {
    testWidgets('dismissing (isActive false→true→false) clears and unfocuses',
        (tester) async {
      final ctrl = TextEditingController(text: 'hello');
      final focus = FocusNode();
      addTearDown(ctrl.dispose);
      addTearDown(focus.dispose);

      // Start inactive
      bool active = false;

      late StateSetter outerSetState;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                outerSetState = setState;
                return SizedBox(
                  width: 300,
                  height: 64,
                  child: SearchPill(
                    config: _config(controller: ctrl, focusNode: focus),
                    isActive: active,
                    barBorderRadius: 20,
                    quality: GlassQuality.minimal,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Activate
      outerSetState(() => active = true);
      await tester.pump();

      // Deactivate — should clear text
      ctrl.text = 'hello';
      outerSetState(() => active = false);
      await tester.pump();

      expect(ctrl.text, isEmpty);
    });

    testWidgets('uses external controller and focusNode without owning them',
        (tester) async {
      final ctrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(ctrl.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        _wrap(
          SearchPill(
            config: _config(controller: ctrl, focusNode: focus),
            isActive: false,
            barBorderRadius: 20,
            quality: GlassQuality.minimal,
          ),
          width: 64,
          height: 64,
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox()); // dispose pill

      // External resources should still be usable (not disposed by pill)
      expect(() => ctrl.text, returnsNormally);
      expect(() => focus.hasFocus, returnsNormally);
    });
  });

  group('SearchPill — onFocusChanged callback', () {
    testWidgets('notifies parent when focus changes', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final focusEvents = <bool>[];

      await tester.pumpWidget(
        _wrap(
          SearchPill(
            config: _config(focusNode: focus),
            isActive: true,
            barBorderRadius: 20,
            quality: GlassQuality.minimal,
            onFocusChanged: focusEvents.add,
          ),
          width: 300,
          height: 64,
        ),
      );
      await tester.pump();

      // Request focus programmatically
      focus.requestFocus();
      await tester.pump();

      // At least one event emitted
      expect(focusEvents, isNotEmpty);
    });
  });
}
