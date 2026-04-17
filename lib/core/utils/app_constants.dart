import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConstants {
  AppConstants._();

  // ==========================================
  // 1. DATABASE & CLOUD CONFIGURATION
  // ==========================================
  static const String usersCollection = 'users';
  static const String attendanceCollection = 'attendance';
  static const String internProfilesCollection = 'intern_profiles';
  static const String acceptedEmailsCollection = 'accepted_emails';
  static const String schoolsCollection = 'schools';
  static const String securityLogsCollection = 'security_logs';

  static const String cloudinaryCloudName = 'dqn0uoaqm';
  static const String cloudinaryUploadPreset = 'zhiyuan_preset';

  // ==========================================
  // 2. PERFORMANCE & UI SETTINGS
  // ==========================================
  static bool get enableHighPerformanceAnimations =>
      _getUserAnimationPreference();
  static bool get enableBackgroundAnimations => _getUserAnimationPreference();
  static int get animationDurationMs =>
      _getUserAnimationPreference() ? 800 : 300;
  static int get backgroundAnimationDurationSec =>
      _getUserAnimationPreference() ? 20 : 60;

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

  // UI Flags
  static bool get enableAnimations => _getUserAnimationPreference();
  static bool get enableTransitions => _getUserAnimationPreference();
  static bool get enableShadows => _getUserAnimationPreference();
  static bool get enableGradients => _getUserAnimationPreference();

  // Device-specific optimizations
  static bool get isLowEndDevice => _checkDevicePerformance();
  static bool _checkDevicePerformance() => false;

  // Adaptive settings
  static int get adaptiveAnimationDuration =>
      _getUserAnimationPreference() ? 800 : 200;
  static bool get shouldEnableBackgroundAnimations =>
      _getUserAnimationPreference();
  static bool get shouldEnableAnyAnimations => _getUserAnimationPreference();

  // ==========================================
  // 3. USER PREFERENCE LOGIC
  // ==========================================
  static bool _getUserAnimationPreference() => _userAnimationPreference;
  static bool _getUserBatteryMode() => _userBatteryMode;

  static Future<void> updateFromUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // We use the exact same keys from your original code
    _userAnimationPreference =
        prefs.getBool('user_animation_preference') ?? false;
    _userBatteryMode = prefs.getBool('user_battery_mode_preference') ?? true;

    debugPrint('AppConstants: Preferences synced with local storage.');
  }

  static bool _userAnimationPreference = false;
  static bool _userBatteryMode = true;
}
