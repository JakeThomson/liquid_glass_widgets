import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../src/renderer/liquid_glass_renderer.dart';

import '../../constants/glass_defaults.dart';
import '../../types/glass_quality.dart';
import '../containers/glass_container.dart';
import '../shared/inherited_liquid_glass.dart';
import 'glass_menu_item.dart';
import '../../theme/glass_theme_helpers.dart';

part 'shared/glass_menu_internal.dart';

/// A liquid glass context menu that morphs from its trigger button.
///
/// [GlassMenu] implements the iOS 26 "liquid glass" morphing pattern where
/// a button seamlessly transforms into a menu. The same glass container
/// transitions between button and menu states using spring physics.
///
/// ## Features
/// - **True morphing**: Button transforms into menu (not overlay)
/// - **Smooth spring physics**: Gentle settle (stiffness: 300, damping: 24)
/// - **Liquid swoop**: Subtle 5px parabolic arc during morph
/// - **Elastic stretch**: [LiquidStretch] wrapping for physics-driven drag
/// - **Scroll-aware selection pill**: Slides to highlight the hovered item;
///   automatically hidden during scrolling to prevent visual noise
/// - **Heterogeneous items**: Mix [GlassMenuItem], [GlassMenuDivider], and
///   [GlassMenuLabel] in a single menu
/// - **glowOnTapOnly**: Momentary glare that disappears on drag/scroll
class GlassMenu extends StatefulWidget {
  /// The widget that triggers the menu.
  ///
  /// If provided, this widget will be wrapped in a [GestureDetector].
  /// For interactive triggers (e.g. [GlassButton]), use [triggerBuilder].
  final Widget? trigger;

  /// A builder for the trigger widget that exposes the menu toggle callback.
  final Widget Function(BuildContext context, VoidCallback toggleMenu)?
      triggerBuilder;

  /// The list of items to display in the menu.
  ///
  /// Accepts any widget — typically [GlassMenuItem], [GlassMenuDivider],
  /// or [GlassMenuLabel].
  final List<Widget> items;

  /// Width of the expanded menu. Defaults to 200.
  final double menuWidth;

  /// Fixed height for the menu content area.
  ///
  /// When set, the menu becomes scrollable and this height is used as the
  /// maximum content height. When null, the menu sizes to fit its children.
  final double? menuHeight;

  /// Border radius of the expanded menu. Defaults to 16.0.
  final double menuBorderRadius;

  /// Custom glass settings for the menu container.
  final LiquidGlassSettings? glassSettings;

  /// Rendering quality for the glass effect.
  final GlassQuality? quality;

  // ---------------------------------------------------------------------------
  // Elastic Stretch (LiquidStretch)
  // ---------------------------------------------------------------------------

  /// Scale factor applied during interaction for tactile feedback.
  /// Defaults to 1.05.
  final double interactionScale;

  /// Stretch multiplier applied to drag offset. Defaults to 0.5.
  final double stretch;

  /// Resistance factor for the elastic drag. Defaults to 0.08.
  final double stretchResistance;

  /// Axis to constrain the stretch to. When null, stretches in both axes.
  final Axis? stretchAxis;

  /// Allow stretch in the positive X direction (right). Defaults to true.
  final bool? allowPositiveX;

  /// Allow stretch in the negative X direction (left). Defaults to true.
  final bool? allowNegativeX;

  /// Allow stretch in the positive Y direction (down). Defaults to true.
  final bool? allowPositiveY;

  /// Allow stretch in the negative Y direction (up). Defaults to true.
  final bool? allowNegativeY;

  // ---------------------------------------------------------------------------
  // Selection Pill
  // ---------------------------------------------------------------------------

  /// Background color of the sliding selection pill.
  ///
  /// Defaults to white at 12% opacity.
  final Color? selectionColor;

  // ---------------------------------------------------------------------------
  // GlassGlow
  // ---------------------------------------------------------------------------

  /// Whether to show a finger-following glare on the menu surface.
  /// Defaults to true.
  final bool enableInteractionGlow;

  /// When true, the glow appears on touch-down but is suppressed after a
  /// >10px drag, preventing a "stuck glow" during scrolling.
  final bool glowOnTapOnly;

  /// Color of the interaction glow. Defaults to white at 15% opacity.
  final Color? glowColor;

  /// Radius of the interaction glow relative to the surface's shortest side.
  /// Defaults to 1.0.
  final double glowRadius;

  /// Creates a liquid glass menu.
  const GlassMenu({
    super.key,
    this.trigger,
    this.triggerBuilder,
    required this.items,
    this.menuWidth = 200,
    this.menuHeight,
    this.menuBorderRadius = 16.0,
    this.glassSettings,
    this.quality,
    this.interactionScale = 1.05,
    this.stretch = 0.5,
    this.stretchResistance = 0.08,
    this.stretchAxis,
    this.allowPositiveX,
    this.allowNegativeX,
    this.allowPositiveY,
    this.allowNegativeY,
    this.selectionColor,
    this.enableInteractionGlow = true,
    this.glowOnTapOnly = true,
    this.glowColor,
    this.glowRadius = 1.0,
  }) : assert(
          trigger != null || triggerBuilder != null,
          'Either trigger or triggerBuilder must be provided',
        );

  @override
  State<GlassMenu> createState() => _GlassMenuState();
}
