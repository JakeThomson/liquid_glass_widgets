import 'dart:async';

import 'package:flutter/widgets.dart';

/// Provides the DX1 deferred-tap logic for glass indicator widgets.
///
/// ## The problem
///
/// On pointer/mouse platforms (macOS, Web, Windows, Linux) a tap-down + tap-up
/// pair arrives in a **single event-loop turn** and is batched into one
/// `setState` flush. The net result: `_isDown` is never `true` for any
/// rendered frame, so the glass indicator never appears and jelly deformation
/// is invisible.
///
/// ## The fix
///
/// When `handleIndicatorTapDown` is called, the mixin:
/// 1. Immediately calls back `setIsDown(true)` (causes one frame with the
///    indicator visible and the spring starting from rest).
/// 2. Schedules a `Timer` (~17 ms, one frame) that calls `setIsDown(false)`.
///
/// This guarantees at least one rendered frame with `_isDown = true`, making
/// the spring animation and jelly deformation visible on all platforms.
///
/// ## Usage
///
/// 1. Mix into your `State` class:
///    ```dart
///    class _MyState extends State<MyWidget>
///        with GlassIndicatorTapMixin<MyWidget> { ... }
///    ```
/// 2. Call [handleIndicatorTapDown] from each segment/tab's `onTapDown`:
///    ```dart
///    onTapDown: (_) => handleIndicatorTapDown(
///      setIsDown: (v) => setState(() => _isDown = v),
///      snapAlign: () => setState(() => _xAlign = _alignmentForIndex(i)),
///    ),
///    ```
/// 3. Call [cancelIndicatorTapTimer] at the start of any drag handler:
///    ```dart
///    void _onDragDown(DragDownDetails d) {
///      cancelIndicatorTapTimer();
///      setState(() { _isDown = true; ... });
///    }
///    ```
/// 4. The mixin overrides `dispose()` and cancels the timer automatically —
///    **no** `dispose()` override is needed in the host class for this timer.
///    If the host class needs its own `dispose()`, call `super.dispose()` to
///    activate the mixin's cleanup.
mixin GlassIndicatorTapMixin<T extends StatefulWidget> on State<T> {
  Timer? _glassTapTimer;

  /// Cancel any pending tap-clear timer.
  ///
  /// Call this at the start of every drag-down handler so a real drag
  /// immediately takes priority over a previously scheduled tap-clear.
  void cancelIndicatorTapTimer() => _glassTapTimer?.cancel();

  /// Handle a tap-down on a segment/tab with deferred indicator clear.
  ///
  /// [setIsDown] is called with `true` immediately and with `false` after
  /// one animation frame (~17 ms).
  ///
  /// [snapAlign] is called immediately to move the indicator to the tapped
  /// position (provides instant visual feedback regardless of whether the
  /// timer fires before the `onTap` callback updates `selectedIndex`).
  void handleIndicatorTapDown({
    required void Function(bool) setIsDown,
    required VoidCallback snapAlign,
  }) {
    _glassTapTimer?.cancel();
    setState(() => setIsDown(true));
    setState(snapAlign);
    _glassTapTimer = Timer(
      const Duration(milliseconds: 17), // ~1 frame @ 60 Hz
      () {
        if (mounted) setState(() => setIsDown(false));
      },
    );
  }

  /// Schedule clearing `_isDown` after [duration].
  ///
  /// Use this instead of [handleIndicatorTapDown] when you don't want to snap
  /// the alignment immediately (e.g. desktop tap-down where you want the spring
  /// to animate from the old position and generate real jelly velocity).
  void scheduleTapClear({
    required Duration duration,
    required void Function(bool) setIsDown,
  }) {
    _glassTapTimer?.cancel();
    _glassTapTimer = Timer(duration, () {
      if (mounted) setState(() => setIsDown(false));
    });
  }

  /// Cancel the auto-clear timer and keep the indicator permanently visible.
  ///
  /// Call from `onLongPressStart` so a press-and-hold beyond the long-press
  /// threshold (~500 ms) doesn't let the 420 ms tap-clear timer hide the
  /// indicator mid-hold.
  void keepIndicatorDown({required void Function(bool) setIsDown}) {
    _glassTapTimer?.cancel();
    _glassTapTimer = null;
    if (mounted) setState(() => setIsDown(true));
  }

  /// Clear the indicator after a long-press ends.
  ///
  /// Call from `onLongPressEnd` or `onLongPressUp` to hide the indicator
  /// when the user lifts their finger after a press-and-hold.
  void releaseIndicatorDown({required void Function(bool) setIsDown}) {
    if (mounted) setState(() => setIsDown(false));
  }

  @override
  void dispose() {
    _glassTapTimer?.cancel();
    super.dispose();
  }
}
