# campus_register

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Development vs Production Configuration Notes

### Device Lock / Hardware Binding Bypass
- **Development Behavior (Current)**: A bypass confirmation dialog is active in `lib/teacher_login_screen.dart`. Authenticated users who log in on a new device or emulator will be prompted to automatically rebind their account to the current device.
- **Production Requirement**: For live production deployment, the re-linking bypass prompt should be disabled. Hardware devices must remain strictly locked to user profiles. Any device re-linking must be executed exclusively by an Organization Administrator from the admin panel.
