import 'package:safe_device/safe_device.dart';
class MockLocationChecker {
  static Future<bool> isMockLocation() async {
    try {
      // Kiểm tra xem mock location có được bật không
      bool isMock = await SafeDevice.isMockLocation;
      print("Is mock location enabled or app detected: $isMock");
      return isMock ?? false;
    } catch (e) {
      print("Error checking mock location: $e");
      return false;
    }
  }
}

