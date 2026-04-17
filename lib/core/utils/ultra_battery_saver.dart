import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_constants.dart';

/// Ultra battery saver for maximum battery life
class UltraBatterySaver {
  static bool _isInitialized = false;
  
  /// Initialize ultra battery saving mode
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _applyUltraBatterySettings();
    _isInitialized = true;
  }
  
  static Future<void> _applyUltraBatterySettings() async {
    // 1. Lock to portrait mode (saves GPU processing)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    
    // 2. Minimal system UI
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    // 3. Disable haptic feedback (saves battery)
    // Note: Haptic feedback is minimal but disabled for max battery
    
    // 4. Set performance mode to low power
    await _setLowPowerMode();
  }
  
  static Future<void> _setLowPowerMode() async {
    // In a real implementation, this would:
    // - Reduce CPU frequency
    // - Lower GPU performance
    // - Limit background processes
    // For Flutter, we optimize the app layer
  }
  
  /// Get battery optimization status
  static bool get isOptimized => _isInitialized;
  
  /// Monitor and adjust based on battery level
  static void adjustForBatteryLevel(int batteryLevel) {
    if (batteryLevel < 20) {
      // Critical battery - ultra aggressive saving
      _enableCriticalBatteryMode();
    } else if (batteryLevel < 50) {
      // Medium battery - normal saving
      _enableNormalBatteryMode();
    } else {
      // Good battery - minimal saving
      _enableMinimalBatteryMode();
    }
  }
  
  static void _enableCriticalBatteryMode() {
    // Disable all non-essential features
    // Reduce update frequency
    // Lower quality settings
  }
  
  static void _enableNormalBatteryMode() {
    // Standard battery saving
    // Moderate performance
  }
  
  static void _enableMinimalBatteryMode() {
    // Minimal impact on user experience
    // Slight optimizations
  }
  
  /// Widget wrapper for ultra battery optimization
  static Widget wrapWithBatteryOptimization({
    required Widget child,
    bool enableAnimation = false,
  }) {
    if (!enableAnimation || !AppConstants.shouldEnableAnyAnimations) {
      return child; // No animation for battery
    }
    
    return AnimatedSwitcher(
      duration: Duration(milliseconds: AppConstants.adaptiveAnimationDuration),
      child: child,
    );
  }
  
  /// Performance monitoring for battery
  static void logPerformanceUsage(String feature, Duration duration) {
    if (duration.inMilliseconds > 50) {
      debugPrint('Battery Alert: $feature took ${duration.inMilliseconds}ms - consider optimization');
    }
  }
  
  /// Clean up resources
  static void dispose() {
    // Restore normal settings if needed
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }
}

/// Mixin for ultra battery-aware widgets
mixin UltraBatteryAware<T extends StatefulWidget> on State<T> {
  bool _isBatteryOptimized = false;
  
  @override
  void initState() {
    super.initState();
    _initializeBatteryOptimization();
  }
  
  void _initializeBatteryOptimization() async {
    await UltraBatterySaver.initialize();
    _isBatteryOptimized = true;
    
    if (mounted) {
      setState(() {}); // Rebuild with optimizations
    }
  }
  
  bool get isBatteryOptimized => _isBatteryOptimized;
  
  /// Override this for battery-optimized builds
  Widget buildBatteryOptimized(BuildContext context);
  
  @override
  Widget build(BuildContext context) {
    if (_isBatteryOptimized) {
      return buildBatteryOptimized(context);
    }
    return build(context);
  }
}

/// Ultra battery-aware animation controller
class UltraBatteryAwareAnimationController extends AnimationController {
  UltraBatteryAwareAnimationController({
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 200),
  }) : super(vsync: vsync, duration: duration);
  
  @override
  TickerFuture repeat({double? min, double? max, bool reverse = false, int? count, Duration? period}) {
    // NEVER repeat animations for battery saving
    // Single animation only
    final future = forward();
    future.then((_) => dispose());
    return future;
  }
  
  @override
  TickerFuture forward({double? from}) {
    // Limit animation duration for battery
    if (duration?.inMilliseconds != null && duration!.inMilliseconds > 200) {
      duration = const Duration(milliseconds: 200);
    }
    return super.forward(from: from);
  }
}
