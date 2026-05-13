// /// ChemAlert — AI Voice Assistant Demo
// ///
// /// Showcases:
// ///   • Animated multi-ring orbital waveform orb (pure Flutter CustomPainter)
// ///   • LiquidGlassButton for the microphone, close, and chat actions
// ///   • GlassCard for the transcript display area
// ///   • Dark navy/purple gradient background
// ///   • Animated "AI Listening…" pulse indicator
// ///
// /// Run standalone:
// ///   flutter run -t lib/chem_alert/chem_alert_demo.dart
// library;

// import 'dart:math' as math;
// import 'dart:ui' as ui;
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // CONSTANTS
// // ─────────────────────────────────────────────────────────────────────────────

// const _kPurple = Color(0xFF9B59FF);
// const _kPink = Color(0xFFE040FB);
// const _kBlue = Color(0xFF4FC3F7);
// const _kDeepNavy = Color(0xFF020715);
// //const _kNavyMid = Color(0xFF020715);

// const _kGlassMic = LiquidGlassSettings(
//   glassColor: Color(0x992A1A4A),
//   thickness: 28,
//   blur: 4,
//   lightIntensity: 0.5,
//   chromaticAberration: 0.02,
//   saturation: 1.3,
// );

// const _kGlassAction = LiquidGlassSettings(
//   glassColor: Color(0x88181830),
//   thickness: 20,
//   blur: 3,
//   lightIntensity: 0.35,
//   chromaticAberration: 0.01,
// );

// // ─────────────────────────────────────────────────────────────────────────────
// // ENTRY POINT
// // ─────────────────────────────────────────────────────────────────────────────

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await LiquidGlassWidgets.initialize();
//   runApp(
//     LiquidGlassWidgets.wrap(child: const ChemAlertApp()),
//   );
// }

// class ChemAlertApp extends StatelessWidget {
//   const ChemAlertApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'ChemAlert',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         brightness: Brightness.dark,
//         useMaterial3: true,
//         colorScheme: const ColorScheme.dark(
//           primary: _kPurple,
//           surface: _kDeepNavy,
//         ),
//       ),
//       home: const ChemAlertScreen(),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // MAIN SCREEN
// // ─────────────────────────────────────────────────────────────────────────────

// enum _ListeningState { idle, listening, processing }

// class ChemAlertScreen extends StatefulWidget {
//   const ChemAlertScreen({super.key});

//   @override
//   State<ChemAlertScreen> createState() => _ChemAlertScreenState();
// }

// class _ChemAlertScreenState extends State<ChemAlertScreen>
//     with TickerProviderStateMixin {
//   // ── Animation controllers ─────────────────────────────────────────────────
//   late final AnimationController _orbController;
//   late final AnimationController _pulseController;
//   late final AnimationController _textController;
//   late final AnimationController _listeningBadgeController;

//   // ── State ─────────────────────────────────────────────────────────────────
//   _ListeningState _state = _ListeningState.listening;
//   int _transcriptIndex = 0;

//   static const _transcripts = [
//     (
//       highlighted: 'Hi, what PPE do I need for Hydrochloric Acid',
//       faded: ' and is it in my stock register and listed in stock.',
//     ),
//     (
//       highlighted: 'Show me the SDS for Sodium Hydroxide',
//       faded: ' and the emergency procedures.',
//     ),
//     (
//       highlighted: 'What are the storage requirements for Acetone',
//       faded: ' and can it be stored near flammable materials?',
//     ),
//   ];

//   @override
//   void initState() {
//     super.initState();

//     _orbController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 8),
//     )..repeat();

//     _pulseController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1600),
//     )..repeat(reverse: true);

//     _textController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 600),
//     )..forward();

//     _listeningBadgeController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 900),
//     )..repeat(reverse: true);
//   }

//   @override
//   void dispose() {
//     _orbController.dispose();
//     _pulseController.dispose();
//     _textController.dispose();
//     _listeningBadgeController.dispose();
//     super.dispose();
//   }

//   void _onMicTap() {
//     setState(() {
//       if (_state == _ListeningState.listening) {
//         _state = _ListeningState.processing;
//       } else {
//         _state = _ListeningState.listening;
//         _transcriptIndex = (_transcriptIndex + 1) % _transcripts.length;
//         _textController.forward(from: 0);
//       }
//     });
//   }

//   void _onReset() {
//     setState(() {
//       _state = _ListeningState.idle;
//     });
//   }

//   bool get _isListening => _state == _ListeningState.listening;
//   bool get _isProcessing => _state == _ListeningState.processing;

//   @override
//   Widget build(BuildContext context) {
//     final topPad = MediaQuery.paddingOf(context).top;
//     final transcript = _transcripts[_transcriptIndex];

//     return Scaffold(
//       backgroundColor: _kDeepNavy,
//       body: Stack(
//         children: [
//           // ── Gradient background ──────────────────────────────────────────
//           const _BackgroundGradient(),

//           // ── Content ─────────────────────────────────────────────────────
//           SafeArea(
//             child: Column(
//               children: [
//                 // ── Top bar ────────────────────────────────────────────────
//                 _TopBar(onReset: _onReset),

//                 // ── AI Listening badge ─────────────────────────────────────
//                 AnimatedBuilder(
//                   animation: _listeningBadgeController,
//                   builder: (context, _) {
//                     final opacity = _isListening
//                         ? (0.6 +
//                             0.4 * _listeningBadgeController.value)
//                         : (_isProcessing ? 1.0 : 0.0);
//                     return Opacity(
//                       opacity: opacity,
//                       child: Padding(
//                         padding: const EdgeInsets.only(top: 4, bottom: 0),
//                         child: Text(
//                           _isProcessing ? 'AI Processing…' : 'AI Listening…',
//                           style: TextStyle(
//                             color: Colors.white.withValues(alpha: 0.7),
//                             fontSize: 14,
//                             fontWeight: FontWeight.w400,
//                             letterSpacing: 0.2,
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 ),

//                 const SizedBox(height: 8),

//                 // ── Orb ────────────────────────────────────────────────────
//                 Expanded(
//                   flex: 5,
//                   child: Stack(
//                     alignment: Alignment.center,
//                     children: [
//                       // Glow circle behind the orb
//                       // CSS: linear-gradient(90deg,
//                       //   rgba(235,102,255,0.30) 0%,
//                       //   rgba(162,70,247,0.30)  50%,
//                       //   rgba(32,119,255,0.30)  100%)
//                       // Rendered as a blurred ellipse so it bleeds softly.
//                       Center(
//                         child: LayoutBuilder(
//                           builder: (context, constraints) {
//                             final w = math.min(constraints.maxWidth, 332.0);
//                             final h = math.min(constraints.maxHeight, 355.0);
//                             return ImageFiltered(
//                               imageFilter: ui.ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
//                               child: Container(
//                                 width: w,
//                                 height: h,
//                                 decoration: const BoxDecoration(
//                                   shape: BoxShape.circle,
//                                   gradient: LinearGradient(
//                                     // 90deg = left-to-right
//                                     begin: Alignment.centerLeft,
//                                     end: Alignment.centerRight,
//                                     colors: [
//                                       Color(0x4DEB66FF), // rgba(235,102,255,0.30)
//                                       Color(0x4DA246F7), // rgba(162,70,247,0.30)
//                                       Color(0x4D2077FF), // rgba(32,119,255,0.30)
//                                     ],
//                                     stops: [0.0, 0.5, 1.0],
//                                   ),
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                       // Orb on top
//                       AnimatedBuilder(
//                         animation: _orbController,
//                         builder: (context, _) {
//                           return AnimatedBuilder(
//                             animation: _pulseController,
//                             builder: (context, _) {
//                               return _OrbWidget(
//                                 progress: _orbController.value,
//                                 pulseValue: _pulseController.value,
//                                 isActive: _isListening || _isProcessing,
//                               );
//                             },
//                           );
//                         },
//                       ),
//                     ],
//                   ),
//                 ),

//                 // ── Transcript ─────────────────────────────────────────────
//                 Expanded(
//                   flex: 3,
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 32),
//                     child: FadeTransition(
//                       opacity: _textController,
//                       child: _TranscriptWidget(
//                         highlighted: transcript.highlighted,
//                         faded: transcript.faded,
//                         state: _state,
//                       ),
//                     ),
//                   ),
//                 ),

//                 // ── Bottom controls ────────────────────────────────────────
//                 _BottomControls(
//                   isListening: _isListening,
//                   isProcessing: _isProcessing,
//                   onMicTap: _onMicTap,
//                   pulseController: _pulseController,
//                 ),

//                 SizedBox(height: topPad > 0 ? 16 : 32),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // BACKGROUND
// // ─────────────────────────────────────────────────────────────────────────────

// class _BackgroundGradient extends StatelessWidget {
//   const _BackgroundGradient();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: const Color(0xFF020715),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // TOP BAR
// // ─────────────────────────────────────────────────────────────────────────────

// class _TopBar extends StatelessWidget {
//   const _TopBar({required this.onReset});
//   final VoidCallback onReset;

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//       child: Row(
//         children: [
//           // Back button
//           GlassButton(
//             onTap: () => Navigator.of(context).maybePop(),
//             quality: GlassQuality.premium,
//             useOwnLayer: true,
//             shape: const LiquidRoundedSuperellipse(borderRadius: 22),
//             settings: _kGlassAction,
//             icon: const SizedBox(
//               width: 44,
//               height: 44,
//               child: Icon(
//                 CupertinoIcons.chevron_left,
//                 color: Colors.white,
//                 size: 18,
//               ),
//             ),
//           ),

//           // Title
//           const Expanded(
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(CupertinoIcons.sparkles, color: _kPurple, size: 20),
//                 SizedBox(width: 8),
//                 Text(
//                   'ChemAlert',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.w600,
//                     letterSpacing: -0.3,
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Reset / refresh button
//           GlassButton(
//             onTap: onReset,
//             quality: GlassQuality.premium,
//             useOwnLayer: true,
//             shape: const LiquidRoundedSuperellipse(borderRadius: 22),
//             settings: _kGlassAction,
//             icon: const SizedBox(
//               width: 44,
//               height: 44,
//               child: Icon(
//                 CupertinoIcons.refresh,
//                 color: Colors.white,
//                 size: 18,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // ORB WIDGET
// // ─────────────────────────────────────────────────────────────────────────────

// class _OrbWidget extends StatelessWidget {
//   const _OrbWidget({
//     required this.progress,
//     required this.pulseValue,
//     required this.isActive,
//   });

//   final double progress;
//   final double pulseValue;
//   final bool isActive;

//   @override
//   Widget build(BuildContext context) {
//     // Add a very subtle scale and rotation so the static image feels alive
//     // when active or pulsing.
//     final scale = 1.0 + (pulseValue * 0.05);
//     final rotation = progress * math.pi * 2 * 0.1;

//     return Transform(
//       alignment: Alignment.center,
//       transform: Matrix4.identity()
//         ..scale(scale, scale)
//         ..rotateZ(rotation),
//       child: Center(
//         child: Image.asset(
//           'assets/chem_alert_orb.png',
//           fit: BoxFit.contain,
//           // Make sure it doesn't get clipped or oversized
//           width: MediaQuery.sizeOf(context).width * 0.85,
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // The orb is built from tilted elliptical "ribbon" layers.
// // Each ribbon = many thin parametric curves drawn close together:
// //   x(θ) = (r + A·sin(n·θ + φ)) · cos(θ)          (wave modulation)
// //   y(θ) = (r + A·sin(n·θ + φ)) · sin(θ) · yScale  (tilt / 3D look)
// // Then the whole layer is rotated by the ring's orientation angle.
// // Multiple overlapping tilted rings at different orientations create the
// // 4-cusped dark center void and the glowing ribbon aesthetic.
// // ─────────────────────────────────────────────────────────────────────────────

// // ─────────────────────────────────────────────────────────────────────────────
// // TRANSCRIPT WIDGET
// // ─────────────────────────────────────────────────────────────────────────────

// class _TranscriptWidget extends StatelessWidget {
//   const _TranscriptWidget({
//     required this.highlighted,
//     required this.faded,
//     required this.state,
//   });

//   final String highlighted;
//   final String faded;
//   final _ListeningState state;

//   @override
//   Widget build(BuildContext context) {
//     final isIdle = state == _ListeningState.idle;

//     if (isIdle) {
//       return Center(
//         child: Text(
//           'Tap the mic to start',
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             color: Colors.white.withValues(alpha: 0.4),
//             fontSize: 18,
//             fontWeight: FontWeight.w400,
//           ),
//         ),
//       );
//     }

//     return Center(
//       child: RichText(
//         textAlign: TextAlign.center,
//         text: TextSpan(
//           children: [
//             TextSpan(
//               text: highlighted,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 24,
//                 fontWeight: FontWeight.w600,
//                 height: 1.35,
//                 letterSpacing: -0.3,
//               ),
//             ),
//             TextSpan(
//               text: faded,
//               style: TextStyle(
//                 color: Colors.white.withValues(alpha: 0.35),
//                 fontSize: 24,
//                 fontWeight: FontWeight.w400,
//                 height: 1.35,
//                 letterSpacing: -0.3,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // BOTTOM CONTROLS
// // ─────────────────────────────────────────────────────────────────────────────

// class _BottomControls extends StatelessWidget {
//   const _BottomControls({
//     required this.isListening,
//     required this.isProcessing,
//     required this.onMicTap,
//     required this.pulseController,
//   });

//   final bool isListening;
//   final bool isProcessing;
//   final VoidCallback onMicTap;
//   final AnimationController pulseController;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         // ── Waveform visualiser strip ──────────────────────────────────────
//         AnimatedOpacity(
//           opacity: isListening ? 1.0 : 0.0,
//           duration: const Duration(milliseconds: 400),
//           child: SizedBox(
//             height: 32,
//             child: AnimatedBuilder(
//               animation: pulseController,
//               builder: (context, _) {
//                 return CustomPaint(
//                   painter: _WaveformPainter(pulseController.value),
//                   size: const Size(double.infinity, 32),
//                 );
//               },
//             ),
//           ),
//         ),

//         const SizedBox(height: 16),

//         // ── Main mic button + side actions ─────────────────────────────────
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             // AI Chat button
//             GlassButton(
//               onTap: () {},
//               quality: GlassQuality.premium,
//               useOwnLayer: true,
//               shape: const LiquidRoundedSuperellipse(borderRadius: 24),
//               settings: _kGlassAction,
//               icon: const SizedBox(
//                 width: 52,
//                 height: 52,
//                 child: Center(
//                   child: Text(
//                     'AI',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 13,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//               ),
//             ),

//             const SizedBox(width: 28),

//             // Mic button — larger, pulsing
//             AnimatedBuilder(
//               animation: pulseController,
//               builder: (context, _) {
//                 final scale = isListening
//                     ? (1.0 + 0.06 * pulseController.value)
//                     : 1.0;
//                 return Transform.scale(
//                   scale: scale,
//                   child: _MicButton(
//                     isListening: isListening,
//                     isProcessing: isProcessing,
//                     onTap: onMicTap,
//                   ),
//                 );
//               },
//             ),

//             const SizedBox(width: 28),

//             // Close button
//             GlassButton(
//               onTap: () {},
//               quality: GlassQuality.premium,
//               useOwnLayer: true,
//               shape: const LiquidRoundedSuperellipse(borderRadius: 24),
//               settings: _kGlassAction,
//               icon: const SizedBox(
//                 width: 52,
//                 height: 52,
//                 child: Icon(
//                   CupertinoIcons.xmark,
//                   color: Colors.white,
//                   size: 20,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // MIC BUTTON
// // ─────────────────────────────────────────────────────────────────────────────

// class _MicButton extends StatelessWidget {
//   const _MicButton({
//     required this.isListening,
//     required this.isProcessing,
//     required this.onTap,
//   });

//   final bool isListening;
//   final bool isProcessing;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return GlassButton(
//       onTap: onTap,
//       quality: GlassQuality.premium,
//       useOwnLayer: true,
//       shape: const LiquidRoundedSuperellipse(borderRadius: 40),
//       settings: _kGlassMic,
//       icon: Container(
//         width: 80,
//         height: 80,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           gradient: isListening
//               ? const SweepGradient(
//                   colors: [_kPurple, _kPink, _kBlue, _kPurple],
//                 )
//               : isProcessing
//                   ? const RadialGradient(
//                       colors: [Color(0xFF5C2D9E), Color(0xFF2A1A4A)],
//                     )
//                   : null,
//           color: isListening || isProcessing
//               ? null
//               : const Color(0xFF1E1040),
//         ),
//         child: Center(
//           child: isProcessing
//               ? const SizedBox(
//                   width: 28,
//                   height: 28,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2.5,
//                     valueColor:
//                         AlwaysStoppedAnimation<Color>(Colors.white),
//                   ),
//                 )
//               : Icon(
//                   isListening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
//                   color: Colors.white,
//                   size: 30,
//                 ),
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // WAVEFORM PAINTER
// // ─────────────────────────────────────────────────────────────────────────────

// class _WaveformPainter extends CustomPainter {
//   const _WaveformPainter(this.phase);
//   final double phase;

//   @override
//   void paint(Canvas canvas, Size size) {
//     final barCount = 32;
//     final barW = (size.width - 80) / barCount;
//     final centerX = size.width / 2;

//     final paint = Paint()
//       ..strokeCap = StrokeCap.round
//       ..strokeWidth = barW * 0.55;

//     for (var i = 0; i < barCount; i++) {
//       final norm = (i - barCount / 2) / (barCount / 2); // -1..1
//       final waveH = math.sin(
//               (norm * math.pi * 2.5) + phase * 2 * math.pi) *
//           0.4;
//       final baseH = 0.2 + 0.3 * (1 - norm.abs());
//       final h = (baseH + waveH).clamp(0.1, 1.0) * size.height;

//       final x = centerX + (i - barCount / 2) * barW;
//       final color = Color.lerp(
//         _kPurple,
//         _kBlue,
//         (i / barCount),
//       )!
//           .withValues(alpha: 0.7);

//       paint.color = color;
//       canvas.drawLine(
//         Offset(x, size.height / 2 - h / 2),
//         Offset(x, size.height / 2 + h / 2),
//         paint,
//       );
//     }
//   }

//   @override
//   bool shouldRepaint(_WaveformPainter oldDelegate) =>
//       oldDelegate.phase != phase;
// }
