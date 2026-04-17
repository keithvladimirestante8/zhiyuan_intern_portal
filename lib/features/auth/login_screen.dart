import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_constants.dart';
import '../../core/utils/battery_manager.dart';
import '../../core/utils/ui_preference_manager.dart';
import '../../core/utils/ultra_battery_saver.dart';
import '../dashboard/dashboard_screen.dart';
import 'register_screen.dart';
import '../../core/services/auth_service.dart';
import '../profile/setup_profile_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late AnimationController _bgAnimationController;
  late AnimationController _entryController;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isBiometricEnabledGlobal = false;

  double _passwordStrength = 0;
  String _passwordStrengthText = "Security: Undefined";
  Color _passwordStrengthColor = Colors.grey;

  int _failedAttempts = 0;
  bool _isAccountLocked = false;
  String? _currentDeviceId;
  String? _lastLoggedInUserId;
  Map<String, dynamic>? _deviceSecurityProfile;

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
        return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      return 'fallback_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _initializeDeviceSecurity() async {
    try {
      _currentDeviceId = await _getDeviceId();
      final prefs = await SharedPreferences.getInstance();

      final deviceProfileJson = prefs.getString('device_security_profile');
      if (deviceProfileJson != null) {
        _deviceSecurityProfile = Map<String, dynamic>.from(
          json.decode(deviceProfileJson),
        );
      } else {
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
      _isBiometricEnabledGlobal = await _authService.isBiometricEnabled();
      setState(() {});
    } catch (e) {
      debugPrint('Device security init error: $e');
    }
  }

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
        _passwordStrengthColor = AppTheme.primaryGold;
      }
    });
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() => _isLoading = true);

    try {
      final credentials = await _authService.getSecureCredentials();

      if (credentials == null) {
        AppSnackbar.warning(context, 'No saved credentials.');
        setState(() => _isLoading = false);
        return;
      }

      final didAuthenticate = await _authService.authenticateWithBiometrics(
        reason: 'Sign in to your Zhiyuan account',
      );

      if (didAuthenticate) {
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: credentials['email']!,
              password: credentials['password']!,
            );

        if (userCredential.user != null) {
          final currentUserId = userCredential.user!.uid;
          await _authorizeUserOnDevice(currentUserId);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_logged_in_user_id', currentUserId);

          await _logSecurityEvent('biometric_login_success', currentUserId);
          AppSnackbar.success(context, 'Login successful.');
          await _navigateToUserScreen(userCredential.user!);
        }
      } else {
        AppSnackbar.warning(context, 'Cancelled.');
      }
    } catch (e) {
      AppSnackbar.error(context, 'Authentication failed.');
      await _logSecurityEvent('biometric_error', 'error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
            AppSnackbar.show(
              context: context,
              message: 'Welcome, CAO.',
              type: SnackbarType.custom,
              customColor: AppTheme.primaryGold,
              title: 'Welcome',
            );
            break;
          case 'hr':
            AppSnackbar.show(
              context: context,
              message: 'Welcome, HR.',
              type: SnackbarType.custom,
              customColor: Colors.blueAccent,
              title: 'Welcome',
            );
            break;
          case 'leader':
            AppSnackbar.show(
              context: context,
              message: 'Welcome, Leader.',
              type: SnackbarType.custom,
              customColor: Colors.purpleAccent,
              title: 'Welcome',
            );
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
      AppSnackbar.error(context, 'Profile error.');
    }
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('saved_email') ?? "";
      _rememberMe = prefs.getBool('remember_me') ?? false;
      _failedAttempts = prefs.getInt('failed_attempts') ?? 0;
      _isAccountLocked = prefs.getBool('account_locked') ?? false;
    });
  }

  @override
  void initState() {
    super.initState();
    UltraBatterySaver.initialize();
    BatteryManager.initialize();
    AppConstants.updateFromUserPreferences();
    _loadSavedEmail();
    _initializeDeviceSecurity();

    preferenceNotifier.addListener(_onPreferencesChanged);

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: AppConstants.backgroundAnimationDurationSec),
    );

    if (AppConstants.shouldEnableBackgroundAnimations) {
      _bgAnimationController.repeat();
    }

    _entryController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: AppConstants.adaptiveAnimationDuration),
    );

    if (AppConstants.shouldEnableAnyAnimations) {
      _entryController.forward();
    } else {
      _entryController.value = 1.0;
    }
  }

  void _onPreferencesChanged() {
    AppConstants.updateFromUserPreferences();

    if (AppConstants.shouldEnableBackgroundAnimations) {
      _bgAnimationController.repeat();
    } else {
      _bgAnimationController.stop();
    }
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _entryController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    UltraBatterySaver.dispose();
    preferenceNotifier.removeListener(_onPreferencesChanged);
    super.dispose();
  }

  Future<void> _forgotPassword() async {
    HapticFeedback.lightImpact();
    if (_emailController.text.isEmpty) {
      AppSnackbar.warning(context, 'Email required.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      AppSnackbar.success(context, 'Reset link sent.');
    } catch (e) {
      AppSnackbar.error(context, e.toString());
    }
  }

  Future<void> _loginUser() async {
    HapticFeedback.mediumImpact();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AppSnackbar.error(context, 'Email and password required.');
      return;
    }

    if (_isAccountLocked) {
      AppSnackbar.error(context, 'Account locked.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();

        await _authService.saveSecureCredentials(email, password);

        if (_lastLoggedInUserId != null && _lastLoggedInUserId != user.uid) {
          await _authService.clearSecureCredentials();
          await _authService.setBiometricEnabled(false);
        }

        if (_rememberMe) {
          await prefs.setString('saved_email', email);
          await prefs.setBool('remember_me', true);
        } else {
          await prefs.remove('saved_email');
          await prefs.setBool('remember_me', false);
        }

        await _authorizeUserOnDevice(user.uid);
        await prefs.setString('last_logged_in_user_id', user.uid);
        await _logSecurityEvent('login_success', user.uid);

        await _navigateToUserScreen(user);
      }
    } on FirebaseAuthException catch (e) {
      HapticFeedback.vibrate();
      _failedAttempts++;
      if (_failedAttempts >= 3) {
        setState(() => _isAccountLocked = true);
        AppSnackbar.error(context, 'Account locked. Try again in 15 minutes.');
        Timer(const Duration(minutes: 15), () {
          if (mounted) setState(() => _isAccountLocked = false);
        });
      } else {
        AppSnackbar.error(context, e.message ?? 'Authentication error.');
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
      AppSnackbar.error(context, 'Account not found.');
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1A232E);
    final Color cardBg = isDark
        ? const Color(0x1AFFFFFF)
        : const Color(0xE6FFFFFF);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
      ),
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
              opacity: 0.02,
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
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: kToolbarHeight + 24,
                bottom: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _entryController,
                    curve: Curves.easeIn,
                  ),
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _entryController,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
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
                                Colors.white.withOpacity(isDark ? 0.08 : 0.4),
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
                              if (AppConstants.shouldEnableBackgroundAnimations)
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
                                )
                              else
                                Image.asset(
                                  'assets/images/zhiyuan_logo.png',
                                  height: 85,
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
                              const Text(
                                'ENTERPRISE PORTAL',
                                style: TextStyle(
                                  color: AppTheme.primaryGold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.5,
                                ),
                              ),
                              const SizedBox(height: 40),
                              _buildTextField(
                                _emailController,
                                'Email',
                                Icons.email_outlined,
                                isDark,
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                _passwordController,
                                'Password',
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
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildPasswordStrengthIndicator(),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      activeColor: AppTheme.primaryGold,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54,
                                      ),
                                      value: _rememberMe,
                                      onChanged: (v) =>
                                          setState(() => _rememberMe = v!),
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
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: AppTheme.primaryGold,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 35),
                              Container(
                                width: double.infinity,
                                height: 55,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (isDark
                                                  ? AppTheme.primaryGold
                                                  : AppTheme.primaryDark)
                                              .withOpacity(0.25),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: CustomButton(
                                  text: 'Login',
                                  onPressed: _isLoading ? null : _loginUser,
                                  variant: ButtonVariant.primary,
                                  size: ButtonSize.medium,
                                  isLoading: _isLoading,
                                  isFullWidth: true,
                                ),
                              ),
                              if (_authService.isBiometricSupported &&
                                  _isBiometricEnabledGlobal)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 12),
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.primaryGold.withOpacity(
                                        0.3,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: CustomButton(
                                    text: 'Biometric Login',
                                    onPressed: _isLoading
                                        ? null
                                        : _authenticateWithBiometrics,
                                    variant: ButtonVariant.ghost,
                                    size: ButtonSize.medium,
                                    icon: const Icon(
                                      Icons.fingerprint,
                                      size: 20,
                                    ),
                                    isFullWidth: true,
                                  ),
                                ),
                              const SizedBox(height: 25),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RegisterScreen(),
                                      ),
                                    ),
                                    child: const Text(
                                      "Activate Account",
                                      style: TextStyle(
                                        color: AppTheme.primaryGold,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
          prefixIcon: Icon(icon, color: AppTheme.primaryGold, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: isDark ? const Color(0x1A000000) : const Color(0x80FFFFFF),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppTheme.primaryGold,
              width: 1.5,
            ),
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
        : const Color(0xFFE6F3FF).withOpacity(0.3);
    final double w = size.width, h = size.height;
    final double x1 =
        w * 0.5 + math.sin(animationValue * math.pi * 2) * w * 0.3;
    final double y1 =
        h * 0.2 + math.cos(animationValue * math.pi * 2) * h * 0.2;
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
    canvas.drawCircle(Offset(x1, y1), w * 0.8, paint1);
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
