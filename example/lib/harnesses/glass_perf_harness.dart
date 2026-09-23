// Perf harness — frame cost of premium glass over a scrolling page.
//
// Eight standalone premium glass buttons (each its own layer, as an app's
// chrome is) over a page that scrolls at a constant speed. After a warm-up
// the harness records [FrameTiming]s for a fixed window and writes a summary
// to `<tmp>/glass_perf.txt` in the app container, and on screen.
//
//   flutter build ios --profile -t lib/harnesses/glass_perf_harness.dart \
//     --dart-define=RECIPE=parity
//
// RECIPE: `original` (the pre-parity premium path: blur + render only),
// `dark` (the dark recipe alone), `decomp` (each frost feature on and off),
// anything else the light and dark recipes against the original.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'look_parity_harness.dart' show kDarkSettings, kSettings;

const String kRecipe = String.fromEnvironment('RECIPE', defaultValue: 'parity');
const int kWarmupMs = 2000;

/// Extra copies of the top bar down the page, to load the GPU enough that
/// it holds its clock for a trace (`--dart-define=COPIES=3`).
const int kCopies = int.fromEnvironment('COPIES', defaultValue: 0);
const int kWindowMs = 6000;

const LiquidGlassSettings kOriginal = LiquidGlassSettings(
  glassColor: Color(0x33FFFFFF),
  blur: 3,
  thickness: 32,
  lightIntensity: 0.6,
  saturation: 1.5,
);

/// Variants stepped through in one launch, each measured for [kWindowMs]
/// and appended to the summary file before the next starts, so a variant
/// that gets the app killed is the one after the last line written. A
/// `<tmp>/glass_variant.txt` holding an index runs that one alone, for a GPU
/// trace.
final List<(String, LiquidGlassSettings)> kVariants = switch (kRecipe) {
  'original' => [('original', kOriginal)],
  'dark' => [('dark', kDarkSettings)],
  'decomp' => [
      ('original', kOriginal),
      ('light', kSettings),
      ('light-noweight', kSettings.copyWith(frostWeight: 1)),
      ('dark', kDarkSettings),
      ('dark-noweight', kDarkSettings.copyWith(frostWeight: 1)),
      ('light-nofrost', kSettings.copyWith(frost: 0)),
      ('dark-nofrost', kDarkSettings.copyWith(frost: 0)),
    ],
  _ => [
      ('warmup', kOriginal),
      ('original', kOriginal),
      ('light', kSettings),
      ('dark', kDarkSettings),
      ('light-noweight', kSettings.copyWith(frostWeight: 1)),
    ],
};

void _log(String line) => File('${Directory.systemTemp.path}/glass_perf.txt')
    .writeAsStringSync('$line\n', mode: FileMode.append);

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) => _log('ERROR ${details.exception}\n'
        '${details.stack.toString().split('\n').take(6).join('\n')}');
    await LiquidGlassWidgets.initialize();
    runApp(LiquidGlassWidgets.wrap(child: const _App()));
  }, (error, stack) {
    _log('ZONE $error\n${stack.toString().split('\n').take(6).join('\n')}');
  });
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => CupertinoApp(
        debugShowCheckedModeBanner: false,
        title: 'Glass Perf',
        theme: CupertinoThemeData(
          brightness: kRecipe == 'dark' ? Brightness.dark : Brightness.light,
        ),
        home: const GlassPerfHarness(),
      );
}

class GlassPerfHarness extends StatefulWidget {
  const GlassPerfHarness({super.key});

  @override
  State<GlassPerfHarness> createState() => _GlassPerfHarnessState();
}

class _GlassPerfHarnessState extends State<GlassPerfHarness>
    with SingleTickerProviderStateMixin {
  final _controller = ScrollController();
  late final Ticker _ticker;
  final _timings = <FrameTiming>[];
  bool _recording = false;
  String? _summary;
  int _variant = 0;
  final _lines = <String>[];

  LiquidGlassSettings get _settings => kVariants[_variant].$2;

  /// Read from `<tmp>/glass_variant.txt` if present: hold that one variant
  /// (for a GPU trace) instead of stepping through the list.
  static final int? _held = () {
    final file = File('${Directory.systemTemp.path}/glass_variant.txt');
    return file.existsSync()
        ? int.tryParse(file.readAsStringSync().trim())
        : null;
  }();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!_controller.hasClients ||
          !_controller.position.hasContentDimensions) {
        return;
      }
      final max = _controller.position.maxScrollExtent;
      final offset = (elapsed.inMicroseconds / 1e6 * 700) % max;
      _controller.jumpTo(offset);
    })
      ..start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    if (_held case final held?) _variant = held;
    File('${Directory.systemTemp.path}/glass_perf.txt')
        .writeAsStringSync('start ${DateTime.now()} held $_held\n');
    _schedule();
  }

  void _schedule() {
    Timer(const Duration(milliseconds: kWarmupMs), () {
      _timings.clear();
      _recording = true;
      Timer(const Duration(milliseconds: kWindowMs), _finish);
    });
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_recording) _timings.addAll(timings);
  }

  double _pct(List<double> sorted, double p) =>
      sorted[math.min(sorted.length - 1, (sorted.length * p).floor())];

  void _finish() {
    _recording = false;
    _log('finish ${kVariants[_variant].$1} timings ${_timings.length}');
    if (_timings.isEmpty) {
      setState(() => _variant = (_variant + 1) % kVariants.length);
      _schedule();
      return;
    }
    final raster = _timings
        .map((t) => t.rasterDuration.inMicroseconds / 1000.0)
        .toList()
      ..sort();
    final span = _timings
        .map((t) => t.totalSpan.inMicroseconds / 1000.0)
        .toList()
      ..sort();
    final fps = _timings.length / (kWindowMs / 1000);
    String row(String name, List<double> v) => '$name '
        'avg ${(v.reduce((a, b) => a + b) / v.length).toStringAsFixed(2)} '
        'p50 ${_pct(v, 0.5).toStringAsFixed(2)} '
        'p90 ${_pct(v, 0.9).toStringAsFixed(2)} '
        'p99 ${_pct(v, 0.99).toStringAsFixed(2)} '
        'max ${v.last.toStringAsFixed(2)}';
    final rss = (ProcessInfo.currentRss / 1e6).toStringAsFixed(0);
    final maxRss = (ProcessInfo.maxRss / 1e6).toStringAsFixed(0);
    final summary = [
      '${kVariants[_variant].$1} frames ${_timings.length} '
          'fps ${fps.toStringAsFixed(1)} rss $rss max $maxRss',
      row('  raster', raster),
      row('  span', span),
    ].join('\n');
    _lines.add(summary);
    _log(summary);
    setState(() {
      if (_held != null) {
        _log('done');
      } else if (_variant < kVariants.length - 1) {
        _variant++;
        _schedule();
      } else {
        _summary = _lines.join('\n');
        _log('done');
      }
    });
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _button(double size) => GlassButton.custom(
        width: size,
        height: size,
        shape: const LiquidOval(),
        useOwnLayer: true,
        settings: _settings,
        quality: GlassQuality.premium,
        label: 'Add',
        onTap: () {},
        child: Icon(
          CupertinoIcons.plus,
          size: 22,
          color: kRecipe == 'dark'
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF000000),
        ),
      );

  Widget _capsule(double width, double height) => GlassButton.custom(
        width: width,
        height: height,
        shape: LiquidRoundedRectangle(borderRadius: height / 2),
        useOwnLayer: true,
        settings: _settings,
        quality: GlassQuality.premium,
        label: 'Label',
        onTap: () {},
        child: Text(
          'Label',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: kRecipe == 'dark'
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF000000),
            decoration: TextDecoration.none,
          ),
        ),
      );

  Widget _row(BuildContext context, int index) {
    final dark = kRecipe == 'dark';
    final ink = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    switch (index % 4) {
      case 0:
        return SizedBox(
          height: 120,
          child: Row(
            children: [
              for (var i = 0; i < 16; i++)
                Expanded(
                  child: ColoredBox(
                    color: i.isEven ? ink : ink.withValues(alpha: 0),
                  ),
                ),
            ],
          ),
        );
      case 1:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Liquid glass bends and frosts the page behind it. ' * 4,
            style: TextStyle(fontSize: 15, color: ink, height: 1.3),
          ),
        );
      case 2:
        return Container(
          height: 140,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                HSVColor.fromAHSV(1, (index * 37) % 360.0, 0.7, 0.9).toColor(),
                HSVColor.fromAHSV(1, (index * 37 + 90) % 360.0, 0.8, 0.6)
                    .toColor(),
              ],
            ),
          ),
        );
      default:
        return SizedBox(
          height: 90,
          child: Center(
            child: Text(
              'Row $index',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = kRecipe == 'dark';
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      child: Stack(
        children: [
          ListView.builder(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 400,
            itemBuilder: _row,
          ),
          Positioned(
            top: top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _button(44),
                const SizedBox(width: 12),
                _capsule(120, 44),
                const Spacer(),
                _button(44),
                const SizedBox(width: 12),
                _button(44),
              ],
            ),
          ),
          for (var c = 1; c <= kCopies; c++)
            Positioned(
              top: top + 8 + c * 150,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _button(56),
                  const SizedBox(width: 12),
                  _capsule(120, 56),
                  const Spacer(),
                  _button(56),
                  const SizedBox(width: 12),
                  _button(56),
                ],
              ),
            ),
          Positioned(
            bottom: bottom + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _button(56),
                const SizedBox(width: 12),
                Expanded(child: _capsule(200, 56)),
                const SizedBox(width: 12),
                _button(56),
                const SizedBox(width: 12),
                _button(56),
              ],
            ),
          ),
          if (_summary case final summary?)
            Positioned(
              left: 16,
              right: 16,
              top: top + 80,
              child: ColoredBox(
                color: const Color(0xDD000000),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    summary,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFFFFFFF),
                      fontFamily: 'Menlo',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
