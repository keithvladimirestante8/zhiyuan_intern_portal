import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/utils/ui_preference_manager.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'firebase_options.dart';
import 'features/auth/login_screen.dart';
import 'core/services/auth_service.dart';
import 'theme/app_theme.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await UIPreferenceManager.initialize();

  final authService = AuthService();
  await authService.initialize();
  await UIPreferenceManager.applyUserPreferences();

  // Load saved theme mode
  final isDarkMode = await UIPreferenceManager.getThemeMode();
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const ZhiyuanApp());
}

class ZhiyuanApp extends StatefulWidget {
  const ZhiyuanApp({super.key});

  @override
  State<ZhiyuanApp> createState() => _ZhiyuanAppState();
}

class _ZhiyuanAppState extends State<ZhiyuanApp> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authService.logoutStream.listen((shouldLogout) {
      if (shouldLogout) {
        _handleGlobalLogout();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _authService.handleLifecycleChange(state);
  }

  void _handleGlobalLogout() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return Listener(
          onPointerDown: (_) => _authService.recordUserActivity(),
          child: MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Zhiyuan Intern Portal',
            debugShowCheckedModeBanner: false,
            themeMode: currentMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,

            // AUTOMATIC ROUTING: Check if user session is valid on startup
            home: FirebaseAuth.instance.currentUser != null
                ? const DashboardScreen()
                : const LoginScreen(),
          ),
        );
      },
    );
  }
}
