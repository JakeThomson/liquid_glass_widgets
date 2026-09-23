// Parity harness — the package's resting glass beside iOS's own.
//
// Each row pairs a native SwiftUI `glassEffect(.regular)` shape on the left
// with a [GlassButton] of the same geometry on the right, over a backdrop
// chosen to expose one property of the material. [kMode] picks the set:
// `look` is the visual comparison (white, grouped grey, running text, a
// photo-like gradient, black); the others are measurement backdrops — flat
// grey and colour ramps for the body tint, rules and gradients for the lens
// and the frost, single lines and rings for what the rim band samples, and
// the same shapes at other sizes. A screenshot of the two side by side,
// cropped and profiled per row, is how the light-mode recipe in
// [kSettings] was calibrated against the native material.
//
// NOT a showcase demo, which is why it does not live in lib/demos: it will
// not run as-is. It needs the same `liquid_glass_widgets/native_press`
// UIKitView factory the press harness needs, registered in the iOS runner's
// AppDelegate. example/ios is scaffolded per checkout and is not tracked, so
// that registration has to be written by hand before this will start.
//
//   cd example && flutter run -t lib/harnesses/look_parity_harness.dart
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Settings under test. Mirrors the light-mode button recipe of the host app
/// this is being calibrated against; edit here and hot-restart.
const LiquidGlassSettings kSettings = LiquidGlassSettings(
  glassColor: Color(0x87F8F8F8),
  blur: 0.6,
  blurWeight: 0.8,
  frost: 14,
  frostOpacity: 0.73,
  frostClamp: 0.4,
  thickness: 32,
  lightIntensity: 0,
  lightAngle: 1.5708,
  ambientStrength: 0,
  ambientRim: 0,
  fresnelStrength: 0,
  refractiveIndex: 1.24,
  saturation: 2.1,
  chromaticAberration: 0,
  edgeAbsorption: 0.035,
  rimShade: 1,
  frostWeight: 2.0,
  rimLight: 1,
  lensModel: GlassLensModel.paraxial,
  shadow: [
    BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 7)),
  ],
);

/// Dark-mode counterpart of [kSettings], calibrated against the native
/// material with `.dark` appearance.
const LiquidGlassSettings kDarkSettings = LiquidGlassSettings(
  glassColor: Color(0x1FFFFFFF),
  blur: 0.6,
  blurWeight: 2.5,
  frost: 14,
  frostOpacity: 0.85,
  frostClamp: -0.45,
  thickness: 32,
  lightIntensity: 0,
  lightAngle: -1.5708,
  ambientStrength: 0,
  ambientRim: 0,
  fresnelStrength: 0,
  refractiveIndex: 1.24,
  saturation: 1.4,
  chromaticAberration: 0,
  edgeAbsorption: 0.035,
  rimShade: 0.45,
  rimShadeEnds: 0,
  frostWeight: 0.5,
  rimLight: 1.15,
  lensModel: GlassLensModel.paraxial,
  shadowElevation: 0,
);

/// Bare lens for the ramp probes: the same geometry as [kSettings] with every
/// colour and light term switched off.
const LiquidGlassSettings kProbeSettings = LiquidGlassSettings(
  glassColor: Color(0x00000000),
  blur: 1.0,
  thickness: 32,
  lightIntensity: 0,
  lightAngle: 1.5708,
  ambientStrength: 0,
  ambientRim: 0,
  fresnelStrength: 0,
  refractiveIndex: 1.24,
  lensModel: GlassLensModel.paraxial,
  saturation: 1.0,
  chromaticAberration: 0,
  edgeAbsorption: 0,
  shadowElevation: 0,
);

/// When true, the package button in the first row is pressed and held from
/// 2.5 s to 6 s after launch, so a screenshot from the shell can check the
/// pressed state without touch injection.
const bool kPress = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(child: const _App()));
  if (kPress) {
    // Host centre of the first row's package side, in logical px.
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final rowHeight = view.physicalSize.height / view.devicePixelRatio / 5;
    final at = Offset(kHostCentres[1], rowHeight / 2);
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      GestureBinding.instance.handlePointerEvent(
        PointerDownEvent(pointer: 99, position: at),
      );
      debugPrint('PRESS down at $at');
    });
    Future<void>.delayed(const Duration(milliseconds: 6000), () {
      GestureBinding.instance.handlePointerEvent(
        PointerUpEvent(pointer: 99, position: at),
      );
      debugPrint('PRESS up');
    });
  }
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => const CupertinoApp(
        debugShowCheckedModeBanner: false,
        title: 'Look Parity',
        theme: CupertinoThemeData(brightness: Brightness.light),
        home: LookParityHarness(),
      );
}

/// Which set of backdrops to show. `look` is the visual comparison; `greys`
/// and `colors` are flat ramps used to fit the body transfer curve.
const String kMode = 'look';

/// Scene the `sweep` mode repeats per entry of [kSweep]: `stripes`, `text`,
/// `dark_text` or `dark_stripes`.
const String kSweepScene = 'stripes';

/// Shape size of the `text` sweep scene.
const Size kSweepButton = Size(56, 56);

/// Five recipes shown one per row against the same native host.
final List<LiquidGlassSettings> kSweep = [
  kSettings,
  kSettings.copyWith(frostWeight: 1),
  kSettings.copyWith(blurWeight: 1),
  kDarkSettings,
  kDarkSettings.copyWith(frostWeight: 1),
];

/// Shows the native and package resting glass side by side over five
/// backdrops.
class LookParityHarness extends StatelessWidget {
  /// Creates the parity harness.
  const LookParityHarness({super.key});

  @override
  Widget build(BuildContext context) {
    final scenes = switch (kMode) {
      'sweep' => [
          for (final settings in kSweep)
            switch (kSweepScene) {
              'text' => _Scene(
                  backdrop: const _TextLines(dark: false),
                  button: kSweepButton,
                  settings: settings,
                ),
              'dark_text' => _Scene(
                  backdrop: const _TextLines(dark: true),
                  dark: true,
                  settings: settings,
                ),
              'dark_grey' => _Scene(
                  backdrop: const _Flat(Color(0xFF1C1C1E)),
                  dark: true,
                  settings: settings,
                ),
              'dark_stripes' => _Scene(
                  backdrop: const _Lines(vertical: true, width: 4, gap: 4),
                  dark: true,
                  button: const Size(80, 80),
                  settings: settings,
                ),
              _ => _Scene(
                  backdrop: const _Lines(vertical: true, width: 4, gap: 4),
                  button: const Size(80, 80),
                  settings: settings,
                ),
            },
        ],
      'dark' => const [
          _Scene(backdrop: _Flat(Color(0xFF000000)), dark: true),
          _Scene(backdrop: _Flat(Color(0xFF1C1C1E)), dark: true),
          _Scene(backdrop: _TextLines(dark: true), dark: true),
          _Scene(backdrop: _Photo(), dark: true),
          _Scene(backdrop: _Flat(Color(0xFFFFFFFF)), dark: true),
        ],
      'dark_greys' => const [
          _Scene(backdrop: _Flat(Color(0xFF000000)), dark: true),
          _Scene(backdrop: _Flat(Color(0xFF404040)), dark: true),
          _Scene(backdrop: _Flat(Color(0xFF808080)), dark: true),
          _Scene(backdrop: _Flat(Color(0xFFC0C0C0)), dark: true),
          _Scene(backdrop: _Flat(Color(0xFFFF0000)), dark: true),
        ],
      'greys' => const [
          _Scene(backdrop: _Flat(Color(0xFF000000)), dark: true),
          _Scene(backdrop: _Flat(Color(0xFF404040)), dark: true),
          _Scene(backdrop: _Flat(Color(0xFF808080))),
          _Scene(backdrop: _Flat(Color(0xFFC0C0C0))),
          _Scene(backdrop: _Flat(Color(0xFFE0E0E0))),
        ],
      'colors' => const [
          _Scene(backdrop: _Flat(Color(0xFFFF0000))),
          _Scene(backdrop: _Flat(Color(0xFF00A000))),
          _Scene(backdrop: _Flat(Color(0xFF0000FF))),
          _Scene(backdrop: _Flat(Color(0xFF3A7BD5))),
          _Scene(backdrop: _Flat(Color(0xFFF7C948))),
        ],
      'sizes' => const [
          _Scene(backdrop: _Flat(Color(0xFFFFFFFF)), button: Size(44, 44)),
          _Scene(backdrop: _Flat(Color(0xFFFFFFFF)), button: Size(80, 80)),
          _Scene(
              backdrop: _Flat(Color(0xFFFFFFFF)),
              button: Size(132, 44),
              capsule: true),
          _Scene(
              backdrop: _Flat(Color(0xFFF2F2F7)),
              button: Size(124, 56),
              capsule: true),
          _Scene(backdrop: _Flat(Color(0xFF808080)), button: Size(80, 80)),
        ],
      'sizes_stripes' => const [
          _Scene(
              backdrop: _Lines(vertical: true, width: 4, gap: 4),
              button: Size(44, 44)),
          _Scene(
              backdrop: _Lines(vertical: true, width: 4, gap: 4),
              button: Size(80, 80)),
          _Scene(
              backdrop: _Lines(vertical: true, width: 4, gap: 4),
              button: Size(132, 44),
              capsule: true),
          _Scene(
              backdrop: _Ramp(vertical: false),
              button: Size(44, 44),
              probe: true),
          _Scene(
              backdrop: _Ramp(vertical: false),
              button: Size(80, 80),
              probe: true),
        ],
      'lines' => const [
          _Scene(backdrop: _Probe(bar: 10, barEnd: 12), probe: true),
          _Scene(backdrop: _Probe(bar: 15, barEnd: 17), probe: true),
          _Scene(backdrop: _Probe(bar: 20, barEnd: 22), probe: true),
          _Scene(backdrop: _Probe(bar: 24, barEnd: 26), probe: true),
          _Scene(backdrop: _Probe(bar: 27, barEnd: 29), probe: true),
        ],
      'probe' => const [
          _Scene(backdrop: _Probe(bar: 8, barEnd: 20), probe: true),
          _Scene(backdrop: _Probe(ring: 15, ringEnd: 17), probe: true),
          _Scene(backdrop: _Probe(ring: 10, ringEnd: 12), probe: true),
          _Scene(backdrop: _Probe(ring: 20, ringEnd: 22), probe: true),
          _Scene(backdrop: _Probe(bar: 30, barEnd: 40), probe: true),
        ],
      'ramp' => const [
          _Scene(backdrop: _Ramp(vertical: false), probe: true),
          _Scene(backdrop: _Ramp(vertical: true), probe: true),
          _Scene(backdrop: _Step(), probe: true),
          _Scene(backdrop: _Ramp(vertical: false)),
          _Scene(backdrop: _Step()),
        ],
      'stripes' => const [
          _Scene(backdrop: _Lines(vertical: true, width: 1, gap: 6)),
          _Scene(backdrop: _Lines(vertical: false, width: 1, gap: 6)),
          _Scene(backdrop: _Lines(vertical: true, width: 2, gap: 12)),
          _Scene(backdrop: _Lines(vertical: true, width: 4, gap: 4)),
          _Scene(backdrop: _Lines(vertical: false, width: 4, gap: 4)),
        ],
      _ => const [
          _Scene(backdrop: _Flat(Color(0xFFFFFFFF))),
          _Scene(backdrop: _Flat(Color(0xFFF2F2F7))),
          _Scene(backdrop: _TextLines()),
          _Scene(backdrop: _Photo()),
          _Scene(backdrop: _Flat(Color(0xFF000000))),
        ],
    };
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      child: Column(children: scenes),
    );
  }
}

/// One backdrop with a native/package pair centred over it.
class _Scene extends StatelessWidget {
  const _Scene({
    required this.backdrop,
    this.dark = false,
    this.probe = false,
    this.button = const Size(56, 56),
    this.capsule = false,
    this.settings,
  });

  /// Package settings for this scene; the recipe for [dark] when null.
  final LiquidGlassSettings? settings;

  final Widget backdrop;
  final bool dark;

  /// Size of the glass shape; a circle unless [capsule].
  final Size button;
  final bool capsule;

  /// Package side rendered with a bare lens — no tint, light or rim — so the
  /// pixel value is the refracted sample and nothing else.
  final bool probe;

  @override
  Widget build(BuildContext context) {
    final host = Size(button.width + 64, button.height + 64);
    final pair = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox.fromSize(
          size: host,
          child: UiKitView(
            viewType: 'liquid_glass_widgets/native_press',
            creationParams: <String, Object>{
              'shape': capsule ? 'capsule' : 'circle',
              'width': button.width,
              'height': button.height,
              'dark': dark,
            },
            creationParamsCodec: const StandardMessageCodec(),
          ),
        ),
        SizedBox.fromSize(
          size: host,
          child: AdaptiveLiquidGlassLayer(
            settings: settings ??
                (probe
                    ? kProbeSettings
                    : dark
                        ? kDarkSettings
                        : kSettings),
            child: Center(
              child: GlassButton.custom(
                width: button.width,
                height: button.height,
                shape: capsule
                    ? LiquidRoundedRectangle(borderRadius: button.height / 2)
                    : const LiquidOval(),
                useOwnLayer: true,
                settings: settings ??
                    (probe
                        ? kProbeSettings
                        : dark
                            ? kDarkSettings
                            : kSettings),
                quality: GlassQuality.premium,
                label: 'Add',
                onTap: () {},
                child: capsule
                    ? const Text(
                        'Label',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000000),
                          decoration: TextDecoration.none,
                        ),
                      )
                    : Icon(
                        CupertinoIcons.plus,
                        size: 22,
                        color: dark
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFF000000),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
    return Expanded(
      child: Stack(
        fit: StackFit.expand,
        children: [
          backdrop,
          CupertinoTheme(
            data: CupertinoThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            child: Center(child: pair),
          ),
        ],
      ),
    );
  }
}

class _Flat extends StatelessWidget {
  const _Flat(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(color: color);
}

/// Host-box centres of the native and package sides, in logical px from the
/// row's left edge: two 120 pt hosts spaced evenly across a 402 pt row.
const List<double> kHostCentres = [114, 288];

/// A grey ramp centred on each host: 0 at 40 pt before the centre, 255 at
/// 40 pt after it. Reading the grey back gives the sampled position directly.
class _Ramp extends StatelessWidget {
  const _Ramp({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _RampPainter(vertical));
}

class _RampPainter extends CustomPainter {
  const _RampPainter(this.vertical);

  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF808080));
    for (final cx in kHostCentres) {
      final c = vertical ? size.height / 2 : cx;
      final rect = vertical
          ? Rect.fromLTRB(cx - 60, c - 40, cx + 60, c + 40)
          : Rect.fromLTRB(cx - 40, 0, cx + 40, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
            end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
            colors: const [Color(0xFF000000), Color(0xFFFFFFFF)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_RampPainter old) => old.vertical != vertical;
}

/// Black features at known offsets from each host centre: a vertical bar
/// from [bar] to [barEnd] pt right of the centre, or a ring from [ring] to
/// [ringEnd] pt. Where the feature shows up under the glass tells which
/// backdrop position each rim pixel samples.
class _Probe extends StatelessWidget {
  const _Probe({this.bar, this.barEnd, this.ring, this.ringEnd});

  final double? bar;
  final double? barEnd;
  final double? ring;
  final double? ringEnd;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ProbePainter(bar, barEnd, ring, ringEnd));
}

class _ProbePainter extends CustomPainter {
  const _ProbePainter(this.bar, this.barEnd, this.ring, this.ringEnd);

  final double? bar;
  final double? barEnd;
  final double? ring;
  final double? ringEnd;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    final black = Paint()..color = const Color(0xFF000000);
    for (final cx in kHostCentres) {
      if (bar != null) {
        canvas.drawRect(
          Rect.fromLTRB(cx + bar!, 0, cx + barEnd!, size.height),
          black,
        );
      }
      if (ring != null) {
        canvas.drawCircle(
          Offset(cx, size.height / 2),
          (ring! + ringEnd!) / 2,
          Paint()
            ..color = const Color(0xFF000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = ringEnd! - ring!,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ProbePainter old) =>
      old.bar != bar ||
      old.barEnd != barEnd ||
      old.ring != ring ||
      old.ringEnd != ringEnd;
}

/// A vertical black/white step 10 pt left of each host centre, so the blurred
/// edge can be read at every distance from the rim.
class _Step extends StatelessWidget {
  const _Step();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _StepPainter());
}

class _StepPainter extends CustomPainter {
  const _StepPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    for (final cx in kHostCentres) {
      canvas.drawRect(
        Rect.fromLTRB(cx - 60, 0, cx - 10, size.height),
        Paint()..color = const Color(0xFF000000),
      );
    }
  }

  @override
  bool shouldRepaint(_StepPainter old) => false;
}

/// Black rules on white at a fixed pitch, to measure refraction and blur.
class _Lines extends StatelessWidget {
  const _Lines(
      {required this.vertical, required this.width, required this.gap});

  final bool vertical;
  final double width;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _LinesPainter(vertical, width, gap));
  }
}

class _LinesPainter extends CustomPainter {
  const _LinesPainter(this.vertical, this.width, this.gap);

  final bool vertical;
  final double width;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    final paint = Paint()..color = const Color(0xFF000000);
    final pitch = width + gap;
    // Centre a rule on the row's centre line so the pattern is symmetric
    // about the buttons.
    final extent = vertical ? size.width : size.height;
    final start = (extent / 2 - width / 2) % pitch;
    for (var p = start; p < extent; p += pitch) {
      canvas.drawRect(
        vertical
            ? Rect.fromLTWH(p, 0, width, size.height)
            : Rect.fromLTWH(0, p, size.width, width),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) =>
      old.vertical != vertical || old.width != width || old.gap != gap;
}

/// Running body text, as a list page would show under a floating button.
/// The same lines are drawn under each host so the two sides read the same
/// content.
class _TextLines extends StatelessWidget {
  const _TextLines({this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 15,
      color: dark ? const Color(0xFFE5E5EA) : const Color(0xFF1C1C1E),
      decoration: TextDecoration.none,
    );
    final lines = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        6,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            i.isEven
                ? 'Groceries for the week and the things'
                : 'Call the dentist \u00b7 Renew the car tax',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: style,
          ),
        ),
      ),
    );
    return ColoredBox(
      color: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      child: Stack(
        children: [
          for (final cx in kHostCentres)
            Positioned(
              left: cx - 90,
              top: 0,
              bottom: 0,
              width: 180,
              child: ClipRect(
                  child: OverflowBox(
                      maxWidth: 400,
                      alignment: Alignment.centerLeft,
                      child: lines)),
            ),
        ],
      ),
    );
  }
}

/// A saturated gradient with structure, so refraction and tint are legible.
class _Photo extends StatelessWidget {
  const _Photo();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A7BD5), Color(0xFFE96A8D), Color(0xFFF7C948)],
        ),
      ),
      child: Row(
        children: List.generate(
          14,
          (j) => Expanded(
            child: ColoredBox(
              color:
                  j.isEven ? const Color(0x33000000) : const Color(0x00000000),
            ),
          ),
        ),
      ),
    );
  }
}
