import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling app permissions.
/// Requests permissions on first app launch to avoid interrupting call flow.
class PermissionService {
  static const String _micPermissionRequestedKey = 'mic_permission_requested';

  /// Check if this is the first time we should request permissions
  static Future<bool> shouldRequestMicrophonePermission() async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey(_micPermissionRequestedKey);
  }

  /// Request microphone permission and mark as requested
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();

    // Mark as requested regardless of result
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_micPermissionRequestedKey, true);

    debugPrint('[PermissionService] Microphone permission: $status');
    return status.isGranted;
  }

  /// Check if microphone permission is currently granted
  static Future<bool> isMicrophonePermissionGranted() async {
    return await Permission.microphone.isGranted;
  }

  /// Open app settings for user to manually grant permission
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
