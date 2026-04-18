import 'dart:math' as math;
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_button.dart';
import '../auth/login_screen.dart';

/// Email verification screen for users who haven't verified their email.
/// Provides options to resend verification email, reload user status,
/// or return to login screen.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _emailSent = false;
  late AnimationController _fadeController;
  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bgAnimationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  Future<void> _resendEmail() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        if (mounted) {
          setState(() {
            _emailSent = true;
            _isLoading = false;
          });
          AppSnackbar.success(
            context,
            'Verification email sent to ${user.email}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.error(context, 'Failed to send email: $e');
      }
    }
  }

  Future<void> _reloadUser() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      await _auth.currentUser?.reload();
      if (mounted) {
        setState(() => _isLoading = false);
        if (_auth.currentUser?.emailVerified ?? false) {
          AppSnackbar.success(context, 'Email verified successfully!');
        } else {
          AppSnackbar.warning(context, 'Email not verified yet. Please check your inbox.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.error(context, 'Failed to reload: $e');
      }
    }
  }

  Future<void> _backToLogin() async {
    HapticFeedback.mediumImpact();
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark
        ? const Color(0x1AFFFFFF)
        : const Color(0xE6FFFFFF);
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.dashboardBaseDark
          : AppTheme.dashboardBgLight,
      body: Stack(
        children: [
          AnimatedBuilder(
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
            child: FadeTransition(
              opacity: _fadeController,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
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
                            color: Colors.white.withOpacity(isDark ? 0.08 : 0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
                              'VERIFY EMAIL',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppTheme.primaryDark,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'A verification link has been sent to your email. Please verify to activate your account.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                            CustomButton(
                              text: 'Resend Email',
                              onPressed: _resendEmail,
                              variant: ButtonVariant.gradient,
                              size: ButtonSize.large,
                              isLoading: _isLoading,
                              isFullWidth: true,
                            ),
                            const SizedBox(height: 16),
                            CustomButton(
                              text: 'I Have Verified',
                              onPressed: _reloadUser,
                              variant: ButtonVariant.gradient,
                              size: ButtonSize.large,
                              isLoading: _isLoading,
                              isFullWidth: true,
                            ),
                            const SizedBox(height: 16),
                            CustomButton(
                              text: 'Back to Login',
                              onPressed: _backToLogin,
                              variant: ButtonVariant.outline,
                              size: ButtonSize.large,
                              isLoading: false,
                              isFullWidth: true,
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
        ],
      ),
    );
  }
}

class MeshGradientPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  MeshGradientPainter({
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      colors: isDark
          ? [
              const Color(0xFF0D1B2A),
              const Color(0xFF1B263B),
              const Color(0xFF415A77),
            ]
          : [
              const Color(0xFFE8F1F5),
              const Color(0xFFD9E2EC),
              const Color(0xFFBCCCDC),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant MeshGradientPainter oldDelegate) => true;
}
