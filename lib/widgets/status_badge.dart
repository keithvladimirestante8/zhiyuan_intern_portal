import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Status badge widget for role/status indicators
class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeType type;
  final BadgeSize size;
  final BadgeVariant variant;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isAnimated;

  const StatusBadge({
    super.key,
    required this.text,
    this.type = BadgeType.info,
    this.size = BadgeSize.medium,
    this.variant = BadgeVariant.filled,
    this.icon,
    this.onTap,
    this.isAnimated = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final BadgeStyle badgeStyle = _getBadgeStyle(isDark);

    Widget badgeWidget = Container(
      padding: _getPadding(),
      decoration: _getDecoration(badgeStyle),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: _getIconSize(),
              color: badgeStyle.textColor,
            ),
            SizedBox(width: text.isNotEmpty ? 6 : 0),
          ],
          Flexible(
            child: Text(
              text,
              style: _getTextStyle(badgeStyle),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          child: badgeWidget,
        ),
      );
    }

    return badgeWidget;
  }

  BadgeStyle _getBadgeStyle(bool isDark) {
    switch (type) {
      case BadgeType.active:
        return BadgeStyle(
          backgroundColor: AppTheme.statusActive,
          textColor: Colors.white,
          borderColor: AppTheme.statusActive,
        );
      case BadgeType.inactive:
        return BadgeStyle(
          backgroundColor: AppTheme.statusInactive,
          textColor: Colors.white,
          borderColor: AppTheme.statusInactive,
        );
      case BadgeType.pending:
        return BadgeStyle(
          backgroundColor: AppTheme.statusPending,
          textColor: Colors.white,
          borderColor: AppTheme.statusPending,
        );
      case BadgeType.completed:
        return BadgeStyle(
          backgroundColor: AppTheme.statusCompleted,
          textColor: Colors.white,
          borderColor: AppTheme.statusCompleted,
        );
      case BadgeType.success:
        return BadgeStyle(
          backgroundColor: AppTheme.getSuccessColor(isDark),
          textColor: Colors.white,
          borderColor: AppTheme.getSuccessColor(isDark),
        );
      case BadgeType.warning:
        return BadgeStyle(
          backgroundColor: AppTheme.getWarningColor(isDark),
          textColor: Colors.white,
          borderColor: AppTheme.getWarningColor(isDark),
        );
      case BadgeType.error:
        return BadgeStyle(
          backgroundColor: AppTheme.getErrorColor(isDark),
          textColor: Colors.white,
          borderColor: AppTheme.getErrorColor(isDark),
        );
      case BadgeType.info:
        return BadgeStyle(
          backgroundColor: AppTheme.getInfoColor(isDark),
          textColor: Colors.white,
          borderColor: AppTheme.getInfoColor(isDark),
        );
      case BadgeType.gold:
        return BadgeStyle(
          backgroundColor: AppTheme.primaryGold,
          textColor: Colors.white,
          borderColor: AppTheme.primaryGold,
        );
      case BadgeType.corporate:
        return BadgeStyle(
          backgroundColor: AppTheme.corporateBlue,
          textColor: Colors.white,
          borderColor: AppTheme.corporateBlue,
        );
    }
  }

  BoxDecoration _getDecoration(BadgeStyle badgeStyle) {
    switch (variant) {
      case BadgeVariant.filled:
        return BoxDecoration(
          color: badgeStyle.backgroundColor,
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          boxShadow: [
            BoxShadow(
              color: badgeStyle.backgroundColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
      
      case BadgeVariant.outlined:
        return BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: badgeStyle.borderColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(_getBorderRadius()),
        );
      
      case BadgeVariant.ghost:
        return BoxDecoration(
          color: badgeStyle.backgroundColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(_getBorderRadius()),
        );
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case BadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case BadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case BadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    }
  }

  TextStyle _getTextStyle(BadgeStyle badgeStyle) {
    switch (size) {
      case BadgeSize.small:
        return TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: badgeStyle.textColor,
          letterSpacing: 0.5,
        );
      case BadgeSize.medium:
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: badgeStyle.textColor,
          letterSpacing: 0.5,
        );
      case BadgeSize.large:
        return TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: badgeStyle.textColor,
          letterSpacing: 0.5,
        );
    }
  }

  double _getBorderRadius() {
    switch (size) {
      case BadgeSize.small:
        return 6;
      case BadgeSize.medium:
        return 8;
      case BadgeSize.large:
        return 12;
    }
  }

  double _getIconSize() {
    switch (size) {
      case BadgeSize.small:
        return 12;
      case BadgeSize.medium:
        return 16;
      case BadgeSize.large:
        return 20;
    }
  }
}

/// Badge style configuration
class BadgeStyle {
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  const BadgeStyle({
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });
}

/// Badge types for different statuses
enum BadgeType {
  active,      // Green badge for active status
  inactive,    // Grey badge for inactive status
  pending,     // Orange badge for pending status
  completed,   // Blue badge for completed status
  success,     // Green badge for success
  warning,     // Orange badge for warning
  error,       // Red badge for error
  info,        // Blue badge for info
  gold,        // Gold badge for premium features
  corporate,   // Corporate blue badge
}

/// Badge sizes
enum BadgeSize {
  small,       // Compact badges
  medium,      // Standard badges
  large,       // Prominent badges
}

/// Badge variants
enum BadgeVariant {
  filled,      // Solid background
  outlined,    // Border only
  ghost,       // Transparent background
}

/// Specialized badges for common use cases

/// Role badge for user roles
class RoleBadge extends StatelessWidget {
  final String role;
  final VoidCallback? onTap;

  const RoleBadge({
    super.key,
    required this.role,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BadgeType badgeType = _getRoleBadgeType(role);

    return StatusBadge(
      text: role,
      type: badgeType,
      size: BadgeSize.small,
      variant: BadgeVariant.filled,
      onTap: onTap,
    );
  }

  BadgeType _getRoleBadgeType(String role) {
    switch (role.toLowerCase()) {
      case 'intern':
        return BadgeType.info;
      case 'department leader':
        return BadgeType.gold;
      case 'hr':
        return BadgeType.corporate;
      case 'cao':
        return BadgeType.gold;
      case 'admin':
        return BadgeType.error;
      default:
        return BadgeType.inactive;
    }
  }
}

/// Online status badge
class OnlineStatusBadge extends StatelessWidget {
  final bool isOnline;
  final bool showText;

  const OnlineStatusBadge({
    super.key,
    required this.isOnline,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      text: showText ? (isOnline ? 'Online' : 'Offline') : '',
      type: isOnline ? BadgeType.active : BadgeType.inactive,
      size: BadgeSize.small,
      variant: BadgeVariant.filled,
      icon: isOnline ? Icons.circle : Icons.circle_outlined,
    );
  }
}

/// Attendance status badge
class AttendanceStatusBadge extends StatelessWidget {
  final String status;
  final VoidCallback? onTap;

  const AttendanceStatusBadge({
    super.key,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BadgeType badgeType = _getAttendanceBadgeType(status);

    return StatusBadge(
      text: status,
      type: badgeType,
      size: BadgeSize.medium,
      variant: BadgeVariant.filled,
      onTap: onTap,
    );
  }

  BadgeType _getAttendanceBadgeType(String status) {
    switch (status.toLowerCase()) {
      case 'present':
      case 'on time':
        return BadgeType.success;
      case 'late':
        return BadgeType.warning;
      case 'absent':
        return BadgeType.error;
      case 'leave':
        return BadgeType.info;
      case 'holiday':
        return BadgeType.completed;
      default:
        return BadgeType.inactive;
    }
  }
}

/// Priority badge for tasks
class PriorityBadge extends StatelessWidget {
  final String priority;
  final VoidCallback? onTap;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BadgeType badgeType = _getPriorityBadgeType(priority);

    return StatusBadge(
      text: priority,
      type: badgeType,
      size: BadgeSize.small,
      variant: BadgeVariant.outlined,
      onTap: onTap,
    );
  }

  BadgeType _getPriorityBadgeType(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return BadgeType.error;
      case 'medium':
      case 'normal':
        return BadgeType.warning;
      case 'low':
        return BadgeType.info;
      default:
        return BadgeType.inactive;
    }
  }
}

/// Department badge with icon
class DepartmentBadge extends StatelessWidget {
  final String department;
  final VoidCallback? onTap;

  const DepartmentBadge({
    super.key,
    required this.department,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon = _getDepartmentIcon(department);

    return StatusBadge(
      text: department,
      type: BadgeType.corporate,
      size: BadgeSize.medium,
      variant: BadgeVariant.outlined,
      icon: icon,
      onTap: onTap,
    );
  }

  IconData _getDepartmentIcon(String department) {
    switch (department.toLowerCase()) {
      case 'hr':
      case 'human resources':
        return Icons.people;
      case 'it':
      case 'information technology':
        return Icons.computer;
      case 'finance':
      case 'accounting':
        return Icons.attach_money;
      case 'marketing':
        return Icons.campaign;
      case 'operations':
        return Icons.settings;
      case 'sales':
        return Icons.trending_up;
      default:
        return Icons.business;
    }
  }
}

/// Animated badge that pulses
class AnimatedStatusBadge extends StatefulWidget {
  final String text;
  final BadgeType type;
  final BadgeSize size;
  final IconData? icon;
  final VoidCallback? onTap;

  const AnimatedStatusBadge({
    super.key,
    required this.text,
    required this.type,
    this.size = BadgeSize.medium,
    this.icon,
    this.onTap,
  });

  @override
  State<AnimatedStatusBadge> createState() => _AnimatedStatusBadgeState();
}

class _AnimatedStatusBadgeState extends State<AnimatedStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: StatusBadge(
            text: widget.text,
            type: widget.type,
            size: widget.size,
            icon: widget.icon,
            onTap: widget.onTap,
          ),
        );
      },
    );
  }
}
