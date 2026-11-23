import 'package:flutter/foundation.dart';

/// Enables the developer sign-in shortcuts, which skip all authentication. They
/// exist only in debug builds made with `--dart-define=DEV_BYPASS=true`.
const bool devBypassEnabled =
    kDebugMode && bool.fromEnvironment('DEV_BYPASS');
