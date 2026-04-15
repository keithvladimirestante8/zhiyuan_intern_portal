import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_theme_switcher.dart';
import 'widgets/custom_button.dart';
import 'core/utils/ultra_battery_saver.dart';
import 'core/utils/battery_manager.dart';
import 'core/constants/app_constants.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _bgAnimationController;
  late AnimationController _entryController;

  bool _isLoading = false;
  bool _obscurePassword = true;

  double _strength = 0;
  String _strengthText = "Security: Undefined";
  Color _strengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();

    UltraBatterySaver.initialize();
    BatteryManager.initialize();
    AppConstants.updateFromUserPreferences(); // Apply user settings

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

  void _checkPassword(String value) {
    if (value.isEmpty) {
      setState(() {
        _strength = 0;
        _strengthText = "Security: Undefined";
        _strengthColor = Colors.grey;
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
      _strength = strength;
      if (strength <= 0.25) {
        _strengthText = "Security: Weak (Insecure)";
        _strengthColor = Colors.redAccent;
      } else if (strength <= 0.5) {
        _strengthText = "Security: Good";
        _strengthColor = Colors.orangeAccent;
      } else if (strength <= 0.75) {
        _strengthText = "Security: Strong";
        _strengthColor = Colors.blueAccent;
      } else {
        _strengthText = "Security: Executive Grade";
        _strengthColor = AppTheme.primaryGold;
      }
    });
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _entryController.dispose();

    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    UltraBatterySaver.dispose();
    super.dispose();
  }

  Future<bool> _isEmailWhitelisted(String email) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('accepted_emails')
        .where('email', isEqualTo: email.toLowerCase().trim())
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> _handleRegistration() async {
    HapticFeedback.mediumImpact();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackbar("Please fill in all fields.", isError: true);
      return;
    }
    if (password != _confirmPasswordController.text.trim()) {
      HapticFeedback.vibrate();
      _showSnackbar("Passwords do not match.", isError: true);
      return;
    }
    if (_strength < 0.75) {
      HapticFeedback.vibrate();
      _showSnackbar(
        "Security risk: Please use a stronger password.",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      bool isAuthorized = await _isEmailWhitelisted(email);
      if (!isAuthorized) {
        _showSnackbar(
          "ACCESS DENIED: Email not in HR pre-approved list.",
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'email': email,
        'role': 'intern',
        'profile_setup_completed': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      await userCredential.user?.sendEmailVerification();
      _showSnackbar("Account Initialized! Verification sent.", isError: false);

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showSnackbar(e.message ?? "Authentication Error", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          ? AppTheme.dashboardBaseDark
          : AppTheme.dashboardBgLight,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppTheme.primaryDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          AnimatedThemeSwitcher(
            isDark: isDark,
            onChanged: (v) {
              themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          const SizedBox(width: 10),
        ],
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
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _entryController,
                    curve: Curves.easeIn,
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
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
                                    height: 75,
                                  ),
                                )
                              else
                                Image.asset(
                                  'assets/images/zhiyuan_logo.png',
                                  height: 75,
                                ),
                              const SizedBox(height: 20),
                              Text(
                                'INTERN ENROLLMENT',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              const Text(
                                'Secure Onboarding Protocol',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 40),
                              _buildField(
                                _emailController,
                                "Authorized Email",
                                Icons.email_outlined,
                                isDark,
                              ),
                              const SizedBox(height: 20),
                              _buildField(
                                _passwordController,
                                "Set Access Password",
                                Icons.lock_outline,
                                isDark,
                                isPass: true,
                                onChanged: _checkPassword,
                              ),
                              const SizedBox(height: 15),
                              Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _strengthText,
                                        style: TextStyle(
                                          color: _strengthColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Icon(
                                        Icons.shield_moon_outlined,
                                        color: _strengthColor,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: _strength,
                                      backgroundColor: Colors.grey.withOpacity(
                                        0.1,
                                      ),
                                      color: _strengthColor,
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildField(
                                _confirmPasswordController,
                                "Confirm Access Password",
                                Icons.lock_reset,
                                isDark,
                                isPass: true,
                              ),
                              const SizedBox(height: 40),
                              _buildRegisterButton(isDark),
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

  Widget _buildField(
      TextEditingController controller,
      String label,
      IconData icon,
      bool isDark, {
        bool isPass = false,
        Function(String)? onChanged,
      }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPass ? _obscurePassword : false,
        onChanged: onChanged,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: AppTheme.primaryGold, size: 20),
          suffixIcon: isPass
              ? IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
              size: 18,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _obscurePassword = !_obscurePassword);
            },
          )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0x1A000000) : const Color(0x80FFFFFF),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.primaryGold, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterButton(bool isDark) {
    Color btnColor = isDark ? AppTheme.primaryGold : AppTheme.primaryDark;
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: btnColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: CustomButton(
        text: 'INITIALIZE ACCOUNT',
        onPressed: _isLoading ? null : _handleRegistration,
        variant: ButtonVariant.primary,
        size: ButtonSize.medium,
        isLoading: _isLoading,
        isFullWidth: true,
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
    final double x3 =
        w * 0.2 + math.sin(animationValue * math.pi * 2 * 0.8) * w * 0.25;
    final double y3 =
        h * 0.8 + math.cos(animationValue * math.pi * 2 * 0.8) * h * 0.25;

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

    final Paint paint3 = Paint()
      ..shader = RadialGradient(
        colors: [color3, color3.withOpacity(0.0)],
        stops: const [0.2, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x3, y3), radius: w * 0.6))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    canvas.drawCircle(Offset(x1, y1), w * 0.8, paint1);
    canvas.drawCircle(Offset(x2, y2), w * 0.7, paint2);
    canvas.drawCircle(Offset(x3, y3), w * 0.6, paint3);

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
  bool shouldRepaint(covariant MeshGradientPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isDark != isDark;
  }
}