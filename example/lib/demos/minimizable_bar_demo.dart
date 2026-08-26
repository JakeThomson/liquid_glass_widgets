/// GlassTabBar.minimizable — SwiftUI's tabBarMinimizeBehavior without the search
///
/// Demonstrates the minimizable placement driven by a
/// [GlassTabBarMinimizeController], the equivalent of
/// `.tabBarMinimizeBehavior(_:)`:
///
///   - all four [GlassBarMinimizeBehavior] cases, switchable at runtime
///   - per-tab scroll views, re-targeted on tab change the way UIKit
///     re-resolves `contentScrollView(for: .bottom)`
///   - a tab whose content is shorter than the viewport, which never minimizes
///   - `extendBody: false`, where the body inset tracks the bar's height
///
/// Run standalone:
///   flutter run -t lib/demos/minimizable_bar_demo.dart
///
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

extension on GlassBarMinimizeBehavior {
  String get label => switch (this) {
        GlassBarMinimizeBehavior.automatic => 'Auto',
        GlassBarMinimizeBehavior.never => 'Never',
        GlassBarMinimizeBehavior.onScrollDown => 'Down',
        GlassBarMinimizeBehavior.onScrollUp => 'Up',
      };
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
  _TrailingMode _trailingMode = _TrailingMode.always;
  int _composerTaps = 0;
  bool _extendBody = true;

  /// One scroll view per tab, as on iOS — the minimize follows whichever one
  /// is currently under the bar.
  late final List<ScrollController> _scrollControllers =
      List.generate(_tabs.length, (_) => ScrollController());

  final _minimize = GlassTabBarMinimizeController(
    behavior: GlassBarMinimizeBehavior.onScrollDown,
  );

  static const _tabs = [
    GlassTab(label: 'Home', icon: Icon(CupertinoIcons.house)),
    GlassTab(label: 'Chat', icon: Icon(CupertinoIcons.chat_bubble_2)),
    GlassTab(label: 'Short', icon: Icon(CupertinoIcons.square_list)),
  ];

  @override
  void initState() {
    super.initState();
    // Repaint the readout as the bar minimizes. The bar and the scaffold
    // subscribe on their own — this listener is only for the debug text.
    _minimize.addListener(_onMinimizeChanged);
  }

  @override
  void dispose() {
    _minimize.removeListener(_onMinimizeChanged);
    _minimize.dispose();
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onMinimizeChanged() => setState(() {});

  void _onTabSelected(int i) {
    setState(() => _selectedIndex = i);
    // The new tab starts with its tabs showing — you just tapped one.
    _minimize.expand();
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
    return GlassScaffold(
      extendBody: _extendBody,
      backgroundColor: const Color(0xFF0A0A0F),
      body: _buildBody(),
      bottomBar: GlassTabBar.minimizable(
        tabs: _tabs,
        selectedIndex: _selectedIndex,
        onTabSelected: _onTabSelected,
        // The controller owns `minimized` — no `minimized:` prop, no
        // NotificationListener, no scroll bookkeeping in this file.
        minimizeController: _minimize,
        scrollController: _scrollControllers[_selectedIndex],
        onMinimizedTabTap: _minimize.expand,
        trailingButton: _trailingButton,
      ),
    );
  }

  Widget _buildBody() {
    final controller = _scrollControllers[_selectedIndex];
    // `Chat` is bottom-aligned, which is the case onScrollUp exists for.
    final reverse = _selectedIndex == 1;
    final itemCount = switch (_selectedIndex) {
      2 => 2, // deliberately shorter than the viewport
      _ => 40,
    };

    return CustomScrollView(
      controller: controller,
      reverse: reverse,
      slivers: [
        if (!reverse)
          SliverSafeArea(
            sliver: SliverToBoxAdapter(child: _buildControls()),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
          sliver: SliverList.separated(
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ContentCard(index: i),
          ),
        ),
      ],
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
            'Scroll to minimize — .tabBarMinimizeBehavior(_:). Tap the '
            'minimized circle to bring the tabs back. "Chat" is bottom-'
            'aligned (try Up); "Short" cannot scroll, so it never minimizes.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          _label('BEHAVIOR'),
          const SizedBox(height: 6),
          CupertinoSlidingSegmentedControl<GlassBarMinimizeBehavior>(
            groupValue: _minimize.behavior,
            onValueChanged: (b) => setState(
              () => _minimize.behavior = b ?? GlassBarMinimizeBehavior.never,
            ),
            children: {
              for (final b in GlassBarMinimizeBehavior.values)
                b: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(b.label, style: const TextStyle(fontSize: 13)),
                ),
            },
          ),
          const SizedBox(height: 12),
          _label('TRAILING BUTTON'),
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
          _toggle(
            value: _extendBody,
            onChanged: (v) => setState(() => _extendBody = v),
            title: 'extendBody',
            subtitle: 'Off: the body inset follows the bar as it shrinks',
          ),
          const SizedBox(height: 4),
          Text(
            'minimized: ${_minimize.minimized}   ·   '
            'resolved: ${_minimize.resolvedBehavior.name}   ·   '
            'composer taps: $_composerTaps',
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

  Widget _toggle({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.1,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      );
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
