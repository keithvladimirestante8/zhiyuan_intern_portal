import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/app_constants.dart';
import '../../core/utils/battery_manager.dart';
import '../../core/utils/ui_preference_manager.dart';
import '../../core/utils/ultra_battery_saver.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_theme_switcher.dart';
import '../../widgets/collapsible_sidebar.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/navigation/mac_dock_nav.dart';
import '../auth/login_screen.dart';
import '../profile/setup_profile_screen.dart';
import '../settings/settings_screen.dart';
import 'attendance_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  late Timer _timer;
  StreamSubscription<QuerySnapshot>? _attendanceSubscription;
  DateTime _currentTime = DateTime.now();

  late AnimationController _bgAnimationController;
  late AnimationController _entryController;
  late PageController _pageController;

  String _displayName = "INTERN";
  double _requiredHours = 0.0;
  double _hoursRendered = 0.0;
  int _shiftsDone = 0;

  bool _isLoading = true;
  String? _docId;
  bool _hasTimedIn = false;
  bool _hasTimedOut = false;

  TimeOfDay? _selectedTime;
  DateTime? _selectedDate;
  bool _isWFH = true;

  DateTime? _targetCompletionDate;

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

    _pageController = PageController(initialPage: _selectedIndex);

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
        final targetDateStr = profileDoc.data()?['target_completion_date'];
        DateTime? targetDate;
        if (targetDateStr != null && targetDateStr is String) {
          try {
            targetDate = DateTime.parse(targetDateStr);
          } catch (e) {
            debugPrint("Error parsing target date: $e");
          }
        }

        setState(() {
          _displayName = profileDoc.data()?['username'] ?? "INTERN";
          _requiredHours = (profileDoc.data()?['required_hours'] ?? 0.0)
              .toDouble();
          _targetCompletionDate = targetDate;
        });
      }

      final attendanceStream = FirebaseFirestore.instance
          .collection('attendance')
          .where('email', isEqualTo: user!.email)
          .snapshots();

      _attendanceSubscription = attendanceStream.listen((snapshot) {
        double totalHours = 0.0;
        int completedShifts = 0;

        for (var doc in snapshot.docs) {
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
    _pageController.dispose();
    _timer.cancel();
    _attendanceSubscription?.cancel();
    UltraBatterySaver.dispose();
    preferenceNotifier.removeListener(_onPreferencesChanged);
    super.dispose();
  }

  Future<void> _handleDTRAction() async {
    if (user == null) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _selectedTime = TimeOfDay.now();
      _selectedDate = DateTime.now();
      _isWFH = true;
    });

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A232E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(isDark ? 0.1 : 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !_hasTimedIn ? "Time In" : "Time Out",
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A232E),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _displayName,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTimePickerButton(isDark, setDialogState),
                const SizedBox(height: 16),
                _buildDatePickerButton(isDark, setDialogState),
                const SizedBox(height: 16),
                _buildWfhToggle(isDark, setDialogState),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A232E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryGold,
                              AppTheme.primaryDark,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGold.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Submit",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
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
    );

    if (result == true && _selectedTime != null && _selectedDate != null) {
      await _submitAttendance(isDark);
    }
  }

  Widget _buildTimePickerButton(bool isDark, StateSetter setDialogState) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _selectedTime ?? TimeOfDay.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(primary: AppTheme.primaryGold),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setDialogState(() => _selectedTime = picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryGold.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              color: AppTheme.primaryGold,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _selectedTime != null
                  ? "${_selectedTime!.hour > 12 ? _selectedTime!.hour - 12 : (_selectedTime!.hour == 0 ? 12 : _selectedTime!.hour)}:${_selectedTime!.minute.toString().padLeft(2, '0')} ${_selectedTime!.period == DayPeriod.am ? 'AM' : 'PM'}"
                  : "Select Time",
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A232E),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerButton(bool isDark, StateSetter setDialogState) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime(2027),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(primary: AppTheme.primaryGold),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setDialogState(() => _selectedDate = picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryGold.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: AppTheme.primaryGold,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _selectedDate != null
                  ? "${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}"
                  : "Select Date",
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A232E),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWfhToggle(bool isDark, StateSetter setDialogState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_rounded,
            color: AppTheme.primaryGold,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            _isWFH ? "WFH" : "OFFICE",
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A232E),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          AnimatedThemeSwitcher(
            isDark: _isWFH,
            onChanged: (value) => setDialogState(() => _isWFH = value),
            size: 32.0,
            activeIcon: Icons.home_rounded,
            inactiveIcon: Icons.business_rounded,
            activeColor: AppTheme.primaryGold,
            inactiveColor: Colors.grey,
            activeTrackColor: AppTheme.primaryGold.withOpacity(0.3),
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAttendance(bool isDark) async {
    if (user == null || _selectedTime == null || _selectedDate == null) return;
    setState(() => _isLoading = true);

    String selectedDateStr =
        "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

    DateTime timeDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final collection = FirebaseFirestore.instance.collection('attendance');

    try {
      if (!_hasTimedIn) {
        final newDoc = await collection.add({
          'email': user!.email,
          'date': selectedDateStr,
          'timeIn': Timestamp.fromDate(timeDateTime),
          'timeOut': null,
          'location': _isWFH ? 'WFH' : 'Office',
          'status': 'Active',
        });
        setState(() {
          _docId = newDoc.id;
          _hasTimedIn = true;
        });
        _showSnackbar("Time-In Recorded Successfully!", Colors.green);
      } else if (_hasTimedIn && !_hasTimedOut) {
        await collection.doc(_docId).update({
          'timeOut': Timestamp.fromDate(timeDateTime),
          'location': _isWFH ? 'WFH' : 'Office',
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

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    HapticFeedback.mediumImpact();
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext dialogContext) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final dialogBg = isDark ? const Color(0xFF1A1C20) : Colors.white;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 24,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.redAccent, Colors.red],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Logout",
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.primaryDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Are you sure you want to end your current session?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: isDark ? Colors.white : AppTheme.primaryDark,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [Colors.redAccent, Colors.red],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                Navigator.of(dialogContext).pop();
                                await FirebaseAuth.instance.signOut();
                                if (mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Logout",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
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
        );
      },
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
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: isDesktop ? 0 : 100.0,
      ),
      child: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        physics: isDesktop ? const NeverScrollableScrollPhysics() : null,
        children: [
          _buildDashboardContent(
            isDesktop,
            isDark,
            textColor,
            cardBg,
            clampedProgress,
          ),
          const SetupProfileScreen(),
          const AttendanceHistoryScreen(),
          const SettingsScreen(),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(
    bool isDesktop,
    bool isDark,
    Color textColor,
    Color cardBg,
    double clampedProgress,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 32,
        right: 32,
        top: 16,
        bottom: isDesktop ? 16 : 120,
      ),
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
                        const SizedBox(height: 20),
                        _buildAIInsightsCard(cardBg, isDark, textColor),
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
                _buildAIInsightsCard(cardBg, isDark, textColor),
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
      drawer: null,
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
                              : _buildActiveContent(
                                  isDesktop,
                                  isDark,
                                  textColor,
                                  cardBg,
                                  clampedProgress,
                                ),
                        ),
                      ],
                    ),
                  ),
                  if (!isDesktop)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      right: 16,
                      child: IconButton(
                        icon: Icon(
                          Icons.logout_rounded,
                          color: AppTheme.primaryGold,
                          size: 24,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        onPressed: () => _showLogoutConfirmation(context),
                        tooltip: 'Logout',
                      ),
                    ),
                  if (!isDesktop)
                    MacDockNav(
                      selectedIndex: _selectedIndex,
                      onItemSelected: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOutCubic,
                        );
                      },
                      isDark: isDark,
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

  Map<String, dynamic> _calculateAIInsights() {
    double remainingHours = _requiredHours - _hoursRendered;
    double progress = _requiredHours > 0
        ? (_hoursRendered / _requiredHours) * 100
        : 0;

    double avgHoursPerShift = _shiftsDone > 0
        ? (_hoursRendered / _shiftsDone)
        : 8.0;

    int remainingShifts = avgHoursPerShift > 0
        ? (remainingHours / avgHoursPerShift).ceil()
        : 0;
    DateTime estimatedDate = DateTime.now().add(
      Duration(days: (remainingShifts / 5).ceil() * 7),
    );

    double requiredHoursPerShift = 0;
    String suggestion = "";
    String status = "";

    if (_targetCompletionDate != null) {
      int daysRemaining = _targetCompletionDate!
          .difference(DateTime.now())
          .inDays;
      if (daysRemaining > 0) {
        int workingDaysLeft = (daysRemaining / 7 * 5).ceil();
        remainingShifts = workingDaysLeft;

        requiredHoursPerShift = workingDaysLeft > 0
            ? (remainingHours / workingDaysLeft)
            : 0;

        int shiftsNeededAt8Hours = (remainingHours / 8).ceil();
        int daysNeededAt8Hours = (shiftsNeededAt8Hours / 5).ceil() * 7;
        DateTime realisticTargetDate = DateTime.now().add(
          Duration(days: daysNeededAt8Hours),
        );

        if (requiredHoursPerShift <= 8) {
          suggestion =
              "Perfect! You need ${requiredHoursPerShift.toStringAsFixed(1)} hours/shift to meet your target.";
          status = "On Track";
        } else if (requiredHoursPerShift <= 10) {
          suggestion =
              "Need ${requiredHoursPerShift.toStringAsFixed(1)} hours/shift. Try working longer shifts.";
          status = "Needs Effort";
        } else if (requiredHoursPerShift <= 12) {
          suggestion =
              "Requires ${requiredHoursPerShift.toStringAsFixed(1)} hours/shift. Consider extending to ${realisticTargetDate.month}/${realisticTargetDate.day}/${realisticTargetDate.year}.";
          status = "Challenging";
        } else {
          suggestion =
              "Not achievable. Extend target to ${realisticTargetDate.month}/${realisticTargetDate.day}/${realisticTargetDate.year} or work more shifts.";
          status = "Unrealistic";
        }
      } else {
        suggestion = "Your target date has passed. Set a new target.";
        status = "Overdue";
      }
    } else {
      suggestion = "Set a target completion date to get AI suggestions.";
      status = "No Target";
    }

    return {
      'remainingHours': remainingHours,
      'progress': progress,
      'avgHoursPerShift': avgHoursPerShift,
      'estimatedDate': estimatedDate,
      'requiredDailyHours': requiredHoursPerShift,
      'suggestion': suggestion,
      'status': status,
      'remainingShifts': remainingShifts,
    };
  }

  Future<void> _setTargetCompletionDate() async {
    if (user == null) return;
    HapticFeedback.mediumImpact();

    final picked = await showDatePicker(
      context: context,
      initialDate:
          _targetCompletionDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppTheme.primaryGold),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      try {
        await FirebaseFirestore.instance
            .collection('intern_profiles')
            .doc(user!.uid)
            .update({'target_completion_date': picked.toIso8601String()});

        setState(() => _targetCompletionDate = picked);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text(
                "Target date set to ${picked.month}/${picked.day}/${picked.year}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint("Error setting target date: $e");
      }
    }
  }

  Widget _buildAIInsightsCard(Color cardBg, bool isDark, Color textColor) {
    final insights = _calculateAIInsights();

    return _buildGlassCard(
      cardBg: cardBg,
      isDark: isDark,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryGold, AppTheme.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGold.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI INSIGHTS',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Smart Completion Tracker',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: insights['status'] == 'On Track'
                      ? Colors.green.withOpacity(0.15)
                      : insights['status'] == 'Needs Effort'
                      ? AppTheme.primaryGold.withOpacity(0.15)
                      : insights['status'] == 'Challenging'
                      ? Colors.orange.withOpacity(0.15)
                      : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: insights['status'] == 'On Track'
                        ? Colors.green.withOpacity(0.3)
                        : insights['status'] == 'Needs Effort'
                        ? AppTheme.primaryGold.withOpacity(0.3)
                        : insights['status'] == 'Challenging'
                        ? Colors.orange.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  insights['status'],
                  style: TextStyle(
                    color: insights['status'] == 'On Track'
                        ? Colors.green
                        : insights['status'] == 'Needs Effort'
                        ? AppTheme.primaryGold
                        : insights['status'] == 'Challenging'
                        ? Colors.orange
                        : isDark
                        ? Colors.white
                        : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey.shade800.withOpacity(0.5)
                  : Colors.grey.shade100.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryGold.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Progress',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${insights['progress'].toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: AppTheme.primaryGold,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${insights['remainingHours'].toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppTheme.primaryGold,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Hours Left',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: insights['progress'] / 100,
                    backgroundColor: Colors.grey.withOpacity(
                      isDark ? 0.15 : 0.2,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryGold,
                    ),
                    minHeight: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          InkWell(
            onTap: _setTargetCompletionDate,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.shade800.withOpacity(0.5)
                    : Colors.grey.shade100.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event_rounded,
                      color: AppTheme.primaryGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target Completion Date',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _targetCompletionDate != null
                              ? "${_targetCompletionDate!.month}/${_targetCompletionDate!.day}/${_targetCompletionDate!.year}"
                              : "Tap to set target date",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: AppTheme.primaryGold.withOpacity(0.8),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryGold.withOpacity(0.08),
                  AppTheme.primaryDark.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryGold.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: AppTheme.primaryGold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Recommendation',
                        style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        insights['suggestion'],
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildAIStat(
                  'Avg Hours/Shift',
                  '${insights['avgHoursPerShift'].toStringAsFixed(1)}h',
                  isDark,
                  Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAIStat(
                  'Shifts Needed',
                  '${insights['remainingShifts']}',
                  isDark,
                  Icons.work_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIStat(
    String label,
    String value,
    bool isDark, [
    IconData? icon,
  ]) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade800.withOpacity(0.5)
            : Colors.grey.shade100.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryGold, size: 16),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A232E),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
