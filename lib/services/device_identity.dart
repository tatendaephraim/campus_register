import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The identifier a profile is bound to.
///
/// On Android this is `ANDROID_ID`, which is unique to the phone, user and app
/// signing key. It replaces `AndroidDeviceInfo.id`, which is the *build number*:
/// every phone of one model on the same OS version shares it, and it changes
/// with each system update.
class DeviceIdentity {
  static const _channel = MethodChannel('campus_register/device');

  /// Returns null when the device cannot be identified. Callers must treat that
  /// as a failure, not as a match.
  static Future<String?> current() async {
    try {
      if (Platform.isAndroid) {
        final id = await _channel.invokeMethod<String>('androidId');
        return id == null || id.isEmpty ? null : id;
      }
      if (Platform.isIOS) {
        return (await DeviceInfoPlugin().iosInfo).identifierForVendor;
      }
    } catch (e) {
      debugPrint('Device identity unavailable: $e');
    }
    return null;
  }
}
