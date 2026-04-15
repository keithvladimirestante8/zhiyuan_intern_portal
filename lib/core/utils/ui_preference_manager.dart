import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// UI Preference Manager for user customization
class UIPreferenceManager {
  static const String _animationsKey = 'user_animation_preference';
  static const String _batteryModeKey = 'user_battery_mode_preference';
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
    
    if (animationsEnabled) {
      return 'Rich UI Mode (Animations On)';
    } else {
      return 'Battery Saver Mode (Animations Off)';
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
}

class _UIPreferenceSettingsState extends State<UIPreferenceSettings> {
  bool _animationsEnabled = false;
  bool _batteryModeEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final animations = await UIPreferenceManager.getAnimationsEnabled();
    final batteryMode = await UIPreferenceManager.getBatteryModeEnabled();
    
    setState(() {
      _animationsEnabled = animations;
      _batteryModeEnabled = batteryMode;
      _isLoading = false;
    });
  }

  Future<void> _toggleAnimations(bool value) async {
    setState(() => _isLoading = true);
    
    try {
      await UIPreferenceManager.setAnimationsEnabled(value);
      
      if (mounted) {
        setState(() {
          _animationsEnabled = value;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Animations enabled! Rich UI mode activated.' : 'Animations disabled for battery saving.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: value ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error updating preferences',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleBatteryMode(bool value) async {
    setState(() => _isLoading = true);
    
    try {
      await UIPreferenceManager.setBatteryModeEnabled(value);
      
      if (mounted) {
        setState(() {
          _batteryModeEnabled = value;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Battery mode enabled for maximum efficiency.' : 'Battery mode disabled.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: value ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error updating preferences',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
          ),
        );
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
        // Animation toggle
        SwitchListTile(
          title: const Text('Rich Animations'),
          subtitle: Text(
            _animationsEnabled 
                ? 'Beautiful animations enabled (uses more battery)'
                : 'Animations disabled for battery saving',
          ),
          value: _animationsEnabled,
          onChanged: _isLoading ? null : _toggleAnimations,
          secondary: Icon(
            _animationsEnabled ? Icons.animation : Icons.battery_saver,
            color: _animationsEnabled ? Colors.green : Colors.orange,
          ),
        ),
        
        const Divider(),
        
        // Battery mode toggle
        SwitchListTile(
          title: const Text('Battery Saver Mode'),
          subtitle: Text(
            _batteryModeEnabled 
                ? 'Maximum battery efficiency enabled'
                : 'Standard performance mode',
          ),
          value: _batteryModeEnabled,
          onChanged: _isLoading ? null : _toggleBatteryMode,
          secondary: Icon(
            _batteryModeEnabled ? Icons.battery_charging_full : Icons.power,
            color: _batteryModeEnabled ? Colors.green : Colors.orange,
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
                    FutureBuilder<String>(
                      future: UIPreferenceManager.getCurrentUIMode(),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Loading...',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
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
