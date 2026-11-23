import 'package:campus_register/role_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('role selection builds at phone size', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: RoleSelectionScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Campus Register'), findsOneWidget);
    expect(find.text('VOLUMETRIC 3D TRACKING ENABLED'), findsOneWidget);
    expect(find.text("I'm an Employee/Educator/Student"), findsOneWidget);
    expect(find.text("I'm a Student"), findsOneWidget);
  });
}
