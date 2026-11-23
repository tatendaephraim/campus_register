// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:campus_register/main.dart';
import 'package:campus_register/role_selection_screen.dart';

void main() {
  testWidgets('App starts on RoleSelectionScreen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CampusRegisterApp(
      initialScreen: RoleSelectionScreen(),
    ));

    // Verify that the role selection screen is shown.
    expect(find.text('Campus Register'), findsOneWidget);
    expect(find.text("I'm a Teacher"), findsOneWidget);
    expect(find.text("I'm a Student"), findsOneWidget);
  });
}
