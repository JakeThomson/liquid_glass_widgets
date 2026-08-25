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
    testWidgets('pinnedActions and actions are mutually exclusive',
        (tester) async {
      expect(
        () => GlassAppBar(
          pinnedActions: const [],
          actions: const [SizedBox()],
        ),
        throwsAssertionError,
      );
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
    return GlassScaffold(
      appBar: GlassAppBar(
        title: Text(title),
        pinnedActions: actions,
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
      appBar: GlassAppBar(
        title: const Text('Toggle'),
        pinnedActions: [
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
