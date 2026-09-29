// Probe harness — what a Flutter app can read about iPhone Duo's bar strip.
//
// On iPhone Duo (iOS 27.1) the status bar, and the bars a container owns, move
// into a fixed-width strip on the outer display and on the inner display in
// landscape. A FlutterViewController owns no bars, but the strip is still
// reserved: it arrives as a one-sided lateral inset with a zero top inset.
// This harness shows those insets live, outlines the safe area, and shades the
// strip that the edge rule below detects, so the rule can be checked in every
// posture without a device.
//
// Two readings are shown side by side: the view's own padding, and
// MediaQuery.viewPaddingOf inside a SafeArea. SafeArea (and Scaffold) remove
// padding for their subtree, and MediaQueryData.removePadding reduces
// viewPadding with it, so detection has to read above them or from the View.
//
// Needs Xcode 27.1 and the iOS 27.1 simulator runtime; the iPhone Duo device
// type only runs on 27.1. With the 27.1 Xcode selected:
//
//   xcodebuild -downloadPlatform iOS
//   xcrun simctl create "iPhone Duo" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo \
//     com.apple.CoreSimulator.SimRuntime.iOS-27-1
//
// Fold and unfold with the Closed / Book / Open buttons under the device in
// DeviceHub (Xcode 27's replacement for Simulator.app); rotate with Rotate
// Right. Every change is also logged as one `DUO_INSETS` line.
//
//   cd example && flutter run -t lib/harnesses/duo_insets_harness.dart
library;

import 'dart:ui' show DisplayFeature;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => const CupertinoApp(
        debugShowCheckedModeBanner: false,
        title: 'Duo Insets',
        theme: CupertinoThemeData(brightness: Brightness.light),
        home: DuoInsetsHarness(),
      );
}

/// The physical side of the screen the bar strip occupies.
enum DuoStripSide { left, right }

/// The side the vertical bar strip is on, or null when bars are horizontal.
///
/// The strip is the only case with a zero top inset and exactly one non-zero
/// lateral inset. A regular iPhone in landscape also has a zero top inset, but
/// insets both sides equally (62, 0, 62, 20 on iPhone 17), so a single lateral
/// inset is required rather than a particular width. The insets are physical,
/// so the side stays correct under RTL, where UIKit's verticalBarEdge reports
/// the same right-hand strip as `leading`.
DuoStripSide? detectDuoStrip(EdgeInsets viewPadding, TargetPlatform platform) {
  if (platform != TargetPlatform.iOS || viewPadding.top != 0) return null;
  final left = viewPadding.left > 0, right = viewPadding.right > 0;
  if (left == right) return null;
  return left ? DuoStripSide.left : DuoStripSide.right;
}

/// Shows the insets, the safe area and the detected strip.
class DuoInsetsHarness extends StatefulWidget {
  /// Creates the insets harness.
  const DuoInsetsHarness({super.key});

  @override
  State<DuoInsetsHarness> createState() => _DuoInsetsHarnessState();
}

class _DuoInsetsHarnessState extends State<DuoInsetsHarness> {
  String _lastLog = '';

  @override
  Widget build(BuildContext context) {
    // Read from the View, not the ambient MediaQuery, so no ancestor that
    // removes padding can hide the strip.
    final view = MediaQueryData.fromView(View.of(context));
    final strip = detectDuoStrip(view.viewPadding, defaultTargetPlatform);
    final stripWidth = switch (strip) {
      DuoStripSide.left => view.viewPadding.left,
      DuoStripSide.right => view.viewPadding.right,
      null => 0.0,
    };

    final lines = <String>[
      'size ${_size(view.size)}  ${view.orientation.name}',
      'viewPadding ${_insets(view.viewPadding)}',
      'padding ${_insets(view.padding)}',
      'viewInsets ${_insets(view.viewInsets)}',
      'displayFeatures ${view.displayFeatures.isEmpty ? '[]' : view.displayFeatures.map(_feature).join(', ')}',
      'strip ${strip == null ? 'none' : '${strip.name}, ${stripWidth.toStringAsFixed(0)} pt'}',
    ];
    final log = 'DUO_INSETS ${lines.join(' | ')}';
    if (log != _lastLog) {
      _lastLog = log;
      debugPrint(log);
    }

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: view.viewPadding,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: CupertinoColors.systemGreen, width: 2),
                ),
              ),
            ),
          ),
          if (strip != null)
            Positioned(
              top: 0,
              bottom: 0,
              width: stripWidth,
              left: strip == DuoStripSide.left ? 0 : null,
              right: strip == DuoStripSide.right ? 0 : null,
              child: const ColoredBox(color: Color(0x33FF3B30)),
            ),
          for (final feature in view.displayFeatures)
            Positioned.fromRect(
              rect: feature.bounds,
              child: const ColoredBox(color: Color(0x66FF9500)),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in lines)
                    Text(line,
                        style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Menlo',
                            color: Color(0xFF000000))),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) => Text(
                      'inside SafeArea: viewPadding ${_insets(MediaQuery.viewPaddingOf(context))}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'Menlo',
                          color: Color(0xFF8E8E93)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const CupertinoTextField(
                      placeholder:
                          'Raise the keyboard: viewPadding should not move'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _size(Size s) =>
      '${s.width.toStringAsFixed(0)}×${s.height.toStringAsFixed(0)}';

  static String _insets(EdgeInsets e) => '(${[
        e.left,
        e.top,
        e.right,
        e.bottom
      ].map((v) => v.toStringAsFixed(0)).join(', ')})';

  static String _feature(DisplayFeature f) =>
      '${f.type.name} ${f.state.name} ${f.bounds.left.toStringAsFixed(0)},${f.bounds.top.toStringAsFixed(0)} '
      '${f.bounds.width.toStringAsFixed(0)}×${f.bounds.height.toStringAsFixed(0)}';
}
