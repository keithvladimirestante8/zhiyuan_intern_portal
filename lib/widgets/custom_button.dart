import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Custom button widget with corporate styling and multiple variants
class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final Widget? icon;
  final double? width;
  final double? height;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ButtonStyle buttonStyle = _getButtonStyle(isDark);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: widget.isFullWidth ? double.infinity : widget.width,
            height: widget.height ?? _getHeight(),
            child: widget.icon != null
                ? _buildButtonWithIcon(buttonStyle, isDark)
                : _buildButton(buttonStyle, isDark),
          ),
        );
      },
    );
  }

  Widget _buildButton(ButtonStyle buttonStyle, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.isLoading ? null : _handleTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _getSplashColor(isDark),
        highlightColor: _getHighlightColor(isDark),
        child: Container(
          decoration: _getContainerDecoration(buttonStyle),
          child: Center(
            child: widget.isLoading
                ? _buildLoadingIndicator()
                : Text(
                    widget.text,
                    style: _getTextStyle(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonWithIcon(ButtonStyle buttonStyle, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.isLoading ? null : _handleTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _getSplashColor(isDark),
        highlightColor: _getHighlightColor(isDark),
        child: Container(
          decoration: _getContainerDecoration(buttonStyle),
          child: Center(
            child: widget.isLoading
                ? _buildLoadingIndicator()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      widget.icon!,
                      const SizedBox(width: 8),
                      Text(
                        widget.text,
                        style: _getTextStyle(),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _controller.forward().then((_) {
      _controller.reverse();
    });
    widget.onPressed?.call();
  }

  Color _getSplashColor(bool isDark) {
    switch (widget.variant) {
      case ButtonVariant.primary:
        return AppTheme.primaryGold.withValues(alpha: 0.3);
      case ButtonVariant.secondary:
        return AppTheme.primaryDark.withValues(alpha: 0.3);
      case ButtonVariant.outline:
        return AppTheme.primaryGold.withValues(alpha: 0.2);
      case ButtonVariant.ghost:
        return AppTheme.primaryGold.withValues(alpha: 0.1);
      case ButtonVariant.danger:
        return AppTheme.error.withValues(alpha: 0.3);
      case ButtonVariant.gradient:
        return AppTheme.primaryGold.withValues(alpha: 0.4);
      case ButtonVariant.glass:
        return AppTheme.primaryGold.withValues(alpha: 0.2);
    }
  }

  Color _getHighlightColor(bool isDark) {
    switch (widget.variant) {
      case ButtonVariant.primary:
        return AppTheme.primaryGold.withValues(alpha: 0.2);
      case ButtonVariant.secondary:
        return AppTheme.primaryDark.withValues(alpha: 0.2);
      case ButtonVariant.outline:
        return AppTheme.primaryGold.withValues(alpha: 0.1);
      case ButtonVariant.ghost:
        return AppTheme.primaryGold.withValues(alpha: 0.05);
      case ButtonVariant.danger:
        return AppTheme.error.withValues(alpha: 0.2);
      case ButtonVariant.gradient:
        return AppTheme.primaryGold.withValues(alpha: 0.3);
      case ButtonVariant.glass:
        return AppTheme.primaryGold.withValues(alpha: 0.1);
    }
  }

  BoxDecoration _getContainerDecoration(ButtonStyle buttonStyle) {
    switch (widget.variant) {
      case ButtonVariant.primary:
        return BoxDecoration(
          color: AppTheme.primaryGold,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGold.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
      
      case ButtonVariant.secondary:
        return BoxDecoration(
          color: AppTheme.primaryDark,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryDark.withValues(alpha: 0.3),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        );
      
      case ButtonVariant.outline:
        return BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: AppTheme.primaryGold, width: 2),
          borderRadius: BorderRadius.circular(12),
        );
      
      case ButtonVariant.ghost:
        return BoxDecoration(
          color: AppTheme.primaryGold.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        );
      
      case ButtonVariant.danger:
        return BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.error.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
      
      case ButtonVariant.gradient:
        return BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryGold,
              AppTheme.primaryGold.withValues(alpha: 0.8),
              AppTheme.primaryDark.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGold.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        );
      
      case ButtonVariant.glass:
        return BoxDecoration(
          color: AppTheme.primaryGold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryGold.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppTheme.primaryGold.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
    }
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: _getIconSize(),
      height: _getIconSize(),
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          widget.variant == ButtonVariant.outline
              ? AppTheme.primaryGold
              : Colors.white,
        ),
      ),
    );
  }

  ButtonStyle _getButtonStyle(bool isDark) {
    switch (widget.variant) {
      case ButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGold,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppTheme.primaryGold.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: _getPadding(),
        );
      
      case ButtonVariant.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: AppTheme.primaryDark.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: _getPadding(),
        );
      
      case ButtonVariant.outline:
        return OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryGold,
          side: BorderSide(color: AppTheme.primaryGold, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: _getPadding(),
        );
      
      case ButtonVariant.ghost:
        return TextButton.styleFrom(
          foregroundColor: AppTheme.primaryGold,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: _getPadding(),
        );
      
      case ButtonVariant.danger:
        return ElevatedButton.styleFrom(
          backgroundColor: AppTheme.error,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppTheme.error.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: _getPadding(),
        );
      
      case ButtonVariant.gradient:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: AppTheme.primaryGold.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: _getPadding(),
        );
      
      case ButtonVariant.glass:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.primaryGold,
          elevation: 0,
          shadowColor: AppTheme.primaryGold.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: _getPadding(),
        );
    }
  }

  TextStyle _getTextStyle() {
    switch (widget.size) {
      case ButtonSize.small:
        return const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        );
      case ButtonSize.medium:
        return const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        );
      case ButtonSize.large:
        return const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        );
    }
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
  }

  double _getHeight() {
    switch (widget.size) {
      case ButtonSize.small:
        return 32;
      case ButtonSize.medium:
        return 44;
      case ButtonSize.large:
        return 56;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case ButtonSize.small:
        return 12;
      case ButtonSize.medium:
        return 16;
      case ButtonSize.large:
        return 20;
    }
  }
}

/// Button variants for different use cases
enum ButtonVariant {
  primary,    // Gold button for main actions
  secondary,  // Dark button for secondary actions
  outline,    // Gold outline for tertiary actions
  ghost,      // Text-only for minimal actions
  danger,     // Red for destructive actions
  gradient,   // Gold gradient button
  glass,      // Glass morphism button
}

/// Button sizes for different contexts
enum ButtonSize {
  small,      // Compact buttons
  medium,     // Standard buttons
  large,      // Prominent buttons
}

/// Custom button for specific corporate actions
class CorporateButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isLoading;
  final Widget? icon;

  const CorporateButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      variant: ButtonVariant.primary,
      size: ButtonSize.medium,
      isLoading: isLoading,
      icon: icon,
      isFullWidth: true,
    );
  }
}

/// Floating action button with corporate styling
class CorporateFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String? tooltip;

  const CorporateFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: AppTheme.primaryGold,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: icon,
      label: tooltip != null ? Text(tooltip!) : const Text(''),
    );
  }
}
