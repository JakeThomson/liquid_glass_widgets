/// GlassNavigationTransition — pinned glass bar chrome across route changes.
///
/// Reproduces the iOS 26 navigation bar: the back button and the trailing
/// actions capsule stay pinned above the Navigator while page content and the
/// title slide, and the capsule morphs in place into the next route's actions.
///
/// Flow mirrors the GitHub app reference recording:
///   Repositories (root, no actions)
///     → Repository        [ + , ••• ]
///       → Discussions     [ + , search ]   '+' is identifier-matched, so it
///                                          stays put while ••• → search
///         → Watchers      (no actions)     capsule scales out in place
///
/// Run standalone:
///   flutter run -t lib/demos/nav_transition_demo.dart
library;

import 'package:flutter/cupertino.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(child: const NavTransitionDemoApp()));
}

/// Stretches every transition to 3s so the pinned chrome can be inspected
/// frame by frame without toggling simulator slow-animations.
const bool kSlowRoutes = false;

/// Drives the demo through the whole flow on a timer, for capture runs.
const bool kAutoDrive = false;

/// Demo app installing a [GlassNavigationShell] around the navigator.
class NavTransitionDemoApp extends StatelessWidget {
  /// Creates the demo app.
  const NavTransitionDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Glass Navigation Transition',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(brightness: Brightness.light),
      // The one integration point: wrap whatever Navigator the app builds.
      builder: (context, child) => GlassNavigationShell(child: child!),
      home: const RepositoriesScreen(),
    );
  }
}

Route<void> _push(Widget screen) {
  if (kSlowRoutes) {
    return _SlowCupertinoPageRoute<void>(builder: (_) => screen);
  }
  return CupertinoPageRoute<void>(builder: (_) => screen);
}

/// A [CupertinoPageRoute] with a stretched duration for frame-by-frame review.
class _SlowCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  _SlowCupertinoPageRoute({required super.builder});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 3000);

  // Explicit so pops are stretched too, not just pushes — the entrance of the
  // actions capsule is easiest to judge on a slow pop.
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 3000);
}

// =============================================================================
// Root — no actions, no back button
// =============================================================================

/// Root screen: a repository list, with no pinned actions and no back button.
class RepositoriesScreen extends StatefulWidget {
  /// Creates the root screen.
  const RepositoriesScreen({super.key});

  @override
  State<RepositoriesScreen> createState() => _RepositoriesScreenState();
}

class _RepositoriesScreenState extends State<RepositoriesScreen> {
  @override
  void initState() {
    super.initState();
    if (kAutoDrive) _AutoDriver.start(context);
  }

  @override
  Widget build(BuildContext context) {
    return _DemoScaffold(
      title: 'Repositories',
      palette: const [Color(0xFFF2F2F7), Color(0xFFE5E5EA)],
      pinnedActions: const [],
      body: ListView(
        padding: const EdgeInsets.only(top: 100, bottom: 40),
        children: [
          for (final repo in const [
            'liquid_glass_widgets',
            'flutter',
            'dart-sdk',
            'skia',
          ])
            _Row(
              title: repo,
              subtitle: 'Tap to open the repository',
              onTap: () => Navigator.of(context).push(
                _push(RepositoryScreen(name: repo)),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Repository — [ + , ••• ]
// =============================================================================

/// Repository detail screen with an add and an overflow action.
class RepositoryScreen extends StatelessWidget {
  /// Creates the repository screen.
  const RepositoryScreen({super.key, required this.name});

  /// Repository name shown as the title.
  final String name;

  @override
  Widget build(BuildContext context) {
    return _DemoScaffold(
      title: name,
      palette: const [Color(0xFFFFF4E5), Color(0xFFFFE0B2)],
      pinnedActions: [
        // Shared id with the next screen's '+', so it stays put across the push.
        GlassBarItem.icon(
          icon: const Icon(CupertinoIcons.add),
          id: 'add',
          label: 'Add',
          onTap: () {},
        ),
        GlassBarItem.icon(
          icon: const Icon(CupertinoIcons.ellipsis),
          label: 'More',
          onTap: () {},
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(top: 100, bottom: 40),
        children: [
          _Row(
            title: 'Discussions',
            subtitle: 'Actions morph: ••• becomes search',
            onTap: () => Navigator.of(context).push(
              _push(const DiscussionsScreen()),
            ),
          ),
          _Row(
            title: 'Plain route (no glass bar)',
            subtitle: 'Pinned chrome retreats, then returns',
            onTap: () =>
                Navigator.of(context).push(_push(const _PlainScreen())),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Discussions — [ + , search ], plus a live action swap
// =============================================================================

/// Discussions screen; '+' is identifier-matched with the previous route.
class DiscussionsScreen extends StatefulWidget {
  /// Creates the discussions screen.
  const DiscussionsScreen({super.key});

  @override
  State<DiscussionsScreen> createState() => _DiscussionsScreenState();
}

class _DiscussionsScreenState extends State<DiscussionsScreen> {
  bool _extraAction = false;

  @override
  Widget build(BuildContext context) {
    return _DemoScaffold(
      title: 'Discussions',
      palette: const [Color(0xFFE3F2FD), Color(0xFFB3E5FC)],
      pinnedActions: [
        GlassBarItem.icon(
          icon: const Icon(CupertinoIcons.add),
          id: 'add',
          label: 'Add',
          onTap: () {},
        ),
        if (_extraAction)
          // A custom widget: measured at its intrinsic width, so the capsule
          // sizes itself around it — no repositioning API needed.
          GlassBarItem.custom(
            id: 'unread',
            label: '12 unread',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text(
                    '12 unread',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ),
            ),
            onTap: () {},
          ),
        GlassBarItem.icon(
          icon: const Icon(CupertinoIcons.search),
          label: 'Search',
          onTap: () {},
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(top: 100, bottom: 40),
        children: [
          _Row(
            title: 'Watchers',
            subtitle: 'Destination has no actions',
            onTap: () => Navigator.of(context).push(
              _push(const WatchersScreen()),
            ),
          ),
          _Row(
            title: _extraAction ? 'Remove an action' : 'Add an action',
            subtitle: 'Capsule resizes in place, no transition involved',
            onTap: () => setState(() => _extraAction = !_extraAction),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Watchers — no actions
// =============================================================================

/// Watchers screen with no pinned actions, so the capsule scales out.
class WatchersScreen extends StatelessWidget {
  /// Creates the watchers screen.
  const WatchersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _DemoScaffold(
      title: 'Watchers',
      palette: const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
      pinnedActions: const [],
      body: ListView(
        padding: const EdgeInsets.only(top: 100, bottom: 40),
        children: [
          for (final name in const ['Arto Bendiken', 'Jane Doe', 'Sam Patel'])
            _Row(title: name, subtitle: 'Watching this repository'),
        ],
      ),
    );
  }
}

/// A route that does not participate in pinning at all.
class _PlainScreen extends StatelessWidget {
  const _PlainScreen();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Plain Cupertino route'),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'This route has no GlassAppBar, so it never registers with the '
            'shell. The pinned chrome retreats as this page covers it, and '
            'comes back on pop.',
            textAlign: TextAlign.center,
            style: CupertinoTheme.of(context).textTheme.textStyle,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Shared scaffolding
// =============================================================================

/// A demo screen: gradient background, striped band, and a pinned glass bar.
class _DemoScaffold extends StatelessWidget {
  const _DemoScaffold({
    required this.title,
    required this.palette,
    required this.pinnedActions,
    required this.body,
  });

  final String title;
  final List<Color> palette;
  final List<GlassBarItem> pinnedActions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      background: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette,
          ),
        ),
      ),
      appBar: GlassAppBar(
        title: Text(title),
        pinnedActions: pinnedActions,
      ),
      body: Stack(
        children: [
          // High-contrast stripes directly under the bar: refraction shifts
          // are obvious over hard edges and invisible over flat colour.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: Row(
              children: List.generate(
                18,
                (i) => Expanded(
                  child: ColoredBox(
                    color: i.isEven
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFFFFFFF),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          body,
        ],
      ),
    );
  }
}

/// A tappable list row.
class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle, this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xCCFFFFFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6E6E73),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: Color(0xFFAEAEB2),
              ),
          ],
        ),
      ),
    );
  }
}

/// Drives the demo automatically so transitions can be captured headlessly.
abstract final class _AutoDriver {
  static void start(BuildContext context) {
    Future<void>.delayed(const Duration(seconds: 3), () async {
      if (!context.mounted) return;
      final nav = Navigator.of(context);
      nav.push(_push(const RepositoryScreen(name: 'liquid_glass_widgets')));
      await Future<void>.delayed(const Duration(seconds: 4));
      nav.push(_push(const DiscussionsScreen()));
      await Future<void>.delayed(const Duration(seconds: 4));
      nav.push(_push(const WatchersScreen()));
      await Future<void>.delayed(const Duration(seconds: 4));
      nav.pop();
      await Future<void>.delayed(const Duration(seconds: 4));
      nav.pop();
      await Future<void>.delayed(const Duration(seconds: 4));
      nav.pop();
    });
  }
}
