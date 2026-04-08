import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_screen.dart';
import 'main.dart';
import 'setup_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  late AnimationController _bgAnimationController;
  late AnimationController _entryController;

  String _displayName = "INTERN";
  double _requiredHours = 0.0;
  double _hoursRendered = 0.0;
  int _shiftsDone = 0;

  bool _isLoading = true;
  String? _docId;
  bool _hasTimedIn = false;
  bool _hasTimedOut = false;

  static const Color zLogoGold = Color(0xFFC2A984);
  static const Color zOnyxBlack = Color(0xFF1A1C20);

  @override
  void initState() {
    super.initState();

    // Background animation
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Entry animations
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => setState(() => _currentTime = DateTime.now()),
    );
    _fetchInternData();
  }

  Future<void> _fetchInternData() async {
    if (user == null) return;
    String todayDate =
        "${_currentTime.year}-${_currentTime.month.toString().padLeft(2, '0')}-${_currentTime.day.toString().padLeft(2, '0')}";

    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('intern_profiles')
          .doc(user!.uid)
          .get();
      if (profileDoc.exists) {
        setState(() {
          _displayName = profileDoc.data()?['username'] ?? "INTERN";
          _requiredHours = (profileDoc.data()?['required_hours'] ?? 0.0)
              .toDouble();
        });
      }

      final allAttendance = await FirebaseFirestore.instance
          .collection('attendance')
          .where('email', isEqualTo: user!.email)
          .get();

      double totalHours = 0.0;
      int completedShifts = 0;

      for (var doc in allAttendance.docs) {
        var data = doc.data();

        if (data['date'] == todayDate) {
          _docId = doc.id;
          _hasTimedIn = data['timeIn'] != null;
          _hasTimedOut = data['timeOut'] != null;
        }

        if (data['timeIn'] != null && data['timeOut'] != null) {
          Timestamp timeIn = data['timeIn'];
          Timestamp timeOut = data['timeOut'];
          Duration difference = timeOut.toDate().difference(timeIn.toDate());

          double shiftHours = difference.inMinutes / 60.0;

          // Smart lunch deduction
          if (shiftHours >= 5.0) shiftHours -= 1.0;

          totalHours += shiftHours;
          completedShifts++;
        }
      }

      setState(() {
        _hoursRendered = totalHours;
        _shiftsDone = completedShifts;
      });
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _entryController.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _handleDTRAction() async {
    if (user == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    String todayDate =
        "${_currentTime.year}-${_currentTime.month.toString().padLeft(2, '0')}-${_currentTime.day.toString().padLeft(2, '0')}";
    final collection = FirebaseFirestore.instance.collection('attendance');

    try {
      if (!_hasTimedIn) {
        final newDoc = await collection.add({
          'email': user!.email,
          'date': todayDate,
          'timeIn': FieldValue.serverTimestamp(),
          'timeOut': null,
          'status': 'Active',
        });
        setState(() {
          _docId = newDoc.id;
          _hasTimedIn = true;
        });
        _showSnackbar("Time-In Recorded Successfully!", Colors.green);
      } else if (_hasTimedIn && !_hasTimedOut) {
        await collection.doc(_docId).update({
          'timeOut': FieldValue.serverTimestamp(),
          'status': 'Completed',
        });
        setState(() => _hasTimedOut = true);
        _showSnackbar("Shift Completed. Great job today!", Colors.green);
        _fetchInternData();
      }
    } catch (e) {
      _showSnackbar("Action failed. Check your connection.", Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
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

    double progress = (_requiredHours > 0)
        ? (_hoursRendered / _requiredHours)
        : 0.0;
    double clampedProgress = progress > 1.0 ? 1.0 : progress;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0F)
          : const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      drawer: _buildSidebar(isDark, textColor),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : zOnyxBlack),
        title: Text(
          'ZHIYUAN DASHBOARD',
          style: TextStyle(
            color: isDark ? Colors.white : zOnyxBlack,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Icon(
            isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
            color: zLogoGold,
            size: 20,
          ),
          Switch(
            value: isDark,
            activeColor: zLogoGold,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          // 1. PREMIUM MESH GRADIENT BACKGROUND
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

          // 2. MAIN CONTENT
          SafeArea(
            child: _isLoading && _docId == null
                ? const Center(
                    child: CircularProgressIndicator(color: zLogoGold),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _entryController,
                            curve: const Interval(0.0, 0.5),
                          ),
                          child: SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: _entryController,
                                    curve: const Interval(
                                      0.0,
                                      0.5,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                                ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome Back,',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _displayName.toUpperCase(),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // --- PROGRESS SECTION ---
                        FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _entryController,
                            curve: const Interval(0.2, 0.7),
                          ),
                          child: SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: _entryController,
                                    curve: const Interval(
                                      0.2,
                                      0.7,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                                ),
                            child: _buildGlassCard(
                              cardBg: cardBg,
                              isDark: isDark,
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Completion Progress",
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "${(clampedProgress * 100).toStringAsFixed(1)}%",
                                        style: const TextStyle(
                                          color: zLogoGold,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: clampedProgress,
                                      backgroundColor: Colors.grey.withOpacity(
                                        isDark ? 0.2 : 0.3,
                                      ),
                                      color: zLogoGold,
                                      minHeight: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${_hoursRendered.toStringAsFixed(1)} Hrs Rendered",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        "Target: $_requiredHours Hrs",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // --- STATS ROW ---
                        FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _entryController,
                            curve: const Interval(0.4, 0.9),
                          ),
                          child: SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: _entryController,
                                    curve: const Interval(
                                      0.4,
                                      0.9,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                                ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildGlassCard(
                                    cardBg: cardBg,
                                    isDark: isDark,
                                    child: _StatCardContent(
                                      title: "Total Hours",
                                      value: _hoursRendered.toStringAsFixed(1),
                                      icon: Icons.timer_rounded,
                                      textColor: textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: _buildGlassCard(
                                    cardBg: cardBg,
                                    isDark: isDark,
                                    child: _StatCardContent(
                                      title: "Shifts Done",
                                      value: _shiftsDone.toString(),
                                      icon: Icons.task_alt_rounded,
                                      textColor: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // --- TIME IN CARD ---
                        FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _entryController,
                            curve: const Interval(0.6, 1.0),
                          ),
                          child: SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: _entryController,
                                    curve: const Interval(
                                      0.6,
                                      1.0,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                                ),
                            child: _buildTimeInCard(cardBg, isDark, textColor),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required Color cardBg,
    required bool isDark,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(isDark ? 0.08 : 0.6),
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
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 50,
                spreadRadius: 10,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTimeInCard(Color cardBg, bool isDark, Color textColor) {
    String txt = !_hasTimedIn
        ? "INITIALIZE TIME-IN"
        : (_hasTimedOut ? "SHIFT COMPLETED" : "RECORD TIME-OUT");

    Color btnBgColor = !_hasTimedIn
        ? zLogoGold
        : (_hasTimedOut
              ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300)
              : Colors.redAccent);

    Color btnTxtColor = !_hasTimedIn
        ? Colors.black
        : (_hasTimedOut ? Colors.grey : Colors.white);

    return _buildGlassCard(
      cardBg: cardBg,
      isDark: isDark,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DAILY TIME RECORD',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
              const Icon(
                Icons.calendar_today_rounded,
                color: zLogoGold,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // LARGE CLOCK
          Text(
            "${_currentTime.hour > 12 ? _currentTime.hour - 12 : (_currentTime.hour == 0 ? 12 : _currentTime.hour)}:${_currentTime.minute.toString().padLeft(2, '0')} ${_currentTime.hour >= 12 ? 'PM' : 'AM'}",
            style: TextStyle(
              color: textColor,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 30),

          // ACTION BUTTON
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!_hasTimedOut && !_isLoading)
                  BoxShadow(
                    color: btnBgColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _hasTimedOut || _isLoading ? null : _handleDTRAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnBgColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      txt,
                      style: TextStyle(
                        color: btnTxtColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDark, Color textColor) {
    return Drawer(
      backgroundColor: isDark
          ? const Color(0xFF0F171C)
          : const Color(0xFFF8F9FA),
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: zLogoGold.withOpacity(0.2)),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/zhiyuan_logo.png', height: 60),
                  const SizedBox(height: 10),
                  const Text(
                    "ZHIYUAN PORTAL",
                    style: TextStyle(
                      color: zLogoGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded, color: zLogoGold),
            title: Text(
              "My Profile",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SetupProfileScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded, color: zLogoGold),
            title: Text(
              "Attendance History",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            onTap: () {} /* Phase 4 */,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: Colors.redAccent.withOpacity(0.1),
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                "Secure Logout",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                HapticFeedback.heavyImpact();
                FirebaseAuth.instance.signOut().then(
                  (_) => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _StatCardContent extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color textColor;
  const _StatCardContent({
    required this.title,
    required this.value,
    required this.icon,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFC2A984), size: 28),
        const SizedBox(height: 15),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// --- CUSTOM PAINTER FOR MESH GRADIENT (ZHIYUAN THEME) ---
class MeshGradientPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  MeshGradientPainter({required this.animationValue, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final Color color1 = isDark
        ? const Color(0xFFCC5500).withOpacity(0.6) // Burnt Orange
        : const Color(0xFFFFDAB9).withOpacity(0.8); // Soft Peach

    final Color color2 = isDark
        ? const Color(0xFFC2A984).withOpacity(0.5) // Zhiyuan Gold
        : const Color(0xFFEADDCA).withOpacity(0.7); // Pale Gold

    final Color color3 = isDark
        ? const Color(0xFF8B4513).withOpacity(0.4) // Rust/Copper for depth
        : const Color(0xFFFFF0DF).withOpacity(0.6); // Warm Beige

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

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = isDark ? const Color(0xFF141619) : const Color(0xFFF8F9FA),
    );

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

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.2, h * 0.8),
        width: w * 0.8,
        height: w * 0.8,
      ),
      math.pi * 0.5,
      math.pi,
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
