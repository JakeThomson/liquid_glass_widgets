import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets_example/apple_mail/apple_mail_demo.dart';

void main() {
  testWidgets('AppleMailDemoApp mounts and displays Mailboxes view',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AppleMailDemoApp());
    await tester.pumpAndSettle();

    // Mailboxes screen title and sections should be present
    expect(find.text('Mailboxes'), findsAtLeast(1));
    expect(find.text('All Inboxes'), findsOneWidget);
    expect(find.text('iCloud'), findsOneWidget);
    expect(find.text('Orion Labs'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Flagged'), findsOneWidget);
  });

  testWidgets(
      'Navigating from Mailboxes to Inbox displays email list and bottom bar',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AppleMailDemoApp());
    await tester.pumpAndSettle();

    // Tap All Inboxes
    await tester.tap(find.text('All Inboxes'));
    await tester.pumpAndSettle();

    // Verify Inbox header and mock emails
    expect(find.text('Inbox'), findsAtLeast(1));
    expect(find.text('Orion Labs · Updated Just Now'), findsOneWidget);
    expect(find.text('Apple'), findsAtLeast(1));
    expect(find.text('Marcus Vance'), findsOneWidget);
    expect(find.text('Project Nova Launch'), findsOneWidget);
    expect(find.text('Starlink'), findsOneWidget);

    // Verify bottom search bar
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('Select button toggles batch selection mode and Done button',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AppleMailDemoApp());
    await tester.pumpAndSettle();

    // Navigate to Inbox
    await tester.tap(find.text('All Inboxes'));
    await tester.pumpAndSettle();

    // Tap Select
    final selectButton = find.text('Select').last;
    expect(find.text('Select'), findsAtLeast(1));
    await tester.tap(selectButton);
    await tester.pumpAndSettle();

    // Batch actions bar should appear
    expect(find.text('Select Messages'), findsOneWidget);
    expect(find.text('Mark'), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Select All'), findsAtLeast(1));

    // Tap Select All
    await tester.tap(find.text('Select All').last);
    await tester.pumpAndSettle();
    expect(find.text('Deselect All'), findsAtLeast(1));
  });

  testWidgets('Tapping email pushes EmailDetailView with headers and body',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AppleMailDemoApp());
    await tester.pumpAndSettle();

    // Navigate to Inbox
    await tester.tap(find.text('All Inboxes'));
    await tester.pumpAndSettle();

    // Tap Marcus Vance email
    await tester.tap(find.text('Project Nova Launch'));
    await tester.pumpAndSettle();

    // Verify detail view
    expect(find.text('to: alex@orion-labs.com'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.trash), findsAtLeast(1));
    expect(find.byIcon(CupertinoIcons.flag), findsAtLeast(1));
    expect(find.byIcon(CupertinoIcons.reply), findsAtLeast(1));
  });

  testWidgets('Compose button opens ComposeEmailSheet with send button',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AppleMailDemoApp());
    await tester.pumpAndSettle();

    // Navigate to Inbox
    await tester.tap(find.text('All Inboxes'));
    await tester.pumpAndSettle();

    // Tap compose button
    final composeIcon = find.byIcon(CupertinoIcons.square_pencil);
    expect(composeIcon, findsOneWidget);
    await tester.tap(composeIcon);
    await tester.pumpAndSettle();

    // Verify compose sheet
    expect(find.text('New message'), findsOneWidget);
    expect(find.text('To: '), findsOneWidget);
    expect(find.text('Cc/Bcc, From: alex@orion-labs.com'), findsOneWidget);
    expect(find.text('Sent from my iPhone'), findsOneWidget);

    // Type recipient
    await tester.enterText(
        find.byType(CupertinoTextField).first, 'sarah@design.io');
    await tester.pumpAndSettle();

    // Verify Send button arrow
    expect(find.byIcon(CupertinoIcons.arrow_up), findsOneWidget);
  });

  testWidgets(
      'GlassBarItem.sheet in EmailDetailView morphs into reply ComposeEmailSheet',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AppleMailDemoApp());
    await tester.pumpAndSettle();

    // Navigate to Inbox
    await tester.tap(find.text('All Inboxes'));
    await tester.pumpAndSettle();

    // Navigate to email detail
    await tester.tap(find.text('Project Nova Launch'));
    await tester.pumpAndSettle();

    // Tap reply sheet item in pinned bar (follows PR #325 GlassBarItem.sheet)
    final replyIcon = find.byIcon(CupertinoIcons.reply).last;
    await tester.tap(replyIcon);
    await tester.pumpAndSettle();

    // Verify reply compose sheet opened
    expect(find.text('New message'), findsOneWidget);
    expect(find.text('Re: Project Nova Launch'), findsOneWidget);
  });

  testWidgets('Inbox options menu opens and reveals all items without clipping',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AppleMailDemoApp());
    await tester.pumpAndSettle();

    // Navigate to Inbox
    await tester.tap(find.text('All Inboxes'));
    await tester.pumpAndSettle();

    // Tap the ellipsis menu button
    final ellipsisFinder = find.byIcon(CupertinoIcons.ellipsis).last;
    await tester.tap(ellipsisFinder);
    await tester.pumpAndSettle();

    // Verify all menu items are rendered and visible
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('List View'), findsOneWidget);
    expect(find.text('About Categories'), findsOneWidget);
    expect(find.text('Show Priority'), findsOneWidget);
    expect(find.text('Show Contact Photos'), findsOneWidget);
  });
}
