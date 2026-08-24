// On-device verification for GlassModalSheet's morph presentation.
//
// The morph needs the Impeller metaball blend, which a headless `flutter test`
// run does not have — so this drives the real demo on a simulator/device, where
// the capability probe actually passes, and proves the morph route is taken
// rather than the slide fallback.
//
//   cd example && flutter test integration_test/morph_demo_test.dart -d <device>

import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_glass_widgets/widgets/overlays/glass_modal_sheet.dart';

import 'package:liquid_glass_widgets_example/demos/glass_modal_sheet_demo.dart'
    as demo;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GlassModalSheet morphs from its trigger on a real renderer',
      (tester) async {
    expect(
      ui.ImageFilter.isShaderFilterSupported,
      isTrue,
      reason: 'This device reports no shader filter support, so the morph '
          'would correctly fall back to the slide. Run it on Impeller.',
    );

    demo.main();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final trigger = find.byIcon(CupertinoIcons.add);
    expect(trigger, findsOneWidget, reason: 'the morph demo trigger');

    await tester.tap(trigger);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    // Mid-morph: the droplet is presenting, and the route did not wrap the
    // page in the slide it replaces. (Scoped to the sheet's own route — the
    // demo's home CupertinoPageRoute has a SlideTransition of its own.)
    expect(find.byType(GlassSheetMorphPresenter), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(GlassSheetMorphPresenter),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );

    await tester.pumpAndSettle();
    expect(find.text('Morph from trigger'), findsWidgets);

    // Let the landed sheet sit for the recording.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    // Barrier tap — the dismissal that morphs back into the trigger.
    await tester.tapAt(const Offset(200, 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(GlassSheetMorphPresenter), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(GlassSheetMorphPresenter), findsNothing);

    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
}
