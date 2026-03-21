import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets_example/constants/glass_settings.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  // Determinate progress values
  double _circularProgress = 0.5;
  double _linearProgress = 0.5;

  // Simulated upload progress
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  Timer? _uploadTimer;

  @override
  void dispose() {
    _uploadTimer?.cancel();
    super.dispose();
  }

  void _startSimulatedUpload() {
    setState(() {
      _uploadProgress = 0.0;
      _isUploading = true;
    });

    _uploadTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _uploadProgress += 0.01;
        if (_uploadProgress >= 1.0) {
          _uploadProgress = 1.0;
          _isUploading = false;
          timer.cancel();

          // Reset after a delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _uploadProgress = 0.0;
              });
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveLiquidGlassLayer(
      settings: RecommendedGlassSettings.standard,
      quality: GlassQuality.standard,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Feedback',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status and loading indicators',
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // =========================================================
                    // CIRCULAR PROGRESS - INDETERMINATE
                    // =========================================================
                    _buildSectionHeader('Circular - Loading'),
                    const SizedBox(height: 16),

                    _buildDemoCard(
                      title: 'Indeterminate Spinner',
                      subtitle: 'Infinite rotation animation',
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              GlassProgressIndicator.circular(
                                size: 14.0,
                                strokeWidth: 2.0,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Small',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              GlassProgressIndicator.circular(),
                              SizedBox(height: 8),
                              Text(
                                'Medium',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              GlassProgressIndicator.circular(
                                size: 28.0,
                                strokeWidth: 3.0,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Large',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // =========================================================
                    // CIRCULAR PROGRESS - DETERMINATE
                    // =========================================================
                    _buildSectionHeader('Circular - Progress Ring'),
                    const SizedBox(height: 16),

                    _buildDemoCard(
                      title: 'Determinate Progress',
                      subtitle: 'Shows completion percentage',
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  GlassProgressIndicator.circular(
                                    value: _circularProgress,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(_circularProgress * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  GlassProgressIndicator.circular(
                                    value: _circularProgress,
                                    size: 40.0,
                                    strokeWidth: 4.0,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(_circularProgress * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Slider(
                            value: _circularProgress,
                            onChanged: (value) {
                              setState(() => _circularProgress = value);
                            },
                            activeColor: const Color(0xFF007AFF),
                            inactiveColor: Colors.white24,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildDemoCard(
                      title: 'Progress Stages',
                      subtitle: '0%, 25%, 50%, 75%, 100%',
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ProgressStage(value: 0.0, label: '0%'),
                          _ProgressStage(value: 0.25, label: '25%'),
                          _ProgressStage(value: 0.5, label: '50%'),
                          _ProgressStage(value: 0.75, label: '75%'),
                          _ProgressStage(value: 1.0, label: '100%'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // =========================================================
                    // CIRCULAR PROGRESS - COLORS
                    // =========================================================
                    _buildSectionHeader('Circular - Colors'),
                    const SizedBox(height: 16),

                    _buildDemoCard(
                      title: 'Color Variants',
                      subtitle: 'Different colors for different contexts',
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              GlassProgressIndicator.circular(
                                value: 0.7,
                                color: Color(0xFF007AFF),
                                size: 32.0,
                                strokeWidth: 3.0,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Info',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              GlassProgressIndicator.circular(
                                value: 0.7,
                                color: Colors.green,
                                size: 32.0,
                                strokeWidth: 3.0,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Success',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              GlassProgressIndicator.circular(
                                value: 0.7,
                                color: Colors.orange,
                                size: 32.0,
                                strokeWidth: 3.0,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Warning',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              GlassProgressIndicator.circular(
                                value: 0.7,
                                color: Colors.red,
                                size: 32.0,
                                strokeWidth: 3.0,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Error',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // =========================================================
                    // LINEAR PROGRESS - INDETERMINATE
                    // =========================================================
                    _buildSectionHeader('Linear - Loading'),
                    const SizedBox(height: 16),

                    _buildDemoCard(
                      title: 'Indeterminate Bar',
                      subtitle: 'Moving bar animation',
                      child: const Column(
                        children: [
                          GlassProgressIndicator.linear(),
                          SizedBox(height: 16),
                          GlassProgressIndicator.linear(
                            height: 6.0,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // =========================================================
                    // LINEAR PROGRESS - DETERMINATE
                    // =========================================================
                    _buildSectionHeader('Linear - Progress Bar'),
                    const SizedBox(height: 16),

                    _buildDemoCard(
                      title: 'Determinate Progress',
                      subtitle: 'Shows completion percentage',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: GlassProgressIndicator.linear(
                                  value: _linearProgress,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${(_linearProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Slider(
                            value: _linearProgress,
                            onChanged: (value) {
                              setState(() => _linearProgress = value);
                            },
                            activeColor: const Color(0xFF007AFF),
                            inactiveColor: Colors.white24,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildDemoCard(
                      title: 'Height Variants',
                      subtitle: 'Thin, standard, and thick bars',
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: GlassProgressIndicator.linear(
                                  value: 0.6,
                                  height: 2.0,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Thin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GlassProgressIndicator.linear(
                                  value: 0.6,
                                  height: 4.0,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Standard',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GlassProgressIndicator.linear(
                                  value: 0.6,
                                  height: 8.0,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Thick',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // =========================================================
                    // LINEAR PROGRESS - COLORS
                    // =========================================================
                    _buildSectionHeader('Linear - Colors'),
                    const SizedBox(height: 16),

                    _buildDemoCard(
                      title: 'Color Variants',
                      subtitle: 'Different colors for different contexts',
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: GlassProgressIndicator.linear(
                                  value: 0.8,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Info',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GlassProgressIndicator.linear(
                                  value: 0.8,
                                  color: Colors.green,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Success',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GlassProgressIndicator.linear(
                                  value: 0.8,
                                  color: Colors.orange,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Warning',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GlassProgressIndicator.linear(
                                  value: 0.8,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Error',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // =========================================================
                    // TOAST / SNACKBAR NOTIFICATIONS
                    // =========================================================
                    _buildSectionHeader('Toast Notifications'),
                    const SizedBox(height: 16),

                    _buildDemoCard(
                      title: 'Toast Types',
                      subtitle: 'Different toast styles for different contexts',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          GlassButton.custom(
                            onTap: () {
                              GlassToast.show(
                                context,
                                message: 'Settings saved successfully!',
                                type: GlassToastType.success,
                                icon: CupertinoIcons.check_mark_circled_solid,
                                position: GlassToastPosition.top,
                              );
                            },
                            width: 160,
                            height: 44,
                            shape:
                                const LiquidRoundedRectangle(borderRadius: 12),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.check_mark_circled_solid,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Success'),
                              ],
                            ),
                          ),
                          GlassButton.custom(
                            onTap: () {
                              GlassToast.show(
                                context,
                                message: 'Failed to connect to server',
                                type: GlassToastType.error,
                                duration: const Duration(seconds: 4),
                                position: GlassToastPosition.top,
                              );
                            },
                            width: 160,
                            height: 44,
                            shape:
                                const LiquidRoundedRectangle(borderRadius: 12),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.xmark_circle_fill,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Error'),
                              ],
                            ),
                          ),
                          GlassButton.custom(
                            onTap: () {
                              GlassToast.show(
                                context,
                                message: 'New message received from Alice',
                                type: GlassToastType.info,
                                position: GlassToastPosition.top,
                              );
                            },
                            width: 160,
                            height: 44,
                            shape:
                                const LiquidRoundedRectangle(borderRadius: 12),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.info_circle_fill,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Info'),
                              ],
                            ),
                          ),
                          GlassButton.custom(
                            onTap: () {
                              GlassToast.show(
                                context,
                                message: 'Storage space running low',
                                type: GlassToastType.warning,
                                position: GlassToastPosition.top,
                              );
                            },
                            width: 160,
                            height: 44,
                            shape:
                                const LiquidRoundedRectangle(borderRadius: 12),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    CupertinoIcons
                                        .exclamationmark_triangle_fill,
                                    size: 16,
                                    color: Colors.white),
                                SizedBox(width: 8),
                                Text('Warning'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildDemoCard(
                      title: 'Toast Positions',
                      subtitle: 'Toasts can appear at top, center, or bottom',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          GlassButton.custom(
                            onTap: () {
                              GlassToast.show(
                                context,
                                message: 'Toast at the top',
                                type: GlassToastType.neutral,
                                position: GlassToastPosition.top,
                              );
                            },
                            width: 160,
                            height: 44,
                            shape:
                                const LiquidRoundedRectangle(borderRadius: 12),
                            child: const Text('Top'),
                          ),
                          GlassButton.custom(
                            onTap: () {
                              GlassToast.show(
                                context,
                                message: 'Toast in the center',
                                type: GlassToastType.neutral,
                                position: GlassToastPosition.center,
                              );
                            },
                            width: 160,
                            height: 44,
                            shape:
                                const LiquidRoundedRectangle(borderRadius: 12),
                            child: const Text('Center'),
                          ),
                          GlassButton.custom(
                            onTap: () {
                              GlassToast.show(
                                context,
                                message: 'Toast at the bottom',
                                type: GlassToastType.neutral,
                                position: GlassToastPosition.bottom,
                              );
                            },
                            width: 160,
                            height: 44,
                            shape:
                                const LiquidRoundedRectangle(borderRadius: 12),
                            child: const Text('Bottom'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildDemoCard(
                      title: 'Toast with Action',
                      subtitle: 'Add interactive action buttons',
                      child: GlassButton.custom(
                        onTap: () {
                          GlassToast.show(
                            context,
                            message: 'Message deleted',
                            type: GlassToastType.neutral,
                            position: GlassToastPosition.top,
                            action: GlassToastAction(
                              label: 'Undo',
                              onPressed: () {
                                GlassToast.show(
                                  context,
                                  message: 'Deletion undone!',
                                  type: GlassToastType.success,
                                  position: GlassToastPosition.top,
                                  duration: const Duration(seconds: 2),
                                );
                              },
                            ),
                            duration: const Duration(seconds: 5),
                          );
                        },
                        width: double.infinity,
                        height: 44,
                        shape: const LiquidRoundedRectangle(borderRadius: 12),
                        child: const Text('Show Toast with Undo Action'),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // =========================================================
                    // REAL-WORLD EXAMPLE - FILE UPLOAD
                    // =========================================================
                    _buildSectionHeader('Real-World Example'),
                    const SizedBox(height: 16),

                    _buildDemoCard(
                      title: 'File Upload Simulation',
                      subtitle: 'Animated progress tracking',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.doc,
                                color: Colors.white70,
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'document.pdf',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isUploading
                                          ? 'Uploading... ${(_uploadProgress * 100).toInt()}%'
                                          : _uploadProgress == 1.0
                                              ? 'Upload complete!'
                                              : '2.4 MB',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _uploadProgress == 1.0
                                            ? Colors.green
                                            : Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_uploadProgress == 1.0)
                                const Icon(
                                  CupertinoIcons.checkmark_circle_fill,
                                  color: Colors.green,
                                  size: 24,
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GlassProgressIndicator.linear(
                            value: _uploadProgress,
                            color: _uploadProgress == 1.0
                                ? Colors.green
                                : const Color(0xFF007AFF),
                          ),
                          const SizedBox(height: 16),
                          GlassButton.custom(
                            onTap: _isUploading ? () {} : _startSimulatedUpload,
                            enabled: !_isUploading,
                            width: double.infinity,
                            height: 44,
                            shape:
                                const LiquidRoundedRectangle(borderRadius: 12),
                            child: Text(
                              _isUploading
                                  ? 'Uploading...'
                                  : _uploadProgress == 1.0
                                      ? 'Upload Again'
                                      : 'Start Upload',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildDemoCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

// Helper widget for progress stages
class _ProgressStage extends StatelessWidget {
  const _ProgressStage({
    required this.value,
    required this.label,
  });

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassProgressIndicator.circular(
          value: value,
          size: 24.0,
          strokeWidth: 3.0,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }
}
