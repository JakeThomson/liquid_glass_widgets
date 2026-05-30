import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets_example/constants/glass_settings.dart';

/// Quick demo: two circle buttons flanking a wide button.
/// Tests anchor stretch physics on high-aspect-ratio buttons.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(child: const _StretchDemoApp()));
}

class _StretchDemoApp extends StatelessWidget {
  const _StretchDemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const _StretchDemoPage(),
    );
  }
}

class _StretchDemoPage extends StatelessWidget {
  const _StretchDemoPage();

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      settings: RecommendedGlassSettings.standard,
      statusBarStyle: GlassStatusBarStyle.light,
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Left circle button — back chevron
                GlassButton(
                  quality: GlassQuality.premium,
                  icon: const Icon(CupertinoIcons.chevron_left),
                  onTap: () {},
                  width: 56,
                  height: 56,
                  iconSize: 22,
                ),
                const SizedBox(width: 12),
                // Wide pill button — text only
                Expanded(
                  child: GlassButton(
                    quality: GlassQuality.premium,
                    icon: const SizedBox.shrink(),
                    label: 'Test',
                    onTap: () {},
                    height: 56,
                    iconSize: 0,
                    shape: const LiquidRoundedSuperellipse(borderRadius: 32),
                  ),
                ),
                const SizedBox(width: 12),
                // Right circle button — forward chevron
                GlassButton(
                  quality: GlassQuality.premium,
                  icon: const Icon(CupertinoIcons.chevron_right),
                  onTap: () {},
                  width: 56,
                  height: 56,
                  iconSize: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
