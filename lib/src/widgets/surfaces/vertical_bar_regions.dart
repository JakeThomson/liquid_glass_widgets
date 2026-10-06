import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The parts of the view UIKit reserves for system elements — on iPhone Duo,
/// the status cluster and the camera at the ends of the vertical bar strip —
/// as [DisplayFeatureType.cutout]s in logical pixels.
///
/// UIKit reports them as the view's occlusion regions,
/// `UIView.reservedRegions(kind: .occlusion)`, and they move: the status
/// cluster grows with live activities and goes with the status bar. Android
/// cutouts reach [MediaQueryData.displayFeatures], but Flutter sends none on
/// iOS yet (flutter/flutter#193025), so the package's iOS plugin reads the
/// regions and this publishes them in the same shape. Once Flutter reports
/// them, [MediaQueryData.displayFeatures] carries the same rects and this can
/// go without the strip moving.
class VerticalBarRegions extends ValueNotifier<List<DisplayFeature>> {
  VerticalBarRegions._() : super(const <DisplayFeature>[]);

  /// The regions of the app's view.
  static final VerticalBarRegions instance = VerticalBarRegions._();

  static const MethodChannel _channel = MethodChannel(
    'liquid_glass_widgets/reserved_regions',
  );

  bool _observing = false;

  /// Starts following the regions, if it has not already.
  ///
  /// Leaves them empty where the plugin is not registered: in a widget test,
  /// or in an app that embeds Flutter without registering its plugins.
  void observe() {
    if (_observing) return;
    _observing = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'didChange') value = _decode(call.arguments);
    });
    unawaited(_observe());
  }

  Future<void> _observe() async {
    try {
      value = _decode(await _channel.invokeListMethod<Object?>('observe'));
    } on MissingPluginException {
      // Not registered; the strip keeps to its measured geometry.
    }
  }

  /// Stops following the regions and forgets them, between tests.
  @visibleForTesting
  void debugReset() {
    _channel.setMethodCallHandler(null);
    _observing = false;
    value = const <DisplayFeature>[];
  }

  static List<DisplayFeature> _decode(Object? regions) => [
    for (final region in (regions as List<Object?>? ?? const []))
      DisplayFeature(
        bounds: Rect.fromLTRB(
          ((region as List<Object?>)[0]! as num).toDouble(),
          (region[1]! as num).toDouble(),
          (region[2]! as num).toDouble(),
          (region[3]! as num).toDouble(),
        ),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
  ];
}
