import 'package:flutter/widgets.dart';

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
}
