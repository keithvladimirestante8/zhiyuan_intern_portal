import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/verify_email_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/profile/setup_profile_screen.dart';

/// Auth guard widget that enforces profile setup completion.
/// Checks the 'profile_setup_completed' flag in Firestore before allowing
/// access to the DashboardScreen. If false or missing, redirects to SetupProfileScreen.
class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _isLoading = true;
  bool _profileSetupCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkProfileSetupStatus();
  }

  Future<void> _checkProfileSetupStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('intern_profiles')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        _profileSetupCompleted = data?['profile_setup_completed'] ?? false;
      } else {
        _profileSetupCompleted = false;
      }
    } catch (e) {
      debugPrint('Error checking profile setup status: $e');
      _profileSetupCompleted = false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const LoginScreen();
    }

    if (!user.emailVerified) {
      return const VerifyEmailScreen();
    }

    if (!_profileSetupCompleted) {
      return const SetupProfileScreen();
    }

    return const DashboardScreen();
  }
}
