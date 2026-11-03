import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LuxuryCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Border? border;
  final double borderRadius;
  final bool hasGlow;

  const LuxuryCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.borderRadius = 16,
    this.hasGlow = false,
  });

  @override
  State<LuxuryCard> createState() => _LuxuryCardState();
}

class _LuxuryCardState extends State<LuxuryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBg = widget.backgroundColor ??
        (_isHovered ? AppColors.cardSurfaceHover : AppColors.cardSurface);

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.border ??
            Border.all(
              color: _isHovered ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
              width: 1,
            ),
        boxShadow: widget.hasGlow || _isHovered
            ? AppColors.cardShadowHover
            : AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: widget.onTap,
          onHover: (hovering) {
            setState(() {
              _isHovered = hovering;
            });
          },
          splashColor: AppColors.primary.withValues(alpha: 0.12),
          highlightColor: AppColors.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.all(16),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
