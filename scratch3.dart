import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/src/renderer/liquid_glass_blend_group.dart';

/// Temporary debug widget to check if blend group has shapes registered.
/// Place this inside the AdaptiveLiquidGlassLayer to inspect the blend group.
class BlendGroupDebug extends StatelessWidget {
  const BlendGroupDebug({super.key});

  @override
  Widget build(BuildContext context) {
    final link = LiquidGlassBlendGroup.maybeOf(context);
    if (link != null) {
      debugPrint('[BlendGroupDebug] Shapes registered: ${link.hasShapes}');
      debugPrint('[BlendGroupDebug] Shape count: ${link.shapeEntries.length}');
    } else {
      debugPrint('[BlendGroupDebug] No blend group found!');
    }
    return const SizedBox.shrink();
  }
}
