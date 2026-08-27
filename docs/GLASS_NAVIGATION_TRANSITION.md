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

Screens opt in with the `GlassAppBar.pinned` constructor, declaring items as
data — the analogue of `UIBarButtonItem`:

```dart
GlassScaffold(
  appBar: GlassAppBar.pinned(
    title: const Text('Repository'),
    actions: [
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

`actions` defaults to empty, so the common back-button-only screen is just
`GlassAppBar.pinned(title: ...)`. The plain `GlassAppBar` constructor keeps
the widget-based `leading`/`actions` API and never participates in pinning —
the constructor choice *is* the mode, so the two APIs cannot be mixed on one
bar.

- **The back button is automatic.** It appears whenever the route can be
  popped (`ModalRoute.impliesAppBarDismissal`) and never on a root route. The
  default action is `Navigator.maybePop` — what Flutter's own `BackButton`
  calls, and what Pages-API routers handle correctly. Override with `onBack`
  for router-specific semantics such as go_router's `context.pop()`, or set
  `backButton: false` to suppress it.
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
- **`GlassBarItem.menu` is the `UIBarButtonItem.menu` analogue.** The whole
  capsule morphs into the pull-down, matching iOS 26's `GlassEffectContainer`
  and `GlassButtonGroupItem.menu`. Only the first menu item in a cluster opens
  a menu; a second is treated as a plain icon. A menu cannot be opened while a
  transition is running, and one already open is dismissed if navigation
  starts — the capsule outlives the route that owns the menu, so nothing else
  would take it down.
- **Participation is the constructor.** A `GlassAppBar.pinned` screen keeps
  the chrome pinned even with no actions; a plain `GlassAppBar` screen does
  not participate, and the pinned chrome retreats while it covers the bar.

## Behaviour and constraints

| Situation | Behaviour |
|---|---|
| Push/pop between participating routes | Chrome pinned; the capsule morphs — a gel swell past its resting width, a spring to the target that overshoots and settles — while item positions ride the same spring; glyphs blur out and arrive soft, sharpening last |
| Interactive back-swipe | Same interpolation, scrubbed by the gesture; cancelled swipes rebound |
| Destination has no actions (or no back button) | The cluster gels out and in through scale on the same spring — glass opacity cannot animate, scale can |
| Tap while a transition runs | Ignored. The chrome is showing a blend of two routes' items, so a tap would fire an action the user can no longer see |
| Navigation starts with a menu open | The menu is dismissed; the capsule outlives the route, so nothing else would |
| Non-participating route or modal sheet on top | Chrome retreats with the covering route's transition and returns on pop |
| No shell installed, or `GlassQuality.minimal` | `GlassAppBar.pinned` renders in-route: automatic back `GlassButton` + `GlassButtonGroup.icons` capsule |

Glass opacity is never animated (a glass surface's backdrop pass renders fully
or not at all); only geometry animates, and only item *contents* cross-fade
and blur. The morph rides the package's bouncy spring profile for the full
length of the route transition — capsule and page share one clock, so the
bounce settles in the same breath the page lands, and a pop plays the same
forward choreography toward the other cluster rather than the push in
reverse. The gel swell is real geometry: the cluster lays out at scale and
the glass re-renders its true shape, carrying the glyphs with it. Timing and
blur constants live together in `GlassNavPinnedMetrics`.

## Direction

`GlassAppBar.pinned` is deliberately the opt-in, not the default — but that
is a transition state, not the end state. On iOS 26 the pinned behaviour *is*
the navigation bar, so the intended trajectory is:

1. Land the data API additively (this release) — nothing shipped changes.
2. Bring `GlassBarItem` to parity with the widget API. Menus have landed;
   what remains is text styles (small) and spacers / multi-capsule grouping /
   prominent items (structural — one capsule becomes *n*, and the count can
   differ between the two routes).
3. At the next major, make pinning the default `GlassAppBar` and demote the
   widget-based `leading`/`actions` constructor to a legacy mode.

Screens written against `GlassAppBar.pinned` today are already written for
that future.

## Current limitations

- `GlassBarItem.spacer()` (multi-capsule grouping, mirroring
  `ToolbarSpacer`/`fixedSpace`) is parsed but not rendered yet; a cluster
  containing one asserts in debug mode.
- Changing a pinned bar's `actions` in place via `setState` swaps the capsule's
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
