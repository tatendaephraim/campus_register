#!/bin/bash
# This script scaffolds the new, role-based application architecture.
# Run from the project root directory.

echo "🚀 Scaffolding new application structure..."

# Core directories
mkdir -p lib/src/core
mkdir -p lib/src/core/api
mkdir -p lib/src/core/database
mkdir -p lib/src/core/models
mkdir -p lib/src/core/services
mkdir -p lib/src/core/utils

# Feature directories (Teacher)
mkdir -p lib/src/features/teacher/auth
mkdir -p lib/src/features/teacher/course_management/ui
mkdir -p lib/src/features/teacher/course_management/provider
mkdir -p lib/src/features/teacher/student_management/ui
mkdir -p lib/src/features/teacher/dashboard/ui

# Feature directories (Student)
mkdir -p lib/src/features/student/auth
mkdir -p lib/src/features/student/attendance_viewer/ui
mkdir -p lib/src/features/student/check_in/ui

# Create placeholder files
touch lib/src/core/database/database_schema.dart
touch lib/src/core/models/teacher.dart
touch lib/src/core/models/student.dart
touch lib/src/core/models/course.dart
touch lib/src/core/models/timetable.dart
touch lib/src/core/models/attendance_record.dart
touch lib/src/core/services/google_auth_service.dart
touch lib/src/core/services/google_sheets_automation_service.dart
touch lib/src/core/services/location_service.dart
touch lib/src/core/services/timetable_service.dart

touch lib/src/features/teacher/auth/ui/teacher_login_screen.dart
touch lib/src/features/teacher/course_management/ui/create_course_screen.dart
touch lib/src/features/teacher/course_management/ui/set_timetable_screen.dart
touch lib/src/features/teacher/student_management/ui/add_student_screen.dart
touch lib/src/features/teacher/dashboard/ui/teacher_dashboard_screen.dart

touch lib/src/features/student/auth/ui/student_registration_screen.dart
touch lib/src/features/student/attendance_viewer/ui/student_dashboard_screen.dart
touch lib/src/features/student/check_in/ui/check_in_screen.dart

# Main entry points
touch lib/main.dart

echo "✅ New application structure created successfully."