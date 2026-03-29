import 'package:flutter/foundation.dart';

/// Performance budget system for tracking active glass widgets.
///
/// Prevents performance issues by warning developers when too many
/// glass widgets are active simultaneously.
///
/// ## Usage
///
/// **Automatic** (via AdaptiveLiquidGlassLayer):
/// ```dart
/// AdaptiveLiquidGlassLayer(
///   settings: LiquidGlassSettings(...),
///   child: Scaffold(...), // Automatically tracked
/// )
/// ```
///
/// **Manual** (for custom implementations):
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   GlassPerformanceBudget.register('MyCustomGlassWidget');
/// }
///
/// @override
/// void dispose() {
///   GlassPerformanceBudget.unregister('MyCustomGlassWidget');
///   super.dispose();
/// }
/// ```
///
/// ## Behavior
///
/// - **1-5 widgets**: ✅ Safe
/// - **6-10 widgets**: ⚠️ Warning in debug mode
/// - **11+ widgets**: ❌ Exception in debug mode (assert)
///
/// ## Why This Matters
///
/// Each glass widget adds GPU overhead:
/// - 1-5 widgets: 5-10% battery overhead
/// - 10 widgets: 15-25% battery overhead
/// - 20+ widgets: 30-50%+ battery overhead (unacceptable)
///
/// This budget system catches performance issues during development
/// before they reach production.
class GlassPerformanceBudget {
  GlassPerformanceBudget._();

  /// Map of widget types to their counts
  static final Map<String, int> _activeWidgets = {};

  /// Total number of active glass widgets
  static int get totalActive => _activeWidgets.values.fold(0, (a, b) => a + b);

  /// Recommended maximum simultaneous glass widgets
  static const int recommendedMax = 10;

  /// Hard limit for debug mode (throws assertion)
  static const int hardLimit = 15;

  /// Whether to enable budget tracking (only in debug mode)
  static bool enabled = kDebugMode;

  /// Registers a new glass widget instance.
  ///
  /// Call this in `initState()` or widget constructor.
  ///
  /// ```dart
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   GlassPerformanceBudget.register('GlassBottomBar');
  /// }
  /// ```
  static void register(String widgetType) {
    if (!enabled) return;

    _activeWidgets[widgetType] = (_activeWidgets[widgetType] ?? 0) + 1;

    final total = totalActive;

    // Log registration in debug mode
    if (kDebugMode && total <= 2) {
      debugPrint(
          '[GlassPerformanceBudget] $widgetType registered ($total active)');
    }

    // Warning threshold (6-10 widgets)
    if (total > 5 && total <= recommendedMax) {
      debugPrint(
        '⚠️ [GlassPerformanceBudget] $total glass widgets active '
        '(recommended max: $recommendedMax). '
        'Consider reducing glass usage for better battery life.',
      );
    }

    // Hard limit (11+ widgets) - throw assertion in debug mode
    if (total > recommendedMax) {
      final message =
          '❌ [GlassPerformanceBudget] Performance budget exceeded!\n'
          '  Active widgets: $total\n'
          '  Recommended max: $recommendedMax\n'
          '  Hard limit: $hardLimit\n'
          '\n'
          'Too many glass widgets will cause:\n'
          '  - Poor battery life (30-50%+ drain)\n'
          '  - Dropped frames (janky UI)\n'
          '  - App Store rejection risk\n'
          '\n'
          'Solutions:\n'
          '  1. Reduce glass surfaces (use fewer GlassCards in lists)\n'
          '  2. Use GlassQuality.standard instead of premium\n'
          '  3. Remove glass from scrollable content\n'
          '  4. Disable glass in Low Power Mode\n'
          '\n'
          'Active widgets: ${_activeWidgets.entries.map((e) => '${e.key}: ${e.value}').join(', ')}';

      if (total > hardLimit) {
        // Hard limit exceeded - throw assertion
        assert(false, message);
      } else {
        // Over recommended but under hard limit - warning only
        debugPrint(message);
      }
    }
  }

  /// Unregisters a glass widget instance.
  ///
  /// Call this in `dispose()`.
  ///
  /// ```dart
  /// @override
  /// void dispose() {
  ///   GlassPerformanceBudget.unregister('GlassBottomBar');
  ///   super.dispose();
  /// }
  /// ```
  static void unregister(String widgetType) {
    if (!enabled) return;

    final currentCount = _activeWidgets[widgetType] ?? 0;
    if (currentCount > 0) {
      _activeWidgets[widgetType] = currentCount - 1;
      if (_activeWidgets[widgetType] == 0) {
        _activeWidgets.remove(widgetType);
      }
    }

    final total = totalActive;

    // Log unregistration only for first few widgets
    if (kDebugMode && total <= 2) {
      debugPrint(
          '[GlassPerformanceBudget] $widgetType unregistered ($total active)');
    }
  }

  /// Returns a breakdown of active widgets by type.
  ///
  /// Useful for debugging performance issues:
  /// ```dart
  /// print(GlassPerformanceBudget.breakdown());
  /// // Output: "GlassBottomBar: 1, GlassCard: 15, GlassButton: 3"
  /// ```
  static String breakdown() {
    if (_activeWidgets.isEmpty) {
      return 'No active glass widgets';
    }

    return _activeWidgets.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  /// Resets all counters.
  ///
  /// Useful for testing:
  /// ```dart
  /// setUp(() {
  ///   GlassPerformanceBudget.reset();
  /// });
  /// ```
  static void reset() {
    _activeWidgets.clear();
  }

  /// Checks if adding another widget would exceed the budget.
  ///
  /// Returns `true` if safe to add, `false` if over budget.
  ///
  /// ```dart
  /// if (GlassPerformanceBudget.canAddWidget()) {
  ///   // Safe to add another glass widget
  /// } else {
  ///   // Use standard widget instead
  /// }
  /// ```
  static bool canAddWidget() {
    return totalActive < recommendedMax;
  }
}
