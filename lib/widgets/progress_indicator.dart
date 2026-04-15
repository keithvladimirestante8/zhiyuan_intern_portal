import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// Custom progress indicator with corporate styling
class CustomProgressIndicator extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final BorderRadius? borderRadius;
  final String? label;
  final bool showPercentage;
  final bool isAnimated;
  final Duration animationDuration;

  const CustomProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.height = 8.0,
    this.borderRadius,
    this.label,
    this.showPercentage = false,
    this.isAnimated = true,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color progressColor = color ?? AppTheme.primaryGold;
    final Color bgColor = backgroundColor ?? 
        (isDark ? Colors.white12 : Colors.black12);

    Widget progressWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextColor(isDark),
                ),
              ),
              if (showPercentage)
                Text(
                  '${(value * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: progressColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        _buildProgressBar(progressColor, bgColor),
      ],
    );

    if (isAnimated) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: value),
        duration: animationDuration,
        curve: Curves.easeInOut,
        builder: (context, animatedValue, child) {
          return _buildProgressBar(progressColor, bgColor, animatedValue);
        },
      );
    }

    return progressWidget;
  }

  Widget _buildProgressBar(Color progressColor, Color bgColor, [double? animatedValue]) {
    final double currentValue = animatedValue ?? value;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
        color: bgColor,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: currentValue.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
              gradient: LinearGradient(
                colors: [
                  progressColor,
                  progressColor.withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: progressColor.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular progress indicator with corporate styling
class CircularProgressIndicator extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final String? label;
  final bool showPercentage;

  const CircularProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.size = 60.0,
    this.strokeWidth = 6.0,
    this.child,
    this.label,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color progressColor = color ?? AppTheme.primaryGold;
    final Color bgColor = backgroundColor ?? 
        (isDark ? Colors.white12 : Colors.black12);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
              ),
            ),
          ),
          // Progress circle
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: value),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, animatedValue, child) {
                return CustomPaint(
                  size: Size(size, size),
                  painter: _CircularProgressPainter(
                    progress: animatedValue,
                    color: progressColor,
                    strokeWidth: strokeWidth,
                  ),
                );
              },
            ),
          ),
          // Center content
          Center(
            child: child ??
                ((label != null || showPercentage)
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (label != null)
                            Text(
                              label!,
                              style: TextStyle(
                                fontSize: size * 0.12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getTextColor(isDark),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          if (showPercentage)
                            Text(
                              '${(value * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: size * 0.15,
                                fontWeight: FontWeight.w600,
                                color: progressColor,
                              ),
                            ),
                        ],
                      )
                    : const SizedBox()),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for circular progress
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double center = size.width / 2;
    final double radius = (size.width - strokeWidth) / 2;

    // Draw progress arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(center, center), radius: radius),
      -math.pi / 2, // Start from top
      2 * math.pi * progress, // Progress angle
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Step progress indicator for multi-step processes
class StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? stepLabels;
  final Color? activeColor;
  final Color? inactiveColor;
  final double height;

  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabels,
    this.activeColor,
    this.inactiveColor,
    this.height = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color activeStepColor = activeColor ?? AppTheme.primaryGold;
    final Color inactiveStepColor = inactiveColor ?? 
        (isDark ? Colors.grey.shade600 : Colors.grey.shade400);

    return Column(
      children: [
        // Step indicators
        SizedBox(
          height: 24,
          child: Row(
            children: List.generate(totalSteps, (index) {
              return Expanded(
                child: Row(
                  children: [
                    // Step circle
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index <= currentStep - 1
                            ? activeStepColor
                            : inactiveStepColor,
                        boxShadow: index <= currentStep - 1
                            ? [
                                BoxShadow(
                                  color: activeStepColor.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: index <= currentStep - 1
                                ? Colors.white
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Connector line
                    if (index < totalSteps - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: index < currentStep - 1
                                ? activeStepColor
                                : inactiveStepColor,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
        // Step labels
        if (stepLabels != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 16,
            child: Row(
              children: List.generate(totalSteps, (index) {
                return Expanded(
                  child: Text(
                    stepLabels![index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: index == currentStep - 1
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: index == currentStep - 1
                          ? activeStepColor
                          : inactiveStepColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

/// Loading skeleton for better perceived performance
class LoadingSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Color? color;

  const LoadingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color skeletonColor = color ?? 
        (isDark ? Colors.grey.shade700 : Colors.grey.shade300);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(4),
        color: skeletonColor,
      ),
      child: _buildShimmerEffect(),
    );
  }

  Widget _buildShimmerEffect() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -1.0, end: 2.0),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return FractionallySizedBox(
          alignment: Alignment(value - 1, 0),
          widthFactor: 0.5,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
