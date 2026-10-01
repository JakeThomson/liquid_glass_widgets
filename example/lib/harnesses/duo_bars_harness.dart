// Parity harness — the package's bars beside iPhone Duo's native vertical bars.
//
// Each scenario rebuilds one of the native reference screens (a SwiftUI
// NavigationStack / TabView built against the iOS 27.1 SDK) with the package's
// own bars, so a screenshot of the two side by side shows where they differ.
// The screens are deliberately the same: the same titles, the same items in
// the same groups, the same forty coloured rows.
//
// NOT a showcase demo, which is why it does not live in lib/demos. It needs
// Xcode 27.1 and the iOS 27.1 simulator runtime: the iPhone Duo device type
// only runs on 27.1, and an app built against an older SDK gets horizontal
// bars. With the 27.1 Xcode selected:
//
//   xcodebuild -downloadPlatform iOS
//   xcrun simctl create "iPhone Duo" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo \
//     com.apple.CoreSimulator.SimRuntime.iOS-27-1
//
// Fold and unfold with the Closed / Book / Open buttons under the device in
// DeviceHub.
//
// The scenario is read from a file in the app's tmp directory, so one build
// covers them all:
//
//   cd example && flutter build ios --simulator --debug \
//     -t lib/harnesses/duo_bars_harness.dart
//   echo SCENARIO=tabsnav > "$(xcrun simctl get_app_container <udid> \
//     <bundle id> data)/tmp/duo_harness.env"
//   xcrun simctl launch --terminate-running-process <udid> <bundle id>
//
// Scenarios: nav, navbottom, tabsnav, root, axis, alert (a dialog over the
// detail screen, 1.5s in) and push (the detail screen pushed 1s in and
// popped 2.5s later, to record the morph). A `DIRECTION=rtl` line lays
// the app out right to left, `BARS=disabled` sets
// GlassVerticalBarBehavior.disabled on the shell, `COMPRESSION=` one of
// GlassVerticalBarCompression's names sets that, and
// `ORIENT=portrait|landscapeLeft|landscapeRight` locks the orientation, as the
// native scenarios' `-orient` does.
library;

import 'dart:io' show Directory, File;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// `KEY=value` lines from `tmp/duo_harness.env` in the app's data container.
///
/// Dart's `Platform.environment` is empty on iOS, so `SIMCTL_CHILD_` variables
/// never reach it; the app's tmp directory is `Directory.systemTemp`, which the
/// host can write through `xcrun simctl get_app_container <udid> <bundle> data`.
final Map<String, String> _env = () {
  final file = File('${Directory.systemTemp.path}/duo_harness.env');
  if (!file.existsSync()) return const <String, String>{};
  return {
    for (final line in file.readAsLinesSync())
      if (line.contains('='))
        line.substring(0, line.indexOf('=')).trim():
            line.substring(line.indexOf('=') + 1).trim(),
  };
}();

final String _scenario = _env['SCENARIO'] ?? 'nav';
final bool _rtl = _env['DIRECTION'] == 'rtl';
final bool _barsDisabled = _env['BARS'] == 'disabled';
final GlassVerticalBarCompression _compression =
    GlassVerticalBarCompression.values.firstWhere(
  (value) => value.name == _env['COMPRESSION'],
  orElse: () => GlassVerticalBarCompression.automatic,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  switch (_env['ORIENT']) {
    case 'portrait':
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
    case 'landscapeLeft':
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft]);
    case 'landscapeRight':
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeRight]);
  }
  runApp(LiquidGlassWidgets.wrap(child: const _App()));
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => CupertinoApp(
        debugShowCheckedModeBanner: false,
        title: 'Duo Bars',
        theme: const CupertinoThemeData(brightness: Brightness.light),
        builder: (context, child) => Directionality(
          textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
          child: GlassNavigationShell(
            verticalBarBehavior: _barsDisabled
                ? GlassVerticalBarBehavior.disabled
                : GlassVerticalBarBehavior.automatic,
            verticalBarCompression: _compression,
            child: child!,
          ),
        ),
        // A navigator is only built with a route source; every route this
        // harness shows comes from the initial stack below.
        onGenerateRoute: (_) => _route(const _ListScreen(title: 'Inbox')),
        onGenerateInitialRoutes: (_) => _initialRoutes(),
      );

  /// The native scenarios open on a pushed detail screen, with the root
  /// underneath, so the back button is showing.
  static List<Route<void>> _initialRoutes() => switch (_scenario) {
        'root' => [_route(const _RootScreen())],
        'tabsnav' => [_route(const _TabsScreen())],
        'navbottom' => [
            _route(const _ListScreen(title: 'Inbox')),
            _route(const _BottomBarScreen()),
          ],
        'axis' => [
            _route(const _ListScreen(title: 'Inbox')),
            _route(const _AxisScreen()),
          ],
        'alert' => [
            _route(const _ListScreen(title: 'Inbox')),
            _route(const _DetailScreen(alert: true)),
          ],
        'push' => [_route(const _ListScreen(title: 'Inbox', pushes: true))],
        _ => [
            _route(const _ListScreen(title: 'Inbox')),
            _route(const _DetailScreen()),
          ],
      };
}

/// The iOS 27 material, which the native bars are drawn in.
const _glass = LiquidGlassSettings.ios27Light;

Route<void> _route(Widget page) =>
    CupertinoPageRoute<void>(builder: (_) => page);

// ─────────────────────────────────────────────────────────────────────────────
// Shared content
// ─────────────────────────────────────────────────────────────────────────────

/// Forty coloured rows, as the native DemoList draws them.
class _Rows extends StatelessWidget {
  const _Rows({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    // Natively the content starts 82pt down in the strip layout, below the
    // title row, and under the navigation bar otherwise.
    final top =
        GlassVerticalBar.maybeOf(context) == null ? padding.top + 44 + 8 : 82.0;
    return ListView.builder(
      padding: EdgeInsets.only(top: top, bottom: 120),
      itemCount: 40,
      itemBuilder: (context, i) => SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    HSVColor.fromAHSV(1, (i % 12) * 30.0, 0.7, 0.9).toColor(),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title row ${i + 1}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                    ),
                  ),
                  const Text(
                    'Secondary text that fills the width of the row',
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ListScreen extends StatefulWidget {
  const _ListScreen({required this.title, this.pushes = false});

  final String title;

  /// Whether to push the detail screen 1s in, and pop it 2.5s later.
  final bool pushes;

  @override
  State<_ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<_ListScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.pushes) return;
    Future<void>.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.push(_route(const _DetailScreen()));
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) => GlassScaffold(
        backgroundColor: CupertinoColors.white,
        appBar: GlassAppBar.pinned(
          title: Text(widget.title),
          buttonSettings: _glass,
        ),
        body: _Rows(title: widget.title),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Scenarios
// ─────────────────────────────────────────────────────────────────────────────

/// The detail screen's trailing items, in the order the native strip reads
/// them: the pinned compose button first, then share and favourite sharing a
/// capsule, then the overflow menu on its own.
List<GlassBarItem> _detailActions() => [
      GlassBarItem.icon(
        icon: const Icon(CupertinoIcons.square_pencil),
        label: 'Compose',
        background: GlassBarItemBackground.separate,
        onTap: () {},
      ),
      GlassBarItem.icon(
        icon: const Icon(CupertinoIcons.share),
        label: 'Share',
        onTap: () {},
      ),
      GlassBarItem.icon(
        icon: const Icon(CupertinoIcons.heart),
        label: 'Favourite',
        onTap: () {},
      ),
      GlassBarItem.menu(
        icon: const Icon(CupertinoIcons.ellipsis),
        label: 'More',
        background: GlassBarItemBackground.separate,
        menuItems: [
          GlassMenuItem(
            title: 'Copy',
            icon: const Icon(CupertinoIcons.doc_on_doc),
            onTap: () {},
          ),
          GlassMenuItem(
            title: 'Delete',
            icon: const Icon(CupertinoIcons.delete),
            isDestructive: true,
            onTap: () {},
          ),
        ],
      ),
    ];

class _DetailScreen extends StatefulWidget {
  const _DetailScreen({this.alert = false});

  /// Whether to present a dialog over the screen 1.5s in, as the native
  /// `alert` scenario does.
  final bool alert;

  @override
  State<_DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<_DetailScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.alert) return;
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      GlassDialog.show<void>(
        context: context,
        settings: _glass,
        title: 'Delete message?',
        message: 'An alert over the vertical bar.',
        actions: [
          GlassDialogAction(label: 'Cancel', onPressed: () {}),
          GlassDialogAction(
            label: 'Delete',
            isDestructive: true,
            onPressed: () {},
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) => GlassScaffold(
        backgroundColor: CupertinoColors.white,
        appBar: GlassAppBar.pinned(
          title: const Text('Detail'),
          buttonSettings: _glass,
          actions: _detailActions(),
        ),
        body: const _Rows(title: 'Detail'),
      );
}

class _BottomBarScreen extends StatelessWidget {
  const _BottomBarScreen();

  @override
  Widget build(BuildContext context) {
    // The group runs down the strip with the toolbar, at the strip's control
    // size.
    final vertical = GlassVerticalBar.maybeOf(context) != null;
    return GlassScaffold(
      backgroundColor: CupertinoColors.white,
      appBar: const GlassAppBar.pinned(
        title: Text('Detail'),
        buttonSettings: _glass,
      ),
      bottomBar: GlassToolbar(
        children: [
          GlassButtonGroup.icons(
              settings: _glass,
              direction: vertical ? Axis.vertical : Axis.horizontal,
              itemPadding: vertical
                  ? const EdgeInsets.symmetric(horizontal: 13, vertical: 14)
                  : const EdgeInsets.all(12),
              items: [
                GlassButtonGroupItem(
                  icon: const Icon(CupertinoIcons.archivebox),
                  onTap: () {},
                ),
                GlassButtonGroupItem(
                  icon: const Icon(CupertinoIcons.flag),
                  onTap: () {},
                ),
              ]),
          const Spacer(),
          GlassButton(
            settings: _glass,
            icon: const Icon(CupertinoIcons.reply),
            width: vertical ? 48 : 44,
            height: vertical ? 48 : 44,
            onTap: () {},
          ),
        ],
      ),
      body: const _Rows(title: 'Detail'),
    );
  }
}

class _RootScreen extends StatelessWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context) => GlassScaffold(
        backgroundColor: CupertinoColors.white,
        appBar: GlassAppBar.pinned(
          title: const Text('Mailboxes'),
          buttonSettings: _glass,
          leading: [
            GlassBarItem.custom(
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Center(child: Text('Edit')),
              ),
              label: 'Edit',
              onTap: () {},
            ),
          ],
          actions: [
            GlassBarItem.icon(
              icon: const Icon(CupertinoIcons.add),
              label: 'Add',
              onTap: () {},
            ),
          ],
        ),
        body: const _Rows(title: 'Mail'),
      );
}

/// Title-only, custom and icon items with each axis behaviour, as the native
/// `axis` scenario declares them.
class _AxisScreen extends StatelessWidget {
  const _AxisScreen();

  /// A red dot and a label. [squeezed] lays the two out in a Wrap, which
  /// wraps like SwiftUI's HStack where the strip squeezes the pill to 48pt; a
  /// Row keeps one line in the horizontal capsule.
  static Widget _pill(String label, {bool squeezed = false}) {
    const dot = DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed,
        shape: BoxShape.circle,
      ),
      child: SizedBox(width: 8, height: 8),
    );
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: squeezed ? 4 : 8),
      child: squeezed
          ? Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              children: [dot, text],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [dot, const SizedBox(width: 4), text],
            ),
    );
  }

  static Widget _text(String label) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(child: Text(label)),
      );

  @override
  Widget build(BuildContext context) => GlassScaffold(
        backgroundColor: CupertinoColors.white,
        appBar: GlassAppBar.pinned(
          title: const Text('Detail'),
          buttonSettings: _glass,
          actions: [
            GlassBarItem.custom(child: _text('Text'), onTap: () {}),
            GlassBarItem.custom(
              child: _text('Text VP'),
              axisBehavior: GlassBarItemAxisBehavior.verticalPreferred,
              onTap: () {},
            ),
            GlassBarItem.custom(child: _pill('Custom')),
            GlassBarItem.custom(
              child: _pill('Custom VP', squeezed: true),
              axisBehavior: GlassBarItemAxisBehavior.verticalPreferred,
            ),
            GlassBarItem.icon(
              icon: const Icon(CupertinoIcons.star),
              axisBehavior: GlassBarItemAxisBehavior.horizontalOnly,
              onTap: () {},
            ),
            GlassBarItem.icon(
              icon: const Icon(CupertinoIcons.bell),
              onTap: () {},
            ),
          ],
        ),
        body: const _Rows(title: 'Detail'),
      );
}

/// Four tabs, each its own navigation stack opened on a pushed detail screen.
class _TabsScreen extends StatefulWidget {
  const _TabsScreen();

  @override
  State<_TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<_TabsScreen> {
  static const _titles = ['Home', 'Library', 'Radio', 'Profile'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) => GlassScaffold(
        backgroundColor: CupertinoColors.white,
        bottomBar: GlassTabBar.bottom(
          settings: _glass,
          selectedIndex: _tab,
          onTabSelected: (i) => setState(() => _tab = i),
          // The native TabView's selected tab takes the app's tint.
          selectedIconColor: CupertinoColors.systemBlue,
          tabs: const [
            GlassTab(icon: Icon(CupertinoIcons.house_fill), label: 'Home'),
            GlassTab(icon: Icon(CupertinoIcons.book_fill), label: 'Library'),
            GlassTab(
              icon: Icon(CupertinoIcons.dot_radiowaves_left_right),
              label: 'Radio',
            ),
            GlassTab(
              icon: Icon(CupertinoIcons.person_crop_circle_fill),
              label: 'Profile',
            ),
          ],
        ),
        body: IndexedStack(
          index: _tab,
          children: [
            for (final title in _titles)
              Navigator(
                onGenerateInitialRoutes: (_, __) => [
                  _route(_ListScreen(title: title)),
                  _route(const _DetailScreen()),
                ],
              ),
          ],
        ),
      );
}
