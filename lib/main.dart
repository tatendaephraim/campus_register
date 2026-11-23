import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/attendance_provider.dart';
import 'ui/dashboard/attendance_dashboard.dart';
import 'ui/enrolment/enrolment_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(
    // Riverpod retries failed providers by default. A corrupt log does not get
    // better by itself, so show the error instead.
    ProviderScope(retry: (_, _) => null, child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Register',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      home: const _Home(),
    );
  }
}

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(attendanceProvider)) {
      AsyncValue(:final value?) =>
        value.profile == null
            ? const EnrolmentScreen()
            : const AttendanceDashboard(),
      AsyncValue(:final error?) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Campus Register cannot start.\n\n$error\n\n'
              'Contact your administrator. Signing is disabled to protect the '
              'existing records.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
