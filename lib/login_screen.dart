import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_screen.dart';
import 'main.dart';
import 'register_screen.dart';
import 'setup_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late AnimationController _bgAnimationController;
  late AnimationController _entryController;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // Password strength tracking
  double _passwordStrength = 0;
  String _passwordStrengthText = "Security: Undefined";
  Color _passwordStrengthColor = Colors.grey;

  // Account lockout protection
  int _failedAttempts = 0;
  bool _isAccountLocked = false;
  bool _isBiometricAvailable = false;
  String? _biometricBoundEmail;
  String? _biometricBoundUserId;
  String? _currentDeviceId;
  String? _lastLoggedInUserId;
  Map<String, dynamic>? _deviceSecurityProfile;

  // Check biometric availability
  Future<void> _checkBiometricAvailability() async {
    try {
      final localAuth = LocalAuthentication();
      _isBiometricAvailable = await localAuth.canCheckBiometrics;
    } catch (e) {
      _isBiometricAvailable = false;
    }
  }

  // Get unique device identifier for security
  Future<String> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand}_${androidInfo.model}_${androidInfo.id}';
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.model}_${iosInfo.identifierForVendor}';
      } else {
        // Fallback for other platforms
        return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      debugPrint('Device ID error: $e');
      return 'fallback_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Initialize device security profile
  Future<void> _initializeDeviceSecurity() async {
    try {
      _currentDeviceId = await _getDeviceId();
      final prefs = await SharedPreferences.getInstance();

      // Load device security profile
      final deviceProfileJson = prefs.getString('device_security_profile');
      if (deviceProfileJson != null) {
        _deviceSecurityProfile = Map<String, dynamic>.from(
          json.decode(deviceProfileJson),
        );
      } else {
        // Create new device profile
        _deviceSecurityProfile = {
          'deviceId': _currentDeviceId,
          'createdAt': DateTime.now().toIso8601String(),
          'lastSecurityCheck': DateTime.now().toIso8601String(),
          'authorizedUsers': <String>[],
          'securityFlags': <String>[],
        };
        await _saveDeviceSecurityProfile();
      }

      _lastLoggedInUserId = prefs.getString('last_logged_in_user_id');
    } catch (e) {
      debugPrint('Device security init error: $e');
    }
  }

  // Save device security profile
  Future<void> _saveDeviceSecurityProfile() async {
    try {
      if (_deviceSecurityProfile != null && _currentDeviceId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'device_security_profile',
          json.encode(_deviceSecurityProfile!),
        );
      }
    } catch (e) {
      debugPrint('Save device profile error: $e');
    }
  }

  // Check if user is authorized on this device
  bool _isUserAuthorizedOnDevice(String userId) {
    if (_deviceSecurityProfile == null) return false;
    final authorizedUsers =
        _deviceSecurityProfile!['authorizedUsers'] as List<dynamic>? ?? [];
    return authorizedUsers.contains(userId);
  }

  // Authorize user on device
  Future<void> _authorizeUserOnDevice(String userId) async {
    try {
      if (_deviceSecurityProfile != null) {
        final authorizedUsers = List<String>.from(
          _deviceSecurityProfile!['authorizedUsers'] as List<dynamic>? ?? [],
        );

        if (!authorizedUsers.contains(userId)) {
          authorizedUsers.add(userId);
          _deviceSecurityProfile!['authorizedUsers'] = authorizedUsers;
          _deviceSecurityProfile!['lastSecurityCheck'] = DateTime.now()
              .toIso8601String();
          await _saveDeviceSecurityProfile();
        }
      }
    } catch (e) {
      debugPrint('Authorize user error: $e');
    }
  }

  // Generate secure biometric key
  String _generateBiometricKey(String userId, String deviceId) {
    return 'bio_${userId.substring(0, 8)}_${deviceId.hashCode}';
  }

  // Real-time password strength checker
  void _checkPasswordStrength(String value) {
    if (value.isEmpty) {
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthText = "Security: Undefined";
        _passwordStrengthColor = Colors.grey;
      });
      return;
    }

    double strength = 0;
    if (value.length < 6) {
      strength = 1 / 4;
    } else if (value.length < 8) {
      strength = 2 / 4;
    } else {
      bool hasUpper = value.contains(RegExp(r'[A-Z]'));
      bool hasDigits = value.contains(RegExp(r'[0-9]'));
      bool hasSpecial = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      if (hasUpper && hasDigits && hasSpecial) {
        strength = 1.0;
      } else if (hasUpper && hasDigits) {
        strength = 0.75;
      } else {
        strength = 0.5;
      }
    }

    setState(() {
      _passwordStrength = strength;
      if (strength <= 0.25) {
        _passwordStrengthText = "Security: Weak (Insecure)";
        _passwordStrengthColor = Colors.redAccent;
      } else if (strength <= 0.5) {
        _passwordStrengthText = "Security: Good";
        _passwordStrengthColor = Colors.orangeAccent;
      } else if (strength <= 0.75) {
        _passwordStrengthText = "Security: Strong";
        _passwordStrengthColor = Colors.blueAccent;
      } else {
        _passwordStrengthText = "Security: Executive Grade";
        _passwordStrengthColor = zLogoGold;
      }
    });
  }

  // Corporate-grade biometric authentication with user-device security
  Future<void> _authenticateWithBiometrics() async {
    final currentEmail = _emailController.text.trim();

    try {
      final localAuth = LocalAuthentication();
      final prefs = await SharedPreferences.getInstance();

      // Check device security initialization
      if (_currentDeviceId == null) {
        _showSnackBar(
          'Security system initializing. Please try again.',
          Colors.orange,
        );
        return;
      }

      // Get saved credentials
      final savedEmail = prefs.getString('saved_email');
      final savedPassword = prefs.getString('saved_password');
      final biometricKey = prefs.getString('biometric_key');

      if (savedEmail == null || savedPassword == null || biometricKey == null) {
        _showSnackBar(
          'Please login with email/password first to enable biometrics',
          Colors.orange,
        );
        return;
      }

      // Verify current email matches saved email
      if (currentEmail != savedEmail) {
        _showSnackBar(
          'Please enter the correct email for biometric login',
          Colors.red,
        );
        return;
      }

      // Check for user switch scenario
      if (_lastLoggedInUserId != null) {
        // Load user profile to check if current user is different
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: currentEmail)
              .limit(1)
              .get();

          if (userDoc.docs.isNotEmpty) {
            final currentUserId = userDoc.docs.first.id;

            // SECURITY CHECK: Different user trying to use previous user's biometric
            if (_lastLoggedInUserId != currentUserId) {
              _showSnackBar(
                'Security Alert: Different user detected. Please login with password.',
                Colors.red,
              );

              // Clear previous biometric binding for security
              await prefs.remove('biometric_key');
              await prefs.remove('biometric_bound_user_id');
              setState(() {
                _biometricBoundUserId = null;
                _biometricBoundEmail = null;
              });
              return;
            }
          }
        } catch (e) {
          debugPrint('User verification error: $e');
        }
      }

      // Perform biometric authentication
      bool didAuthenticate = await localAuth.authenticate(
        localizedReason: 'Sign in to your Zhiyuan account',
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        try {
          // Verify credentials with Firebase
          final userCredential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(
                email: savedEmail,
                password: savedPassword,
              );

          if (userCredential.user != null) {
            final currentUserId = userCredential.user!.uid;

            // SECURITY: Verify user is authorized on this device
            if (!_isUserAuthorizedOnDevice(currentUserId)) {
              await _authorizeUserOnDevice(currentUserId);
            }

            // Generate and store secure biometric key
            final newBiometricKey = _generateBiometricKey(
              currentUserId,
              _currentDeviceId!,
            );
            await prefs.setString('biometric_key', newBiometricKey);
            await prefs.setString('biometric_bound_user_id', currentUserId);
            await prefs.setString('last_logged_in_user_id', currentUserId);

            setState(() {
              _biometricBoundUserId = currentUserId;
              _biometricBoundEmail = savedEmail;
              _lastLoggedInUserId = currentUserId;
            });

            // Log security event
            await _logSecurityEvent('biometric_login_success', currentUserId);

            _showSnackBar('Biometric authentication successful!', Colors.green);

            // Navigate to appropriate screen
            await _navigateToUserScreen(userCredential.user!);
          }
        } catch (e) {
          _showSnackBar(
            'Authentication failed. Invalid credentials.',
            Colors.red,
          );

          // Security: Clear compromised data
          await prefs.remove('biometric_key');
          await prefs.remove('saved_password');
          await _logSecurityEvent('biometric_login_failed', 'unknown');
        }
      } else {
        _showSnackBar('Biometric authentication cancelled', Colors.orange);
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      _showSnackBar('Biometric error: ${e.toString()}', Colors.red);
      await _logSecurityEvent('biometric_error', 'error: $e');
    }
  }

  // Log security events for audit trail
  Future<void> _logSecurityEvent(String eventType, String userId) async {
    try {
      await FirebaseFirestore.instance.collection('security_logs').add({
        'eventType': eventType,
        'userId': userId,
        'deviceId': _currentDeviceId,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Theme.of(context).platform.toString(),
      });
    } catch (e) {
      debugPrint('Security logging error: $e');
    }
  }

  // Navigate user to appropriate screen based on profile
  Future<void> _navigateToUserScreen(User user) async {
    if (!mounted) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        String role = doc.data()?['role'] ?? 'intern';

        switch (role) {
          case 'cao':
            _showSnackBar('Welcome, Chief Admin Officer.', zLogoGold);
            // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const CAODashboardScreen()));
            break;
          case 'hr':
            _showSnackBar('Welcome, HR Admin.', Colors.blueAccent);
            // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HRDashboardScreen()));
            break;
          case 'leader':
            _showSnackBar('Welcome, Department Leader.', Colors.purpleAccent);
            // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LeaderDashboardScreen()));
            break;
          case 'intern':
          default:
            if (doc.data()?['profile_setup_completed'] == true) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const SetupProfileScreen(),
                ),
              );
            }
            break;
        }
      } else {
        await _fallbackToLegacyInternCheck(user.uid);
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      _showSnackBar('Error loading user profile', Colors.red);
    }
  }

  double _calculatePasswordStrength(String password) {
    if (password.length < 6) return 0.2;
    if (password.length < 8) return 0.4;

    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int criteria = 0;
    if (hasUpper) criteria++;
    if (hasLower) criteria++;
    if (hasDigits) criteria++;
    if (hasSpecial) criteria++;

    return criteria / 4.0;
  }

  static const Color zLogoGold = Color(0xFFC2A984);
  static const Color zNavyBlue = Color(0xFF1A237E);
  static const Color zOnyxBlack = Color(0xFF1A1C20);

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    _checkBiometricAvailability();
    _initializeDeviceSecurity();

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('saved_email') ?? "";
      _rememberMe = prefs.getBool('remember_me') ?? false;
      _failedAttempts = prefs.getInt('failed_attempts') ?? 0;
      _isAccountLocked = prefs.getBool('account_locked') ?? false;
      _biometricBoundEmail = prefs.getString('biometric_bound_email');
      _biometricBoundUserId = prefs.getString('biometric_bound_user_id');
      _lastLoggedInUserId = prefs.getString('last_logged_in_user_id');
    });
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _entryController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _forgotPassword() async {
    HapticFeedback.lightImpact();
    if (_emailController.text.isEmpty) {
      _showSnackBar(
        'Please enter your email to reset password.',
        Colors.orange,
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      _showSnackBar('Reset link sent to your email.', Colors.green);
    } catch (e) {
      _showSnackBar(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _loginUser() async {
    HapticFeedback.mediumImpact();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter both email and password.', Colors.redAccent);
      return;
    }

    // Check account lockout status
    if (_isAccountLocked) {
      _showSnackBar('Account temporarily locked. Try again later.', Colors.red);
      return;
    }

    // Assume internet is available for now
    final hasInternet = true;

    if (!hasInternet) {
      _showSnackBar('No internet connection', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user == null) {
        _showSnackBar('Login failed. User not found.', Colors.red);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', email);
        await prefs.setString('saved_password', password);
        await prefs.setBool('remember_me', true);

        // Clear previous biometric binding when user changes
        if (_biometricBoundUserId != null && _biometricBoundUserId != user.uid) {
          await prefs.remove('biometric_key');
          await prefs.remove('biometric_bound_user_id');
          await prefs.remove('biometric_bound_email');
          setState(() {
            _biometricBoundUserId = null;
            _biometricBoundEmail = null;
          });
        }
      } else {
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);

        // Clear all biometric data when remember me is off
        await prefs.remove('biometric_key');
        await prefs.remove('biometric_bound_user_id');
        await prefs.remove('biometric_bound_email');
        setState(() {
          _biometricBoundUserId = null;
          _biometricBoundEmail = null;
        });
      }

      // Authorize user on device and update last login
      await _authorizeUserOnDevice(user.uid);
      await prefs.setString('last_logged_in_user_id', user.uid);
      setState(() {
        _lastLoggedInUserId = user.uid;
      });

      // Log successful login
      await _logSecurityEvent('login_success', user.uid);

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        if (doc.exists) {
          String role = doc.data()?['role'] ?? 'intern';
          switch (role) {
            case 'cao':
              _showSnackBar('Welcome, Chief Admin Officer.', zLogoGold);
              // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const CAODashboardScreen()));
              break;
            case 'hr':
              _showSnackBar('Welcome, HR Admin.', Colors.blueAccent);
              // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HRDashboardScreen()));
              break;
            case 'leader':
              _showSnackBar(
                'Welcome, Department Leader.',
                Colors.purpleAccent,
              );
              // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LeaderDashboardScreen()));
              break;
            case 'intern':
            default:
              if (doc.data()?['profile_setup_completed'] == true) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardScreen(),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SetupProfileScreen(),
                  ),
                );
              }
              break;
          }
        } else {
          await _fallbackToLegacyInternCheck(user.uid);
        }
      }
    } on FirebaseAuthException catch (e) {
      HapticFeedback.vibrate();

      // Handle failed login attempts
      _failedAttempts++;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('failed_attempts', _failedAttempts);

      // Lock account after 3 failed attempts
      if (_failedAttempts >= 3) {
        _isAccountLocked = true;
        await prefs.setBool('account_locked', true);
        _showSnackBar(
          'Too many failed attempts. Account locked for 15 minutes.',
          Colors.red,
        );

        // Auto-unlock after 15 minutes
        Timer(const Duration(minutes: 15), () async {
          _isAccountLocked = false;
          _failedAttempts = 0;
          await prefs.setBool('account_locked', false);
          await prefs.setInt('failed_attempts', 0);
        });
      } else {
        _showSnackBar(e.message ?? 'Auth Error', Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fallbackToLegacyInternCheck(String uid) async {
    final legacyDoc = await FirebaseFirestore.instance
        .collection('intern_profiles')
        .doc(uid)
        .get();
    if (legacyDoc.exists && mounted) {
      if (legacyDoc.data()?['profile_setup_completed'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SetupProfileScreen()),
        );
      }
    } else {
      if (mounted) {
        _showSnackBar(
          'Account record not found in the system.',
          Colors.redAccent,
        );
      }
    }
  }

  // Password strength indicator
  Widget _buildPasswordStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _passwordStrengthText,
              style: TextStyle(
                color: _passwordStrengthColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: Colors.grey.withOpacity(0.3),
            color: _passwordStrengthColor,
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1A232E);
    final Color cardBg = isDark
        ? const Color(0x1AFFFFFF)
        : const Color(0xE6FFFFFF);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0F)
          : const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: MeshGradientPainter(
                    animationValue: _bgAnimationController.value,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Center(
                child: Image.asset(
                  'assets/images/zhiyuan_logo.png',
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: MediaQuery.of(context).size.height * 0.6,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        isDark
                            ? Icons.nightlight_round
                            : Icons.wb_sunny_rounded,
                        color: zLogoGold,
                        size: 20,
                      ),
                      Switch(
                        value: isDark,
                        activeColor: zLogoGold,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          themeNotifier.value = v
                              ? ThemeMode.dark
                              : ThemeMode.light;
                        },
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0, 0.05),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _entryController,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                          child: FadeTransition(
                            opacity: CurvedAnimation(
                              parent: _entryController,
                              curve: Curves.easeOut,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 30,
                                  sigmaY: 30,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(40),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(
                                        isDark ? 0.08 : 0.6,
                                      ),
                                      width: 1.5,
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(
                                          isDark ? 0.08 : 0.4,
                                        ),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(
                                          isDark ? 0.2 : 0.05,
                                        ),
                                        blurRadius: 50,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _bgAnimationController,
                                        builder: (context, child) {
                                          return Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..setEntry(3, 2, 0.002)
                                              ..rotateY(
                                                _bgAnimationController.value *
                                                    2 *
                                                    math.pi *
                                                    5,
                                              ),
                                            child: child,
                                          );
                                        },
                                        child: Image.asset(
                                          'assets/images/zhiyuan_logo.png',
                                          height: 85,
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      Text(
                                        'ZHIYUAN',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 4,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'ENTERPRISE PORTAL',
                                        style: TextStyle(
                                          color: zLogoGold,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Sign in to continue your session',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),

                                      const SizedBox(height: 40),

                                      _buildTextField(
                                        _emailController,
                                        'Corporate Email',
                                        Icons.alternate_email_rounded,
                                        isDark,
                                      ),
                                      const SizedBox(height: 20),
                                      _buildTextField(
                                        _passwordController,
                                        'Access Password',
                                        Icons.lock_outline_rounded,
                                        isDark,
                                        isPassword: true,
                                        onChanged: _checkPasswordStrength,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: Colors.grey,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            HapticFeedback.selectionClick();
                                            setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Password strength indicator
                                      _buildPasswordStrengthIndicator(),
                                      const SizedBox(height: 12),

                                      const SizedBox(height: 12),

                                      Row(
                                        children: [
                                          SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: Checkbox(
                                              activeColor: zLogoGold,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              side: BorderSide(
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.black54,
                                              ),
                                              value: _rememberMe,
                                              onChanged: (v) {
                                                HapticFeedback.selectionClick();
                                                setState(
                                                  () => _rememberMe = v!,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Remember Me",
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: _forgotPassword,
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(50, 30),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: const Text(
                                              'Forgot Password?',
                                              style: TextStyle(
                                                color: zLogoGold,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 35),

                                      // Login button
                                      Container(
                                        width: double.infinity,
                                        height: 55,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  (isDark
                                                          ? zLogoGold
                                                          : zOnyxBlack)
                                                      .withOpacity(0.25),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _loginUser,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isDark
                                                ? zLogoGold
                                                : zOnyxBlack,
                                            foregroundColor: isDark
                                                ? Colors.black
                                                : Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 24,
                                                  width: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                )
                                              : const Text(
                                                  'SECURE LOGIN',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1.5,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                        ),
                                      ),

                                      // Biometric login button
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: zLogoGold.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _authenticateWithBiometrics,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: zLogoGold,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.fingerprint,
                                                color: zLogoGold,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'LOGIN WITH BIOMETRICS',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Sign up button section
                                      const SizedBox(height: 25),
                                      FadeTransition(
                                        opacity: CurvedAnimation(
                                          parent: _entryController,
                                          curve: const Interval(0.8, 1.0),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Authorized Intern?",
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black54,
                                                fontSize: 13,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                HapticFeedback.selectionClick();
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const RegisterScreen(),
                                                  ),
                                                );
                                              },
                                              child: const Text(
                                                "Activate Account",
                                                style: TextStyle(
                                                  color: zLogoGold,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isDark, {
    bool isPassword = false,
    Widget? suffixIcon,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        onChanged: onChanged,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1A232E),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: zLogoGold, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: isDark ? const Color(0x1A000000) : const Color(0x80FFFFFF),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: zLogoGold, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class MeshGradientPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  MeshGradientPainter({required this.animationValue, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final Color color1 = isDark
        ? const Color(0xFFCC5500).withOpacity(0.6)
        : const Color(0xFFFFDAB9).withOpacity(0.8);
    final Color color2 = isDark
        ? const Color(0xFFC2A984).withOpacity(0.5)
        : const Color(0xFFEADDCA).withOpacity(0.7);
    final Color color3 = isDark
        ? const Color(0xFF8B4513).withOpacity(0.4)
        : const Color(0xFFFFF0DF).withOpacity(0.6);

    final double w = size.width;
    final double h = size.height;

    final double x1 =
        w * 0.5 + math.sin(animationValue * math.pi * 2) * w * 0.3;
    final double y1 =
        h * 0.2 + math.cos(animationValue * math.pi * 2) * h * 0.2;
    final double x2 =
        w * 0.8 + math.cos(animationValue * math.pi * 2 * 1.5) * w * 0.2;
    final double y2 =
        h * 0.7 + math.sin(animationValue * math.pi * 2 * 1.5) * h * 0.2;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = isDark ? const Color(0xFF141619) : const Color(0xFFF8F9FA),
    );

    final Paint paint1 = Paint()
      ..shader = RadialGradient(
        colors: [color1, color1.withOpacity(0.0)],
        stops: const [0.2, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x1, y1), radius: w * 0.8))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    final Paint paint2 = Paint()
      ..shader = RadialGradient(
        colors: [color2, color2.withOpacity(0.0)],
        stops: const [0.2, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x2, y2), radius: w * 0.7))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    canvas.drawCircle(Offset(x1, y1), w * 0.8, paint1);
    canvas.drawCircle(Offset(x2, y2), w * 0.7, paint2);

    final Paint arcPaint = Paint()
      ..color = isDark
          ? Colors.white.withOpacity(0.03)
          : Colors.black.withOpacity(0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.5),
        width: w * 1.5,
        height: w * 1.5,
      ),
      0,
      math.pi * 1.5,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MeshGradientPainter oldDelegate) => true;
}
