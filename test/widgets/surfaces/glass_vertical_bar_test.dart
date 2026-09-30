import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/src/widgets/surfaces/tab_bar_vertical_layout.dart';
import 'package:liquid_glass_widgets/widgets/surfaces/shared/glass_nav_pinned_host.dart';

/// iPhone Duo's outer display in portrait, as the iOS 27.1 simulator reports
/// it: a zero top inset, the status bar and the 84pt strip on the right.
const _outerPortrait = Size(466, 678);
const _outerPortraitPadding = EdgeInsets.fromLTRB(0, 0, 84, 34);

void main() {
  setUp(() {
    GlassNavigationShellState.debugPinningSupported = true;
  });

  tearDown(() {
    GlassNavigationShellState.debugPinningSupported = null;
  });

  /// A widget test on iOS, the only platform that reserves a strip.
  void testDuo(String description, WidgetTesterCallback callback) =>
      testWidgets(
        description,
        callback,
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

  /// Puts the test view into a posture, restored when the test ends.
  void setScreen(
    WidgetTester tester, {
    Size size = _outerPortrait,
    EdgeInsets padding = _outerPortraitPadding,
  }) {
    const dpr = 3.0;
    tester.view
      ..devicePixelRatio = dpr
      ..physicalSize = size * dpr
      ..viewPadding = FakeViewPadding(
        left: padding.left * dpr,
        top: padding.top * dpr,
        right: padding.right * dpr,
        bottom: padding.bottom * dpr,
      )
      ..padding = FakeViewPadding(
        left: padding.left * dpr,
        top: padding.top * dpr,
        right: padding.right * dpr,
        bottom: padding.bottom * dpr,
      );
    addTearDown(tester.view.reset);
  }

  Widget shellApp(
    Widget home, {
    GlassVerticalBarBehavior behavior = GlassVerticalBarBehavior.automatic,
    GlassVerticalBarCompression compression =
        GlassVerticalBarCompression.automatic,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    return CupertinoApp(
      builder: (context, child) => Directionality(
        textDirection: textDirection,
        child: GlassNavigationShell(
          verticalBarBehavior: behavior,
          verticalBarCompression: compression,
          child: child!,
        ),
      ),
      home: home,
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump();
  }

  /// The centre of [icon] as drawn by the shell.
  Offset pinned(WidgetTester tester, IconData icon) => tester.getCenter(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(icon),
        ),
      );

  group('GlassVerticalBar.resolve', () {
    GlassVerticalBarData? resolve({
      EdgeInsets viewPadding = _outerPortraitPadding,
      Size size = _outerPortrait,
      TargetPlatform platform = TargetPlatform.iOS,
      TextDirection textDirection = TextDirection.ltr,
      GlassVerticalBarCompression compression =
          GlassVerticalBarCompression.automatic,
    }) =>
        GlassVerticalBar.resolve(
          viewPadding: viewPadding,
          size: size,
          platform: platform,
          textDirection: textDirection,
          compression: compression,
        );

    test('finds the strip on the side with the only lateral inset', () {
      final bar = resolve()!;
      expect(bar.edge, GlassVerticalBarEdge.trailing);
      expect(bar.width, 84);
      expect(bar.top, 170);
      expect(bar.bottom, 24);
      expect(bar.collapsesTabBar, isFalse);
    });

    test('keeps the physical side under RTL, where it is the leading edge', () {
      expect(
        resolve(textDirection: TextDirection.rtl)!.edge,
        GlassVerticalBarEdge.leading,
      );
    });

    test('is null with a top inset: inner portrait keeps horizontal bars', () {
      expect(
        resolve(
          viewPadding: const EdgeInsets.fromLTRB(0, 82, 0, 34),
          size: const Size(669, 951),
        ),
        isNull,
      );
    });

    test('is null for a regular iPhone in landscape, inset on both sides', () {
      expect(
        resolve(
          viewPadding: const EdgeInsets.fromLTRB(62, 0, 62, 20),
          size: const Size(874, 402),
        ),
        isNull,
      );
    });

    test('is null off iOS', () {
      expect(resolve(platform: TargetPlatform.android), isNull);
    });

    test('keeps clear of the camera at one end in outer landscape', () {
      const size = Size(678, 466);
      final left = resolve(
        viewPadding: const EdgeInsets.fromLTRB(84, 0, 0, 34),
        size: size,
      )!;
      expect(left.top, 82);
      expect(left.bottom, 24);
      final right = resolve(
        viewPadding: const EdgeInsets.fromLTRB(0, 0, 84, 34),
        size: size,
      )!;
      expect(right.top, 24);
      expect(right.bottom, 82);
    });

    test('starts below the status cluster on the inner display in landscape',
        () {
      final bar = resolve(size: const Size(951, 669))!;
      expect(bar.top, 120);
      expect(bar.bottom, 24);
    });

    test('collapses the tab bar as the compression asks', () {
      const landscape = Size(678, 466);
      expect(resolve(size: landscape)!.collapsesTabBar, isTrue);
      expect(
        resolve(
          size: landscape,
          compression: GlassVerticalBarCompression.prefersTabBar,
        )!
            .collapsesTabBar,
        isFalse,
      );
      expect(
        resolve(compression: GlassVerticalBarCompression.prefersBarItems)!
            .collapsesTabBar,
        isTrue,
      );
    });
  });

  group('GlassNavigationShell', () {
    testDuo('publishes the strip to its subtree', (tester) async {
      setScreen(tester);
      GlassVerticalBarData? seen;
      await tester.pumpWidget(shellApp(Builder(builder: (context) {
        seen = GlassVerticalBar.maybeOf(context);
        return const SizedBox();
      })));
      expect(seen?.edge, GlassVerticalBarEdge.trailing);
    });

    testDuo('publishes nothing when disabled', (tester) async {
      setScreen(tester);
      GlassVerticalBarEdge? seen = GlassVerticalBarEdge.leading;
      await tester.pumpWidget(shellApp(
        Builder(builder: (context) {
          seen = GlassVerticalBar.edgeOf(context);
          return const SizedBox();
        }),
        behavior: GlassVerticalBarBehavior.disabled,
      ));
      expect(seen, isNull);
    });

    testDuo('publishes nothing on a regular iPhone', (tester) async {
      setScreen(
        tester,
        size: const Size(402, 874),
        padding: const EdgeInsets.fromLTRB(0, 62, 0, 34),
      );
      GlassVerticalBarEdge? seen = GlassVerticalBarEdge.leading;
      await tester.pumpWidget(shellApp(Builder(builder: (context) {
        seen = GlassVerticalBar.edgeOf(context);
        return const SizedBox();
      })));
      expect(seen, isNull);
    });
  });

  group('pinned chrome in the strip', () {
    testDuo('stacks the back button and the groups down the strip',
        (tester) async {
      setScreen(tester);
      await tester.pumpWidget(shellApp(const _Screen(title: 'Root')));
      await settle(tester);
      _push(
        tester,
        _Screen(title: 'Detail', actions: [
          GlassBarItem.icon(
            icon: const Icon(CupertinoIcons.share),
            onTap: () {},
          ),
          GlassBarItem.icon(
            icon: const Icon(CupertinoIcons.heart),
            onTap: () {},
          ),
        ]),
      );
      await settle(tester);

      // The column is 12pt in from the strip's inner edge at x 382, so its
      // controls are centred at x 406 + 24.
      final back = pinned(tester, CupertinoIcons.back);
      final share = pinned(tester, CupertinoIcons.share);
      final heart = pinned(tester, CupertinoIcons.heart);
      expect(back.dx, closeTo(418, 0.01));
      expect(share.dx, closeTo(418, 0.01));
      expect(heart.dx, closeTo(418, 0.01));

      // The back button is the 48pt circle at y 170; the shared capsule
      // follows 12pt below it, 50pt a slot.
      expect(back.dy, 170 + 24);
      expect(share.dy, 170 + 48 + 12 + 25);
      expect(heart.dy, share.dy + 50);
    });

    testDuo('keeps the title leading in a row at the top', (tester) async {
      setScreen(tester);
      await tester.pumpWidget(shellApp(const _Screen(title: 'Root')));
      await settle(tester);

      final title = tester.getRect(find.text('Root'));
      expect(title.left, 20);
      expect(title.center.dy, closeTo(24 + 24, 0.5));
    });

    testDuo('leaves custom content in the horizontal row', (tester) async {
      setScreen(tester);
      await tester.pumpWidget(shellApp(_Screen(title: 'Root', actions: [
        GlassBarItem.custom(child: const Text('Custom')),
        GlassBarItem.icon(
          icon: const Icon(CupertinoIcons.bell),
          onTap: () {},
        ),
        GlassBarItem.icon(
          icon: const Icon(CupertinoIcons.star),
          axisBehavior: GlassBarItemAxisBehavior.horizontalOnly,
          onTap: () {},
        ),
      ])));
      await settle(tester);

      final custom = tester.getRect(find.descendant(
        of: find.byType(GlassNavPinnedHost),
        matching: find.text('Custom'),
      ));
      final star = pinned(tester, CupertinoIcons.star);
      final bell = pinned(tester, CupertinoIcons.bell);

      // Custom content and the horizontal-only icon share the row at the top
      // of the content, ending against the strip.
      expect(custom.center.dy, closeTo(48, 0.5));
      expect(star.dy, closeTo(48, 0.5));
      expect(star.dx, lessThan(382));
      // The icon goes vertical.
      expect(bell.dx, closeTo(418, 0.01));
      expect(bell.dy, 170 + 24);
    });

    testDuo('verticalPreferred pulls custom content into the strip',
        (tester) async {
      setScreen(tester);
      await tester.pumpWidget(shellApp(_Screen(title: 'Root', actions: [
        GlassBarItem.custom(
          child: const SizedBox(width: 20, height: 20, child: Text('3')),
          axisBehavior: GlassBarItemAxisBehavior.verticalPreferred,
        ),
      ])));
      await settle(tester);

      final badge = tester.getCenter(find.descendant(
        of: find.byType(GlassNavPinnedHost),
        matching: find.text('3'),
      ));
      expect(badge.dx, closeTo(418, 0.5));
      expect(badge.dy, greaterThan(170));
    });

    testDuo('overflows into a ••• menu above a tab bar', (tester) async {
      setScreen(tester);
      await tester.pumpWidget(shellApp(_TabsScreen(actions: [
        for (final icon in [
          CupertinoIcons.share,
          CupertinoIcons.heart,
          CupertinoIcons.flag,
          CupertinoIcons.bell,
          CupertinoIcons.tag,
        ])
          GlassBarItem.icon(
            icon: Icon(icon),
            label: '$icon',
            background: GlassBarItemBackground.separate,
            onTap: () {},
          ),
      ])));
      await settle(tester);

      // 170 to the tab bar's top at 678 - 24 - 212 = 442, less 12: room for
      // four 48pt circles and their gaps, the last of them the overflow.
      final host = find.byType(GlassNavPinnedHost);
      expect(
        find.descendant(of: host, matching: find.byIcon(CupertinoIcons.share)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: host, matching: find.byIcon(CupertinoIcons.flag)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: host, matching: find.byIcon(CupertinoIcons.bell)),
        findsNothing,
      );
      final more = pinned(tester, CupertinoIcons.ellipsis);
      expect(more.dy + 24, lessThanOrEqualTo(442 - 12));
    });

    testDuo('stays horizontal under GlassVerticalBarBehavior.disabled',
        (tester) async {
      setScreen(tester);
      await tester.pumpWidget(shellApp(
        _Screen(title: 'Root', actions: [
          GlassBarItem.icon(
            icon: const Icon(CupertinoIcons.bell),
            onTap: () {},
          ),
        ]),
        behavior: GlassVerticalBarBehavior.disabled,
      ));
      await settle(tester);

      // The bar's own row, at the top of the screen, as before.
      expect(pinned(tester, CupertinoIcons.bell).dy, lessThan(44));
    });
  });

  group('GlassTabBar in the strip', () {
    testDuo('becomes an icon-only capsule at the bottom of the strip',
        (tester) async {
      setScreen(tester);
      await tester.pumpWidget(shellApp(const _TabsScreen()));
      await settle(tester);

      expect(find.byType(TabBarVerticalLayout), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      // Four tabs: 6 + 4 × 50 + 6, ending 24pt above the screen's bottom.
      final profile = tester.getCenter(
        find.byIcon(CupertinoIcons.person_crop_circle),
      );
      expect(profile.dx, closeTo(418, 0.01));
      expect(profile.dy, 678 - 24 - 6 - 25);
    });

    testDuo('selects a tab on a tap', (tester) async {
      setScreen(tester);
      await tester.pumpWidget(shellApp(const _TabsScreen()));
      await settle(tester);

      await tester.tap(find.byIcon(CupertinoIcons.book));
      await settle(tester);
      expect(find.text('Library body'), findsOneWidget);
    });

    testDuo('collapses to the selected tab and opens on a tap', (tester) async {
      setScreen(tester);
      await tester.pumpWidget(shellApp(
        const _TabsScreen(),
        compression: GlassVerticalBarCompression.prefersBarItems,
      ));
      await settle(tester);

      expect(find.byIcon(CupertinoIcons.house), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.book), findsNothing);

      await tester.tap(find.byIcon(CupertinoIcons.house));
      await settle(tester);
      expect(find.byIcon(CupertinoIcons.book), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.book));
      await settle(tester);
      expect(find.text('Library body'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.house), findsNothing);
    });

    testDuo('stays horizontal on a regular iPhone', (tester) async {
      setScreen(
        tester,
        size: const Size(402, 874),
        padding: const EdgeInsets.fromLTRB(0, 62, 0, 34),
      );
      await tester.pumpWidget(shellApp(const _TabsScreen()));
      await settle(tester);

      expect(find.byType(TabBarVerticalLayout), findsNothing);
      expect(find.text('Home'), findsWidgets);
    });
  });

  group('GlassScaffold in the strip', () {
    testDuo('drops the bottom fade for a bar that left the bottom edge',
        (tester) async {
      setScreen(tester);
      await tester.pumpWidget(shellApp(const _TabsScreen()));
      await settle(tester);

      final effect = tester.widget<GlassScrollEdgeEffect>(
        find.byType(GlassScrollEdgeEffect),
      );
      expect(effect.fadeBottom, isFalse);
      // The pinned bar's title row, 24pt down and 48pt tall, plus the fade.
      expect(effect.topFadeHeight, 24 + 48 + 20);
    });
  });

  group('GlassToolbar in the strip', () {
    testDuo('stacks its items at the bottom of the strip', (tester) async {
      setScreen(tester);
      await tester.pumpWidget(shellApp(GlassScaffold(
        appBar: const GlassAppBar.pinned(title: Text('Detail')),
        bottomBar: GlassToolbar(children: [
          GlassButton(
            icon: const Icon(CupertinoIcons.archivebox),
            width: 48,
            height: 48,
            onTap: () {},
          ),
          const Spacer(),
          GlassButton(
            icon: const Icon(CupertinoIcons.reply),
            width: 48,
            height: 48,
            onTap: () {},
          ),
        ]),
        body: const SizedBox(),
      )));
      await settle(tester);

      final archive = tester.getCenter(find.byIcon(CupertinoIcons.archivebox));
      final reply = tester.getCenter(find.byIcon(CupertinoIcons.reply));
      expect(archive.dx, closeTo(418, 0.01));
      expect(reply.dx, closeTo(418, 0.01));
      expect(reply.dy, 678 - 24 - 24);
      // The spacer collapses to the strip's gap.
      expect(archive.dy, reply.dy - 48 - 12);
    });
  });
}

void _push(WidgetTester tester, Widget screen) {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.push(CupertinoPageRoute<void>(builder: (_) => screen));
}

class _Screen extends StatelessWidget {
  const _Screen({required this.title, this.actions = const []});

  final String title;
  final List<GlassBarItem> actions;

  @override
  Widget build(BuildContext context) => GlassScaffold(
        appBar: GlassAppBar.pinned(title: Text(title), actions: actions),
        body: Center(child: Text('$title body')),
      );
}

class _TabsScreen extends StatefulWidget {
  const _TabsScreen({this.actions = const []});

  final List<GlassBarItem> actions;

  @override
  State<_TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<_TabsScreen> {
  static const _titles = ['Home', 'Library', 'Radio', 'Profile'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) => GlassScaffold(
        appBar: GlassAppBar.pinned(
          title: const Text('Tabs'),
          actions: widget.actions,
        ),
        bottomBar: GlassTabBar.bottom(
          selectedIndex: _tab,
          onTabSelected: (i) => setState(() => _tab = i),
          tabs: const [
            GlassTab(icon: Icon(CupertinoIcons.house), label: 'Home'),
            GlassTab(icon: Icon(CupertinoIcons.book), label: 'Library'),
            GlassTab(
              icon: Icon(CupertinoIcons.dot_radiowaves_left_right),
              label: 'Radio',
            ),
            GlassTab(
              icon: Icon(CupertinoIcons.person_crop_circle),
              label: 'Profile',
            ),
          ],
        ),
        body: Center(child: Text('${_titles[_tab]} body')),
      );
}
