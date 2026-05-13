# Architecture Guide

This document describes the internal architecture of `liquid_glass_widgets` for contributors and future maintainers.

---

## File Layout Convention

```
lib/
├── liquid_glass_widgets.dart     ← Public barrel (only export from here)
├── constants/
│   └── glass_defaults.dart       ← Static const values only — never test directly
├── types/                        ← Public enums and data types
├── theme/                        ← GlassTheme, GlassThemeData, GlassThemeHelpers
├── utils/                        ← Pure utilities (testable in isolation)
│   ├── draggable_indicator_physics.dart
│   └── glass_spring.dart
└── widgets/
    ├── interactive/              ← Leaf widgets (buttons, inputs, toggles)
    ├── shared/                   ← Package-internal shared sub-widgets (NOT exported)
    │   ├── adaptive_glass.dart
    │   ├── animated_glass_indicator.dart
    │   └── ...
    └── surfaces/                 ← Public surface/container widgets
        ├── glass_bottom_bar.dart
        ├── glass_tab_bar.dart
        ├── glass_searchable_bottom_bar.dart
        └── shared/               ← Internal widgets for bar-family surfaces
            ├── bottom_bar_internal.dart
            ├── tab_bar_internal.dart
            ├── searchable_bottom_bar_internal.dart
            └── glass_search_bar_config.dart   ← Shared config type (IS exported)
```

---

## The Internal Widget Extraction Pattern

Every bar-family widget (`GlassBottomBar`, `GlassTabBar`, `GlassSearchableBottomBar`) follows a strict two-file pattern.

### Rule: Public file = API only

The `glass_*.dart` file contains **only**:
- The public `StatefulWidget` class with full dartdoc
- Its `State` class (thin — only wires the public API to the internal widget)
- Public configuration data classes (e.g. `GlassTab`, `GlassBottomBarTab`)

It must **not** contain any stateful sub-widgets with gesture logic.

### Rule: Internal file = all logic

The `shared/*_internal.dart` file contains:
- All stateful sub-widgets (formerly `_PrivateWidget` classes)
- Gesture handlers, spring builders, drag physics
- Rendering helper methods (`_buildSimpleMode`, `_buildHighQualityMode` etc.)
- Pure utility functions annotated `@visibleForTesting`

The internal file is **not exported** from `liquid_glass_widgets.dart`.

### Why this pattern?

1. **Readability**: Public API is immediately clear without scrolling 1,000+ lines
2. **Testability**: Internal classes can be named (non-private) and constructed directly in tests
3. **Circular import prevention**: Config types that need to be imported by both the public widget and the internal widget live in their own `shared/` file (see `glass_search_bar_config.dart`)

### Current file sizes (v0.7.16)

| File | Lines | Internal file |
|---|---|---|
| `glass_bottom_bar.dart` | ~895 | `shared/bottom_bar_internal.dart` |
| `glass_tab_bar.dart` | ~310 | `shared/tab_bar_internal.dart` |
| `glass_searchable_bottom_bar.dart` | ~820 | `shared/searchable_bottom_bar_internal.dart` |

---

## Import Rules

```
liquid_glass_widgets.dart
  └── exports glass_*.dart (public widgets)
  └── exports glass_search_bar_config.dart (shared config — IS public)
  └── does NOT export *_internal.dart files

glass_bottom_bar.dart
  └── imports shared/bottom_bar_internal.dart
  └── JellyClipper defined here (imported by bottom_bar_internal via `show`)

shared/bottom_bar_internal.dart
  └── imports glass_bottom_bar.dart show GlassBottomBarTab, GlassBottomBarExtraButton, JellyClipper
  └── imports shared/glass_search_bar_config.dart (NOT glass_searchable_bottom_bar.dart)
```

**Critical rule**: Never import a public widget file from its own internal file for anything other than its public data types via an explicit `show` clause. That is how the circular dependency was introduced in the first place and resolved in v0.7.16.

---

## Test Coverage Ceiling

**Effective coverage (renderer excluded): ~91.8 %** — 4 146 / 4 514 lines\
**Raw Codecov badge: ~81 %** — 4 496 / 5 553 lines (includes untestable GPU renderer)

The Codecov badge shows the raw number because that is what `lcov.info` contains.
The gap between 81 % and 91.8 % is accounted for entirely by `lib/src/renderer/`
(16 files, ~1 039 lines) — GPU `CustomPainter`, `RenderObject`, and shader-loading
paths that require a real GPU rasterizer and cannot be exercised in a headless VM.

The CI threshold gate strips `lib/src/renderer/*` before checking the 90 % floor,
so the gate measures effective coverage and will not false-fire on the renderer.

The remaining ~8.2 % (effective) should not be pursued:

| Category | Examples | Why untestable |
|---|---|---|
| GPU renderer paths | `paint()` in `CustomPainter` subclasses, shader uniform setters | Requires real GPU rasterizer — headless VM has no rasterizer |
| Web-only branches | `kIsWeb` blocks, `_captureBackgroundAsync` | Test VM is not a web runtime |
| Impeller warmup | `preWarm()` in `GlassEffect` | Shader loading fails silently in headless |
| Private constructors | `GlassDefaults._()`, singletons | Intentionally uncallable |
| Error catch branches | `toImageSync` catch | Only fires on real hardware failure |

**Do not** add workarounds (mocks of `kIsWeb`, fake GPU contexts) to push coverage
past this ceiling — the complexity is not worth it and the tests would not
represent real behaviour.

---

## Bug Fixes Reference (v0.7.16)

### Memory Leak — `GlassSearchableBottomBar`
When `controller` was replaced at runtime, `didUpdateWidget` attached a new listener without removing the old one. Pattern to follow everywhere a `ChangeNotifier` is used:

```dart
@override
void didUpdateWidget(covariant MyWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.controller != widget.controller) {
    oldWidget.controller.removeListener(_onControllerChanged); // ← always remove first
    widget.controller.addListener(_onControllerChanged);
  }
}

@override
void dispose() {
  widget.controller.removeListener(_onControllerChanged);
  super.dispose();
}
```

### NaN/Infinity Guard — `DraggableIndicatorPhysics`
A zero-size `RenderBox` (during cold widget tree build) caused division-by-zero in velocity calculation, producing `NaN` velocities that broke spring snapping. Guard pattern:

```dart
final box = context.findRenderObject() as RenderBox?;
if (box == null || !box.hasSize || box.size.width == 0) return; // ← guard
final velocityX = details.velocity.pixelsPerSecond.dx / box.size.width;
```

---

## Quality System

Widgets resolve rendering quality in this priority order:

1. Explicit `quality:` parameter on the widget
2. `InheritedLiquidGlass` widget quality from an ancestor `LiquidGlassScope`
3. `GlassThemeData.qualityFor(context)` from `GlassTheme`
4. `GlassQuality.standard` (universal fallback)

Surface widgets (`GlassBottomBar`, `GlassAppBar`, `GlassToolbar`, `GlassSideBar`) use `GlassQuality.premium` as their documented default. All other widgets default to `GlassQuality.standard`.

Always resolve via:
```dart
final effectiveQuality = GlassThemeHelpers.resolveQuality(
  context,
  widgetQuality: widget.quality,
  // fallback: GlassQuality.premium  ← only for surface widgets
);
```

### Premium vs. Standard Rendering Physics

There is a fundamental mathematical difference in how visual properties are rendered across quality levels:

*   **Premium (Impeller / 3D Ray-Marched SDF):** 
    Uses a 3D ray-marched signed-distance field. `thickness` extrudes real 3D geometry towards the user, and `lightIntensity` calculates a physical specular reflection bouncing off that bevel.
*   **Standard / Minimal (Skia/Web / 2D Fragment Shader):** 
    Uses a 2D fragment shader or pure Canvas operations. Because there is no 3D geometry, `thickness` is faked via a 2D inner rim/stroke, and `lightIntensity` drives a 2D linear gradient over that rim.

**Tuning Tradeoff:** Because the physics models are entirely different, passing identical high values (e.g., `thickness: 15.0`, `lightIntensity: 1.5`) will look beautifully refractive and deep in Premium, but can look overpowering, thick, and overly bright (like a bold painted stroke) when the device falls back to Standard or Minimal. When designing for the package, it is often best to tune the baseline settings for Standard, or accept that Standard is meant to be a flatter, "frosted macOS" aesthetic while Premium provides the heavy "refractive iOS" look.

> [!NOTE]
> **Proposed Enhancement: Automatic Normalization**
> To solve the tuning tradeoff above without requiring developers to tune multiple settings, we plan to intercept the `LiquidGlassSettings` inside `AdaptiveGlass` before it gets passed to the fallback rendering pipeline. 
> 
> *Implementation Plan:*
> When `!canUsePremiumShader` is true, apply the following scaling logic to the `baseSettings` to map the heavy 3D math down to 2D math safely:
> *   `thickness: baseSettings.effectiveThickness * 0.4`
> *   `lightIntensity: baseSettings.effectiveLightIntensity * 0.6`
> 
> This will ensure that when an app tuned for Premium drops to Standard, the color, line boldness, and brightness remain perceptually identical without looking overly garish.

---

## Release Process

1. All changes go through `mcp_dart-mcp-server_analyze_files` — must return `No errors`
2. Full test suite must pass: `mcp_dart-mcp-server_run_tests`
3. Update `CHANGELOG.md` with the new version entry before tagging
4. Bump `version:` in `pubspec.yaml`
5. Commit, `git tag v<version>`, push both
6. `dart pub publish`

The maintainer (sdegenaar) handles all git operations manually.






Here is a breakdown of the specific variables you can play with in lib/widgets/overlays/shared/glass_menu_internal.dart to adjust the speed, size, and angle.

Feel free to make your adjustments, test them out, and then I can review the final math!

1. Speed of Opening and Closing
The speed is governed by the Flutter physics engine (SpringDescription). Look at lines 51 and 58:

```dart
static const _openSpring = SpringDescription(
    mass: 1.0,
    stiffness: 30.0, // Increase this to make it faster (e.g., 80.0, 150.0)
    damping: 8.0,    // Increase this proportionally so it doesn't bounce forever
  );
  static const _closeSpring = SpringDescription(
    mass: 1.0,
    stiffness: 30.0, 
    damping: 8.0,
  );
  ```

To make it faster: Increase stiffness. You'll need to increase damping as well to maintain the same "feel".
The Close Bump: On line 322 inside _closeMenu(), there is velocityHint: -2.5. This is the initial "kick" that drives the J-curve undershoot on closing. Increase this (e.g., -5.0) for a more violent snap, or decrease it (-1.0) for a softer bump.
2. The Size of the Menu Circle as it Drops (Teardrop Shape)
The teardrop is created by the difference in timing between the position moving and the size growing. Look at lines 368 and 371:

```dart
// The 2.5 is the amplitude of the overshoot. 
    // Increase it to make the blob drop much further down before snapping back up.
    final pathT = const _CustomBackOutCurve(2.5).transform(clampedValue) + closeUndershoot;
    // This controls how fast the blob inflates into a rectangle.
    // Try Curves.easeIn (stays a small circle longer) or Curves.easeOut (inflates to full size immediately).
    final sizeT = Curves.easeInOut.transform(clampedValue) + closeUndershoot;

 ```

3. The Angle / Trajectory of the Drop
Currently, the blob travels in a perfectly straight diagonal line from the button's center to the menu's final center. This is defined by:

```dart
final currentDx = finalDx * pathT;
    final currentDy = finalDy * pathT;

```
Because both X and Y use the exact same pathT multiplier, the path is a straight diagonal.

To create a curved trajectory (e.g., an arc or swoop): You can offset the timing of one axis. For example, if you want it to drop straight down first, and then swing to the right, you could delay the X-axis:

```dart
// Example: Make X lag behind Y to create a curved swooping arc
    final currentDx = finalDx * Curves.easeIn.transform(clampedValue); // or math.pow(pathT, 2)
    final currentDy = finalDy * pathT;
    
```
Go ahead and experiment with these values, and let me know when you want me to review your changes!


Now, the items start fading in exactly halfway through the animation (at 50%) and are fully solid at 100%.

Give it a hot reload! It should drop fast and naturally reveal the items as it lands without any weird flashes or delays. Let me know how it feels!

final itemOpacity = ((value - 0.5) / 0.5).clamp(0.0, 1.0);
