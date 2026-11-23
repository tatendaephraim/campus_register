import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart';
import 'role_selection_screen.dart';
import 'student_dashboard_screen.dart';
import 'student_repository.dart';
import 'teacher_dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'teacher_repository.dart';
import 'onboarding_screen.dart';
import 'services/device_identity.dart';
import 'ui/design_tokens.dart';
import 'services/theme_service.dart';

void main() async {
  // Ensure Flutter bindings are initialized before using plugins.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://omdoceplvstgfmztpcsg.supabase.co',
    ),
    publishableKey: const String.fromEnvironment(
      'SUPABASE_KEY',
      defaultValue: 'sb_publishable_CnvAQvdeO82XS52OALVx5A_H1apCkpi',
    ),
  );

  // Initialize Theme Service
  await ThemeService.instance.init();

  runApp(const CampusRegisterApp());
}

/// Checks if a student is registered on this device or a teacher is logged in, and returns the appropriate
/// starting screen.
Future<Widget> _getInitialScreen() async {
  // Initialize the database. This will create the .db file and tables on first run.
  await DatabaseHelper.instance.database;

  // Check if onboarding is completed.
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/.onboarding_completed');
    final onboardingDone = await file.exists();
    if (!onboardingDone) {
      return const OnboardingScreen();
    }
  } catch (_) {
    // If anything fails (e.g. storage access issues), fall through to normal screen.
  }

  // Check if a teacher is logged in persistently.
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/.logged_in_teacher_email');
    if (await file.exists()) {
      final email = (await file.readAsString()).trim();
      if (email.isNotEmpty) {
        final teacher = await TeacherRepository().getTeacherByEmail(email);
        if (teacher.role.trim().toLowerCase() == 'admin') {
          return AdminDashboardScreen(admin: teacher);
        }
        return TeacherDashboardScreen(teacher: teacher);
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error loading persistently logged-in teacher: $e');
  }

  final deviceId = await _getDeviceId();
  if (deviceId != null) {
    final student = await StudentRepository().getStudentByDeviceId(deviceId);
    if (student != null) {
      // If a student is found for this device, go to their dashboard.
      return StudentDashboardScreen(student: student);
    }
  }

  // If no student is registered and no teacher is logged in, show the role selection screen.
  return const RoleSelectionScreen();
}

/// Gets a unique identifier for the current device.
Future<String?> _getDeviceId() => DeviceIdentity.current();

class CampusRegisterApp extends StatelessWidget {
  const CampusRegisterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeSettings>(
      valueListenable: ThemeService.instance.settingsNotifier,
      builder: (context, themeSettings, child) {
        final seedColor = themeSettings.getSeedColor();
        final themeMode = themeSettings.themeMode;

        return MaterialApp(
          title: 'Campus Register',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.slate50,
            textTheme: AppType.textTheme(Brightness.light),
            colorScheme: ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.light,
              primary: seedColor,
              secondary: AppColors.amber,
              surface: Colors.white,
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shadowColor: Colors.black.withValues(alpha: 0.03),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.xlR,
                side: const BorderSide(color: AppColors.slate200, width: 1),
              ),
              color: Colors.white,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.slate50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: AppRadius.mdR,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdR,
                borderSide: const BorderSide(color: AppColors.slate200, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdR,
                borderSide: BorderSide(color: seedColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdR,
                borderSide: const BorderSide(color: AppColors.danger, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdR,
                borderSide: const BorderSide(color: AppColors.danger, width: 2),
              ),
              labelStyle: AppType.body(context, color: AppColors.slate500, weight: FontWeight.w500),
              floatingLabelStyle: AppType.body(context, color: seedColor, weight: FontWeight.w700),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdR),
                textStyle: AppType.body(context, weight: FontWeight.w700, fontSize: 16, letterSpacing: 0.2),
              ),
            ),
            appBarTheme: AppBarTheme(
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              titleTextStyle: AppType.display(
                context,
                color: AppColors.slate800,
                weight: FontWeight.w600,
                fontSize: 20,
                letterSpacing: -0.4,
              ),
              iconTheme: const IconThemeData(color: AppColors.slate800),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.slate900,
            textTheme: AppType.textTheme(Brightness.dark),
            colorScheme: ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.dark,
              primary: seedColor,
              secondary: AppColors.amberLight,
              surface: AppColors.slate800,
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.xlR,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1),
              ),
              color: AppColors.slate800,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.slate900,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: AppRadius.mdR,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdR,
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdR,
                borderSide: BorderSide(color: seedColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdR,
                borderSide: const BorderSide(color: AppColors.danger, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdR,
                borderSide: const BorderSide(color: AppColors.danger, width: 2),
              ),
              labelStyle: AppType.body(context, color: Colors.grey, weight: FontWeight.w500),
              floatingLabelStyle: AppType.body(context, color: seedColor, weight: FontWeight.w700),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdR),
                textStyle: AppType.body(context, weight: FontWeight.w700, fontSize: 16, letterSpacing: 0.2),
              ),
            ),
            appBarTheme: AppBarTheme(
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              titleTextStyle: AppType.display(
                context,
                color: Colors.white,
                weight: FontWeight.w600,
                fontSize: 20,
                letterSpacing: -0.4,
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
          ),
          home: const StartupGate(),
        );
      },
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final Future<Widget> _initialScreenFuture = _getInitialScreen();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return snapshot.data!;
        }

        if (snapshot.hasError) {
          return const RoleSelectionScreen();
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
