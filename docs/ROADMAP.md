# Roadmap: 1.x → 2.0

> Last updated: 2026-08-27 (reflecting 1.1.0 shipped state)

This document tracks planned and future work for `liquid_glass_widgets` post-1.0.
The guiding principle remains: **fewer, better widgets that map 1:1 to real iOS 26 components**.

For historical version notes (0.14 → 1.0), see [`CHANGELOG.md`](../CHANGELOG.md).

---

## Current Status (1.1.0)

| Criterion | Status | Notes |
|---|---|---|
| No known P0/P1 bugs | ✅ Clear | No open crash reports |
| Dartdoc complete on all public API | ✅ Done | `public_member_api_docs` enforced permanently |
| Test coverage ≥ 90% | ✅ Done | ~92% line coverage (physical ceiling) |
| No `Icons.*` (Material) in `lib/` | ✅ Done | Zero hits — fully `CupertinoIcons` |
| No hardcoded `Colors.*` in `lib/` | ✅ Done | All replaced with `CupertinoColors` or explicit hex `Color` literals |
| `material.dart` imports in `lib/` | ✅ Done | 36 → 0 files |
| Light mode + dark mode | ✅ Done | `GlassTheme.brightnessOf` is the single brightness authority |
| RTL layout verified | ✅ Done | `EdgeInsetsDirectional` / `AlignmentDirectional` audit complete |
| Keyboard / Tab focus / Enter-Space | ✅ Done | `GlassFocusRegion`, focus ring, semantics on all 12 widget families |
| `docs/PLATFORM_SUPPORT.md` | ✅ Done | All platforms, shader tiers, known bugs documented |
| Navigation transition morph | ✅ Done (1.1.0) | `GlassNavigationShell` + `GlassAppBar.pinned` (#221) |
| Scroll-to-minimize | ✅ Done (1.1.0) | `GlassTabBarMinimizeController`, all four behaviour cases (#228) |
| Tab bar bottom accessory | ✅ Done (1.1.0) | `bottomAccessory` / `bottomAccessoryHeight` on `GlassTabBar.bottom()` |
| Example app covers all widgets | ⚠️ Partial | Not verified against current widget catalogue |
| Platform testing matrix complete | ⚠️ Partial | iOS + Android confirmed; Web, Windows, macOS need QA |
| CHANGELOG migration guides | ⚠️ Partial | Not audited for all 1.0.x → 1.1.0 changes |
| README widget table accurate | ⚠️ Stale | Last updated for ~0.15 era |

---

## Active: 1.1.x Hardening

### Scroll Edge Effect Fidelity (Shipped in 1.2.0)

`GlassScrollEdgeEffect` and `GlassScaffold` now default to `GlassScrollEdgeStyle.blur`,
composing `ProgressiveBlur` with a 2-pass separable Gaussian shader (`shaders/progressive_blur.frag`).
Content scrolling beneath navigation chrome now progressively blurs live (matching iOS 26
`.scrollEdgeEffectStyle`), preserving contrast and legibility for bar controls while keeping
underlying content visible. `maxSigma` is configurable and can be driven from scroll offset.

See [`docs/PROGRESSIVE_BLUR.md`](PROGRESSIVE_BLUR.md) for the `ProgressiveBlur` API.

### Named `LiquidGlassSettings` Presets

The package exposes 22 `LiquidGlassSettings` parameters. Apple ships two named
variants (`.regular`, `.clear`). In practice, the demo source contains calibrated
presets (`_barGlassSettings`, `_kPillGlass`, `_kTriggerGlass`) that consumers
copy out of demo files because the generic `interactive` preset reads flat in
production. The demos are the real design system, and the design system should
be in the package.

**Planned:** Named constructors on `LiquidGlassSettings`:

```dart
LiquidGlassSettings.regular({Brightness brightness})  // adaptive control glass
LiquidGlassSettings.clear({Brightness brightness})    // media-rich; pairs with backerColor
LiquidGlassSettings.chrome({Brightness brightness})   // bars/pills — the apple_music values
```

These would be additive (no breaking changes). Secondary: annotate tier-specific
parameters consistently with a `/// Premium only.` or `/// Standard only.` first line.

### Nested Glass: Debug Assert + Vibrancy Fill

When a `GlassEffect` descendant reads `InheritedLiquidGlass(avoidsRefraction: true)`
(set by `GlassContainer`), the inner glass effect currently renders with no visible
surface at all — not a "degraded" surface as documented. The failure looks like a
broken widget, not a guardrail.

**Planned (in order of preference):**

1. **Vibrancy fill fallback** — when `avoidsRefraction: true`, render as a translucent
   tinted fill with the rim/specular preserved but the lens dropped. Approximates the
   iOS 26 vibrancy layer behaviour.
2. **Debug assert** — if (1) is too large for this cycle, at minimum assert in debug
   mode with a message naming the offending ancestor. A silent invisible widget is the
   worst available outcome.

---

## Post-1.0 Candidates

Ideas under consideration. None committed.

### New Widgets

- [ ] `GlassSplitView` — proper `UISplitViewController` equivalent with adaptive
  columns, swipe-to-collapse, and navigation state. **Large scope — requires
  dedicated planning before implementation.**
- [ ] `GlassColorWell` — iOS 26 colour picker pill. Scoped as a trigger widget:
  a tappable glass swatch that opens a `GlassPopover`; colour picker content
  is supplied by the caller.

### Enhancements

- [ ] **Scroll-driven glass materialisation** — app bar surface transitions from
  transparent to frosted on scroll. Closely related to the scroll edge fidelity
  fix above; the two may ship together when `GlassScrollEdgeStyle.blur` lands.
- [ ] **`GlassAppBar` Phase 3 compact search icon** — when `GlassLargeTitle.searchBar`
  and `GlassAppBar.largeTitleController` are in use and `searchBarCollapseProgress == 1.0`,
  show a compact search affordance that re-expands on tap. Blocked by: `GlassAppBar`
  currently implements `ObstructingPreferredSizeWidget` with a fixed `preferredSize`;
  Phase 3 requires dynamic height, touching the layout contract with `CupertinoPageScaffold`.
  Phases 1 + 2 (shipped 0.19.6) deliver 90% of the value; Phase 3 is a polish milestone.
- [ ] **`GlassToast` queue management** — show multiple toasts sequentially instead
  of overlapping.
- [ ] **Drag-to-reorder in `GlassTabBar.bottom()`** — long-press to rearrange tabs,
  matching iOS tab bar customisation.
- [ ] **`GlassSheet` snap points** — configurable detent heights (peek / half / full)
  matching `UISheetPresentationController.Detent`.
- [ ] **Materialize at rest** — a pinned bar whose `actions` change via `setState`
  still swaps instantly. The route-driven effect is a pure function of transition
  progress; at rest there is none, so this needs a local spring plus reconciliation
  when a route transition starts mid-animation. The phase rail is already in place.
- [ ] **Per-item content blur during cluster morphs** — items entering or leaving a
  *surviving* capsule cross-fade but do not blur, unlike a whole cluster that
  materializes. An `ImageFiltered` per item per frame needs to earn its saveLayer.
- [ ] **`GlassNavigationTransition` pinning as default** — the `.pinned` constructor
  is the transition vehicle; once `GlassBarItem` reaches parity with the widget API,
  a major release can make the data-driven API the plain `GlassAppBar`. Remaining
  parity work: text/prominent item styles, `GlassBarItem.spacer()` rendering with
  multi-capsule grouping.

### Platform Edge Cases

- [ ] **CanvasKit Web circular clipping** — `LiquidOval` relies on
  `ClipRRect(borderRadius: 9999)` to work around an iOS PlatformView compositing
  bug (Flutter #177551). On Web (CanvasKit) this massive radius breaks path clipping.
  Needs `ClipOval` / `BoxShape.circle` on Web, or an upstream engine fix.
- [ ] **`platformViewBackdrop` quality cliff** — when `platformViewBackdrop: true`,
  rendering is capped at `_FrostedFallback` regardless of requested quality tier.
  The `platformViewBackdrop` dartdoc explains this, but the long-term fix is upstream:
  make `RepaintBoundary`/`ImageFilter` capture include hybrid-composed PlatformViews.

### Accessibility

- [ ] **`reduceTransparency` native detection** — `GlassAccessibilityScope` currently
  approximates Reduce Transparency via `MediaQuery.highContrastOf(context)`, which maps
  to **Increase Contrast** on iOS — a different toggle. A small method channel reading
  `UIAccessibility.isReduceTransparencyEnabled` would give exact detection. Until then,
  the README notes the approximation.
- [ ] **Light-mode golden tests** — add golden snapshots for key widgets in
  `Brightness.light` to catch regressions.

### Documentation and pub.dev

- [ ] **Widget catalogue page** — README or docs/ page with screenshots of every
  widget in both quality modes.
- [ ] **Screenshots** — 3–5 screenshots in `pubspec.yaml` for the pub.dev listing.
- [ ] **Analysis score** — ensure 160/160 pub points.
- [ ] **Dedicated documentation site** (GitHub Pages or similar).
- [ ] **Figma/Sketch component library** matching the widget catalogue.
- [ ] **VS Code / IntelliJ snippet pack** for common widget patterns.

### Ecosystem

- [ ] `GlassFilterBar` — horizontal scrollable chip row (the `GlassTabBar(isScrollable: true)`
  successor). Variable-width items, momentum physics, tap-only selection, no safe-area
  handling. The `isScrollable` flag on `GlassTabBar` is a deprecation candidate.

---

## Semver Commitment (from 1.0.0)

- **Patch** (1.0.x / 1.1.x): Bug fixes only.
- **Minor** (1.x.0): New widgets, new parameters, non-breaking additions.
- **Major** (2.0.0): Breaking changes (widget removal, parameter rename, behaviour change).

Deprecated symbols from the 1.x series (`GlassBottomBar`, `GlassSearchableBottomBar`,
`GlassBottomBarTab`, `GlassTabBar(isScrollable: true)`) are scheduled for removal in 2.0.0.
