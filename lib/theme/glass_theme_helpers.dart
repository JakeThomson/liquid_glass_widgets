import 'package:flutter/widgets.dart';

import '../types/glass_quality.dart';
import '../widgets/shared/inherited_liquid_glass.dart';
import 'glass_theme.dart';
import 'glass_theme_data.dart';

/// Helper functions for working with Glass Theme.
class GlassThemeHelpers {
  GlassThemeHelpers._();

  /// Retrieves the theme data from the widget tree.
  ///
  /// Returns the current [GlassThemeData] from the nearest [GlassTheme]
  /// ancestor. If no theme is found, returns [GlassThemeData.fallback].
  static GlassThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<GlassTheme>();
    return theme?.data ?? GlassThemeData.fallback();
  }

  /// Resolves the effective [GlassQuality] for a widget using the standard
  /// three-level priority chain:
  ///
  /// 1. **Widget-level** — [widgetQuality] if explicitly set (not null).
  /// 2. **Ancestor-level** — the [GlassQuality] propagated by the nearest
  ///    [AdaptiveLiquidGlassLayer] via [InheritedLiquidGlass].
  /// 3. **Theme-level** — [GlassThemeData.qualityFor] from the nearest
  ///    [GlassTheme] ancestor.
  /// 4. **Fallback** — [fallback], defaults to [GlassQuality.standard].
  ///    Surface widgets (app bar, toolbar, bottom bar, sidebar) should pass
  ///    [GlassQuality.premium] here to match their default premium aesthetic.
  ///
  /// This is the canonical replacement for the recurring pattern:
  /// ```dart
  /// final inherited =
  ///     context.dependOnInheritedWidgetOfExactType<InheritedLiquidGlass>();
  /// final themeData = GlassThemeData.of(context);
  /// final effectiveQuality = widgetQuality ??
  ///     inherited?.quality ??
  ///     themeData.qualityFor(context) ??
  ///     GlassQuality.standard;
  /// ```
  static GlassQuality resolveQuality(
    BuildContext context, {
    GlassQuality? widgetQuality,
    GlassQuality fallback = GlassQuality.standard,
  }) {
    if (widgetQuality != null) return widgetQuality;
    final inherited =
        context.dependOnInheritedWidgetOfExactType<InheritedLiquidGlass>();
    if (inherited != null) return inherited.quality;
    final themeData = GlassThemeData.of(context);
    return themeData.qualityFor(context) ?? fallback;
  }
}
