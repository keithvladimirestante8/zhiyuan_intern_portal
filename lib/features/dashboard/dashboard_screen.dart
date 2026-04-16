import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/collapsible_sidebar.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/battery_manager.dart';
import '../../core/utils/ui_preference_manager.dart';
import '../../core/utils/ultra_battery_saver.dart';
import '../settings/settings_screen.dart';
import '../profile/setup_profile_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';

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

  int _selectedIndex = 0;

  final List<String> _screenTitles = [
    'ZHIYUAN DASHBOARD',
    'MY PROFILE',
    'ATTENDANCE HISTORY',
    'SETTINGS',
  ];

  @override
  void initState() {
    super.initState();

    UltraBatterySaver.initialize();
    BatteryManager.initialize();
    AppConstants.updateFromUserPreferences();

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
    _timer.cancel();
    UltraBatterySaver.dispose();
    preferenceNotifier.removeListener(_onPreferencesChanged);
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

  Widget _buildSidebar(bool isDark, Color textColor, {required bool isMobile}) {
    return CollapsibleSidebar(
      key: ValueKey(isMobile),
      displayName: _displayName,
      user: user,
      bgAnimationController: _bgAnimationController,
      isDark: isDark,
      textColor: textColor,
      isMobile: isMobile,
      selectedIndex: _selectedIndex,
      onItemSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
        if (isMobile) {
          Navigator.pop(context);
        }
      },
      onToggle: (expanded) {
        if (!isMobile) setState(() {});
      },
    );
  }

  Widget _buildCustomHeader(bool isDesktop, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 16.0,
        bottom: 8.0,
        left: 16.0,
        right: 24.0,
      ),
      child: Row(
        children: [
          if (!isDesktop) ...[
            Builder(
              builder: (context) => IconButton(
                icon: Icon(
                  Icons.menu_rounded,
                  color: isDark ? Colors.white : AppTheme.primaryDark,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (isDesktop) const SizedBox(width: 16),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _screenTitles[_selectedIndex],
                key: ValueKey<int>(_selectedIndex),
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.primaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveContent(
    bool isDesktop,
    bool isDark,
    Color textColor,
    Color cardBg,
    double clampedProgress,
  ) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent(
          isDesktop,
          isDark,
          textColor,
          cardBg,
          clampedProgress,
        );
      case 1:
        return const SetupProfileScreen();
      case 2:
        return Center(
          child: Text(
            "Attendance History Phase 4 Module",
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case 3:
        return const SettingsScreen();
      default:
        return _buildDashboardContent(
          isDesktop,
          isDark,
          textColor,
          cardBg,
          clampedProgress,
        );
    }
  }

  Widget _buildDashboardContent(
    bool isDesktop,
    bool isDark,
    Color textColor,
    Color cardBg,
    double clampedProgress,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _entryController,
              curve: const Interval(0.0, 0.4),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overview',
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      fontSize: 13,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _displayName.toUpperCase(),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (isDesktop)
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _entryController,
                curve: const Interval(0.2, 0.6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildGlassCard(
                                cardBg: cardBg,
                                isDark: isDark,
                                padding: const EdgeInsets.all(20),
                                child: _StatCardContent(
                                  title: "Total Hours",
                                  value: _hoursRendered.toStringAsFixed(1),
                                  icon: Icons.timer_outlined,
                                  textColor: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildGlassCard(
                                cardBg: cardBg,
                                isDark: isDark,
                                padding: const EdgeInsets.all(20),
                                child: _StatCardContent(
                                  title: "Shifts Done",
                                  value: _shiftsDone.toString(),
                                  icon: Icons.task_alt_rounded,
                                  textColor: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildGlassCard(
                                cardBg: cardBg,
                                isDark: isDark,
                                padding: const EdgeInsets.all(20),
                                child: _StatCardContent(
                                  title: "Target Hours",
                                  value: _requiredHours.toStringAsFixed(0),
                                  icon: Icons.flag_outlined,
                                  textColor: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildProgressCard(
                          cardBg,
                          isDark,
                          textColor,
                          clampedProgress,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: _buildTimeInCard(cardBg, isDark, textColor),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassCard(
                        cardBg: cardBg,
                        isDark: isDark,
                        padding: const EdgeInsets.all(20),
                        child: _StatCardContent(
                          title: "Total Hours",
                          value: _hoursRendered.toStringAsFixed(1),
                          icon: Icons.timer_outlined,
                          textColor: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildGlassCard(
                        cardBg: cardBg,
                        isDark: isDark,
                        padding: const EdgeInsets.all(20),
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
                const SizedBox(height: 15),
                _buildProgressCard(cardBg, isDark, textColor, clampedProgress),
                const SizedBox(height: 15),
                _buildTimeInCard(cardBg, isDark, textColor),
              ],
            ),
        ],
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

    final Size screenSize = MediaQuery.of(context).size;
    final bool isDesktop = screenSize.width >= 1024 && screenSize.height >= 600;

    double progress = (_requiredHours > 0)
        ? (_hoursRendered / _requiredHours)
        : 0.0;
    double clampedProgress = progress > 1.0 ? 1.0 : progress;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.dashboardBaseDark
          : AppTheme.dashboardBgLight,
      extendBodyBehindAppBar: false,
      drawer: !isDesktop
          ? Drawer(
              backgroundColor: isDark
                  ? AppTheme.sidebarBgDark
                  : AppTheme.sidebarBgLight,
              elevation: 0,
              child: _buildSidebar(isDark, textColor, isMobile: true),
            )
          : null,
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(isDark, textColor, isMobile: false),
          Expanded(
            child: ClipRect(
              child: Stack(
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
                  SafeArea(
                    child: Column(
                      children: [
                        _buildCustomHeader(isDesktop, isDark, textColor),
                        Expanded(
                          child: _isLoading && _docId == null
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryGold,
                                  ),
                                )
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder:
                                      (
                                        Widget child,
                                        Animation<double> animation,
                                      ) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                  child: _buildActiveContent(
                                    isDesktop,
                                    isDark,
                                    textColor,
                                    cardBg,
                                    clampedProgress,
                                  ),
                                ),
                        ),
                      ],
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

  Widget _buildProgressCard(
    Color cardBg,
    bool isDark,
    Color textColor,
    double clampedProgress,
  ) {
    return _buildGlassCard(
      cardBg: cardBg,
      isDark: isDark,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Completion Progress",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${(clampedProgress * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: clampedProgress,
              backgroundColor: Colors.grey.withOpacity(isDark ? 0.2 : 0.3),
              color: AppTheme.primaryGold,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required Color cardBg,
    required bool isDark,
    required EdgeInsets padding,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(isDark ? 0.05 : 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
                blurRadius: 30,
                offset: const Offset(0, 4),
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
        ? "TIME-IN"
        : (_hasTimedOut ? "COMPLETED" : "TIME-OUT");

    Color btnBgColor = !_hasTimedIn
        ? AppTheme.primaryGold
        : (_hasTimedOut
              ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300)
              : const Color(0xFFE53935));

    Color btnTxtColor = !_hasTimedIn
        ? Colors.black
        : (_hasTimedOut ? Colors.grey : Colors.white);

    return _buildGlassCard(
      cardBg: cardBg,
      isDark: isDark,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: AppTheme.primaryGold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'DAILY RECORD',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              "${_currentTime.hour > 12 ? _currentTime.hour - 12 : (_currentTime.hour == 0 ? 12 : _currentTime.hour)}:${_currentTime.minute.toString().padLeft(2, '0')}",
              style: TextStyle(
                color: textColor,
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          Center(
            child: Text(
              _currentTime.hour >= 12 ? 'PM' : 'AM',
              style: const TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (!_hasTimedOut && !_isLoading)
                  BoxShadow(
                    color: btnBgColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: CustomButton(
              text: txt,
              onPressed: _hasTimedOut || _isLoading ? null : _handleDTRAction,
              variant: ButtonVariant.primary,
              size: ButtonSize.small,
              isLoading: _isLoading,
              isFullWidth: true,
            ),
          ),
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
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryGold, size: 22),
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: textColor.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
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
        ? AppTheme.gradient1Dark.withOpacity(0.6)
        : AppTheme.gradient1Light.withOpacity(0.8);
    final Color color2 = isDark
        ? AppTheme.gradient2Dark.withOpacity(0.5)
        : AppTheme.gradient2Light.withOpacity(0.7);
    final Color color3 = isDark
        ? AppTheme.gradient3Dark.withOpacity(0.4)
        : AppTheme.gradient3Light.withOpacity(0.6);

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
        ..color = isDark ? AppTheme.dashboardBgDark : AppTheme.dashboardBgLight,
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
