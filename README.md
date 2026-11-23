# Campus Register

Campus Register is a Flutter-based attendance platform for schools and institutions that need secure, location-aware, and offline-capable class check-ins.

## What it does

The app helps organizations manage attendance with a stronger integrity model than a simple tap-to-check-in experience.

It combines:

- real-time classroom timetable matching,
- geofenced venue validation,
- altitude-based floor checks,
- biometric verification,
- offline-first local storage,
- cloud sync to Supabase and reporting to Google Sheets.

## Why it stands out

The core differentiator is the app’s attendance assurance approach:

- a student must be in the correct place,
- during the correct time window,
- and verified through biometrics,
- before attendance is recorded.

This makes the system more resistant to casual fraud and buddy check-ins.

## Main user roles

- Student: check in securely, view attendance history, and see course schedules.
- Teacher: manage courses, students, venues, timetables, and reporting.
- Admin: oversee approvals, analytics, members, and organization-level operations.

## Technical highlights

- Flutter + Dart for the mobile app
- SQLite for fast offline persistence
- Supabase for cloud-backed shared data
- Google Maps and geolocation for venue-based validation
- biometric authentication via native device APIs
- Google Sheets automation for attendance export and visibility

## Documentation

- Detailed technical guide: [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md)
- Security model: [security_model.md](security_model.md)
- Product overview notes: [about.md](about.md)

## Getting started

1. Install Flutter and the required SDK tools.
2. Run:
   - flutter pub get
   - flutter run
3. Grant the required device permissions for location and biometrics.

## Bottom line

Campus Register is more than an attendance tracker. It is a practical, real-world attendance integrity system designed for modern campus operations.
