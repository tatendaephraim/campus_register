import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart';
import 'student.dart';
import 'role_selection_screen.dart';
import 'student_dashboard_screen.dart';
import 'student_repository.dart';

void main() async {
  // Ensure Flutter bindings are initialized before using plugins.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://omdoceplvstgfmztpcsg.supabase.co',
    anonKey: 'sb_publishable_CnvAQvdeO82XS52OALVx5A_H1apCkpi',
  );

  // Determine the initial screen.
  final Widget initialScreen = await _getInitialScreen();

  runApp(CampusRegisterApp(initialScreen: initialScreen));
}

/// Checks if a student is registered on this device and returns the appropriate
/// starting screen.
Future<Widget> _getInitialScreen() async {
  // Initialize the database. This will create the .db file and tables on first run.
  await DatabaseHelper.instance.database;

  final deviceId = await _getDeviceId();
  if (deviceId != null) {
    final student = await StudentRepository().getStudentByDeviceId(deviceId);
    if (student != null) {
      // If a student is found for this device, go to their dashboard.
      return StudentDashboardScreen(student: student);
    }
  }

  // If no student is registered, show the role selection screen.
  return const RoleSelectionScreen();
}

/// Gets a unique identifier for the current device.
Future<String?> _getDeviceId() async {
  final deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.id;
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    return iosInfo.identifierForVendor;
  }
  return null;
}

class CampusRegisterApp extends StatelessWidget {
  final Widget initialScreen;
  const CampusRegisterApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Register',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.light,
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFFF59E0B), // Amber
          background: const Color(0xFFF8FAFC), // Slate 50
          surface: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.03),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC), // Slate 50
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          floatingLabelStyle: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.2),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF1E293B), // Slate 800
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF1E293B)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          primary: const Color(0xFF818CF8), // Lighter Indigo
          secondary: const Color(0xFFFBBF24),
          background: const Color(0xFF0F172A), // Slate 900
          surface: const Color(0xFF1E293B), // Slate 800
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
          ),
          color: const Color(0xFF1E293B),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F172A), // Slate 900
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF818CF8), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          floatingLabelStyle: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.2),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      themeMode: ThemeMode.system,
      home: initialScreen,
    );
  }
}
