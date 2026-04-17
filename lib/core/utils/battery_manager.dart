import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_constants.dart';

/// Battery management utilities
class BatteryManager {
  static bool _isOptimized = false;
  
  /// Initialize battery optimizations
  static void initialize() {
    if (AppConstants.enableBatterySaver && !_isOptimized) {
      _applyBatteryOptimizations();
      _isOptimized = true;
    }
  }
  
  static void _applyBatteryOptimizations() {
    // Reduce system UI overhead
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
    
    // Lock to portrait mode to save battery
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    
    // Disable haptic feedback for battery saving
    // Note: This is optional as haptic feedback uses minimal battery
  }
  
  /// Monitor battery usage and adjust performance
  static void adjustPerformanceBasedOnBattery() {
    // In a real app, you would monitor battery level
    // For now, we'll use the static settings
    
    if (AppConstants.enableBatterySaver) {
      _reducePerformance();
    } else {
      _restorePerformance();
    }
  }
  
  static void _reducePerformance() {
    // Reduce frame rate
    // Disable heavy animations
    // Lower quality settings
  }
  
  static void _restorePerformance() {
    // Restore normal performance
    // Enable full animations
    // Restore quality settings
  }
  
  /// Get battery optimization status
  static bool get isOptimized => _isOptimized;
  
  /// Toggle battery saver mode
  static void toggleBatterySaver(bool enable) {
    if (enable) {
      _applyBatteryOptimizations();
    } else {
      _removeBatteryOptimizations();
    }
    _isOptimized = enable;
  }
  
  static void _removeBatteryOptimizations() {
    // Restore all orientations
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    
    // Restore normal system UI
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
    );
  }
}

/// Widget wrapper for battery-aware UI
class BatteryAwareWidget extends StatelessWidget {
  final Widget child;
  final Widget? lowBatteryChild;
  
  const BatteryAwareWidget({
    super.key,
    required this.child,
    this.lowBatteryChild,
  });
  
  @override
  Widget build(BuildContext context) {
    if (AppConstants.enableBatterySaver && lowBatteryChild != null) {
      return lowBatteryChild!;
    }
    
    return child;
  }
}

/// Battery-aware animation
class BatteryAwareAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool enableAnimation;
  
  const BatteryAwareAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
    this.enableAnimation = true,
  });
  
  @override
  State<BatteryAwareAnimation> createState() => _BatteryAwareAnimationState();
}

class _BatteryAwareAnimationState extends State<BatteryAwareAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    
    final shouldAnimate = widget.enableAnimation && 
        !AppConstants.enableBatterySaver;
    
    if (shouldAnimate) {
      _controller = AnimationController(
        duration: widget.duration,
        vsync: this,
      );
      
      _animation = CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      );
      
      _controller.forward();
    }
  }
  
  @override
  void dispose() {
    if (_controller.isAnimating) {
      _controller.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.enableAnimation || AppConstants.enableBatterySaver) {
      return widget.child;
    }
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _animation,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
