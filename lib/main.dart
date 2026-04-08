import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_screen.dart';

// Global theme notifier for app-wide theme access
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ZhiyuanApp());
}

class ZhiyuanApp extends StatelessWidget {
  const ZhiyuanApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return MaterialApp(
          title: 'Zhiyuan Intern Portal',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode, // Use current theme mode

          // Light theme settings
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            useMaterial3: true,
            fontFamily: 'Inter',
          ),

          // Dark theme settings
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F171C),
            useMaterial3: true,
            fontFamily: 'Inter',
          ),

          home: const LoginScreen(),
        );
      },
    );
  }
}