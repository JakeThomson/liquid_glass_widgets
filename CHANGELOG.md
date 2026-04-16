# 0.7.12

### Bug Fixes

- **FIX**: Interactive blend-group stretch asymmetry — `LiquidStretch` now expands geometry symmetrically from the widget centre, fixing the left-leans-in / right-resists imbalance during touch-drag on button groups.

- **FIX**: Erroneous highlight bias — removed a legacy shader hack that skewed surface normals horizontally. Normals are now derived accurately from the SDF gradient, eliminating optical hotspots that made straight groups look crooked.

- **PERF**: Zero-jitter animation bounds — geometry texture mapping is now strictly bound to the physical size it was rasterised for, stopping frame-lag wobble when buttons change scale during interactive drags.

- **FIX**: Theme quality cascade — audited 15+ widgets (`GlassBottomBar`, `GlassSwitch`, `GlassTextField`, and others) that were silently overriding the global `GlassThemeVariant` quality setting with `GlassQuality.premium`. All widgets now correctly inherit and respect the global quality profile, protecting frame rate and thermal limits on older devices (e.g. iPhone 12 and below).

- **FIX**: Zero-thickness blur — setting `thickness: 0` no longer makes the glass fully transparent. Backdrop blur now renders correctly on glass surfaces regardless of geometric thickness, restoring backward-compatible behaviour.

- **FEAT**: `GlassSearchBarConfig.focusNode` — optional `FocusNode` for `GlassSearchBarConfig`. When provided, the caller has full programmatic focus control (`requestFocus()`, `unfocus()`, `addListener()`) independent of `autoFocusOnExpand`. The widget adopts the caller-provided node without disposing it (caller owns lifecycle), matching Flutter's own `TextField.focusNode` contract.

- **FEAT**: `GlassSearchBar.focusNode` — same `FocusNode` support added to the standalone `GlassSearchBar` for consistency. `GlassTextField` already had this.

- **FIX**: `ExtraButtonPosition` — new enum on `GlassBottomBarExtraButton`. Set `.position = ExtraButtonPosition.afterSearch` to pin the extra button to the **right** of the search pill. Spring geometry calculations reserve space correctly to prevent `RenderFlex` overflows during expand/collapse. Default is `ExtraButtonPosition.beforeSearch` — fully backwards-compatible.

- **FIX**: Windows / SkSL shader compilation — eliminated all dynamic array index expressions from `sdf.glsl`. The previous `getShapeSDFFromArray(int index)` computed offsets at runtime, which SkSL/glslang on Windows rejects with *"index expression must be constant"*. Replaced with literal-indexed `sdf0()`…`sdf15()` helpers and a fully-unrolled `sceneSDF` for 1–16 shapes. `MAX_SHAPES` stays 16; no API or visual change.

- **TOOLING**: `scripts/validate_shaders.sh` — macOS script that validates all shaders against Windows/SkSL compiler rules using `glslangValidator`. Run `bash scripts/validate_shaders.sh` before releasing. Requires `brew install glslang` (one-time).

---

# 0.7.11

### Bug Fixes

- **FIX**: Windows/Android build failure — three shader compilation errors on the SPIR-V/glslang path: loop bounds must be compile-time constants; `dFdx`/`dFdy` on a scalar `float` is rejected by glslang (geometry shader now uses `#ifdef IMPELLER_TARGET_METAL` to keep hardware derivatives on iOS/macOS and fall back to ±0.5 px finite differences on Vulkan/OpenGL ES); global non-constant initialisers at file scope in `liquid_glass_final_render.frag` moved into `main()`.

- **FIX**: Blend-group asymmetry — the liquid-glass merge neck between grouped buttons leaned toward the left button. Fixed with a bidirectional smooth-union pass (L→R + R→L, averaged 50/50) that cancels the directional bias exactly.

---

# 0.7.10

### Bug Fixes

- **FIX**: Windows build (`flutter build windows`) — two shader issues fatal on SkSL/glslang but silently accepted on Metal: `no match for min(int, int)` (replaced with a ternary) and global non-constant initialisers (moved into `main()`). No visual change on any platform.

---

# 0.7.9

### Bug Fixes

- **FIX**: Windows build failure — `uShapeData[MAX_SHAPES * 6]` was passed as a by-value function parameter, which glslang rejects. Fixed by accessing it as a global uniform. No visual change.

### Tweaks

- **TWEAK**: `GlassSearchableBottomBar` iOS 26 Apple News parity — animated inline `×` clear button replaces microphone when text is present; simplified hit-testing layout replaces `Overlay` layers; guaranteed GPU liquid-glass merging between the search and dismiss pills in a single shader pass.

---

# 0.7.8

### Tweaks

- **TWEAK**: `GlassThemeVariant.light` now defaults to a cool-tinted `glassColor` (`Color(0x32D2DCF0)`), stronger `refractiveIndex`, and boosted `ambientStrength` to ensure premium specular rendering and visible refraction on flat white backgrounds.

### Examples

- **Apple News demo** — replaced `Image.network` calls with pre-sized bundled assets (`example/assets/news_images/`) to fix Impeller GPU command-buffer overflow on iOS 26 physical devices.
- **Apple News demo** — `collapsedLogoBuilder` now mirrors the active tab icon instead of a static badge.

---

# 0.7.7

### Refactor

- **Internal**: Removed `GlassIndicatorTapMixin` and migrated `GlassTabBar` and `GlassSegmentedControl` fully to raw `Listener` pointer events, matching `GlassBottomBar`'s robust drag-cancel and press-and-hold handling. No API change.

---

# 0.7.6

### Bug Fixes

- **FIX**: `LiquidGlassBlendGroup` asymmetry — left buttons attracted their neighbours more strongly than right buttons in groups of 3+. Fixed with a bidirectional smooth-union pass (L→R + R→L, averaged 50/50). Two-shape groups are mathematically identical to before.

- **FIX**: `GlassButtonGroup` — glass effect could bleed as a dark rectangle on Impeller with `GlassQuality.premium` and `useOwnLayer: true`. A `ClipRRect(antiAlias)` now hard-clips the bleed at the superellipse boundary without forcing a quality downgrade.

---

# 0.7.5

### Bug Fixes

- **FIX**: `GlassBottomBar` / `GlassSearchableBottomBar` — added `HitTestBehavior.opaque` to the root `GestureDetector` so the full bar height reliably consumes pointer events on simulator and desktop.

- **FIX**: `GlassSearchableBottomBar` — keyboard no longer flickers on physical devices; focus is requested after the expansion animation completes.

- **FIX**: `GlassSearchableBottomBar` — dead zone at expanded search pill edges resolved; the full glass surface now claims taps and routes them to the search field.

### New — `GlassSearchBarConfig` parameters

Seven new parameters (all backwards-compatible):

| Parameter | Type | Default | Description |
|---|---|---|---|
| `autoFocusOnExpand` | `bool` | `false` | Keyboard opens automatically on expand. |
| `trailingBuilder` | `WidgetBuilder?` | `null` | Replaces the mic icon with any custom widget. |
| `textInputAction` | `TextInputAction?` | `null` | Keyboard action key (`search`, `done`, `go`, …). |
| `keyboardType` | `TextInputType?` | `null` | Keyboard layout (`url`, `emailAddress`, …). |
| `autocorrect` | `bool` | `true` | Disable for codes, usernames, etc. |
| `enableSuggestions` | `bool` | `true` | Controls QuickType bar on iOS. |
| `onTapOutside` | `TapRegionCallback?` | `null` | Called when user taps outside the field. |

---

# 0.7.4

### New Components

- **`GlassSearchableBottomBar`** — `GlassBottomBar` with a morphing search pill that shares the same `AdaptiveLiquidGlassLayer` as the tab pill, producing iOS 26 liquid-merge blending. When `isSearchActive` is `true` the tab pill collapses and the search pill expands via spring animation. Configured via `GlassSearchBarConfig`.

### Examples

- **Apple News demo** (`example/lib/apple_news/apple_news_demo.dart`) — iOS 26 Apple News replica showcasing `GlassSearchableBottomBar`.

### Visual Fixes

- **FIX**: Default glow color on press changed from iOS system blue to a brightness-adaptive neutral white (~35% light / ~22% dark), matching iOS 26 glass press behaviour.

---

# 0.7.3

### Performance

- **PERF**: Deleted unused `rotate2d()` from `render.glsl` — it was compiled into every shader binary but never called.
- **PERF**: Eliminated a redundant `normalize()` in `interactive_indicator.frag` by reusing an already-computed length.
- **PERF**: Removed a no-op `canvas.save()`/`canvas.restore()` pair in `GlassGlow` paint.

### Bug Fixes

- **FIX**: `GlassGlow` tracking — glow gradient is now correctly recreated each frame when `glowOffset` changes, fixing the spotlight freezing at its initial position.
- **FIX**: Glow on Skia/Web — `LightweightLiquidGlass` now wraps in `GlassGlowLayer`, giving the Skia path the same light-follows-touch behaviour as Impeller.
- **FIX**: Glow on first touch — spotlight now appears immediately at the tap position instead of sliding in from the widget's top-left corner.
- **FIX**: Glow tracking inside button groups — converted from widget-local to global coordinates so the spotlight correctly follows touches regardless of nesting depth.
- **FIX**: Glow radius on wide buttons — switched from `shortestSide` to `√(width × height)` so the spotlight scales proportionally to the button area.

---

# 0.7.2

### Performance & Polish

- **PERF**: Lightweight shader (`lightweight_glass.frag`) — reduced ALU instruction count ~10–15 ops per fragment; restored the `normalZ` Fresnel ramp to `sqrt(1 − dot(n,n))`.
- **PERF**: Impeller final render shader — eliminated `length()`/`normalize()` from anisotropic specular; made `getHeight()` fully branchless; collapsed four `step()` multiplications into one.
- **PERF**: Dart side — cached light direction trig in `LiquidGlassRenderObject` (only recomputed when `lightAngle` changes); changed `GlassGroupLink.shapeEntries` from `List` to `Iterable` to eliminate per-frame heap allocation.
- **FIX**: Adjusted `GlassBottomBar`, `GlassTabBar`, and `GlassSegmentedControl` spring from 500ms `bouncySpring` to 350ms `snappySpring`, matching iOS 26 segment-indicator physics.

---

# 0.7.1

### Bug Fixes

- **FIX**: `GlassBottomBar`, `GlassTabBar`, `GlassSegmentedControl` — rapid taps no longer prematurely snap the indicator, killing spring physics. Removed pixel-snapping from `onHorizontalDragDown` so taps correctly use spatial distance for the iOS 26 jump animation.

---

# 0.7.0

### New Components

- **`GlassDivider`** — iOS 26-style hairline separator, horizontal and vertical. Theme-adaptive opacity (dark: 20% white / light: 10% black).
- **`GlassListTile`** — iOS 26 Settings-style row with leading icon, title, subtitle, trailing widget, and automatic grouped dividers. Use inside a zero-padding `GlassCard`. Convenience constants: `GlassListTile.chevron`, `GlassListTile.infoButton`.
- **`GlassStepper`** — iOS 26 `UIStepper` equivalent. Compact `−`/`+` glass pill with auto-repeat on hold, `min`/`max` clamping, `wraps` cycling, fractional `step`, and haptic feedback.
- **`GlassWizard` + `GlassWizardStep`** — multi-step flow with numbered indicators, checkmarks, and expandable step content.

### Accessibility

- **`GlassAccessibilityScope`** — reads platform Reduce Motion and Reduce Transparency preferences and propagates them to all glass widgets in its subtree:
  - **Reduce Motion**: spring animations snap instantly.
  - **Reduce Transparency**: replaces the full glass shader pipeline with a plain `BackdropFilter(blur)` + frosted container.
- Semantics updated across all remaining widgets to match iOS `UIAccessibility` conventions.

### Performance

- **PERF**: `GlassSpecularSharpness` enum — replaces `pow(lightCatch, exponent)` (two transcendentals per fragment) with a pure squaring chain in `lightweight_glass.frag`. Zero transcendentals. Default: `.medium`.
- **PERF**: `pow(x, 1.5)` → `x·√x` in Impeller edge lighting — `sqrt()` is a single hardware SFU instruction.
- **PERF**: Anisotropic specular and Fresnel rim brightening ported from the Impeller path to `lightweight_glass.frag`, closing the largest visual gap between rendering paths.
- **PERF**: Content-adaptive glass strength — intensity auto-adjusts based on backdrop luminance on Impeller, or `MediaQuery.platformBrightness` on Skia/Web.

### Developer Experience

- **`GlassRefractionSource`** — renamed from `LiquidGlassBackground` to better reflect its role. `LiquidGlassBackground` remains as a deprecated `typedef` (removed in 1.0.0).
- **Synchronous background capture** — rebuilt using `boundary.toImageSync()` on native (zero CPU↔GPU readback) and async `toImage()` on web.

---

# 0.6.1

### Visual Quality

- **FIX**: True surface normal storage in geometry texture — the geometry pass now stores the SDF-gradient-derived surface normal instead of the refraction displacement vector. The render shader decodes and recomputes displacement via `refract()`. Specular highlights on blended glass shapes (e.g. two overlapping pills) now correctly follow true surface curvature rather than the refraction direction. Single-shape surfaces are visually identical to 0.6.0.
- **FIX**: Anisotropic specular highlights (Impeller) — specular lobe stretched 20% along the surface tangent, producing the horizontal oval highlight that matches iOS 26.
- **FIX**: Fresnel edge luminosity ramp (Impeller) — gentle brightness ramp at grazing angles matching iOS 26's centre-to-edge luminosity gradient.
- **FIX**: Luminosity-preserving glass tint in lightweight shader — replaced additive tint with the same `applyGlassColor()` model as the Impeller path: achromatic glass lifts toward white, chromatic glass shifts hue while preserving luminance.

### Performance

- **PERF**: Branchless `smoothUnion` — eliminated a conditional branch that caused warp divergence when glass shapes transition between merged and separate.
- **PERF**: `if/else if` dispatch in shape SDF — GPU now short-circuits after the first type match; default changed to `0.0` for a clearly visible failure mode.
- **PERF**: Single texture fetch when chromatic aberration is disabled — `interactive_indicator.frag` previously sampled the background three times unconditionally; 66% fewer texture reads in the common case.
- **PERF**: Flat-interior early-exit in final render shader — pixels where `normalXY ≈ 0` skip `refract()` and all texture samples, replaced with a single background sample. Lossless.

---

# 0.6.0

### Breaking Changes

- **`LiquidGlassLayer.useBackdropGroup` removed.** Glass layers now automatically detect a `BackdropGroup` ancestor. Remove `useBackdropGroup: true` from any `LiquidGlassLayer(...)` calls.

### New Features

- **`LiquidGlassWidgets.wrap()`** — wraps your app in a `GlassBackdropScope` in one line:
  ```dart
  runApp(LiquidGlassWidgets.wrap(const MyApp()));
  ```
- **`GlassMotionScope`** — drives glass specular angle from any `Stream<double>` (e.g. device gyroscope). No new dependencies required.

### Performance

- **PERF**: `GlassBackdropScope` auto-activation — glass layers automatically share a single GPU backdrop capture when a scope ancestor is present.
- **PERF**: Local-space geometry rasterization — geometry texture cached until pill size or shape changes, eliminating per-frame rebuilds during animation.
- **PERF**: Shader UV bounds check — discards fragments where geometry UV falls outside `[0, 1]`, preventing the thin "protruding line" artifact during jelly-physics expansion.

### Visual

- **FIX**: Refraction UV — uses `uSize` uniform (always valid on first frame) instead of `textureSize()` which returns `(0,0)` on the first frame in Impeller.
- **FIX**: `precision highp float` in final render shader (was `mediump`, risking colour banding on mobile).
- **FIX**: iOS 26 glass tint model — preserves backdrop luminance while shifting chroma. Replaces Photoshop Overlay mode.
- **FIX**: Leading-dot rim artifact — `x / (1 + x)` soft-clamping on highlight intensity prevents bright corner artifact during drag.
- **FIX**: Impeller indicator clipping — jelly physics animations no longer clip at the static bounding box (`clipExpansion` parameter added).
- **FIX**: Web & WASM — removed `dart:io` imports from shader resolution logic.

### Dependencies

- **Removed `motor` dependency** — replaced with self-contained `glass_spring.dart`. Zero third-party runtime dependencies beyond the Flutter SDK.

---

# 0.5.0

### Breaking Changes

**`LiquidGlass` removed from the public API.**
It was inadvertently exposed and silently renders nothing on Skia/Web. Use `AdaptiveGlass` instead:

```dart
// Before
LiquidGlass(settings: LiquidGlassSettings(...), child: ...)

// After
AdaptiveGlass(settings: LiquidGlassSettings(...), child: ...)
```

`LiquidGlassLayer`, `LiquidGlassBlendGroup`, `LiquidGlassSettings`, `LiquidShape`, `GlassGlow`, and `debugPaintLiquidGlassGeometry` remain public.

### New Features

- **`GlassBackdropScope`** — halves GPU blur capture cost when multiple glass surfaces are on screen simultaneously. Wrap your `MaterialApp` or `Scaffold` to activate:

```dart
GlassBackdropScope(
  child: MaterialApp(
    home: Scaffold(
      appBar: GlassAppBar(...),
      bottomNavigationBar: GlassBottomBar(...),
    ),
  ),
)
```

### Renderer

The renderer from `liquid_glass_renderer` (whynotmake.it, MIT) is now vendored directly, giving full control over the rendering pipeline with no user-facing API changes.

---

# 0.4.1

### Bug Fixes

- **FIX**: `GlassBottomBar` and other surfaces now correctly respond to dynamic `glassSettings` changes on `GlassQuality.standard` — `AdaptiveGlass` in grouped mode now inherits settings from `InheritedLiquidGlass` instead of using empty defaults.
- **FIX**: Luminance-aware ambient floor for white glass on `GlassQuality.standard` — high-opacity white glass no longer renders as dark grey.

### New

- **FEAT**: `GlassBottomBar.iconLabelSpacing` — configurable vertical gap between tab icon and label (default: `4.0`). Thanks @baneizalfe (#11).

### Breaking Changes

**Library-wide `IconData` → `Widget` API migration.** All icon parameters now accept any `Widget`:

```dart
// Before
GlassButton(icon: CupertinoIcons.heart, onTap: () {})

// After
GlassButton(icon: Icon(CupertinoIcons.heart), onTap: () {})
// Or any custom widget:
GlassButton(icon: SvgPicture.asset('assets/heart.svg'), onTap: () {})
```

`GlassBottomBarTab.selectedIcon` renamed to `activeIcon` to match Flutter's `BottomNavigationBarItem` convention.

---

# 0.4.0

### New Components

- **`GlassMenu` / `GlassMenuItem` / `GlassPullDownButton`** — iOS 26 morphing context menu with spring physics and position-aware expansion.
- **`GlassButtonGroup`** — joined-style container for related actions (e.g. Bold/Italic/Underline toolbar).
- **`GlassFormField`** / **`GlassPasswordField`** / **`GlassTextArea`** / **`GlassPicker`** — full iOS 26 input suite.
- **`GlassSideBar`** — vertical navigation surface with header, footer, and scrollable items.
- **`GlassToolbar`** — standard iOS-style action toolbar.
- **`GlassTabBar`** — horizontal tab navigation bar with animated indicator and scrollable mode for 5+ tabs.
- **`GlassProgressIndicator`** — circular and linear variants (indeterminate and determinate), iOS 26 specs.
- **`GlassToast` / `GlassSnackBar`** — 5 notification types, 3 positions, auto-dismiss, swipe-to-dismiss.
- **`GlassBadge`** — count and dot status badges, 4 positions.
- **`GlassActionSheet`** — iOS-style bottom-anchored action list.

### Performance

- **Universal Platform Support** — `AdaptiveGlass` and `AdaptiveLiquidGlassLayer` introduced. All 26 widgets deliver consistent glass quality on Web, Skia, and Impeller.
- **Batch-blur optimisation** — glass containers share a single `BackdropFilter` (was: one per widget). ~5× faster in common multi-widget layouts.
- **Impeller pipeline warm-up** — shaders pre-compile at startup to eliminate first-frame jank.

### Theme System

- **`GlassTheme` / `GlassThemeData` / `GlassThemeVariant`** — global styling and quality inheritance across all widgets. Set once, inherited everywhere.

---

# 0.3.0 — 0.1.0

Early access and preview releases establishing the core widget library, initial glass rendering pipeline (`LiquidGlass`, `LiquidGlassLayer`, `LiquidGlassBlendGroup`), and foundational components (`GlassBottomBar`, `GlassButton`, `GlassSwitch`, `GlassCard`, `GlassSearchBar`, `GlassSlider`, `GlassChip`, `GlassSegmentedControl`, `GlassSheet`, `GlassDialog`, `GlassIconButton`).
