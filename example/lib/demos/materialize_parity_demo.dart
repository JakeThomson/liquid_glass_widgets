// Parity harness — the package's materialize transition beside iOS's own.
//
// The top button is a native SwiftUI `glassEffect` circle whose entrance and
// exit are `glassEffectTransition(.materialize)`; the bottom is
// [GlassMaterialize] over the same geometry. One toggle drives both, so a
// single screen recording captures the two animations frame for frame.
//
// Not part of the example showcase — it needs the native platform view
// registered in the iOS runner's AppDelegate.
//
//   cd example && flutter run -t lib/demos/materialize_parity_demo.dart
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(child: const _App()));
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => const CupertinoApp(
        debugShowCheckedModeBanner: false,
        title: 'Materialize Parity',
        theme: CupertinoThemeData(brightness: Brightness.light),
        home: MaterializeParityDemo(),
      );
}

/// Shows the native and package transitions one above the other.
class MaterializeParityDemo extends StatefulWidget {
  /// Creates the parity harness.
  const MaterializeParityDemo({super.key});

  @override
  State<MaterializeParityDemo> createState() => _MaterializeParityDemoState();
}

class _MaterializeParityDemoState extends State<MaterializeParityDemo> {
  MethodChannel? _native;
  bool _visible = true;
  bool _looping = false;

  @override
  void initState() {
    super.initState();
    // Auto-run so a recording can be taken without driving the simulator.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loop());
  }

  void _setVisible(bool value) {
    // The native side first: the platform-channel hop costs a fraction of a
    // frame, and starting it earlier keeps the two entrances aligned rather
    // than handing our side a head start the comparison would then measure.
    _native?.invokeMethod<void>('setVisible', value);
    setState(() => _visible = value);
  }

  Future<void> _loop() async {
    if (_looping) return;
    setState(() => _looping = true);
    // Long holds: the transitions are ~250-350ms, and the still frames either
    // side are what make the onset legible in a recording.
    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      _setVisible(false);
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      _setVisible(true);
    }
    if (mounted) setState(() => _looping = false);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Text(
                  'Materialize parity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 28),
                const _Label('NATIVE — glassEffectTransition(.materialize)'),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: UiKitView(
                    viewType: 'liquid_glass_widgets/native_materialize',
                    onPlatformViewCreated: (id) => _native = MethodChannel(
                      'liquid_glass_widgets/native_materialize_$id',
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const _Label('PACKAGE — GlassMaterialize'),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Center(
                    child: GlassMaterialize(
                      visible: _visible,
                      // Matched to the native side's explicit linear 600ms so
                      // the comparison measures shape, not duration.
                      duration: const Duration(milliseconds: 600),
                      exitDuration: const Duration(milliseconds: 600),
                      child: GlassButton(
                        icon: const Icon(CupertinoIcons.search),
                        width: 56,
                        height: 56,
                        useOwnLayer: true,
                        label: 'Search',
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                CupertinoButton.filled(
                  onPressed: () => _setVisible(!_visible),
                  child: Text(_visible ? 'Dematerialize' : 'Materialize'),
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  onPressed: _looping ? null : _loop,
                  child: Text(_looping ? 'Looping…' : 'Loop 4×'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 0.4,
            color: Color(0x8A000000),
          ),
        ),
      );
}

/// A backdrop with structure, so refraction dissolving to nothing is legible.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBFD4F2), Color(0xFFE9C7D8), Color(0xFFF7D9A8)],
        ),
      ),
      child: Column(
        children: List.generate(
          16,
          (i) => Expanded(
            child: Row(
              children: List.generate(
                9,
                (j) => Expanded(
                  child: ColoredBox(
                    color: (i + j).isEven
                        ? const Color(0x22000000)
                        : const Color(0x00000000),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
