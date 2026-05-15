/// Quality Comparison Demo — Premium vs Standard side-by-side
///
/// Renders GlassButton, GlassSegmentedControl, GlassCard, and GlassTabBar
/// with IDENTICAL [LiquidGlassSettings] at both quality levels so you can
/// directly compare how the thickness/light normalization affects each widget
/// on the Standard (2D lightweight shader) path.
///
/// Settings are deliberately higher than defaults (thickness: 28,
/// lightIntensity: 0.9) to make the normalization delta clearly visible.
///
/// Run standalone:
///   flutter run -t example/lib/demos/quality_comparison_demo.dart
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

// ── Default glass settings for the tuning panel ──────────────────────────────
const _kDefaultThickness = 28.0;
const _kDefaultLightIntensity = 0.9;
const _kDefaultBlur = 3.0;
const _kDefaultAmbient = 0.22;
const _kDefaultSaturation = 1.2;
const _kDefaultRefractiveIndex = 1.25;

// ── Entry point ───────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(
    // Recommended for production: auto-benchmarks the device and
    // degrades quality gracefully on weaker hardware.
    adaptiveQuality: true,
    child: const _App(),
  ));
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Quality Comparison',
      debugShowCheckedModeBanner: false,
      home: _ComparisonPage(),
    );
  }
}

// ── Demo page ─────────────────────────────────────────────────────────────────

class _ComparisonPage extends StatefulWidget {
  const _ComparisonPage();

  @override
  State<_ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<_ComparisonPage> {
  int _segIndex = 0;
  int _tabIndex = 0;
  bool _switchValue = false;
  double _sliderValue = 0.4;
  bool _backgroundSampling = true;

  // ── Live tuning state ────────────────────────────────────────────────────
  bool _showTuning = false;
  double _thickness = _kDefaultThickness;
  double _lightIntensity = _kDefaultLightIntensity;
  double _blur = _kDefaultBlur;
  double _ambient = _kDefaultAmbient;
  double _saturation = _kDefaultSaturation;
  double _refractiveIndex = _kDefaultRefractiveIndex;

  LiquidGlassSettings get _kGlass => LiquidGlassSettings(
    glassColor: Colors.white12,
    blur: _blur,
    thickness: _thickness,
    lightIntensity: _lightIntensity,
    ambientStrength: _ambient,
    chromaticAberration: 0.02,
    refractiveIndex: _refractiveIndex,
    saturation: _saturation,
  );

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      enableBackgroundSampling: _backgroundSampling,
      background: Stack(
          fit: StackFit.expand,
          children: [
            // Background — mountain landscape gives good glass contrast
            Image.network(
              'https://images.unsplash.com/photo-1506905925346-21bda4d32df4'
              '?q=80&w=2070&auto=format&fit=crop',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1a2a4a),
                      Color(0xFF0d1b2a),
                      Color(0xFF162032)
                    ],
                  ),
                ),
              ),
            ),
            // Subtle dark veil for readability
            Container(color: Colors.black.withValues(alpha: 0.28)),
          ],
        ),
        child: Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                _buildColumnLabels(),
                const SizedBox(height: 4),
                // Live tuning panel — collapse when not needed
                _TuningPanel(
                  visible: _showTuning,
                  thickness: _thickness,
                  lightIntensity: _lightIntensity,
                  blur: _blur,
                  ambient: _ambient,
                  saturation: _saturation,
                  refractiveIndex: _refractiveIndex,
                  onChanged: (t, li, b, a, s, ri) => setState(() {
                    _thickness = t;
                    _lightIntensity = li;
                    _blur = b;
                    _ambient = a;
                    _saturation = s;
                    _refractiveIndex = ri;
                  }),
                ),
                Expanded(child: _buildComparisonList()),
              ],
            ),
          ),
        ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Quality Comparison',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Row(
                children: [
                  const Text('BG Sample', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 24,
                    width: 40,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: CupertinoSwitch(
                        value: _backgroundSampling,
                        onChanged: (v) => setState(() => _backgroundSampling = v),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Tuning toggle
          GestureDetector(
            onTap: () => setState(() => _showTuning = !_showTuning),
            child: Text(
              _showTuning ? '▲ Hide tuning' : '▼ Tune settings',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'thickness: ${_thickness.toStringAsFixed(0)}  '
            'light: ${_lightIntensity.toStringAsFixed(2)}  '
            'blur: ${_blur.toStringAsFixed(1)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ── Column labels ─────────────────────────────────────────────────────────

  Widget _buildColumnLabels() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _QualityBadge(
              label: 'PREMIUM',
              subtitle: 'Impeller · 3D SDF',
              color: const Color(0xFFFFB830),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QualityBadge(
              label: 'STANDARD',
              subtitle: 'Skia/Web · 2D shader',
              color: const Color(0xFF5AC8FA),
            ),
          ),
        ],
      ),
    );
  }

  // ── Comparison list ───────────────────────────────────────────────────────

  Widget _buildComparisonList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        children: [
          // ── GlassButton ─────────────────────────────────────────────────
          _ComparisonRow(
            label: 'GlassButton',
            premium: GlassButton(
              useOwnLayer: true,
              settings: _kGlass,
              quality: GlassQuality.premium,
              onTap: () {},
              icon: const Icon(CupertinoIcons.play_arrow_solid),
              label: 'Press',
            ),
            standard: GlassButton(
              useOwnLayer: true,
              settings: _kGlass,
              quality: GlassQuality.standard,
              onTap: () {},
              icon: const Icon(CupertinoIcons.play_arrow_solid),
              label: 'Press',
            ),
          ),

          const SizedBox(height: 20),

          // ── GlassSegmentedControl ────────────────────────────────────────
          _ComparisonRow(
            label: 'GlassSegmentedControl',
            premium: GlassSegmentedControl(
              useOwnLayer: true,
              glassSettings: _kGlass,
              indicatorSettings: _kGlass,
              quality: GlassQuality.premium,
              segments: const ['Day', 'Week', 'Month'],
              selectedIndex: _segIndex,
              onSegmentSelected: (i) => setState(() => _segIndex = i),
            ),
            standard: GlassSegmentedControl(
              useOwnLayer: true,
              glassSettings: _kGlass,
              indicatorSettings: _kGlass,
              quality: GlassQuality.standard,
              segments: const ['Day', 'Week', 'Month'],
              selectedIndex: _segIndex,
              onSegmentSelected: (i) => setState(() => _segIndex = i),
            ),
          ),

          const SizedBox(height: 20),

          // ── GlassCard ───────────────────────────────────────────────────
          _ComparisonRow(
            label: 'GlassCard',
            premium: GlassCard(
              useOwnLayer: true,
              settings: _kGlass,
              quality: GlassQuality.premium,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '3D bevel · specular\nreflection',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            standard: GlassCard(
              useOwnLayer: true,
              settings: _kGlass,
              quality: GlassQuality.standard,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Standard',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '2D rim · normalised\nthickness & light',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── GlassTabBar (full-width stacked) ─────────────────────────────
          _FullWidthRow(
            label: 'GlassTabBar',
            premiumWidget: GlassTabBar(
              useOwnLayer: true,
              settings: _kGlass,
              quality: GlassQuality.premium,
              tabs: [
                GlassTab(icon: const Icon(CupertinoIcons.home)),
                GlassTab(icon: const Icon(CupertinoIcons.search)),
                GlassTab(icon: const Icon(CupertinoIcons.person)),
              ],
              selectedIndex: _tabIndex,
              onTabSelected: (i) => setState(() => _tabIndex = i),
            ),
            standardWidget: GlassTabBar(
              useOwnLayer: true,
              settings: _kGlass,
              quality: GlassQuality.standard,
              tabs: [
                GlassTab(icon: const Icon(CupertinoIcons.home)),
                GlassTab(icon: const Icon(CupertinoIcons.search)),
                GlassTab(icon: const Icon(CupertinoIcons.person)),
              ],
              selectedIndex: _tabIndex,
              onTabSelected: (i) => setState(() => _tabIndex = i),
            ),
          ),

          const SizedBox(height: 20),

          // ── GlassSwitch ───────────────────────────────────────────────────
          _ComparisonRow(
            label: 'GlassSwitch',
            premium: GlassSwitch(
              value: _switchValue,
              quality: GlassQuality.premium,
              onChanged: (v) => setState(() => _switchValue = v),
            ),
            standard: GlassSwitch(
              value: _switchValue,
              quality: GlassQuality.standard,
              onChanged: (v) => setState(() => _switchValue = v),
            ),
          ),

          const SizedBox(height: 20),

          // ── GlassSlider ───────────────────────────────────────────────────
          _FullWidthRow(
            label: 'GlassSlider',
            premiumWidget: GlassSlider(
              value: _sliderValue,
              quality: GlassQuality.premium,
              onChanged: (v) => setState(() => _sliderValue = v),
            ),
            standardWidget: GlassSlider(
              value: _sliderValue,
              quality: GlassQuality.standard,
              onChanged: (v) => setState(() => _sliderValue = v),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

/// Column header badge showing quality tier name and renderer description.
class _QualityBadge extends StatelessWidget {
  const _QualityBadge({
    required this.label,
    required this.subtitle,
    required this.color,
  });

  final String label;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Side-by-side comparison row for widgets that fit in equal columns.
class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.premium,
    required this.standard,
  });

  final String label;
  final Widget premium;
  final Widget standard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(child: premium),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Center(child: standard),
            ),
          ],
        ),
      ],
    );
  }
}

/// Full-width stacked row for widgets like GlassTabBar that need the full width.
class _FullWidthRow extends StatelessWidget {
  const _FullWidthRow({
    required this.label,
    required this.premiumWidget,
    required this.standardWidget,
  });

  final String label;
  final Widget premiumWidget;
  final Widget standardWidget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),

        // Premium
        Row(
          children: [
            _QualityPill('PREMIUM', const Color(0xFFFFB830)),
            const SizedBox(width: 10),
            Expanded(child: premiumWidget),
          ],
        ),

        const SizedBox(height: 12),

        // Standard
        Row(
          children: [
            _QualityPill('STANDARD', const Color(0xFF5AC8FA)),
            const SizedBox(width: 10),
            Expanded(child: standardWidget),
          ],
        ),
      ],
    );
  }
}

/// Small vertical pill label for the full-width stacked rows.
class _QualityPill extends StatelessWidget {
  const _QualityPill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ── Tuning panel ──────────────────────────────────────────────────────────────

/// Collapsible live tuning panel for iterating on glass settings.
///
/// Shows sliders for the 6 key params that affect the premium/standard visual
/// delta. Also displays what the Standard path's normalization produces for
/// thickness and lightIntensity, so you can see both values simultaneously.
class _TuningPanel extends StatelessWidget {
  const _TuningPanel({
    required this.visible,
    required this.thickness,
    required this.lightIntensity,
    required this.blur,
    required this.ambient,
    required this.saturation,
    required this.refractiveIndex,
    required this.onChanged,
  });

  final bool visible;
  final double thickness;
  final double lightIntensity;
  final double blur;
  final double ambient;
  final double saturation;
  final double refractiveIndex;

  /// (thickness, lightIntensity, blur, ambient, saturation, refractiveIndex)
  final void Function(double, double, double, double, double, double) onChanged;

  // Standard normalisation multipliers (from GlassThemeHelpers).
  static const _thicknessMul = 0.40;
  static const _lightMul = 0.60;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Text(
                'TUNING',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              // Standard normalised preview
              Text(
                'std thickness≈${(thickness * _thicknessMul).toStringAsFixed(1)}  '
                'std light≈${(lightIntensity * _lightMul).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF5AC8FA),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Slider('thickness', thickness, 4, 60, (v) => onChanged(v, lightIntensity, blur, ambient, saturation, refractiveIndex)),
          _Slider('lightIntensity', lightIntensity, 0, 1.5, (v) => onChanged(thickness, v, blur, ambient, saturation, refractiveIndex)),
          _Slider('blur', blur, 0, 12, (v) => onChanged(thickness, lightIntensity, v, ambient, saturation, refractiveIndex)),
          _Slider('ambient', ambient, 0, 1, (v) => onChanged(thickness, lightIntensity, blur, v, saturation, refractiveIndex)),
          _Slider('saturation', saturation, 0.5, 2, (v) => onChanged(thickness, lightIntensity, blur, ambient, v, refractiveIndex)),
          _Slider('refractiveIndex', refractiveIndex, 1.0, 2.0, (v) => onChanged(thickness, lightIntensity, blur, ambient, saturation, v)),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider(this.label, this.value, this.min, this.max, this.onChanged);

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            '$label: ${value.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 1.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: Colors.white38,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white70,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
