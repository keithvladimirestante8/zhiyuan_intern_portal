import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Glass morphism card widget with corporate styling
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? tintColor;
  final double blur;
  final double opacity;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final bool isInteractive;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.tintColor,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.border,
    this.boxShadow,
    this.onTap,
    this.isInteractive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget cardWidget = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: border ?? _getBorder(isDark),
        boxShadow: boxShadow ?? _getBoxShadow(isDark),
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            border: Border.all(
              color: (tintColor ?? AppTheme.primaryGold).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Glass effect background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius ?? BorderRadius.circular(16),
                    color: _getGlassColor(isDark),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );

    if (isInteractive || onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }

  Color _getGlassColor(bool isDark) {
    if (tintColor != null) {
      return tintColor!.withOpacity(opacity);
    }
    return isDark 
        ? AppTheme.glassCardDark 
        : AppTheme.glassCardLight;
  }

  Border _getBorder(bool isDark) {
    return Border.all(
      color: isDark 
          ? AppTheme.primaryGold.withOpacity(0.3)
          : AppTheme.primaryGold.withOpacity(0.2),
      width: 1,
    );
  }

  List<BoxShadow> _getBoxShadow(bool isDark) {
    return [
      BoxShadow(
        color: isDark 
            ? Colors.black.withOpacity(0.3)
            : Colors.black.withOpacity(0.1),
        blurRadius: blur,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: (tintColor ?? AppTheme.primaryGold).withOpacity(0.1),
        blurRadius: blur / 2,
        offset: const Offset(0, 2),
      ),
    ];
  }
}

/// Premium glass card with enhanced effects
class PremiumGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? tintColor;
  final VoidCallback? onTap;
  final bool isAnimated;

  const PremiumGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.tintColor,
    this.onTap,
    this.isAnimated = true,
  });

  @override
  State<PremiumGlassCard> createState() => _PremiumGlassCardState();
}

class _PremiumGlassCardState extends State<PremiumGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isAnimated) {
      _controller = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );

      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: 0.98,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));

      _opacityAnimation = Tween<double>(
        begin: 0.1,
        end: 0.2,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));
    }
  }

  @override
  void dispose() {
    if (widget.isAnimated) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAnimated) {
      return GlassCard(
        child: widget.child,
        padding: widget.padding,
        margin: widget.margin,
        width: widget.width,
        height: widget.height,
        borderRadius: widget.borderRadius,
        tintColor: widget.tintColor,
        onTap: widget.onTap,
        isInteractive: widget.onTap != null,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GlassCard(
            child: widget.child,
            padding: widget.padding,
            margin: widget.margin,
            width: widget.width,
            height: widget.height,
            borderRadius: widget.borderRadius,
            tintColor: widget.tintColor,
            opacity: _opacityAnimation.value,
            onTap: () {
              if (widget.onTap != null) {
                _controller.forward().then((_) {
                  _controller.reverse();
                });
                widget.onTap!();
              }
            },
            isInteractive: widget.onTap != null,
          ),
        );
      },
    );
  }
}

/// Glass card specifically for dashboard widgets
class DashboardGlassCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? action;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const DashboardGlassCard({
    super.key,
    required this.child,
    this.title,
    this.action,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: padding ?? const EdgeInsets.all(20),
      margin: margin,
      width: width,
      height: height,
      tintColor: AppTheme.primaryGold,
      opacity: 0.05,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextColor(isDark),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// Glass card for profile sections
class ProfileGlassCard extends StatelessWidget {
  final Widget child;
  final String title;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ProfileGlassCard({
    super.key,
    required this.child,
    required this.title,
    this.icon,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PremiumGlassCard(
      padding: padding ?? const EdgeInsets.all(24),
      margin: margin,
      tintColor: AppTheme.primaryGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: AppTheme.primaryGold,
                  size: 24,
                ),
                const SizedBox(width: 12),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextColor(isDark),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
