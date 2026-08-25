# Glass Navigation Transition

Pinned navigation-bar chrome across route transitions — the iOS 26 navigation
bar model, where bar items belong to the navigation stack rather than to any
one screen.

During a push or pop (including the interactive back-swipe, scrubbed
proportionally with the gesture), page content and the title slide with the
route transition while the glass back button and the trailing actions capsule
stay pinned in place above the `Navigator`. A capsule present on both routes
morphs in place: its width animates between the two measured clusters, matched
items hold their position, and changed icons cross-fade. Apple documents the
same behaviour on
[`UIBarButtonItem.identifier`](https://developer.apple.com/documentation/uikit/uibarbuttonitem/identifier):
*"When the set of bar button items in a navigation bar or toolbar changes (for
example, when pushing or popping view controllers), UIKit automatically
animates the transition between the different sets of items."*

## Setup

Install `GlassNavigationShell` once, wrapping whatever `Navigator` your app
builds:

```dart
CupertinoApp(
  builder: (context, child) => GlassNavigationShell(child: child!),
  home: const HomeScreen(),
);
```

This works with **any routing library built on the Pages API** — go_router,
auto_route, beamer — because the shell only reads `ModalRoute` animations and
never intercepts navigation:

```dart
CupertinoApp.router(
  routerConfig: router,
  builder: (context, child) => GlassNavigationShell(child: child!),
);
```

With go_router, use `CupertinoPage` in your `pageBuilder`s to keep the native
slide and back-swipe.

## Declaring a screen's bar items

Screens opt in through `GlassAppBar.pinnedActions`, declaring items as data —
the analogue of `UIBarButtonItem`:

```dart
GlassScaffold(
  appBar: GlassAppBar(
    title: const Text('Repository'),
    pinnedActions: [
      GlassBarItem.icon(
        icon: const Icon(CupertinoIcons.add),
        id: 'add',
        onTap: _create,
      ),
      GlassBarItem.icon(
        icon: const Icon(CupertinoIcons.ellipsis),
        onTap: _showMore,
      ),
    ],
  ),
  body: ...,
);
```

- **The back button is automatic.** It appears whenever the route can be
  popped (`ModalRoute.impliesAppBarDismissal`) and never on a root route. The
  default action is `Navigator.maybePop` — what Flutter's own `BackButton`
  calls, and what Pages-API routers handle correctly. Override with `onBack`
  for router-specific semantics such as go_router's `context.pop()`.
- **`id` mirrors `UIBarButtonItem.identifier`.** Items sharing an `id` across
  two routes are treated as the same item and hold their position while
  everything around them morphs. Without an `id`, items are matched
  positionally from the trailing edge — UIKit's documented default heuristic.
- **`GlassBarItem.custom` is the `customView:` analogue.** Any widget can sit
  in the capsule; it is measured at its intrinsic width during layout and the
  capsule sizes itself around it. There is deliberately no API to offset or
  reposition a cluster — iOS 26 has none either, which is exactly why custom
  content needs no coordination: the widget *is* an item, and layout flows
  from that.
- **`const []` and `null` mean different things.** An empty list opts the
  screen into pinning with no trailing items (the back button still pins);
  `null` opts the screen out entirely, and the chrome retreats while a
  non-participating route covers it.

## Behaviour and constraints

| Situation | Behaviour |
|---|---|
| Push/pop between participating routes | Chrome pinned; capsule width and item positions interpolate; changed icons cross-fade |
| Interactive back-swipe | Same interpolation, scrubbed by the gesture; cancelled swipes rebound |
| Destination has no actions (or no back button) | The cluster switches off/on once at the transition midpoint — appearing and disappearing are deliberately not animated |
| Non-participating route or modal sheet on top | Chrome retreats with the covering route's transition and returns on pop |
| No shell installed, or `GlassQuality.minimal` | `pinnedActions` renders in-route: automatic back `GlassButton` + `GlassButtonGroup.icons` capsule |

Glass opacity is never animated (a glass surface's backdrop pass renders fully
or not at all); only geometry animates, and only item *contents* cross-fade.

## Current limitations

- `GlassBarItem.spacer()` (multi-capsule grouping, mirroring
  `ToolbarSpacer`/`fixedSpace`) is parsed but not rendered yet; a cluster
  containing one asserts in debug mode.
- Changing `pinnedActions` in place via `setState` swaps the capsule's
  contents without animating the resize.
- One navigator per shell; nested navigators (for example go_router's
  `StatefulShellRoute` branches) are not yet supported.
- RTL layouts are untested.

## Demos

The example showcase app uses pinned chrome throughout — every category page
pins its back button, and the navigation-patterns demo pins its actions,
including a **Nested Navigation** pattern that walks a three-level drill-down
with identifier-matched items morphing at each push:

```bash
cd example
flutter run                                         # full showcase
flutter run -t lib/demos/nav_bar_patterns_demo.dart # nav patterns
```
