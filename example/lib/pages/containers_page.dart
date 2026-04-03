import 'package:liquid_glass_widgets_example/constants/glass_settings.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ContainersPage extends StatelessWidget {
  const ContainersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveLiquidGlassLayer(
      quality: GlassQuality.standard,
      settings: RecommendedGlassSettings.standard,
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
                    const SizedBox(height: 20),
                    const Text(
                      'Containers',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Glass container widgets for content',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // GlassContainer Section
                    const _SectionTitle(title: 'GlassContainer'),
                    const SizedBox(height: 16),
                    GlassContainer(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Basic Glass Container',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The foundational container widget with glass effect. Use this as a base for custom glass surfaces.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.all(16),
                            shape: const LiquidRoundedSuperellipse(
                              borderRadius: 20,
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  CupertinoIcons.cube_box,
                                  color: Colors.blue,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Custom Shape',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassContainer(
                            width: double.infinity,
                            height: 100,
                            alignment: Alignment.center,
                            child: const Text(
                              'Fixed Size',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // GlassCard Section
                    const _SectionTitle(title: 'GlassCard'),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  CupertinoIcons.rectangle_stack,
                                  color: Colors.purple,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Glass Card Title',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Standard card styling',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 12),
                          const Text(
                            'GlassCard provides opinionated defaults for card-like content with 16px padding and 12px rounded corners.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GlassCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                const Icon(
                                  CupertinoIcons.heart_fill,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Favorites',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                const Icon(
                                  CupertinoIcons.star_fill,
                                  color: Colors.amber,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Starred',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                const Icon(
                                  CupertinoIcons.bookmark_fill,
                                  color: Colors.green,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Saved',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // GlassPanel Section
                    const _SectionTitle(title: 'GlassPanel'),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Settings Panel',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _SettingsRow(
                            icon: Icon(CupertinoIcons.bell_fill),
                            title: 'Notifications',
                            subtitle: 'Manage notification settings',
                          ),
                          const SizedBox(height: 16),
                          _SettingsRow(
                            icon: Icon(CupertinoIcons.lock_fill),
                            title: 'Privacy',
                            subtitle: 'Control your privacy settings',
                          ),
                          const SizedBox(height: 16),
                          _SettingsRow(
                            icon: Icon(CupertinoIcons.paintbrush_fill),
                            title: 'Appearance',
                            subtitle: 'Customize the look and feel',
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'GlassPanel is optimized for larger content areas with 24px padding and 20px rounded corners.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // GlassDivider Section
                    const _SectionTitle(title: 'GlassDivider'),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Section A',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const GlassDivider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Section B',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const GlassDivider(indent: 16, endIndent: 16),
                          const SizedBox(height: 8),
                          Text(
                            'Section C — custom indent',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: SizedBox(
                        height: 60,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text('Left',
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.8))),
                            const GlassDivider.vertical(),
                            Text('Center',
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.8))),
                            const GlassDivider.vertical(),
                            Text('Right',
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.8))),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // GlassListTile Section
                    const _SectionTitle(title: 'GlassListTile'),
                    const SizedBox(height: 16),
                    Text(
                      'Grouped settings list — zero-padding GlassCard',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          GlassListTile(
                            leading: const Icon(CupertinoIcons.person_fill,
                                color: Colors.blue),
                            title: const Text('Account'),
                            trailing: GlassListTile.chevron,
                            onTap: () {},
                          ),
                          GlassListTile(
                            leading: const Icon(CupertinoIcons.bell_fill,
                                color: Colors.orange),
                            title: const Text('Notifications'),
                            subtitle: const Text('Banners, sounds, badges'),
                            trailing: GlassListTile.chevron,
                            onTap: () {},
                          ),
                          GlassListTile(
                            leading: const Icon(CupertinoIcons.lock_fill,
                                color: Colors.green),
                            title: const Text('Privacy & Security'),
                            trailing: GlassListTile.chevron,
                            onTap: () {},
                          ),
                          GlassListTile(
                            leading: const Icon(CupertinoIcons.paintbrush_fill,
                                color: Colors.purple),
                            title: const Text('Appearance'),
                            subtitle: const Text('Dark mode, accent colour'),
                            trailing: GlassListTile.chevron,
                            isLast: true,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // GlassStepper Section — iOS 26 UIStepper equivalent
                    const _SectionTitle(title: 'GlassStepper'),
                    const SizedBox(height: 8),
                    Text(
                      'iOS 26 UIStepper — tap or hold for auto-repeat',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _StepperDemo(),

                    const SizedBox(height: 40),

                    // GlassWizard Section — multi-step flow
                    const _SectionTitle(title: 'GlassWizard'),
                    const SizedBox(height: 8),
                    Text(
                      'Multi-step flow — tap headers or buttons to advance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _WizardDemo(),

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
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Widget icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: icon,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Icon(
          CupertinoIcons.chevron_right,
          color: Colors.white.withValues(alpha: 0.4),
          size: 20,
        ),
      ],
    );
  }
}

// iOS 26-style +/- stepper demo
class _StepperDemo extends StatefulWidget {
  const _StepperDemo();

  @override
  State<_StepperDemo> createState() => _StepperDemoState();
}

class _StepperDemoState extends State<_StepperDemo> {
  double _quantity = 1;
  double _temperature = 20;
  double _rating = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Quantity row
        GlassCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quantity',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              Row(
                children: [
                  Text(
                    _quantity.toInt().toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GlassStepper(
                    value: _quantity,
                    min: 1,
                    max: 99,
                    step: 1,
                    onChanged: (v) => setState(() => _quantity = v),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Temperature row with larger step
        GlassCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Temperature',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              Row(
                children: [
                  Text(
                    '${_temperature.toInt()}°C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GlassStepper(
                    value: _temperature,
                    min: -10,
                    max: 40,
                    step: 0.5,
                    onChanged: (v) => setState(() => _temperature = v),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Wrapping rating
        GlassCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rating (wraps)',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              Row(
                children: [
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < _rating ? Icons.star : Icons.star_border,
                        color: i < _rating ? Colors.amber : Colors.white38,
                        size: 18,
                      );
                    }),
                  ),
                  const SizedBox(width: 12),
                  GlassStepper(
                    value: _rating,
                    min: 1,
                    max: 5,
                    step: 1,
                    wraps: true,
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Multi-step wizard demo
class _WizardDemo extends StatefulWidget {
  const _WizardDemo();

  @override
  State<_WizardDemo> createState() => _WizardDemoState();
}

class _WizardDemoState extends State<_WizardDemo> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return GlassWizard(
      currentStep: _currentStep,
      onStepTapped: (i) => setState(() => _currentStep = i),
      steps: [
        GlassWizardStep(
          title: const Text('Account'),
          subtitle: const Text('Enter your credentials'),
          content: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassButton(
              icon: const Icon(CupertinoIcons.arrow_right),
              label: 'Continue',
              onTap: () => setState(() => _currentStep = 1),
            ),
          ),
        ),
        GlassWizardStep(
          title: const Text('Profile'),
          subtitle: const Text('Tell us about yourself'),
          content: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassButton(
              icon: const Icon(CupertinoIcons.arrow_right),
              label: 'Continue',
              onTap: () => setState(() => _currentStep = 2),
            ),
          ),
        ),
        const GlassWizardStep(
          title: Text('All done'),
          subtitle: Text('Your account is ready'),
          isCompleted: true,
        ),
      ],
    );
  }
}
