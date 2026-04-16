import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication service for biometric and session management
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Timer? _sessionTimer;
  int _autoLogoutMinutes = 30; // -1 represents "Never"
  DateTime? _lastActivity;

  final StreamController<bool> _logoutStreamController =
      StreamController<bool>.broadcast();
  Stream<bool> get logoutStream => _logoutStreamController.stream;

  /// Initialize auth service and check for stale sessions on startup
  Future<void> initialize() async {
    await _loadSettings();

    // Disk-based check for persistent session timeout
    if (_auth.currentUser != null) {
      if (_autoLogoutMinutes == -1) {
        // "Never" mode: Just start the timer/activity
        recordUserActivity();
      } else if (_autoLogoutMinutes > 0) {
        final prefs = await SharedPreferences.getInstance();
        final lastActivityStr = prefs.getString('last_activity_timestamp');

        if (lastActivityStr != null) {
          final lastActivity = DateTime.parse(lastActivityStr);
          final difference = DateTime.now().difference(lastActivity).inMinutes;

          if (difference >= _autoLogoutMinutes) {
            debugPrint('Session expired while app was closed. Logging out.');
            await forceLogout();
            return;
          }
        }
        // If still valid, refresh the activity timestamp
        recordUserActivity();
      }
    }

    _startSessionTimer();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoLogoutMinutes = prefs.getInt('autoLogoutMinutes') ?? 30;
    } catch (e) {
      debugPrint('Error loading auth settings: $e');
    }
  }

  bool get isBiometricSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  // --- SECURE CREDENTIALS ---
  Future<void> saveSecureCredentials(String email, String password) async {
    await _secureStorage.write(key: 'secure_email', value: email);
    await _secureStorage.write(key: 'secure_password', value: password);
  }

  Future<Map<String, String>?> getSecureCredentials() async {
    final email = await _secureStorage.read(key: 'secure_email');
    final password = await _secureStorage.read(key: 'secure_password');
    if (email != null && password != null)
      return {'email': email, 'password': password};
    return null;
  }

  Future<void> clearSecureCredentials() async {
    await _secureStorage.delete(key: 'secure_email');
    await _secureStorage.delete(key: 'secure_password');
  }

  // --- BIOMETRICS ---
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (enabled && !isBiometricSupported) return false;
      if (enabled) {
        final bool canAuth =
            await _localAuth.canCheckBiometrics ||
            await _localAuth.isDeviceSupported();
        if (!canAuth) return false;
      } else {
        await clearSecureCredentials();
      }
      await prefs.setBool('biometricEnabled', enabled);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometricEnabled') ?? false;
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'Authenticate to access',
  }) async {
    try {
      if (!isBiometricSupported) return false;
      final bool didAuth = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
      if (didAuth) recordUserActivity();
      return didAuth;
    } catch (e) {
      return false;
    }
  }

  // --- SESSION LOGIC ---
  Future<void> setAutoLogoutMinutes(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('autoLogoutMinutes', minutes);
      _autoLogoutMinutes = minutes;
      _startSessionTimer();
    } catch (e) {
      debugPrint('Error setting auto logout: $e');
    }
  }

  int get autoLogoutMinutes => _autoLogoutMinutes;

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    if (_autoLogoutMinutes > 0) {
      _sessionTimer = Timer(Duration(minutes: _autoLogoutMinutes), () {
        _handleSessionTimeout();
      });
    }
  }

  void handleLifecycleChange(AppLifecycleState state) {
    if (_auth.currentUser == null || _autoLogoutMinutes == -1) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_autoLogoutMinutes == 0) {
        _handleSessionTimeout();
      }
    }
  }

  void _handleSessionTimeout() {
    forceLogout();
    _logoutStreamController.add(true);
  }

  void recordUserActivity() async {
    if (_autoLogoutMinutes == -1) return;
    _lastActivity = DateTime.now();
    _startSessionTimer();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_activity_timestamp',
      _lastActivity!.toIso8601String(),
    );
  }

  Future<void> forceLogout() async {
    try {
      _sessionTimer?.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_activity_timestamp');
      await _auth.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  void dispose() {
    _sessionTimer?.cancel();
    _logoutStreamController.close();
  }
}
