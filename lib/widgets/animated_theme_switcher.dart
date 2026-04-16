import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// iOS-style toggle with smooth background transitions
class AnimatedThemeSwitcher extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;
  final double size;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final Color activeColor;
  final Color inactiveColor;
  final Color? activeTrackColor;
  final Color? inactiveTrackColor;

  const AnimatedThemeSwitcher({
    super.key,
    required this.isDark,
    required this.onChanged,
    this.size = 24.0,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeColor,
    required this.inactiveColor,
    this.activeTrackColor,
    this.inactiveTrackColor,
  });

  @override
  State<AnimatedThemeSwitcher> createState() => _AnimatedThemeSwitcherState();
}

class _AnimatedThemeSwitcherState extends State<AnimatedThemeSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _positionAnimation;
  late Animation<Color?> _bgColorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Sync animation state with the initial theme mode to fix color inconsistency
    if (widget.isDark) {
      _animationController.value = 1.0;
    }

    _colorAnimation =
        ColorTween(
          begin: widget.inactiveColor,
          end: widget.activeColor,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOutCubic,
          ),
        );

    _positionAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _bgColorAnimation =
        ColorTween(
          begin: widget.inactiveTrackColor ?? widget.inactiveColor.withOpacity(0.3),
          end: widget.activeTrackColor ?? widget.activeColor.withOpacity(0.3),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOutCubic,
          ),
        );
  }

  @override
  void didUpdateWidget(AnimatedThemeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      if (widget.isDark) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final double knobPosition = widget.isDark
            ? (widget.size * 0.95)
            : // Dark mode: slightly more to right edge
              4; // Light mode: flush to left edge

        final Color currentColor =
            _colorAnimation.value ?? widget.inactiveColor;
        final Color currentBgColor =
            _bgColorAnimation.value ?? (widget.inactiveTrackColor ?? widget.inactiveColor.withOpacity(0.3));

        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.onChanged(!widget.isDark);
          },
          child: Container(
            width: widget.size * 2.1,
            height: widget.size * 1.2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.size * 0.9),
              color: Colors.grey.shade300.withOpacity(0.4),
              boxShadow: [
                // Main shadow for depth
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
                // Ambient shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.size * 0.85),
                color: currentBgColor,
                boxShadow: [
                  // Inner shadow for depth
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Track with mini hole effect
                  Positioned(
                    left: 2,
                    right: 2,
                    top: 2,
                    bottom: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.size * 0.8),
                        color: Colors.grey.shade400.withOpacity(0.15),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            widget.size * 0.75,
                          ),
                          color: Colors.grey.shade500.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ),
                  // Active track highlight with smooth transition
                  Positioned(
                    left: widget.isDark ? null : 2,
                    right: widget.isDark ? 2 : null,
                    top: 2,
                    bottom: 2,
                    width: widget.isDark
                        ? (widget.size * 0.35)
                        : // Dark mode: shorter track
                          (widget.size * 0.7), // Light mode: longer track
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.size * 0.75),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            currentColor.withOpacity(0.25),
                            currentColor.withOpacity(0.08),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // iOS-style knob with mini hole
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    left: knobPosition,
                    top: 2,
                    bottom: 2,
                    width: widget.size - 4,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          // Knob shadow for floating effect
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                          // Top highlight
                          BoxShadow(
                            color: Colors.white.withOpacity(0.9),
                            blurRadius: 1,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Mini hole effect (inner circle)
                          Center(
                            child: Container(
                              width: widget.size * 0.4,
                              height: widget.size * 0.4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade200.withOpacity(0.3),
                                gradient: RadialGradient(
                                  center: const Alignment(-0.2, -0.2),
                                  radius: 0.6,
                                  colors: [
                                    Colors.grey.shade100.withOpacity(0.4),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Icon with shadow
                          Center(
                            child: Icon(
                              widget.isDark
                                  ? widget.activeIcon
                                  : widget.inactiveIcon,
                              size: widget.size * 0.35,
                              color: currentColor,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 1,
                                  offset: const Offset(0, 0.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Theme transition wrapper for smooth theme switching
class ThemeTransitionWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const ThemeTransitionWrapper({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<ThemeTransitionWrapper> createState() => _ThemeTransitionWrapperState();
}

class _ThemeTransitionWrapperState extends State<ThemeTransitionWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void triggerTransition() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: 1.0 - _fadeAnimation.value,
          child: widget.child,
        );
      },
    );
  }
}

/// Enhanced theme switcher with spring animation
class SpringThemeSwitcher extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const SpringThemeSwitcher({
    super.key,
    required this.isDark,
    required this.onChanged,
  });

  @override
  State<SpringThemeSwitcher> createState() => _SpringThemeSwitcherState();
}

class _SpringThemeSwitcherState extends State<SpringThemeSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Sync animation state for SpringThemeSwitcher consistency
    if (widget.isDark) {
      _controller.value = 1.0;
    }

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 3.14159,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    _controller.forward().then((_) {
      widget.onChanged(!widget.isDark);
      _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 60,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: widget.isDark
                      ? AppTheme.primaryDark
                      : AppTheme.primaryGold,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (widget.isDark
                                  ? AppTheme.primaryDark
                                  : AppTheme.primaryGold)
                              .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      left: widget.isDark ? 30 : 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: widget.isDark ? 8 : 38,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Icon(
                          widget.isDark
                              ? Icons.nightlight_round
                              : Icons.wb_sunny_rounded,
                          size: 16,
                          color: widget.isDark
                              ? AppTheme.primaryGold
                              : AppTheme.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
