import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'login_screen.dart';
import 'theme/app_theme.dart';

class CollapsibleSidebar extends StatefulWidget {
  final String displayName;
  final User? user;
  final AnimationController? bgAnimationController;
  final bool isDark;
  final Color textColor;
  final bool isMobile;
  final Function(bool) onToggle;
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CollapsibleSidebar({
    super.key,
    required this.displayName,
    required this.user,
    this.bgAnimationController,
    required this.isDark,
    required this.textColor,
    this.isMobile = false,
    required this.onToggle,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar>
    with TickerProviderStateMixin {
  
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  late Animation<double> _fadeAnimation;

  String? _photoUrl;
  String _appVersion = "1.0.0";

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isMobile;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: widget.isMobile ? 1.0 : 0.0,
    );

    _widthAnimation = Tween<double>(
      begin: widget.isMobile ? 280.0 : 70.0,
      end: widget.isMobile ? 280.0 : 240.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: widget.isMobile ? 1.0 : 0.0, end: 1.0)
        .animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _initPackageInfo();
    _fetchProfilePic();
  }

  Future<void> _initPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
        });
      }
    } catch (e) {
      debugPrint("Package info error: $e");
    }
  }

  Future<void> _fetchProfilePic() async {
    if (widget.user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('intern_profiles')
            .doc(widget.user!.uid)
            .get();

        if (doc.exists && mounted) {
          final newUrl = doc.data()?['photo_url'];
          if (newUrl != _photoUrl) {
            setState(() {
              _photoUrl = newUrl;
            });
          }
        }
      } catch (e) {
        debugPrint("Error fetching profile picture: $e");
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    if (widget.isMobile) return;
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    widget.onToggle(_isExpanded);
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    HapticFeedback.heavyImpact();
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext dialogContext) {
        final dialogBg = AppTheme.getSidebarBgColor(widget.isDark);
        return Dialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                      color: Colors.redAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 32),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Secure Logout",
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : AppTheme.primaryDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Are you sure you want to end your current session?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                              color: widget.isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: widget.isDark ? Colors.white : AppTheme.primaryDark,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            if (widget.isMobile) Navigator.pop(context);
                            FirebaseAuth.instance.signOut().then(
                                  (_) => Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                                    (route) => false,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final sidebarBgColor = AppTheme.getSidebarBgColor(widget.isDark);
        return Container(
          width: _widthAnimation.value,
          decoration: BoxDecoration(
            color: sidebarBgColor,
            border: Border(
              right: BorderSide(
                color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(4, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                if (!widget.isMobile) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _buildToggleButton(),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  const SizedBox(height: 10),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        if (_isExpanded) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildExpandedProfile(),
                          ),
                          const SizedBox(height: 30),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: _buildCollapsedProfile(),
                          ),
                          const SizedBox(height: 30),
                        ],
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 20 : 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isExpanded) ...[
                                const Text(
                                  'MENU',
                                  style: TextStyle(
                                    color: AppTheme.primaryGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              _buildMenuItems(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(_isExpanded ? 20 : 10),
                  child: _buildBottomSection(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggleButton() {
    final cardBg = AppTheme.getSidebarCardColor(widget.isDark);
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cardBg,
        border: Border.all(
          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            _toggleSidebar();
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _isExpanded ? Icons.chevron_left_rounded : Icons.menu_rounded,
              key: ValueKey(_isExpanded),
              color: widget.isDark ? Colors.white70 : Colors.black87,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedProfile() {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryGold.withOpacity(0.15),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.5), width: 1.5),
      ),
      child: _photoUrl != null && _photoUrl!.isNotEmpty
          ? ClipRRect(
        borderRadius: BorderRadius.circular(22.5),
        child: CachedNetworkImage(
          imageUrl: _photoUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGold),
          errorWidget: (context, url, error) => const Icon(Icons.person_rounded, color: AppTheme.primaryGold, size: 24),
        ),
      )
          : const Icon(Icons.person_rounded, color: AppTheme.primaryGold, size: 24),
    );
  }

  Widget _buildExpandedProfile() {
    final cardBg = AppTheme.getSidebarCardColor(widget.isDark);
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: cardBg,
          border: Border.all(
            color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGold.withOpacity(0.15),
                border: Border.all(color: AppTheme.primaryGold.withOpacity(0.5), width: 2),
              ),
              child: _photoUrl != null && _photoUrl!.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: CachedNetworkImage(
                  imageUrl: _photoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGold)),
                  errorWidget: (context, url, error) => const Icon(Icons.person_rounded, color: AppTheme.primaryGold, size: 35),
                ),
              )
                  : const Icon(Icons.person_rounded, color: AppTheme.primaryGold, size: 35),
            ),
            const SizedBox(height: 18),
            Text(
              widget.displayName,
              style: TextStyle(
                color: widget.isDark ? Colors.white : AppTheme.primaryDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'INTERN',
                style: TextStyle(color: AppTheme.primaryGold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 3),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.user?.email ?? '',
              style: TextStyle(
                color: widget.isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItems() {
    return Column(
      children: [
        _buildMenuItem(index: 0, icon: Icons.dashboard_rounded, title: "Dashboard", subtitle: "Overview & tracking"),
        const SizedBox(height: 12),
        _buildMenuItem(index: 1, icon: Icons.person_outline_rounded, title: "My Profile", subtitle: "Manage your info"),
        const SizedBox(height: 12),
        _buildMenuItem(index: 2, icon: Icons.history_rounded, title: "Attendance", subtitle: "View time records"),
        const SizedBox(height: 12),
        _buildMenuItem(index: 3, icon: Icons.settings_rounded, title: "Settings", subtitle: "App preferences"),
      ],
    );
  }

  Widget _buildMenuItem({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    bool isActive = widget.selectedIndex == index;
    final activeBg = AppTheme.getSidebarCardColor(widget.isDark);
    final inactiveIconBg = AppTheme.getSidebarCardColor(widget.isDark);

    if (_isExpanded) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive ? AppTheme.primaryGold.withOpacity(0.8) : (widget.isDark ? Colors.grey.shade700 : Colors.grey.shade400),
              width: isActive ? 1.5 : 1.0,
            ),
            color: isActive ? activeBg : Colors.transparent,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onItemSelected(index);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isActive ? AppTheme.sidebarBgDark : inactiveIconBg,
                      ),
                      child: Icon(
                        icon,
                        color: isActive ? Colors.white : (widget.isDark ? Colors.white : AppTheme.primaryDark),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isActive ? AppTheme.primaryGold : (widget.isDark ? Colors.white : AppTheme.primaryDark),
                              fontSize: 15,
                              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: widget.isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive) const Icon(Icons.chevron_right_rounded, color: AppTheme.sidebarBgDark, size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      return Tooltip(
        message: title,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isActive ? AppTheme.sidebarBgDark : inactiveIconBg,
            border: Border.all(
              color: isActive ? AppTheme.primaryGold : (widget.isDark ? Colors.grey.shade700 : Colors.grey.shade400),
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onItemSelected(index);
              },
              child: Icon(
                icon,
                color: isActive ? Colors.white : (widget.isDark ? Colors.white : AppTheme.primaryDark),
                size: 22,
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildBottomSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isExpanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent, width: 1.5),
              color: widget.isDark ? Colors.black26 : Colors.red.shade50,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showLogoutConfirmation(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: widget.isDark ? Colors.grey.shade800 : Colors.red.shade100,
                          border: Border.all(color: Colors.redAccent, width: 1.5),
                        ),
                        child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Secure Logout",
                              style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                            ),
                            Text(
                              "Sign out safely",
                              style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          Tooltip(
            message: "Logout",
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.isDark ? Colors.grey.shade800 : Colors.red.shade100,
                border: Border.all(color: Colors.redAccent, width: 1.5),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showLogoutConfirmation(context),
                  child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                ),
              ),
            ),
          ),
        if (_isExpanded) ...[
          const SizedBox(height: 16),
          Text(
            "v$_appVersion • Enterprise Edition",
            style: TextStyle(
              color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}