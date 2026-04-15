import 'package:flutter/material.dart';

/// Centralized theme management for Zhiyuan Intern Portal
/// Corporate/bank-level color system and design tokens
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // ==================== BRAND COLORS ====================
  
  /// Primary brand accent - Premium Bronze/Gold
  static const Color primaryGold = Color(0xFFC2A984);

  /// Primary dark color - Deep Slate Grey/Onyx Black
  static const Color primaryDark = Color(0xFF1A1C20);

  // ==================== BACKGROUND SYSTEM ====================
  
  /// Dashboard mesh background - Dark mode
  static const Color dashboardBgDark = Color(0xFF141619);
  
  /// Dashboard mesh background - Light mode
  static const Color dashboardBgLight = Color(0xFFF8F9FA);
  
  /// Main theme background - Dark mode
  static const Color mainThemeBgDark = Color(0xFF0F171C);
  
  /// Main theme background - Light mode
  static const Color mainThemeBgLight = Color(0xFFF5F7FA);
  
  /// Dashboard base background - Dark mode
  static const Color dashboardBaseDark = Color(0xFF0A0A0F);

  // ==================== SIDEBAR COLORS ====================
  
  /// Sidebar background - Dark mode (aligned with dashboard)
  static const Color sidebarBgDark = Color(0xFF141619);
  
  /// Sidebar background - Light mode (aligned with dashboard)
  static const Color sidebarBgLight = Color(0xFFF8F9FA);
  
  /// Sidebar card/component background - Dark mode
  static const Color sidebarCardDark = Color(0xFF1A1C20);
  
  /// Sidebar card/component background - Light mode
  static const Color sidebarCardLight = Color(0xFFFFFFFF);

  // ==================== CARD & SURFACE COLORS ====================
  
  /// Glass card background - Dark mode (with opacity)
  static const Color glassCardDark = Color(0x1AFFFFFF);
  
  /// Glass card background - Light mode (with opacity)
  static const Color glassCardLight = Color(0xE6FFFFFF);
  
  /// Card background - Dark mode
  static const Color cardBgDark = Color(0xFF141A2B);
  
  /// Card background - Light mode
  static const Color cardBgLight = Color(0xFFF1EEE9);

  // ==================== MESH GRADIENT COLORS ====================
  
  // Dark mode gradient colors
  static const Color gradient1Dark = Color(0xFFCC5500);
  static const Color gradient2Dark = Color(0xFFC2A984);
  static const Color gradient3Dark = Color(0xFF8B4513);
  
  // Light mode gradient colors
  static const Color gradient1Light = Color(0xFFFFDAB9);
  static const Color gradient2Light = Color(0xFFEADDCA);
  static const Color gradient3Light = Color(0xFFFFF0DF);

  // ==================== TEXT COLORS ====================
  
  /// Primary text color - Light mode
  static const Color textPrimaryLight = Color(0xFF1A232E);
  
  /// Secondary text color - Dark mode
  static const Color textSecondaryDark = Colors.white;
  
  /// Muted text color
  static const Color textMuted = Color(0xFF666666);

  // ==================== STATUS & FEEDBACK COLORS ====================
  
  /// Success color
  static const Color success = Colors.green;
  
  /// Error color
  static const Color error = Colors.red;
  
  /// Warning color
  static const Color warning = Colors.orange;
  
  /// Info color
  static const Color info = Colors.blue;

  // ==================== INTERACTIVE COLORS ====================
  
  /// Button primary color (Time-in state)
  static const Color buttonPrimary = Color(0xFFE53935);
  
  /// Disabled button color
  static const Color buttonDisabled = Colors.grey;
  
  /// Logout/Warning accent
  static const Color logoutAccent = Colors.redAccent;

  // ==================== OPACITY & OVERLAY COLORS ====================
  
  /// White overlay for dark mode
  static const Color whiteOverlay10 = Color(0x1AFFFFFF);
  static const Color whiteOverlay05 = Color(0x0DFFFFFF);
  static const Color whiteOverlay03 = Color(0x08FFFFFF);
  
  /// Black overlay for light mode
  static const Color blackOverlay20 = Color(0x33000000);
  static const Color blackOverlay10 = Color(0x1A000000);
  static const Color blackOverlay05 = Color(0x0D000000);
  static const Color blackOverlay03 = Color(0x08000000);
  static const Color blackOverlay02 = Color(0x05000000);

  // ==================== BORDER & DIVIDER COLORS ====================
  
  /// Border color - Dark mode
  static const Color borderDark = Color(0x1AFFFFFF);
  
  /// Border color - Light mode
  static const Color borderLight = Color(0x99FFFFFF);

  // ==================== SHADOW COLORS ====================
  
  /// Shadow color - Dark mode
  static const Color shadowDark = Color(0x33000000);
  
  /// Shadow color - Light mode
  static const Color shadowLight = Color(0x0D000000);

  // ==================== SEMANTIC COLOR TOKENS ====================
  
  /// Success semantic colors
  static const Color successLight = Color(0xFF4CAF50);
  static const Color successDark = Color(0xFF388E3C);
  static const Color successBackground = Color(0xFFE8F5E8);
  
  /// Warning semantic colors
  static const Color warningLight = Color(0xFFFF9800);
  static const Color warningDark = Color(0xFFF57C00);
  static const Color warningBackground = Color(0xFFFFF3E0);
  
  /// Error semantic colors
  static const Color errorLight = Color(0xFFF44336);
  static const Color errorDark = Color(0xFFD32F2F);
  static const Color errorBackground = Color(0xFFFFEBEE);
  
  /// Info semantic colors
  static const Color infoLight = Color(0xFF2196F3);
  static const Color infoDark = Color(0xFF1976D2);
  static const Color infoBackground = Color(0xFFE3F2FD);
  
  /// Status colors for different states
  static const Color statusActive = Color(0xFF4CAF50);
  static const Color statusInactive = Color(0xFF9E9E9E);
  static const Color statusPending = Color(0xFFFF9800);
  static const Color statusCompleted = Color(0xFF2196F3);
  
  /// Interactive element colors
  static const Color interactivePrimary = Color(0xFF1976D2);
  static const Color interactiveSecondary = Color(0xFF7B1FA2);
  static const Color interactiveDisabled = Color(0xFFBDBDBD);
  
  /// Text hierarchy colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textHint = Color(0xFF9E9E9E);

  // ==================== THEME DATA ====================
  
  /// Get light theme data
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: mainThemeBgLight,
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        primary: primaryGold,
        secondary: gradient2Light,
        surface: cardBgLight,
        background: mainThemeBgLight,
        error: error,
      ),
    );
  }
  
  /// Get dark theme data
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: mainThemeBgDark,
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        secondary: gradient2Dark,
        surface: cardBgDark,
        background: mainThemeBgDark,
        error: error,
      ),
    );
  }

  // ==================== HELPER METHODS ====================
  
  /// Get appropriate text color based on theme
  static Color getTextColor(bool isDark) {
    return isDark ? textSecondaryDark : textPrimaryLight;
  }
  
  /// Get appropriate card color based on theme
  static Color getCardColor(bool isDark) {
    return isDark ? glassCardDark : glassCardLight;
  }
  
  /// Get appropriate sidebar background based on theme
  static Color getSidebarBgColor(bool isDark) {
    return isDark ? sidebarBgDark : sidebarBgLight;
  }
  
  /// Get appropriate sidebar card color based on theme
  static Color getSidebarCardColor(bool isDark) {
    return isDark ? sidebarCardDark : sidebarCardLight;
  }
  
  /// Get appropriate border color based on theme
  static Color getBorderColor(bool isDark) {
    return isDark ? borderDark : borderLight;
  }
  
  /// Get appropriate shadow color based on theme
  static Color getShadowColor(bool isDark) {
    return isDark ? shadowDark : shadowLight;
  }
  
  // ==================== SEMANTIC HELPER METHODS ====================
  
  /// Get success color based on theme
  static Color getSuccessColor(bool isDark) {
    return isDark ? successDark : successLight;
  }
  
  /// Get warning color based on theme
  static Color getWarningColor(bool isDark) {
    return isDark ? warningDark : warningLight;
  }
  
  /// Get error color based on theme
  static Color getErrorColor(bool isDark) {
    return isDark ? errorDark : errorLight;
  }
  
  /// Get info color based on theme
  static Color getInfoColor(bool isDark) {
    return isDark ? infoDark : infoLight;
  }
  
  /// Get status color based on status type
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return statusActive;
      case 'inactive':
        return statusInactive;
      case 'pending':
        return statusPending;
      case 'completed':
        return statusCompleted;
      default:
        return statusInactive;
    }
  }
  
  /// Get interactive color based on state
  static Color getInteractiveColor(bool isEnabled, bool isDark) {
    if (!isEnabled) return interactiveDisabled;
    return isDark ? interactivePrimary : interactiveSecondary;
  }
  
  /// Get text color based on hierarchy
  static Color getTextHierarchyColor(String hierarchy) {
    switch (hierarchy.toLowerCase()) {
      case 'primary':
        return textPrimary;
      case 'secondary':
        return textSecondary;
      case 'disabled':
        return textDisabled;
      case 'hint':
        return textHint;
      default:
        return textPrimary;
    }
  }
}

/// Extension for easy color access
extension AppThemeColors on Color {
  /// Add opacity helper
  Color withOpacityValue(double opacity) {
    return withOpacity(opacity);
  }
}
