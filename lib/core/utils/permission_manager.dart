import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'logger.dart';

class PermissionManager {
  Future<bool> requestLocationPermission() async {
    LocationPermission permission;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Consider guiding the user to app settings here,
      // e.g., by calling Geolocator.openAppSettings() after a dialog.
      return false;
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      return true;
    }

    return false;
  }

  Future<bool> isLocationPermissionGranted() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }
}