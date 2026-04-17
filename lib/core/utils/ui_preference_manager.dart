import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_constants.dart';
import '../../main.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/animated_theme_switcher.dart';
import '../../theme/app_theme.dart';

/// Global preference notifier for UI settings
class PreferenceNotifier extends ChangeNotifier {
  bool _animationsEnabled = false;
  bool _batteryModeEnabled = true;

  bool get animationsEnabled => _animationsEnabled;
  bool get batteryModeEnabled => _batteryModeEnabled;

  void updatePreferences(bool animations, bool batteryMode) {
    _animationsEnabled = animations;
    _batteryModeEnabled = batteryMode;
    notifyListeners();
  }
}

/// Global preference notifier instance
final preferenceNotifier = PreferenceNotifier();

/// UI Preference Manager for user customization
class UIPreferenceManager {
  static const String _animationsKey = 'user_animation_preference';
  static const String _batteryModeKey = 'user_battery_mode_preference';
  static const String _themeModeKey = 'user_theme_mode_preference';
  static bool _isInitialized = false;
  
  /// Initialize user preferences
  static Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    // Set defaults on first run
    if (!prefs.containsKey(_animationsKey)) {
      await prefs.setBool(_animationsKey, false); // Default to battery saving
    }

    if (!prefs.containsKey(_batteryModeKey)) {
      await prefs.setBool(_batteryModeKey, true); // Default to battery mode
    }

    if (!prefs.containsKey(_themeModeKey)) {
      await prefs.setBool(_themeModeKey, false); // Default to light mode
    }

    // Initialize preferenceNotifier with current values
    final animations = prefs.getBool(_animationsKey) ?? false;
    final batteryMode = prefs.getBool(_batteryModeKey) ?? true;
    preferenceNotifier.updatePreferences(animations, batteryMode);

    _isInitialized = true;
  }
  
  /// Get user's animation preference
  static Future<bool> getAnimationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_animationsKey) ?? false;
  }
  
  /// Set user's animation preference
  static Future<void> setAnimationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animationsKey, enabled);
    final batteryMode = await getBatteryModeEnabled();
    preferenceNotifier.updatePreferences(enabled, batteryMode);
  }
  
  /// Get user's battery mode preference
  static Future<bool> getBatteryModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_batteryModeKey) ?? true;
  }
  
  /// Set user's battery mode preference
  static Future<void> setBatteryModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_batteryModeKey, enabled);
    final animations = await getAnimationsEnabled();
    preferenceNotifier.updatePreferences(animations, enabled);
  }
  
  /// Get user's theme mode preference (true = dark, false = light)
  static Future<bool> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeModeKey) ?? false;
  }
  
  /// Set user's theme mode preference (true = dark, false = light)
  static Future<void> setThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeModeKey, isDark);
  }
  
  /// Check if animations should be enabled based on user preference
  static Future<bool> shouldEnableAnimations() async {
    final userPreference = await getAnimationsEnabled();
    final batteryMode = await getBatteryModeEnabled();
    
    // User choice overrides everything
    if (!userPreference) return false;
    
    // If user wants animations but battery mode is on, still respect user choice
    return userPreference;
  }
  
  /// Get current UI mode description
  static Future<String> getCurrentUIMode() async {
    final animationsEnabled = await getAnimationsEnabled();
    final batteryMode = await getBatteryModeEnabled();
    
    if (batteryMode) {
      return 'Battery Saver Mode';
    } else {
      if (animationsEnabled) {
        return 'Rich UI Mode';
      } else {
        return 'Performance Mode';
      }
    }
  }
  
  /// Apply user preferences to app constants (call this on app start)
  static Future<void> applyUserPreferences() async {
    await initialize();
    
    final animationsEnabled = await getAnimationsEnabled();
    final batteryMode = await getBatteryModeEnabled();
    
    // Note: In a real app, you'd update the AppConstants dynamically
    // For now, we'll use the getters that check user preferences
    
    debugPrint('UI Mode: ${await getCurrentUIMode()}');
  }
}

/// Widget wrapper that respects user preferences
class UserPreferenceAwareWidget extends StatelessWidget {
  final Widget child;
  final Widget? animatedChild;
  
  const UserPreferenceAwareWidget({
    super.key,
    required this.child,
    this.animatedChild,
  });
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: UIPreferenceManager.shouldEnableAnimations(),
      builder: (context, snapshot) {
        final enableAnimations = snapshot.data ?? false;
        
        if (enableAnimations && animatedChild != null) {
          return animatedChild!;
        }
        
        return child;
      },
    );
  }
}

/// Settings screen widget for UI preferences
class UIPreferenceSettings extends StatefulWidget {
  const UIPreferenceSettings({super.key});

  @override
  State<UIPreferenceSettings> createState() => _UIPreferenceSettingsState();
  
  static final GlobalKey<_UIPreferenceSettingsState> globalKey = GlobalKey<_UIPreferenceSettingsState>();
}

class _UIPreferenceSettingsState extends State<UIPreferenceSettings> {
  bool _animationsEnabled = false;
  bool _batteryModeEnabled = true;
  bool _isDarkMode = false;
  bool _isLoading = true;
  String _currentMode = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final animations = await UIPreferenceManager.getAnimationsEnabled();
    final batteryMode = await UIPreferenceManager.getBatteryModeEnabled();
    final darkMode = await UIPreferenceManager.getThemeMode();
    final currentMode = await UIPreferenceManager.getCurrentUIMode();
    
    setState(() {
      _animationsEnabled = animations;
      _batteryModeEnabled = batteryMode;
      _isDarkMode = darkMode;
      _currentMode = currentMode;
      _isLoading = false;
    });
  }

  Future<void> _toggleAnimations(bool value) async {
    await UIPreferenceManager.setAnimationsEnabled(value);
    final currentMode = await UIPreferenceManager.getCurrentUIMode();
    setState(() {
      _animationsEnabled = value;
      _currentMode = currentMode;
    });
  }

  Future<void> _toggleBatteryMode(bool value) async {
    await UIPreferenceManager.setBatteryModeEnabled(value);
    final currentMode = await UIPreferenceManager.getCurrentUIMode();
    setState(() {
      _batteryModeEnabled = value;
      _currentMode = currentMode;
    });
  }
  
  Future<void> savePreferences() async {
    await UIPreferenceManager.setAnimationsEnabled(_animationsEnabled);
    await UIPreferenceManager.setBatteryModeEnabled(_batteryModeEnabled);
  }

  Future<void> _toggleThemeMode(bool value) async {
    setState(() => _isLoading = true);
    
    try {
      await UIPreferenceManager.setThemeMode(value);
      
      // Update global theme notifier
      themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
      
      if (mounted) {
        setState(() {
          _isDarkMode = value;
          _isLoading = false;
        });
        
        AppSnackbar.info(
          context,
          value ? 'Dark mode enabled.' : 'Light mode enabled.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.error(context, 'Update failed.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Animation toggle with premium switch
        ListTile(
          title: const Text('Rich Animations'),
          subtitle: Text(
            _animationsEnabled 
                ? 'Animations enabled'
                : 'Animations disabled',
            style: TextStyle(
              fontSize: 12,
              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          leading: Icon(
            _animationsEnabled ? Icons.animation : Icons.battery_saver,
            color: _animationsEnabled ? Colors.green : Colors.orange,
          ),
          trailing: AnimatedThemeSwitcher(
            isDark: _animationsEnabled,
            onChanged: (v) => _toggleAnimations(v),
            size: 32.0,
            activeIcon: Icons.animation,
            inactiveIcon: Icons.battery_saver,
            activeColor: Colors.green,
            inactiveColor: Colors.orange,
            activeTrackColor: Colors.green.withOpacity(0.3),
            inactiveTrackColor: Colors.orange.withOpacity(0.3),
          ),
        ),
        
        const Divider(),
        
        // Dark mode toggle with premium switch
        ListTile(
          title: const Text('Dark Mode'),
          subtitle: Text(
            _isDarkMode 
                ? 'Dark theme enabled'
                : 'Light theme enabled',
            style: TextStyle(
              fontSize: 12,
              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          leading: Icon(
            _isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: _isDarkMode ? Colors.grey.shade800 : Colors.orange,
          ),
          trailing: AnimatedThemeSwitcher(
            isDark: _isDarkMode,
            onChanged: (v) => _toggleThemeMode(v),
            size: 32.0,
            activeIcon: Icons.nightlight_round,
            inactiveIcon: Icons.wb_sunny_rounded,
            activeColor: AppTheme.primaryDark,
            inactiveColor: AppTheme.primaryGold,
            activeTrackColor: AppTheme.mainThemeBgDark,
            inactiveTrackColor: AppTheme.mainThemeBgLight,
          ),
        ),
        
        const Divider(),
        
        // Battery mode toggle with premium switch
        ListTile(
          title: const Text('Battery Saver Mode'),
          subtitle: Text(
            _batteryModeEnabled 
                ? 'Battery saver enabled'
                : 'Performance mode',
            style: TextStyle(
              fontSize: 12,
              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          leading: Icon(
            _batteryModeEnabled ? Icons.battery_charging_full : Icons.power,
            color: _batteryModeEnabled ? Colors.green : Colors.orange,
          ),
          trailing: AnimatedThemeSwitcher(
            isDark: _batteryModeEnabled,
            onChanged: (v) => _toggleBatteryMode(v),
            size: 32.0,
            activeIcon: Icons.battery_charging_full,
            inactiveIcon: Icons.power,
            activeColor: Colors.green,
            inactiveColor: Colors.orange,
            activeTrackColor: Colors.green.withOpacity(0.3),
            inactiveTrackColor: Colors.orange.withOpacity(0.3),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Current mode info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _animationsEnabled ? Icons.palette : Icons.eco,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Mode',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      _currentMode,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
