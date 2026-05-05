import 'package:flutter/material.dart';

/// A menu item for use within a [GlassMenu].
///
/// [GlassMenuItem] provides a standard layout for menu options, including
/// support for icons, labels, subtitles, and "destructive" styling.
class GlassMenuItem extends StatefulWidget {
  /// Creates a glass menu item.
  const GlassMenuItem({
    required this.title,
    required this.onTap,
    super.key,
    this.icon,
    this.isDestructive = false,
    this.trailing,
    this.height = 44.0,
    this.subtitle,
    this.enabled = true,
    this.titleStyle,
    this.subtitleStyle,
    this.iconColor,
    this.iconSize = 20.0,
  });

  /// The primary text of the item.
  final String title;

  /// Optional secondary text shown below [title].
  final String? subtitle;

  /// The icon widget displayed before the title.
  final Widget? icon;

  /// Callback when the item is tapped.
  final VoidCallback onTap;

  /// Whether this is a destructive action (e.g., Delete).
  ///
  /// Renders with red text and distinct hover effect.
  final bool isDestructive;

  /// Whether this item is enabled and interactive.
  ///
  /// When false, the item is rendered at reduced opacity and tap gestures
  /// are ignored. Defaults to true.
  final bool enabled;

  /// A widget to display after the title (e.g., shortcut key).
  final Widget? trailing;

  /// Height of the item.
  ///
  /// Defaults to 44.0 (standard iOS touch target).
  final double height;

  /// Custom text style for the title. When null, uses the default style
  /// derived from [isDestructive].
  final TextStyle? titleStyle;

  /// Custom text style for the subtitle. When null, uses a muted default.
  final TextStyle? subtitleStyle;

  /// Override for the icon foreground color. Falls back to the computed
  /// color from [isDestructive] when null.
  final Color? iconColor;

  /// Size of the icon. Defaults to 20.0.
  final double iconSize;

  @override
  State<GlassMenuItem> createState() => _GlassMenuItemState();
}

class _GlassMenuItemState extends State<GlassMenuItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  // QUALITY 1 FIX: Clear hover flag on dispose so it cannot leak when the
  // overlay closes while the desktop cursor is still positioned over this item.
  @override
  void dispose() {
    _isHovered = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Smart color inheritance: iconColor → titleStyle.color → destructive → white
    final Color defaultTextColor = widget.isDestructive
        ? const Color(0xFFEF5350)
        : const Color(0xE6FFFFFF);
    final Color defaultIconColor = widget.iconColor ??
        widget.titleStyle?.color ??
        (widget.isDestructive
            ? const Color(0xFFEF5350)
            : const Color(0xB3FFFFFF));

    final Color textColor = widget.titleStyle?.color ?? defaultTextColor;

    final Color backgroundColor = _isPressed
        ? const Color(0x26FFFFFF)
        : _isHovered
            ? const Color(0x1AFFFFFF)
            : Colors.transparent;

    final double scale = _isPressed ? 0.98 : 1.0;
    final bool hasSubtitle = widget.subtitle != null;

    // Increase height when subtitle is present if no explicit height override.
    final double effectiveHeight =
        hasSubtitle && widget.height == 44.0 ? 58.0 : widget.height;

    final Widget content = GestureDetector(
      onTapDown:
          widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp:
          widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: SizedBox(
          height: effectiveHeight,
          // SizedBox fixes the layout footprint so AnimatedScale's
          // RenderTransform cannot overflow its parent (Stack or Column).
          // Transform-based widgets retain the pre-scale layout size, which
          // causes the overflow banner during press (scale=0.98) inside the
          // menu's bounded Positioned.fill.
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              height: effectiveHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // Icon
                  if (widget.icon != null) ...[
                    IconTheme(
                      data: IconThemeData(
                          color: defaultIconColor, size: widget.iconSize),
                      child: widget.icon!,
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Title (+ optional subtitle)
                  Expanded(
                    child: hasSubtitle
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: widget.titleStyle ??
                                    TextStyle(
                                      color: textColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                              Text(
                                widget.subtitle!,
                                style: widget.subtitleStyle ??
                                    TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ],
                          )
                        : Text(
                            widget.title,
                            style: widget.titleStyle ??
                                TextStyle(
                                  color: textColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                  ),

                  // Trailing
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return widget.enabled ? content : Opacity(opacity: 0.4, child: content);
  }
}

/// A subtle hairline separator for use within a [GlassMenu].
///
/// Place between [GlassMenuItem] instances to create visual groupings.
/// Renders as a thin semi-transparent horizontal line.
class GlassMenuDivider extends StatelessWidget {
  /// Creates a glass menu divider.
  const GlassMenuDivider({super.key, this.height = 1.0, this.color});

  /// Height of the divider line. Defaults to 1.0.
  final double height;

  /// Color of the divider. Defaults to white at 15% opacity.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: color ?? Colors.white.withValues(alpha: 0.15),
    );
  }
}

/// A non-interactive section label for use within a [GlassMenu].
///
/// Use to add named groupings above related [GlassMenuItem]s.
/// Renders in a small, muted caption style.
class GlassMenuLabel extends StatelessWidget {
  /// Creates a glass menu section label.
  const GlassMenuLabel({
    required this.title,
    super.key,
    this.style,
    // QUALITY 3 FIX: Explicit height so _getItemHeight() in the menu state
    // uses this value rather than a hardcoded 30.0, preventing pill-position
    // drift when a custom style has a non-default fontSize.
    this.height = 30.0,
  });

  /// The label text.
  final String title;

  /// Override for the default caption text style.
  final TextStyle? style;

  /// Height of this label row, used by [GlassMenu] to compute the selection
  /// pill position. Defaults to 30.0 — increase if using a large [style].
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 2),
      child: Text(
        title.toUpperCase(),
        style: style ??
            TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
