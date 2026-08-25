/// GlassNavigationTransition with go_router — the same pinned bar chrome,
/// driven by a declarative router instead of imperative Navigator pushes.
///
/// This demo exists to prove the feature is router-agnostic. Nothing in the
/// package knows about go_router: the shell is installed through
/// `CupertinoApp.router`'s `builder`, and screens register through
/// `ModalRoute.of`, which every Pages-API router provides.
///
/// It also exercises both back actions — the default `Navigator.maybePop` on
/// one screen, and go_router's own `context.pop()` via `onBack` on another.
///
/// Run standalone:
///   flutter run -t lib/demos/nav_transition_gorouter_demo.dart
library;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(child: const GoRouterNavTransitionApp()));
}

/// Demo app wiring [GlassNavigationShell] into a `CupertinoApp.router`.
class GoRouterNavTransitionApp extends StatelessWidget {
  /// Creates the demo app.
  const GoRouterNavTransitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp.router(
      title: 'Glass Nav Transition (go_router)',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(brightness: Brightness.light),
      routerConfig: _router,
      // Same one-line installation as with the imperative Navigator.
      builder: (context, child) => GlassNavigationShell(child: child!),
    );
  }
}

/// CupertinoPage keeps the native slide and the interactive back-swipe, which
/// is what the pinned chrome scrubs against.
final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => const CupertinoPage<void>(
        child: _RepositoriesScreen(),
      ),
      routes: [
        GoRoute(
          path: 'repo',
          pageBuilder: (context, state) => const CupertinoPage<void>(
            child: _RepositoryScreen(),
          ),
          routes: [
            GoRoute(
              path: 'discussions',
              pageBuilder: (context, state) => const CupertinoPage<void>(
                child: _DiscussionsScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'watchers',
                  pageBuilder: (context, state) => const CupertinoPage<void>(
                    child: _WatchersScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class _RepositoriesScreen extends StatelessWidget {
  const _RepositoriesScreen();

  @override
  Widget build(BuildContext context) {
    return _DemoScaffold(
      title: 'Repositories',
      palette: const [Color(0xFFF2F2F7), Color(0xFFE5E5EA)],
      pinnedActions: const [],
      rows: [
        _RowData(
          'liquid_glass_widgets',
          'go_router push — chrome pins',
          () => context.go('/repo'),
        ),
      ],
    );
  }
}

class _RepositoryScreen extends StatelessWidget {
  const _RepositoryScreen();

  @override
  Widget build(BuildContext context) {
    return _DemoScaffold(
      title: 'liquid_glass_widgets',
      palette: const [Color(0xFFFFF4E5), Color(0xFFFFE0B2)],
      // Default back action: Navigator.maybePop, which go_router handles.
      pinnedActions: [
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
      rows: [
        _RowData(
          'Discussions',
          '••• morphs into search',
          () => context.go('/repo/discussions'),
        ),
      ],
    );
  }
}

class _DiscussionsScreen extends StatelessWidget {
  const _DiscussionsScreen();

  @override
  Widget build(BuildContext context) {
    return _DemoScaffold(
      title: 'Discussions',
      palette: const [Color(0xFFE3F2FD), Color(0xFFB3E5FC)],
      // Explicit router-specific pop, to prove onBack works.
      onBack: () => context.pop(),
      pinnedActions: [
        GlassBarItem.icon(
          icon: const Icon(CupertinoIcons.add),
          id: 'add',
          label: 'Add',
          onTap: () {},
        ),
        GlassBarItem.icon(
          icon: const Icon(CupertinoIcons.search),
          label: 'Search',
          onTap: () {},
        ),
      ],
      rows: [
        _RowData(
          'Watchers',
          'Destination has no actions',
          () => context.go('/repo/discussions/watchers'),
        ),
      ],
    );
  }
}

class _WatchersScreen extends StatelessWidget {
  const _WatchersScreen();

  @override
  Widget build(BuildContext context) {
    return const _DemoScaffold(
      title: 'Watchers',
      palette: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
      pinnedActions: [],
      rows: [
        _RowData('Arto Bendiken', 'Watching this repository', null),
        _RowData('Jane Doe', 'Watching this repository', null),
      ],
    );
  }
}

// =============================================================================
// Shared scaffolding
// =============================================================================

@immutable
class _RowData {
  const _RowData(this.title, this.subtitle, this.onTap);
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}

class _DemoScaffold extends StatelessWidget {
  const _DemoScaffold({
    required this.title,
    required this.palette,
    required this.pinnedActions,
    required this.rows,
    this.onBack,
  });

  final String title;
  final List<Color> palette;
  final List<GlassBarItem> pinnedActions;
  final List<_RowData> rows;
  final VoidCallback? onBack;

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
        onBack: onBack,
      ),
      body: Stack(
        children: [
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
          ListView(
            padding: const EdgeInsets.only(top: 100, bottom: 40),
            children: [
              for (final row in rows)
                GestureDetector(
                  onTap: row.onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xCCFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6E6E73),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
