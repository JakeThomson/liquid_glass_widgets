/// GlassTabBar.minimizable — SwiftUI's tabBarMinimizeBehavior without the search
///
/// Demonstrates the minimizable placement: the tab pill minimizes to the
/// selected tab's circle on scroll (mirroring
/// `.tabBarMinimizeBehavior(.onScrollDown)`), with the trailing slot in each
/// of its modes:
///
///   - none    — no trailing pill in either state
///   - always  — present in both states (Tab(role: .search) behavior)
///
/// Run standalone:
///   flutter run -t lib/demos/minimizable_bar_demo.dart
///
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(child: const _DemoApp()));
}

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'GlassTabBar.minimizable',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(brightness: Brightness.dark),
      builder: (context, child) => Theme(
        data: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        ),
        child: child!,
      ),
      home: const _DemoHome(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trailing-slot modes
// ─────────────────────────────────────────────────────────────────────────────

enum _TrailingMode {
  none('None'),
  always('Always');

  const _TrailingMode(this.label);
  final String label;
}

// ─────────────────────────────────────────────────────────────────────────────
// Home
// ─────────────────────────────────────────────────────────────────────────────

/// Public entry point — use this when navigating from the example app shell.
class MinimizableBarDemo extends StatelessWidget {
  const MinimizableBarDemo({super.key});

  @override
  Widget build(BuildContext context) => const _DemoHome();
}

class _DemoHome extends StatefulWidget {
  const _DemoHome();

  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  int _selectedIndex = 0;
  bool _minimized = false;
  _TrailingMode _trailingMode = _TrailingMode.always;
  int _composerTaps = 0;

  static const _tabs = [
    GlassTab(label: 'Home', icon: Icon(CupertinoIcons.house)),
    GlassTab(label: 'Alerts', icon: Icon(CupertinoIcons.bell)),
    GlassTab(label: 'Favorites', icon: Icon(CupertinoIcons.heart)),
  ];

  /// Mirrors `.tabBarMinimizeBehavior(.onScrollDown)`: scrolling down starts
  /// the minimize, scrolling back up expands again. The bar itself animates
  /// the morph — this just decides *when*.
  bool _onScroll(UserScrollNotification n) {
    if (n.direction == ScrollDirection.reverse && !_minimized) {
      setState(() => _minimized = true);
    } else if (n.direction == ScrollDirection.forward && _minimized) {
      setState(() => _minimized = false);
    }
    return false;
  }

  GlassTabBarTrailingButton? get _trailingButton {
    final button = GlassTabBarTrailingButton(
      icon: const Icon(CupertinoIcons.square_pencil),
      onTap: () => setState(() => _composerTaps++),
    );
    return switch (_trailingMode) {
      _TrailingMode.none => null,
      _TrailingMode.always => button,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              sliver: SliverToBoxAdapter(child: _buildControls()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
              sliver: SliverList.separated(
                itemCount: 40,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _ContentCard(index: i),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GlassTabBar.minimizable(
        tabs: _tabs,
        selectedIndex: _selectedIndex,
        onTabSelected: (i) => setState(() => _selectedIndex = i),
        minimized: _minimized,
        onMinimizedTabTap: () => setState(() => _minimized = false),
        trailingButton: _trailingButton,
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'GlassTabBar.minimizable',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Scroll down to minimize, up to expand — '
            '.tabBarMinimizeBehavior(.onScrollDown). '
            'Tap the minimized circle to bring the tabs back.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'TRAILING BUTTON',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 6),
          CupertinoSlidingSegmentedControl<_TrailingMode>(
            groupValue: _trailingMode,
            onValueChanged: (m) =>
                setState(() => _trailingMode = m ?? _TrailingMode.always),
            children: {
              for (final m in _TrailingMode.values)
                m: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(m.label, style: const TextStyle(fontSize: 13)),
                ),
            },
          ),
          const SizedBox(height: 8),
          Text(
            'minimized: $_minimized   ·   composer taps: $_composerTaps',
            style: TextStyle(
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filler content
// ─────────────────────────────────────────────────────────────────────────────

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.index});

  final int index;

  static const _hues = [
    Color(0xFF3D5AFE),
    Color(0xFF00BFA5),
    Color(0xFFFF6D00),
    Color(0xFFD500F9),
    Color(0xFFFFD600),
  ];

  @override
  Widget build(BuildContext context) {
    final hue = _hues[index % _hues.length];
    return Container(
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            hue.withValues(alpha: 0.55),
            hue.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(
        'Item number $index',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}
