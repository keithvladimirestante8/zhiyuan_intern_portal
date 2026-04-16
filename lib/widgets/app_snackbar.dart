import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Snackbar type enum for different message categories
enum SnackbarType {
  success,
  error,
  warning,
  info,
  custom,
}

/// Snackbar position enum for placement control
enum SnackbarPosition {
  top,
  bottom,
  auto, // Automatically chooses based on keyboard visibility
}

/// Premium glassmorphism snackbar widget with corporate styling
/// Features: Glass effect, left accent line, icons, title/message, close button, progress bar
class AppSnackbar {
  AppSnackbar._();

  /// Show a snackbar with the specified parameters
  static void show({
    required BuildContext context,
    required String message,
    String? title,
    SnackbarType type = SnackbarType.info,
    SnackbarPosition position = SnackbarPosition.auto,
    Duration duration = const Duration(seconds: 3),
    Color? customColor,
  }) {
    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stateColor = _getStateColor(type, isDark, customColor);
    final textColor = _getTextColor(isDark);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 1), // Very long, we handle dismissal manually
        padding: EdgeInsets.zero,
        margin: _getMargin(position, context),
        content: _GlassySnackbar(
          title: title,
          message: message,
          type: type,
          stateColor: stateColor,
          textColor: textColor,
          duration: duration,
        ),
      ),
    );

    HapticFeedback.lightImpact();
  }

  /// Get state color based on type and theme
  static Color _getStateColor(
    SnackbarType type,
    bool isDark,
    Color? customColor,
  ) {
    if (customColor != null) return customColor;

    switch (type) {
      case SnackbarType.success:
        return AppTheme.getSuccessColor(isDark);
      case SnackbarType.error:
        return AppTheme.getErrorColor(isDark);
      case SnackbarType.warning:
        return AppTheme.getWarningColor(isDark);
      case SnackbarType.info:
        return AppTheme.getInfoColor(isDark);
      case SnackbarType.custom:
        return AppTheme.primaryGold;
    }
  }

  /// Get text color based on theme
  static Color _getTextColor(bool isDark) {
    return isDark ? Colors.white : Colors.black87;
  }

  /// Get margin based on position
  static EdgeInsets _getMargin(SnackbarPosition position, BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;

    SnackbarPosition effectivePosition = position;
    if (position == SnackbarPosition.auto) {
      effectivePosition = isKeyboardVisible
          ? SnackbarPosition.top
          : SnackbarPosition.bottom;
    }

    switch (effectivePosition) {
      case SnackbarPosition.top:
        return EdgeInsets.only(
          top: mediaQuery.padding.top + kToolbarHeight + 8,
          left: 16,
          right: 16,
        );
      case SnackbarPosition.bottom:
        return EdgeInsets.only(
          bottom: mediaQuery.padding.bottom + 16,
          left: 16,
          right: 16,
        );
      case SnackbarPosition.auto:
        return const EdgeInsets.all(16);
    }
  }

  /// Convenience method for success messages
  static void success(
    BuildContext context,
    String message, {
    String? title,
    SnackbarPosition position = SnackbarPosition.auto,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context: context,
      message: message,
      title: title ?? 'Success',
      type: SnackbarType.success,
      position: position,
      duration: duration,
    );
  }

  /// Convenience method for error messages
  static void error(
    BuildContext context,
    String message, {
    String? title,
    SnackbarPosition position = SnackbarPosition.auto,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context: context,
      message: message,
      title: title ?? 'Error',
      type: SnackbarType.error,
      position: position,
      duration: duration,
    );
  }

  /// Convenience method for warning messages
  static void warning(
    BuildContext context,
    String message, {
    String? title,
    SnackbarPosition position = SnackbarPosition.auto,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context: context,
      message: message,
      title: title ?? 'Warning',
      type: SnackbarType.warning,
      position: position,
      duration: duration,
    );
  }

  /// Convenience method for info messages
  static void info(
    BuildContext context,
    String message, {
    String? title,
    SnackbarPosition position = SnackbarPosition.auto,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context: context,
      message: message,
      title: title ?? 'Info',
      type: SnackbarType.info,
      position: position,
      duration: duration,
    );
  }
}

/// Glassmorphism snackbar widget with progress bar
class _GlassySnackbar extends StatefulWidget {
  final String? title;
  final String message;
  final SnackbarType type;
  final Color stateColor;
  final Color textColor;
  final Duration duration;

  const _GlassySnackbar({
    required this.title,
    required this.message,
    required this.type,
    required this.stateColor,
    required this.textColor,
    required this.duration,
  });

  @override
  State<_GlassySnackbar> createState() => _GlassySnackbarState();
}

class _GlassySnackbarState extends State<_GlassySnackbar>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _entranceController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Progress bar animation
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Entrance animation (slide in + fade)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    ));

    // Start entrance animation
    _entranceController.forward();

    // Start progress bar and trigger exit when complete
    _progressController.forward().then((_) {
      if (mounted) {
        _dismissWithAnimation();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  IconData _getIcon() {
    switch (widget.type) {
      case SnackbarType.success:
        return Icons.check_circle;
      case SnackbarType.error:
        return Icons.error;
      case SnackbarType.warning:
        return Icons.warning;
      case SnackbarType.info:
        return Icons.info;
      case SnackbarType.custom:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.stateColor.withOpacity(0.15),
                    border: Border.all(
                      color: widget.stateColor.withOpacity(0.5),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Left accent line
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 6,
                          color: widget.stateColor,
                        ),
                      ),
                      // Main content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
                        child: Row(
                          children: [
                            // Icon
                            Icon(
                              _getIcon(),
                              color: widget.stateColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            // Title + Message
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.title != null) ...[
                                    Text(
                                      widget.title!,
                                      style: TextStyle(
                                        color: widget.stateColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  Text(
                                    widget.message,
                                    style: TextStyle(
                                      color: widget.textColor,
                                      fontWeight: FontWeight.w400,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Close button
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _dismissWithAnimation();
                              },
                              color: widget.textColor,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      // Progress bar at bottom
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: _progressController.value,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation(widget.stateColor),
                              minHeight: 2,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _dismissWithAnimation() {
    _progressController.stop(); // Stop progress bar animation
    _entranceController.reverse().then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
  }
}
