import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// App-wide constants for performance and configuration
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // Performance settings - CONTROLLED BY USER PREFERENCES
  static bool get enableHighPerformanceAnimations => _getUserAnimationPreference();
  static bool get enableBackgroundAnimations => _getUserAnimationPreference();
  static int get animationDurationMs => _getUserAnimationPreference() ? 800 : 300;
  static int get backgroundAnimationDurationSec => _getUserAnimationPreference() ? 20 : 60;

  // Battery optimization - CONTROLLED BY USER
  static bool get enableBatterySaver => _getUserBatteryMode();
  static int get maxFPS => _getUserAnimationPreference() ? 60 : 30;
  static bool get enableHardwareAcceleration => _getUserAnimationPreference();

  // Memory management
  static const bool enableImageCaching = true;
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const bool enableLazyLoading = true;

  // Network optimization
  static const Duration networkTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const bool enableRequestCaching = true;

  // UI optimization - CONTROLLED BY USER PREFERENCES
  static bool get enableAnimations => _getUserAnimationPreference();
  static bool get enableTransitions => _getUserAnimationPreference();
  static bool get enableShadows => _getUserAnimationPreference();
  static bool get enableGradients => _getUserAnimationPreference();

  // Device-specific optimizations
  static bool get isLowEndDevice => _checkDevicePerformance();

  static bool _checkDevicePerformance() {
    // This would check device specs in a real app
    // For now, assume mid-range performance
    return false;
  }

  // Adaptive settings - BASED ON USER PREFERENCES
  static int get adaptiveAnimationDuration {
    return _getUserAnimationPreference() ? 800 : 200;
  }

  static bool get shouldEnableBackgroundAnimations {
    return _getUserAnimationPreference();
  }

  static bool get shouldEnableAnyAnimations {
    return _getUserAnimationPreference();
  }

  // User preference getters
  static bool _getUserAnimationPreference() {
    debugPrint('AppConstants: Animation preference = $_userAnimationPreference');
    return _userAnimationPreference;
  }
  
  static bool _getUserBatteryMode() {
    debugPrint('AppConstants: Battery mode = $_userBatteryMode');
    return _userBatteryMode;
  }

  // Method to update preferences (called by UIPreferenceManager)
  static Future<void> updateFromUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final animationsEnabled = prefs.getBool('user_animation_preference') ?? false;
    final batteryModeEnabled = prefs.getBool('user_battery_mode_preference') ?? true;
    
    debugPrint('AppConstants: Updating preferences - Animations: $animationsEnabled, Battery: $batteryModeEnabled');
    
    // Update internal state
    _userAnimationPreference = animationsEnabled;
    _userBatteryMode = batteryModeEnabled;
  }
  
  // Internal state variables
  static bool _userAnimationPreference = false;
  static bool _userBatteryMode = true;
}
