import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/widgets/surfaces/shared/glass_nav_pinned_host.dart';

void main() {
  setUp(() {
    // Headless test runs report no shader support; force the gate open so the
    // pinned path is exercised. Individual tests override to test the gate.
    GlassNavigationShellState.debugPinningSupported = true;
  });

  tearDown(() {
    GlassNavigationShellState.debugPinningSupported = null;
  });

  Widget shellApp(Widget home, {bool enabled = true}) {
    return CupertinoApp(
      builder: (context, child) =>
          GlassNavigationShell(enabled: enabled, child: child!),
      home: home,
    );
  }

  /// Settles the route transition and the post-frame registration handover.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump();
  }

  /// The back button drawn by the shell, as opposed to any in-route fallback.
  Finder pinnedBack() => find.descendant(
        of: find.byType(GlassNavPinnedHost),
        matching: find.byIcon(CupertinoIcons.back),
      );

  group('registration and hoisting', () {
    testWidgets('a screen with pinnedActions hands its items to the host',
        (tester) async {
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: [
          GlassBarItem.icon(
            icon: const Icon(CupertinoIcons.add),
            onTap: () {},
          ),
        ],
      )));
      await settle(tester);

      // The host renders the capsule above the navigator...
      expect(find.byType(GlassNavPinnedHost), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(CupertinoIcons.add),
        ),
        findsOneWidget,
      );
      // ...and the in-route bar holds only an unpainted measuring placeholder.
      expect(
        find.descendant(
          of: find.byType(GlassAppBar),
          matching: find.byType(GlassButtonGroup),
        ),
        findsNothing,
      );
    });

    testWidgets('no back button on a root route', (tester) async {
      await tester.pumpWidget(
        shellApp(const _Screen(title: 'Root', actions: [])),
      );
      await settle(tester);

      expect(find.byIcon(CupertinoIcons.back), findsNothing);
    });

    testWidgets('pushed route gets a pinned back button that pops',
        (tester) async {
      await tester.pumpWidget(
        shellApp(const _Screen(title: 'Root', actions: [])),
      );
      await settle(tester);

      await _push(tester, const _Screen(title: 'Detail', actions: []));
      await settle(tester);

      expect(find.text('Detail'), findsOneWidget);
      final back = find.descendant(
        of: find.byType(GlassNavPinnedHost),
        matching: find.byIcon(CupertinoIcons.back),
      );
      expect(back, findsOneWidget);

      await tester.tap(back);
      await settle(tester);
      expect(find.text('Detail'), findsNothing);
      // Back at the root, the button is gone again.
      expect(find.byIcon(CupertinoIcons.back), findsNothing);
    });

    testWidgets('onBack overrides the default pop', (tester) async {
      var custom = 0;
      await tester.pumpWidget(
        shellApp(const _Screen(title: 'Root', actions: [])),
      );
      await settle(tester);
      await _push(
        tester,
        _Screen(title: 'Detail', actions: const [], onBack: () => custom++),
      );
      await settle(tester);

      await tester.tap(find.descendant(
        of: find.byType(GlassNavPinnedHost),
        matching: find.byIcon(CupertinoIcons.back),
      ));
      await settle(tester);

      expect(custom, 1);
      expect(find.text('Detail'), findsOneWidget); // custom handler didn't pop
    });

    testWidgets('pinned items are tappable at rest', (tester) async {
      var taps = 0;
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: [
          GlassBarItem.icon(
            icon: const Icon(CupertinoIcons.add),
            label: 'Add',
            onTap: () => taps++,
          ),
        ],
      )));
      await settle(tester);

      await tester.tap(find.descendant(
        of: find.byType(GlassNavPinnedHost),
        matching: find.byIcon(CupertinoIcons.add),
      ));
      expect(taps, 1);
    });

    testWidgets('custom items are measured at their intrinsic width',
        (tester) async {
      const wide = SizedBox(width: 120, height: 20);
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: [
          GlassBarItem.icon(icon: const Icon(CupertinoIcons.add), onTap: () {}),
          const GlassBarItem.custom(child: wide),
        ],
      )));
      await settle(tester);

      final capsule = tester.getSize(find.descendant(
        of: find.byType(GlassNavPinnedHost),
        matching: find.byType(GlassButton),
      ));
      // One 46pt icon slot + the 120pt custom child.
      expect(capsule.width, greaterThanOrEqualTo(166));
    });

    testWidgets('in-place pinnedActions update reaches the host',
        (tester) async {
      await tester.pumpWidget(shellApp(const _TogglingScreen()));
      await settle(tester);
      expect(find.byIcon(CupertinoIcons.bell), findsNothing);

      await tester.tap(find.text('toggle'));
      await settle(tester);

      expect(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(CupertinoIcons.bell),
        ),
        findsOneWidget,
      );
    });
  });

  group('transitions', () {
    testWidgets('chrome renders mid-transition while items morph',
        (tester) async {
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: [
          GlassBarItem.icon(
            icon: const Icon(CupertinoIcons.add),
            id: 'add',
            onTap: () {},
          ),
          GlassBarItem.icon(
            icon: const Icon(CupertinoIcons.ellipsis),
            onTap: () {},
          ),
        ],
      )));
      await settle(tester);

      await _push(
        tester,
        _Screen(
          title: 'Detail',
          actions: [
            GlassBarItem.icon(
              icon: const Icon(CupertinoIcons.add),
              id: 'add',
              onTap: () {},
            ),
            GlassBarItem.icon(
              icon: const Icon(CupertinoIcons.search),
              onTap: () {},
            ),
          ],
        ),
      );

      // Past the swap point: incoming side shows, matched item cross-fades.
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(GlassNavPinnedHost), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(CupertinoIcons.search),
        ),
        findsOneWidget,
      );

      await settle(tester);
      expect(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(CupertinoIcons.ellipsis),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'exiting item smoothly fades out during morph without abrupt pop',
        (tester) async {
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: [
          GlassBarItem.icon(
            icon: const Icon(CupertinoIcons.add),
            id: 'add',
            onTap: () {},
          ),
          GlassBarItem.icon(
            icon: const Icon(CupertinoIcons.ellipsis),
            id: 'more',
            onTap: () {},
          ),
        ],
      )));
      await settle(tester);

      await _push(
        tester,
        _Screen(
          title: 'Detail',
          actions: [
            GlassBarItem.icon(
              icon: const Icon(CupertinoIcons.ellipsis),
              id: 'more',
              onTap: () {},
            ),
          ],
        ),
      );

      // Mid-transition: exiting item ('add') is still mounted with fading opacity
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(CupertinoIcons.add),
        ),
        findsOneWidget,
      );

      await settle(tester);
      // Once settled, only the destination screen's items remain
      expect(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(CupertinoIcons.add),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(CupertinoIcons.ellipsis),
        ),
        findsOneWidget,
      );
    });

    testWidgets('capsule switches off when the destination has no actions',
        (tester) async {
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: [
          GlassBarItem.icon(icon: const Icon(CupertinoIcons.add), onTap: () {}),
        ],
      )));
      await settle(tester);

      await _push(tester, const _Screen(title: 'Empty', actions: []));
      await settle(tester);

      expect(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(CupertinoIcons.add),
        ),
        findsNothing,
      );
      // The back button still pins: empty list opts in, it does not opt out.
      expect(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(CupertinoIcons.back),
        ),
        findsOneWidget,
      );
    });

    testWidgets('chrome retreats under a non-participating route',
        (tester) async {
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: [
          GlassBarItem.icon(icon: const Icon(CupertinoIcons.add), onTap: () {}),
        ],
      )));
      await settle(tester);

      await _push(
        tester,
        const CupertinoPageScaffold(child: Center(child: Text('Plain'))),
      );
      await settle(tester);

      // The plain route does not register; the host renders no chrome while
      // fully covered (the widget itself stays mounted at zero size).
      expect(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(CupertinoIcons.add),
        ),
        findsNothing,
      );

      Navigator.of(tester.element(find.text('Plain'))).pop();
      await settle(tester);
      expect(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(CupertinoIcons.add),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the back button is inert for the length of a push',
        (tester) async {
      var custom = 0;
      await tester.pumpWidget(
        shellApp(const _Screen(title: 'Root', actions: [])),
      );
      await settle(tester);
      await _push(
        tester,
        _Screen(title: 'Detail', actions: const [], onBack: () => custom++),
      );

      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(pinnedBack(), warnIfMissed: false);
      await tester.pump();
      expect(custom, 0);

      await settle(tester);
      await tester.tap(pinnedBack());
      expect(custom, 1);
    });

    testWidgets('the back button is inert from the first frame of a pop',
        (tester) async {
      var custom = 0;
      await tester.pumpWidget(
        shellApp(const _Screen(title: 'Root', actions: [])),
      );
      await settle(tester);
      await _push(
        tester,
        _Screen(title: 'Detail', actions: const [], onBack: () => custom++),
      );
      await settle(tester);

      // A pop leaves progress at 1.0 for its first frames, so by value alone
      // this is indistinguishable from being at rest — only the controller's
      // status says the transition is running.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.tap(pinnedBack(), warnIfMissed: false);
      await tester.pump();
      expect(custom, 0);

      await settle(tester);
    });

    testWidgets(
        'the back button is inert mid back-swipe and live again once '
        'a cancelled swipe rebounds', (tester) async {
      var custom = 0;
      await tester.pumpWidget(
        shellApp(const _Screen(title: 'Root', actions: [])),
      );
      await settle(tester);
      await _push(
        tester,
        _Screen(title: 'Detail', actions: const [], onBack: () => custom++),
      );
      await settle(tester);

      final swipe = await tester.startGesture(const Offset(2, 300));
      await swipe.moveBy(const Offset(80, 0));
      await tester.pump();

      await tester.tap(pinnedBack(), warnIfMissed: false);
      await tester.pump();
      expect(custom, 0);

      // Cancelling springs the route back. The rebound's final value tick
      // lands on 1.0 before the controller reports itself completed, so the
      // chrome only learns it is at rest again from the status change.
      await swipe.moveBy(const Offset(-70, 0));
      await swipe.up();
      await settle(tester);

      await tester.tap(pinnedBack());
      expect(custom, 1);
      expect(find.text('Detail'), findsOneWidget);
    });

    testWidgets('pinned actions are inert mid-transition', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        shellApp(const _Screen(title: 'Root', actions: [])),
      );
      await settle(tester);
      await _push(
        tester,
        _Screen(
          title: 'Detail',
          actions: [
            GlassBarItem.icon(
              icon: const Icon(CupertinoIcons.add),
              onTap: () => taps++,
            ),
          ],
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      final add = find.descendant(
        of: find.byType(GlassNavPinnedHost),
        matching: find.byIcon(CupertinoIcons.add),
      );
      expect(add, findsOneWidget);
      await tester.tap(add, warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);

      await settle(tester);
      await tester.tap(add);
      expect(taps, 1);
    });
  });

  group('pull-down menus', () {
    List<GlassBarItem> menuActions({String label = 'Copy'}) => [
          GlassBarItem.menu(
            icon: const Icon(CupertinoIcons.ellipsis),
            id: 'more',
            label: 'More',
            menuItems: [GlassMenuItem(title: label, onTap: () {})],
          ),
        ];

    testWidgets('a menu item opens the pull-down from the pinned capsule',
        (tester) async {
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: menuActions(),
      )));
      await settle(tester);

      expect(find.text('Copy'), findsNothing);
      await tester.tap(find.descendant(
        of: find.byType(GlassNavPinnedHost),
        matching: find.byIcon(CupertinoIcons.ellipsis),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('a menu cannot be opened mid-transition', (tester) async {
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: menuActions(),
      )));
      await settle(tester);
      await _push(
        tester,
        _Screen(title: 'Detail', actions: menuActions(label: 'Delete')),
      );

      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(
        find.descendant(
          of: find.byType(GlassNavPinnedHost),
          matching: find.byIcon(CupertinoIcons.ellipsis),
        ),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Delete'), findsNothing);

      await settle(tester);
    });

    testWidgets('an open menu is dismissed when navigation starts',
        (tester) async {
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: menuActions(),
      )));
      await settle(tester);

      await tester.tap(find.descendant(
        of: find.byType(GlassNavPinnedHost),
        matching: find.byIcon(CupertinoIcons.ellipsis),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);

      // The capsule outlives the route, so nothing else would take the menu
      // down as the page slides out from under it.
      await _push(tester, const _Screen(title: 'Detail', actions: []));
      await settle(tester);

      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('only the first menu item in a cluster opens a menu',
        (tester) async {
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: [
          GlassBarItem.menu(
            icon: const Icon(CupertinoIcons.ellipsis),
            menuItems: [GlassMenuItem(title: 'First', onTap: () {})],
          ),
          GlassBarItem.menu(
            icon: const Icon(CupertinoIcons.square_arrow_up),
            menuItems: [GlassMenuItem(title: 'Second', onTap: () {})],
          ),
        ],
      )));
      await settle(tester);

      await tester.tap(find.descendant(
        of: find.byType(GlassNavPinnedHost),
        matching: find.byIcon(CupertinoIcons.square_arrow_up),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsNothing);

      await tester.tap(find.descendant(
        of: find.byType(GlassNavPinnedHost),
        matching: find.byIcon(CupertinoIcons.ellipsis),
      ));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
    });

    testWidgets('without a shell the menu still opens in-route',
        (tester) async {
      GlassNavigationShellState.debugPinningSupported = false;
      await tester.pumpWidget(CupertinoApp(
        home: _Screen(title: 'Root', actions: menuActions()),
      ));
      await settle(tester);

      expect(find.byType(GlassNavPinnedHost), findsNothing);
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
    });
  });

  group('fallback rendering', () {
    Finder inRouteCapsule() => find.descendant(
          of: find.byType(GlassAppBar),
          matching: find.byType(GlassButtonGroup),
        );

    testWidgets('without a shell the bar renders the same items in-route',
        (tester) async {
      await tester.pumpWidget(CupertinoApp(
        home: _Screen(
          title: 'Root',
          actions: [
            GlassBarItem.icon(
              icon: const Icon(CupertinoIcons.add),
              onTap: () {},
            ),
          ],
        ),
      ));
      await settle(tester);

      expect(find.byType(GlassNavPinnedHost), findsNothing);
      expect(inRouteCapsule(), findsOneWidget);
    });

    testWidgets('in-route back button appears on pushed routes and pops',
        (tester) async {
      await tester.pumpWidget(const CupertinoApp(home: _Screen(title: 'Root')));
      await settle(tester);
      await _push(tester, const _Screen(title: 'Detail', actions: []));
      await settle(tester);

      final back = find.descendant(
        of: find.byType(GlassAppBar),
        matching: find.byIcon(CupertinoIcons.back),
      );
      expect(back, findsOneWidget);
      await tester.tap(back);
      await settle(tester);
      expect(find.text('Detail'), findsNothing);
    });

    testWidgets('a disabled shell behaves like no shell', (tester) async {
      await tester.pumpWidget(shellApp(
        enabled: false,
        _Screen(
          title: 'Root',
          actions: [
            GlassBarItem.icon(
              icon: const Icon(CupertinoIcons.add),
              onTap: () {},
            ),
          ],
        ),
      ));
      await settle(tester);

      expect(find.byType(GlassNavPinnedHost), findsNothing);
      expect(inRouteCapsule(), findsOneWidget);
    });

    testWidgets('an unsupported device falls back in-route', (tester) async {
      GlassNavigationShellState.debugPinningSupported = false;
      await tester.pumpWidget(shellApp(_Screen(
        title: 'Root',
        actions: [
          GlassBarItem.icon(icon: const Icon(CupertinoIcons.add), onTap: () {}),
        ],
      )));
      await settle(tester);

      expect(find.byType(GlassNavPinnedHost), findsNothing);
      expect(inRouteCapsule(), findsOneWidget);
    });
  });

  group('API guards', () {
    testWidgets('the two constructors cannot mix widget and data APIs',
        (tester) async {
      // Structurally impossible now: the plain constructor has no pinned
      // parameters and the pinned constructor has no widget parameters, so
      // the two APIs cannot be mixed on one bar.
      expect(
        const GlassAppBar.pinned().pinnedActions,
        isEmpty,
      );
      expect(const GlassAppBar(actions: [SizedBox()]).pinnedActions, isNull);
    });

    testWidgets('spacers are rejected until multi-capsule rendering lands',
        (tester) async {
      await tester.pumpWidget(shellApp(const _Screen(
        title: 'Root',
        actions: [GlassBarItem.spacer()],
      )));
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('maybeOf finds the shell from a route subtree', (tester) async {
      GlassNavigationShellState? found;
      await tester.pumpWidget(CupertinoApp(
        builder: (context, child) => GlassNavigationShell(child: child!),
        home: Builder(
          builder: (context) {
            found = GlassNavigationShell.maybeOf(context);
            return const SizedBox();
          },
        ),
      ));
      expect(found, isNotNull);
      expect(found!.isActive, isTrue);
    });
  });
}

Future<void> _push(WidgetTester tester, Widget screen) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.push(CupertinoPageRoute<void>(builder: (_) => screen));
  await tester.pump();
}

/// A minimal screen with a pinned bar.
class _Screen extends StatelessWidget {
  const _Screen({required this.title, this.actions, this.onBack});

  final String title;
  final List<GlassBarItem>? actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    // Screens with actions use the pinned constructor; a null actions list
    // means this screen deliberately uses the widget-based bar and does not
    // participate in pinning.
    final items = actions;
    return GlassScaffold(
      appBar: items == null
          ? GlassAppBar(title: Text(title))
          : GlassAppBar.pinned(
              title: Text(title),
              actions: items,
              onBack: onBack,
            ),
      body: Center(child: Text('$title body')),
    );
  }
}

/// A screen whose actions change with setState.
class _TogglingScreen extends StatefulWidget {
  const _TogglingScreen();

  @override
  State<_TogglingScreen> createState() => _TogglingScreenState();
}

class _TogglingScreenState extends State<_TogglingScreen> {
  bool _extra = false;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar.pinned(
        title: const Text('Toggle'),
        actions: [
          GlassBarItem.icon(icon: const Icon(CupertinoIcons.add), onTap: () {}),
          if (_extra)
            GlassBarItem.icon(
              icon: const Icon(CupertinoIcons.bell),
              onTap: () {},
            ),
        ],
      ),
      body: Center(
        child: CupertinoButton(
          onPressed: () => setState(() => _extra = !_extra),
          child: const Text('toggle'),
        ),
      ),
    );
  }
}
