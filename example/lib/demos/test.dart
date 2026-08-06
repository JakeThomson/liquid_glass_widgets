
// Minimal repro — liquid_glass_widgets #<new>
// "Premium / useOwnLayer glass lens lags & detaches from its content under a
//  continuous ancestor transform (CupertinoSheet drag)".
//
// Env: Flutter 3.44.8 stable · Impeller · iOS 26 · liquid_glass_widgets 0.29.0
//
// Run on an iOS 26 device/simulator:
//   flutter run -t repro/issue1_glass_transform_desync.dart
//
// Steps:
//   1. Tap "Open sheet".
//   2. Drag the sheet up/down SLOWLY.
//   3. Watch the premium glass pill in the app bar. A HIGH-CONTRAST checkerboard
//      sits directly behind it, so the glass refraction is clearly visible — and
//      while the background scales you can see the refracted lens drift AWAY from
//      the pill's frame/text, snapping back when you release.
//
// Compare: switch the GlassContainer below to
//   `useOwnLayer: false, quality: GlassQuality.standard`
// → the lens no longer detaches (inline paint, no transform-tracking layer).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _BackgroundScreen(),
    ),
  ));
}

class _BackgroundScreen extends StatelessWidget {
  const _BackgroundScreen();

  @override
  Widget build(BuildContext context) {
    // GlassPage wires up LiquidGlassScope + backdrop isolation so the premium
    // GlassContainer below has a correctly-sourced backdrop to refract against.
    // Without this, the glass has no isolation scope and the tracking layer
    // drifts under a continuous ancestor transform (the CupertinoSheet drag).
    return GlassPage(
      background: const _Checkerboard(),
      statusBarStyle: GlassStatusBarStyle.light,
      child: Scaffold(
        // Body goes behind the (transparent) app bar so the glass pill refracts
        // the checkerboard directly beneath it.
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Background (drag the sheet slowly)'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: GlassContainer(
                // The path under test: own compositing layer + premium shader →
                // the glass renders into a separate cached layer
                // (GeometryTransformTrackingLayer) that tracks ancestor transforms
                // reactively. With GlassPage providing the isolation scope, the
                // tracking layer should stay aligned during a CupertinoSheet drag.
                useOwnLayer: true,
                quality: GlassQuality.premium,
                height: 44,
                shape: LiquidRoundedRectangle(borderRadius: 22.0),
                child: Center(
                  child: Text('premium glass', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ),
        body: const SizedBox.expand(), // background rendered by GlassPage
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () => showCupertinoSheet<void>(
              context: context,
              scrollableBuilder: (context, controller) => const _Sheet(),
            ),
            label: const Text('Open sheet'),
          ),
        ),
      ),
    );
  }
}

/// High-contrast checkerboard so glass refraction (and its detachment) is obvious.
class _Checkerboard extends StatelessWidget {
  const _Checkerboard();

  @override
  Widget build(BuildContext context) {
    const cols = 8;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols),
      itemCount: cols * 24,
      itemBuilder: (_, i) {
        final bool on = ((i ~/ cols) + (i % cols)).isEven;
        return ColoredBox(color: on ? const Color(0xFF3F51B5) : const Color(0xFFFFC107));
      },
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: CupertinoColors.systemBackground,
    child: Center(child: Text('Drag me up/down slowly')),
  );
}