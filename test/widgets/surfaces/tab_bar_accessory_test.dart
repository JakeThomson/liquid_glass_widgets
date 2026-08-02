import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  group('GlassTabBar Accessory iOS 26 Layout', () {
    testWidgets('searchable placement uses TweenAnimationBuilder',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTabBar.searchable(
              isSearchActive: false,
              tabs: const [GlassTab(label: '1'), GlassTab(label: '2')],
              selectedIndex: 0,
              onTabSelected: (_) {},
              searchConfig: GlassSearchBarConfig(
                onSearchToggle: (_) {},
              ),
              bottomAccessory:
                  const SizedBox(height: 50, width: 100, key: Key('acc')),
              bottomAccessoryHeight: 50,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('acc')), findsOneWidget);
      // In searchable mode, TweenAnimationBuilder is used for the accessory animation.
      expect(find.byType(TweenAnimationBuilder<double>), findsWidgets);

      // Test the preferredSize computation.
      var tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
      // Base bar height (64) + vertical padding (20) * 2 + accessory (50) + spacing (8) = 162
      expect(tabBar.preferredSize.height, 162.0);

      // Rebuild in inline mode
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassTabBar.searchable(
              isSearchActive: true,
              tabs: const [GlassTab(label: '1'), GlassTab(label: '2')],
              selectedIndex: 0,
              onTabSelected: (_) {},
              searchBarHeight: 36, // Explicitly match my mental calculation
              searchConfig: GlassSearchBarConfig(
                onSearchToggle: (_) {},
              ),
              bottomAccessory:
                  const SizedBox(height: 50, width: 100, key: Key('acc')),
              bottomAccessoryHeight: 50,
            ),
          ),
        ),
      );

      tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
      // Base search bar height (36) + vertical padding (20) * 2 = 76 (accessory is beside, not added to height)
      expect(tabBar.preferredSize.height, 76.0);
    });
  });
}
