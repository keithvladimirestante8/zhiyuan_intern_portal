import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// A Mac-style floating glassy dock navigation bar for mobile devices.
/// Features animated icons, a golden indicator dot for the active item,
/// and haptic feedback on interactions.
class MacDockNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isDark;

  const MacDockNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withOpacity(0.4)
              : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.15)
                : Colors.black.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDockItem(
                  index: 0,
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                ),
                _buildDockItem(
                  index: 1,
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                ),
                _buildDockItem(
                  index: 2,
                  icon: Icons.history_rounded,
                  label: 'History',
                ),
                _buildDockItem(
                  index: 3,
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isActive = selectedIndex == index;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onItemSelected(index);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Icon(
                icon,
                color: isActive
                    ? AppTheme.primaryGold
                    : (isDark ? Colors.white70 : Colors.black54),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: 4,
              width: isActive ? 4 : 0,
              decoration: BoxDecoration(
                color: AppTheme.primaryGold,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
