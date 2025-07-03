import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Request camera permission for video calls
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }

  /// Request microphone permission for audio/video calls
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  /// Request both camera and microphone permissions
  static Future<Map<Permission, PermissionStatus>>
      requestCallPermissions() async {
    return await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  /// Check if camera permission is granted
  static Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }

  /// Check if microphone permission is granted
  static Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Check if both call permissions are granted
  static Future<bool> hasCallPermissions() async {
    final camera = await Permission.camera.isGranted;
    final microphone = await Permission.microphone.isGranted;
    return camera && microphone;
  }

  /// Open app settings if permissions are permanently denied
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
