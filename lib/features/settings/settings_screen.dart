import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/battery_manager.dart';
import '../../core/utils/ui_preference_manager.dart';
import '../../core/utils/ultra_battery_saver.dart';
import '../../core/services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/animated_theme_switcher.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final AuthService _authService = AuthService();

  bool _biometricEnabled = false;
  int _autoLogoutMinutes = 30;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    UltraBatterySaver.initialize();
    BatteryManager.initialize();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    try {
      await _authService.initialize();
      await UIPreferenceManager.initialize();

      final biometricEnabled = await _authService.isBiometricEnabled();
      final autoLogoutMinutes = _authService.autoLogoutMinutes;

      setState(() {
        _biometricEnabled = biometricEnabled;
        _autoLogoutMinutes = autoLogoutMinutes;
      });
    } catch (e) {
      debugPrint('Error initializing settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final biometricSuccess = await _authService.setBiometricEnabled(
        _biometricEnabled,
      );
      if (!biometricSuccess) throw Exception('Failed to update biometrics');

      await _authService.setAutoLogoutMinutes(_autoLogoutMinutes);
      await UIPreferenceSettings.globalKey.currentState?.savePreferences();
      await UIPreferenceManager.applyUserPreferences();
      await AppConstants.updateFromUserPreferences();

      if (mounted) {
        AppSnackbar.show(
          context: context,
          message: 'Saved.',
          type: SnackbarType.custom,
          customColor: AppTheme.primaryGold,
          title: 'Success',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Save failed.');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (value) {
        final success = await _authService.authenticateWithBiometrics(
          reason: 'Verify identity to enable biometric login',
        );
        if (!success) {
          if (mounted) {
            AppSnackbar.error(context, 'Authentication failed.');
          }
          setState(() => _isProcessing = false);
          return;
        }
      }
      setState(() => _biometricEnabled = value);
    } catch (e) {
      debugPrint('Biometric error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color headerColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1A232E);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(headerColor, titleColor),
          const SizedBox(height: 24),
          _buildUserCard(titleColor),
          const SizedBox(height: 32),
          Text(
            'Security',
            style: TextStyle(
              color: headerColor,
              fontSize: 13,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                if (_authService.isBiometricSupported)
                  _buildSettingTile(
                    title: 'Biometric Authentication',
                    subtitle: 'Use fingerprint or face recognition',
                    icon: Icons.fingerprint,
                    isToggle: true,
                    value: _biometricEnabled,
                    onChanged: _isProcessing ? null : _toggleBiometric,
                    activeIcon: Icons.fingerprint,
                    inactiveIcon: Icons.lock_outline,
                    activeColor: Colors.green,
                    inactiveColor: Colors.grey,
                  ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                _buildSettingTile(
                  title: 'Auto Logout',
                  subtitle: 'Automatically logout after inactivity',
                  icon: Icons.timer,
                  isToggle: false,
                  value: null,
                  trailing: Text(
                    _autoLogoutMinutes == -1
                        ? 'Never'
                        : (_autoLogoutMinutes == 0
                              ? 'Immediately'
                              : '$_autoLogoutMinutes min'),
                    style: const TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: _showAutoLogoutDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'UI Preferences',
            style: TextStyle(
              color: headerColor,
              fontSize: 13,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(child: UIPreferenceSettings(key: UIPreferenceSettings.globalKey)),
          const SizedBox(height: 32),
          CustomButton(
            text: _isProcessing ? 'Saving...' : 'Save Settings',
            onPressed: _isProcessing ? null : _saveSettings,
            variant: ButtonVariant.primary,
            size: ButtonSize.medium,
            isFullWidth: true,
            isLoading: _isProcessing,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color headerColor, Color titleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: TextStyle(
            color: headerColor,
            fontSize: 13,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'USER PREFERENCES',
          style: TextStyle(
            color: titleColor,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Color titleColor) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.primaryGold, AppTheme.primaryDark],
              ),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              user?.email ?? 'User',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isToggle,
    bool? value,
    ValueChanged<bool>? onChanged,
    Widget? trailing,
    VoidCallback? onTap,
    IconData? activeIcon,
    IconData? inactiveIcon,
    Color? activeColor,
    Color? inactiveColor,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isToggle ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primaryGold, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF1A232E),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isToggle)
                AnimatedThemeSwitcher(
                  isDark: value ?? false,
                  onChanged: onChanged ?? (v) {},
                  size: 32.0,
                  activeIcon: activeIcon ?? Icons.check,
                  inactiveIcon: inactiveIcon ?? Icons.close,
                  activeColor: activeColor ?? AppTheme.primaryGold,
                  inactiveColor: inactiveColor ?? Colors.grey,
                  activeTrackColor: (activeColor ?? AppTheme.primaryGold).withOpacity(0.3),
                  inactiveTrackColor: (inactiveColor ?? Colors.grey).withOpacity(0.3),
                )
              else if (trailing != null)
                trailing,
            ],
          ),
        ),
      ),
    );
  }

  void _showAutoLogoutDialog() {
    final List<int> options = [-1, 0, 15, 30, 60, 120];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1C20) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(isDark ? 0.08 : 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto Logout Delay',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A232E),
                ),
              ),
              const SizedBox(height: 16),
              ...options.map((minutes) {
                final bool isSelected = _autoLogoutMinutes == minutes;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _autoLogoutMinutes = minutes);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryGold.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryGold.withOpacity(0.5)
                              : (isDark ? Colors.white12 : Colors.black12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              minutes == -1
                                  ? 'Never'
                                  : (minutes == 0
                                        ? 'Immediately'
                                        : '$minutes minutes'),
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.primaryGold
                                    : (isDark
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade800),
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryGold,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    UltraBatterySaver.dispose();
    super.dispose();
  }
}
