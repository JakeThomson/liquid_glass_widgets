/// GlassTabBar Demo — interactive tab count selector.
///
/// Demonstrates [GlassBottomBar] with a configurable number of tabs (1–6),
/// showing how the pill, icons, and labels adapt as tabs are added or removed.
///
/// Run standalone:
///   flutter run -t example/lib/demos/glass_tab_bar_demo.dart
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(child: const _App()));
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'GlassTabBar Demo',
      debugShowCheckedModeBanner: false,
      home: _TabBarDemoPage(),
    );
  }
}

// ── Demo page ────────────────────────────────────────────────────────────────

class _TabBarDemoPage extends StatefulWidget {
  const _TabBarDemoPage();

  @override
  State<_TabBarDemoPage> createState() => _TabBarDemoPageState();
}

class _TabBarDemoPageState extends State<_TabBarDemoPage> {
  int _tabCount = 4;
  int _selectedIndex = 0;

  static const _allTabs = [
    (icon: CupertinoIcons.house_fill, label: 'Home'),
    (icon: CupertinoIcons.search, label: 'Search'),
    (icon: CupertinoIcons.heart_fill, label: 'Favourites'),
    (icon: CupertinoIcons.bell_fill, label: 'Alerts'),
    (icon: CupertinoIcons.person_fill, label: 'Profile'),
    (icon: CupertinoIcons.settings, label: 'Settings'),
  ];

  static const _pageColors = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
    Color(0xFF0F3460),
    Color(0xFF533483),
    Color(0xFF2D132C),
    Color(0xFF1B262C),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = _allTabs.take(_tabCount).toList();
    final clampedIndex = _selectedIndex.clamp(0, _tabCount - 1);

    return Scaffold(
      backgroundColor: _pageColors[clampedIndex],
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.5,
                colors: [
                  _pageColors[clampedIndex].withValues(alpha: 0.0),
                  _pageColors[clampedIndex],
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Title ──────────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'GlassTabBar Demo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),

                // ── Tab count slider ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        'Tabs: $_tabCount',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _tabCount.toDouble(),
                          min: 1,
                          max: 6,
                          divisions: 5,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white30,
                          onChanged: (v) => setState(() {
                            _tabCount = v.round();
                            _selectedIndex =
                                _selectedIndex.clamp(0, _tabCount - 1);
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Page content ───────────────────────────────────────
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tabs[clampedIndex].icon,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tabs[clampedIndex].label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── GlassBottomBar ─────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassBottomBar(
              selectedIndex: clampedIndex,
              onTabSelected: (i) => setState(() => _selectedIndex = i),
              tabs: tabs
                  .map((t) => GlassBottomBarTab(
                        icon: Icon(t.icon),
                        label: t.label,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
