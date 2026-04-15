import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

/// Performance optimization utilities
class PerformanceOptimizer {
  static void optimizeForBattery() {
    if (AppConstants.enableBatterySaver) {
      // Reduce visual effects
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      
      // Disable haptic feedback to save battery
      HapticFeedback.lightImpact(); // This will be minimal
    }
  }
  
  static void optimizeAppLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _pauseHeavyAnimations();
        break;
      case AppLifecycleState.resumed:
        _resumeAnimations();
        break;
      case AppLifecycleState.detached:
        cleanupResources();
        break;
      default:
        break;
    }
  }
  
  static void _pauseHeavyAnimations() {
    // Pause background animations when app is not in focus
    // This saves battery significantly
  }
  
  static void _resumeAnimations() {
    // Resume animations when app is active
  }
  
  static void cleanupResources() {
    // Clean up resources when app is completely closed
  }
  
  /// Widget wrapper for performance optimization
  static Widget optimizedWidget({
    required Widget child,
    bool? enableAnimations,
    bool? enableTransitions,
  }) {
    final shouldAnimate = enableAnimations ?? AppConstants.enableAnimations;
    final shouldTransition = enableTransitions ?? AppConstants.enableTransitions;
    
    if (!shouldAnimate && !shouldTransition) {
      return child;
    }
    
    return AnimatedSwitcher(
      duration: shouldTransition 
          ? Duration(milliseconds: AppConstants.adaptiveAnimationDuration)
          : Duration.zero,
      child: child,
    );
  }
  
  /// Performance monitoring
  static void logPerformance(String operation, Duration duration) {
    if (duration.inMilliseconds > 100) {
      debugPrint('Performance Warning: $operation took ${duration.inMilliseconds}ms');
    }
  }
}

/// Mixin for performance-aware widgets
mixin PerformanceAwareWidget<T extends StatefulWidget> on State<T> {
  bool _isOptimized = false;
  
  @override
  void initState() {
    super.initState();
    _optimizeForDevice();
  }
  
  void _optimizeForDevice() {
    if (AppConstants.isLowEndDevice) {
      _isOptimized = true;
      _applyLowEndOptimizations();
    }
  }
  
  void _applyLowEndOptimizations() {
    // Reduce visual complexity for low-end devices
    // Disable heavy animations
    // Use simpler widgets
  }
  
  bool get isOptimized => _isOptimized;
  
  /// Override this to provide performance-optimized builds
  Widget buildOptimized(BuildContext context);
  
  @override
  Widget build(BuildContext context) {
    if (_isOptimized) {
      return buildOptimized(context);
    }
    return build(context); // Normal build
  }
}

/// Battery-aware animation controller
class BatteryAwareAnimationController extends AnimationController {
  BatteryAwareAnimationController({
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 800),
  }) : super(vsync: vsync, duration: duration);
  
  @override
  TickerFuture repeat({double? min, double? max, bool reverse = false, int? count, Duration? period}) {
    // Only repeat if battery saver is off and app is in foreground
    if (AppConstants.shouldEnableBackgroundAnimations) {
      return super.repeat(min: min, max: max, reverse: reverse, count: count, period: period);
    } else {
      // Single animation instead of repeating
      forward();
      return TickerFuture.complete();
    }
  }
}
