import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:emulator_checker/emulator_checker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:play_integrity_flutter/models/play_integrity_model.dart';
import 'package:play_integrity_flutter/play_integrity_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../../core/utils/logger.dart'; // Giả định bạn có logger này
import '../../../../core/utils/ultil.dart'; // Giả định bạn có Util này

class DeviceSensorService {
  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Connectivity _connectivity = Connectivity();
  final PlayIntegrityFlutter _playIntegrityFlutterApi = PlayIntegrityFlutter();
  static const Duration _timeOut = Duration(seconds: 15);
  static const Duration _shortSensorTimeout = Duration(seconds: 2);
  StreamSubscription<Position>? _positionSubscription;
  bool _isOperationCancelled = false; // Đổi tên để rõ ràng hơn cho từng hoạt động
  bool _isCollecting = false;

  void _logCheckDetail(
    String checkName,
    Map<String, List<String>> logMap,
    String message, {
    dynamic value,
    String status = "INFO",
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry =
        "$timestamp [$status] $checkName: $message" + (value != null ? " | Value: $value" : "");
    appLogger.i(logEntry);
    if (!logMap.containsKey(checkName)) {
      logMap[checkName] = [];
    }
    logMap[checkName]!.add(logEntry);
  }

  // Future<void> cancelExistingSubscription(Map<String, List<String>> logMap, String parentCheckName) async {
  //   if (_positionSubscription != null) {
  //     _logCheckDetail(parentCheckName, logMap, "Hủy subscription GPS hiện tại trước khi tạo mới.", status: "INFO_CLEANUP");
  //     try {
  //       _positionSubscription?.pause(); // Pause trước khi cancel có thể giúp một số trường hợp
  //       await _positionSubscription?.cancel();
  //       _positionSubscription = null;
  //       // _isOperationCancelled nên được quản lý bởi logic của hàm gọi, không phải ở đây.
  //       // Hoặc nếu đây là một hành động hủy toàn cục, thì có thể set.
  //       // Tuy nhiên, logic hiện tại là _isOperationCancelled được reset mỗi lần collect.
  //       _logCheckDetail(parentCheckName, logMap, "Subscription GPS đã được hủy thành công.", status: "INFO_CLEANUP");
  //       await Future.delayed(const Duration(milliseconds: 100)); // Giảm delay
  //     } catch (e) {
  //       _logCheckDetail(parentCheckName, logMap, "Lỗi khi hủy subscription GPS hiện tại", value: e.toString(), status: "ERROR_CLEANUP");
  //     }
  //   }
  // }

  // Future<void> forceCancelAllSubscriptions(Map<String, List<String>> logMap, String parentCheckName) async {
  //   _logCheckDetail(parentCheckName, logMap, "Bắt đầu buộc hủy tất cả subscription GPS.", status: "INFO_CLEANUP");
  //   int retries = 3; // Giảm số lần thử lại
  //   while (_positionSubscription != null && retries > 0) {
  //     try {
  //       _positionSubscription?.pause();
  //       await _positionSubscription?.cancel();
  //       _positionSubscription = null;
  //       _logCheckDetail(parentCheckName, logMap, "Buộc hủy subscription GPS thành công (thử $retries).", status: "INFO_CLEANUP");
  //       await Future.delayed(const Duration(milliseconds: 100)); // Giảm delay
  //       break; // Thoát vòng lặp khi thành công
  //     } catch (e) {
  //       _logCheckDetail(parentCheckName, logMap, "Lỗi khi buộc hủy subscription GPS, thử lại ($retries)", value: e.toString(), status: "ERROR_CLEANUP");
  //       retries--;
  //       await Future.delayed(const Duration(milliseconds: 100)); // Giảm delay
  //     }
  //   }
  //   if (_positionSubscription != null) {
  //     _logCheckDetail(parentCheckName, logMap, "Không thể buộc hủy subscription GPS sau nhiều lần thử.", status: "ERROR_CLEANUP");
  //     _positionSubscription = null; // Dù sao cũng set null
  //   }
  //   _isCollecting = false; // Quan trọng: đặt lại trạng thái thu thập
  //   _isOperationCancelled = true; // Đánh dấu hoạt động đã bị hủy
  // }

  // Future<void> dispose() async {
  //   _logCheckDetail("DISPOSE", {}, "Bắt đầu dispose DeviceSensorService và hủy subscriptions.", status: "INFO_LIFECYCLE");
  //   await forceCancelAllSubscriptions({}, "DISPOSE");
  //   _logCheckDetail("DISPOSE", {}, "DeviceSensorService disposed.", status: "INFO_LIFECYCLE");
  // }

  // Future<Map<String, dynamic>> checkRootJailbreak(Map<String, List<String>> logMap) async {
  //   const String checkName = "B1.1_RootJailbreak";
  //   _logCheckDetail(checkName, logMap, "Bắt đầu kiểm tra.");
  //   bool isCompromised = false;
  //   String details = "";
  //   try {
  //     isCompromised = await FlutterJailbreakDetection.jailbroken;
  //     details = "FlutterJailbreakDetection.jailbroken(kiểm tra thiết bị có bị can thiệp không): $isCompromised";
  //     _logCheckDetail(checkName, logMap, details, value: isCompromised);
  //     if (isCompromised) {
  //       _logCheckDetail(checkName, logMap, "PHÁT HIỆN - Thiết bị Rooted/Jailbroken.", status: "WARN");
  //     }
  //   } catch (e) {
  //     details = "Lỗi khi kiểm tra Root/Jailbreak: $e";
  //     _logCheckDetail(checkName, logMap, details, status: "ERROR");
  //     appLogger.e("$checkName Error", error: e);
  //   }
  //   return {'isCompromised': isCompromised, 'details': details};
  // }

  // Future<Map<String, dynamic>> checkEmulator(Map<String, List<String>> logMap) async {
  //   const String checkName = "B1.4_Check máy ảo";
  //   _logCheckDetail(checkName, logMap, "Bắt đầu kiểm tra.");
  //   bool isEmulator = false;
  //   String details = "";
  //   try {
  //     isEmulator = await EmulatorChecker.isEmulator();
  //     details = "EmulatorCheck.isEmulator(): $isEmulator";
  //     _logCheckDetail(checkName, logMap, details, value: isEmulator);

  //     if (!isEmulator && Platform.isAndroid) {
  //       AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
  //       if (!androidInfo.isPhysicalDevice) isEmulator = true;
  //       _logCheckDetail(
  //         checkName,
  //         logMap,
  //         "Android isPhysicalDevice: ${androidInfo.isPhysicalDevice}",
  //         value: androidInfo.isPhysicalDevice,
  //       );
  //     } else if (!isEmulator && Platform.isIOS) {
  //       IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
  //       if (!iosInfo.isPhysicalDevice) isEmulator = true;
  //       _logCheckDetail(
  //         checkName,
  //         logMap,
  //         "iOS isPhysicalDevice: ${iosInfo.isPhysicalDevice}",
  //         value: iosInfo.isPhysicalDevice,
  //       );
  //     }

  //     if (isEmulator) {
  //       _logCheckDetail(checkName, logMap, "PHÁT HIỆN - Thiết bị là giả lập.", status: "WARN");
  //     }
  //   } catch (e) {
  //     details = "Lỗi khi kiểm tra Giả lập: $e";
  //     _logCheckDetail(checkName, logMap, details, status: "ERROR");
  //     appLogger.e("$checkName Error", error: e);
  //   }
  //   return {'isEmulator': isEmulator, 'details': details};
  // }

  // Future<Map<String, dynamic>> checkDeviceIntegrity(Map<String, List<String>> logMap) async {
  //   const String checkName = "B1.5_kiểm tra thiết bị bằng API Play Integrity của google(Android)";
  //   _logCheckDetail(checkName, logMap, "Bắt đầu kiểm tra.");
  //   bool integrityPass = false;
  //   String platformDetails = "";
  //   String details = "";

  //   try {
  //     if (Platform.isAndroid) {
  //       platformDetails = "Play Integrity (Android)";
  //       _logCheckDetail(checkName, logMap, "Kiểm tra trên $platformDetails.");
  //       try {
  //         final String nonce = DateTime.now().millisecondsSinceEpoch.toString() + math.Random().nextInt(999999).toString();
  //         // QUAN TRỌNG: Thay thế bằng key thực tế của bạn từ Google Play Console.
  //         // Đây chỉ là giá trị giữ chỗ.
  //         const String decryptionKey = "YOUR_ACTUAL_DECRYPTION_KEY_FROM_PLAY_CONSOLE";
  //         const String verificationKey = "YOUR_ACTUAL_VERIFICATION_KEY_FROM_PLAY_CONSOLE";

  //         if (decryptionKey == "YOUR_ACTUAL_DECRYPTION_KEY_FROM_PLAY_CONSOLE" || verificationKey == "YOUR_ACTUAL_VERIFICATION_KEY_FROM_PLAY_CONSOLE") {
  //           _logCheckDetail(
  //             checkName,
  //             logMap,
  //             "Play Integrity: Cần cung cấp Decryption Key và Verification Key từ Play Console. Bỏ qua kiểm tra.",
  //             status: "CONFIG_REQUIRED",
  //           );
  //           // Quyết định xem có nên coi đây là pass hay fail. Tạm thời coi là pass để không chặn chức năng.
  //           integrityPass = true; // Hoặc false nếu yêu cầu key là bắt buộc
  //            details = "Play Integrity keys not configured.";
  //         } else {
  //           _logCheckDetail(checkName, logMap, "Gọi _playIntegrityFlutterApi.playIntegrityPayload với nonce: $nonce");
  //           final PlayIntegrity integrityPayload = await _playIntegrityFlutterApi.playIntegrityPayload(nonce, decryptionKey, verificationKey);
  //           details = "Received Play Integrity Payload. ";
  //           _logCheckDetail(checkName, logMap, "Device Integrity Verdicts", value: integrityPayload.deviceIntegrity?.deviceRecognitionVerdict);
  //           _logCheckDetail(checkName, logMap, "App Integrity Verdict", value: integrityPayload.appIntegrity?.appRecognitionVerdict);
  //           _logCheckDetail(checkName, logMap, "Nonce in payload", value: integrityPayload.requestDetails?.nonce);

  //           final deviceVerdicts = integrityPayload.deviceIntegrity?.deviceRecognitionVerdict;
  //           if (deviceVerdicts != null && (deviceVerdicts.contains("MEETS_DEVICE_INTEGRITY") || deviceVerdicts.contains("MEETS_STRONG_INTEGRITY"))) {
  //             integrityPass = true;
  //             details += "Device meets required integrity level.";
  //             if (integrityPayload.appIntegrity?.appRecognitionVerdict != "PLAY_RECOGNIZED" && integrityPayload.appIntegrity?.appRecognitionVerdict != "UNRECOGNIZED_VERSION") {
  //               integrityPass = false; // App không đạt yêu cầu có thể là một vấn đề.
  //               details += " | AppIntegrity không đạt yêu cầu: ${integrityPayload.appIntegrity?.appRecognitionVerdict}.";
  //               _logCheckDetail(
  //                 checkName,
  //                 logMap,
  //                 "AppIntegrity không đạt yêu cầu: ${integrityPayload.appIntegrity?.appRecognitionVerdict}.",
  //                 value: integrityPayload.appIntegrity?.appRecognitionVerdict,
  //                 status: "WARN_SUB_CHECK",
  //               );
  //             }
  //             if (integrityPayload.requestDetails?.nonce != nonce) {
  //               integrityPass = false;
  //               details += " | Nonce mismatch!";
  //               _logCheckDetail(checkName, logMap, "Nonce mismatch!", status: "ERROR_SUB_CHECK");
  //             }
  //           } else {
  //             integrityPass = false;
  //             details += "Device does not meet required integrity level: ${deviceVerdicts?.join(', ')}";
  //           }
  //         }
  //       } catch (e) {
  //         integrityPass = false;
  //         details = "Lỗi khi xử lý Play Integrity: $e";
  //         _logCheckDetail(checkName, logMap, details, status: "ERROR");
  //         appLogger.e("$checkName - Play Integrity Processing Error", error: e);
  //       }
  //     } else if (Platform.isIOS) {
  //       platformDetails = "DeviceCheck (iOS)";
  //       details = "DeviceCheck logic for iOS needs a specific package or platform channel implementation. Placeholder: Assuming pass.";
  //       _logCheckDetail(checkName, logMap, "Kiểm tra trên $platformDetails. $details", status: "INFO_TODO");
  //       integrityPass = true; // Giả định pass cho iOS vì chưa implement
  //     } else {
  //       platformDetails = "Nền tảng không xác định";
  //       details = "Không hỗ trợ kiểm tra tính toàn vẹn trên nền tảng này.";
  //       _logCheckDetail(checkName, logMap, details, status: "INFO");
  //       integrityPass = true; // Giả định pass cho nền tảng không xác định
  //     }

  //     if (!integrityPass) {
  //       _logCheckDetail(checkName, logMap, "KẾT LUẬN: Xác thực thiết bị ($platformDetails) THẤT BẠI. $details", status: "WARN");
  //     } else {
  //       _logCheckDetail(checkName, logMap, "KẾT LUẬN: Xác thực thiết bị ($platformDetails) THÀNH CÔNG.", status: "PASS");
  //     }
  //   } catch (e) {
  //     details = "Lỗi khi kiểm tra tính toàn vẹn thiết bị: $e";
  //     _logCheckDetail(checkName, logMap, details, status: "ERROR");
  //     appLogger.e("$checkName Error", error: e);
  //   }
  //   return {'integrityPass': integrityPass, 'details': details};
  // }

  // Future<Map<String, dynamic>> checkLocation(Map<String, List<String>> logMap) async {
  //   const String checkName = "B1.7_Location";
  //   _logCheckDetail(checkName, logMap, "Bắt đầu kiểm tra vị trí (B1.7).");
  //   bool isMockLocation = false;
  //   String details = "";
  //   try {
  //     final LocationPermission permission = await _geolocator.checkPermission();
  //     if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
  //       details = "Không có quyền truy cập vị trí.";
  //       _logCheckDetail(checkName, logMap, details, status: "WARN");
  //     } else {
  //       final Position? position = await _getSingleGpsPosition(_timeOut, logMap, checkName);
  //       if (position == null) {
  //         details = "Không thể lấy vị trí GPS.";
  //         _logCheckDetail(checkName, logMap, details, status: "WARN");
  //       } else if (position.latitude == 0.0 && position.longitude == 0.0) {
  //         isMockLocation = true; // Coi (0,0) là khả nghi
  //         details = "Địa chỉ GPS giả hoặc không xác định (0,0).";
  //         _logCheckDetail(checkName, logMap, details, status: "WARN");
  //       } else {
  //         details = "Vị trí thực tế (B1.7): Lat: ${position.latitude}, Lng: ${position.longitude}, Mock: ${position.isMocked}";
  //         _logCheckDetail(checkName, logMap, details);
  //         if (Platform.isAndroid && position.isMocked) {
  //           isMockLocation = true;
  //           _logCheckDetail(checkName, logMap, "PHÁT HIỆN (B1.7) - Vị trí là giả mạo (isMocked: true).", status: "WARN");
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     details = "Lỗi khi kiểm tra vị trí (B1.7): $e";
  //     _logCheckDetail(checkName, logMap, details, status: "ERROR");
  //     appLogger.e("$checkName Error", error: e);
  //   }
  //   return {'isMockLocation': isMockLocation, 'details': details};
  // }

  // Future<Map<String, dynamic>> checkIsMockLocation(Map<String, List<String>> logMap) async {
  //   const String checkName = "B2.1_IsMockLocation";
  //   _logCheckDetail(checkName, logMap, "Bắt đầu kiểm tra isMocked từ GPS hiện tại.");
  //   int score = 0;

  //   if (!Platform.isAndroid) {
  //     _logCheckDetail(checkName, logMap, "Bỏ qua do không phải Android. Điểm nghi ngờ: 0.");
  //     return {'score': score};
  //   }

  //   final Position? position = await _getSingleGpsPosition(_timeOut, logMap, checkName);

  //   if (position == null) {
  //     _logCheckDetail(checkName, logMap, "Không thể lấy dữ liệu GPS để kiểm tra isMocked. Điểm nghi ngờ: 0.", status: "WARN");
  //     return {'score': score};
  //   }

  //   if (position.isMocked) {
  //     score = 20;
  //     _logCheckDetail(
  //       checkName,
  //       logMap,
  //       "PHÁT HIỆN isMockLocation=true tại ${position.timestamp} (Lat: ${position.latitude}, Lon: ${position.longitude}). Điểm nghi ngờ: 20.",
  //       value: 20,
  //       status: "WARN_SCORE",
  //     );
  //   } else {
  //     _logCheckDetail(checkName, logMap, "Không phát hiện isMockLocation=true trong dữ liệu GPS. Điểm nghi ngờ: 0.", value: 0);
  //   }
  //   return {'score': score};
  // }
  // Future<LocationPermission?> checkAndRequestLocationPermission(
  //   Map<String, List<String>> logMap,
  //   String parentCheckName,
  // ) async {
  //   LocationPermission permission = await Geolocator.checkPermission();

  //   if (permission == LocationPermission.denied) {
  //     permission = await Geolocator.requestPermission();
  //     if (permission == LocationPermission.denied) {
  //       _logCheckDetail(parentCheckName, logMap, "Người dùng từ chối quyền vị trí.", status: "WARN_PERMISSION");
  //       return null;
  //     }
  //   }

  //   if (permission == LocationPermission.deniedForever) {
  //     _logCheckDetail(parentCheckName, logMap, "Người dùng đã từ chối quyền vĩnh viễn. Không thể xin lại bằng code.", status: "ERROR_PERMISSION_FOREVER");
  //     return null;
  //   }

  //   return permission;
  // }

  // Future<Position?> _getSingleGpsPosition(
  //   Duration timeout,
  //   Map<String, List<String>> logMap,
  //   String parentCheckName, {
  //   int maxRetry = 2,
  //   Duration retryDelay = const Duration(milliseconds: 500),
  // }) async {
  //   for (int attempt = 0; attempt <= maxRetry; attempt++) {
  //     try {
  //       LocationPermission? permission = await checkAndRequestLocationPermission(logMap, parentCheckName);
  //           if (permission == null) {
  //             return null;
  //           }

  //       final position = await _geolocator.getCurrentPosition(
  //         locationSettings: const LocationSettings(
  //           accuracy: LocationAccuracy.medium,
  //           distanceFilter: 0,
  //         ),
  //       ).timeout(timeout, onTimeout: () {
  //         _logCheckDetail(parentCheckName, logMap, "Timeout lần $attempt khi lấy GPS.", status: "WARN_SUB_GPS_TIMEOUT");
  //         throw TimeoutException("Timeout lần $attempt khi lấy GPS");
  //       });

  //       _logCheckDetail(parentCheckName, logMap, "Đã lấy GPS thành công lần $attempt: isMocked=${position.isMocked}.", value: position.toString());
  //       return position;
  //     } catch (e) {
  //       _logCheckDetail(parentCheckName, logMap, "Lỗi lần $attempt khi lấy GPS: $e", status: "ERROR_SUB_GPS");
  //       if (attempt < maxRetry) {
  //         await Future.delayed(retryDelay);
  //       }
  //     }
  //   }

  //   _logCheckDetail(parentCheckName, logMap, "Không thể lấy được GPS sau $maxRetry lần thử.", status: "ERROR_FINAL_SUB_GPS");
  //   return null;
  // }


  // Future<AccelerometerEvent?> _getSingleAccelerometerEvent(Duration timeout, Map<String, List<String>> logMap, String parentCheckName) async {
  //   try {
  //     if (!await accelerometerEvents.isEmpty) { // Kiểm tra stream có event không
  //       return await accelerometerEvents.first.timeout(timeout, onTimeout: (){
  //         _logCheckDetail(parentCheckName, logMap, "Timeout khi lấy 1 điểm Accelerometer.", status: "WARN_SUB_ACCEL_TIMEOUT");
  //         throw TimeoutException("Timed out waiting for Accelerometer event");
  //       });
  //     } else {
  //       _logCheckDetail(parentCheckName, logMap, "Stream Accelerometer không có dữ liệu ban đầu.", status: "WARN_SUB_ACCEL_NODATA");
  //       return null;
  //     }
  //   } catch (e) {
  //     _logCheckDetail(parentCheckName, logMap, "Lỗi khi lấy 1 điểm Accelerometer (có thể không được hỗ trợ hoặc lỗi)", value: e.toString(), status: "ERROR_SUB_ACCEL");
  //     return null;
  //   }
  // }

  // Future<List<Map<String, dynamic?>>> collectPairedGpsAccelData({
  //   int targetSamples = 7,
  //   Duration sampleInterval = const Duration(seconds: 15), // Hiện tại không được sử dụng để điều chỉnh tốc độ lấy mẫu
  //   Duration overallTimeout = const Duration(seconds: 50),
  //   required Map<String, List<String>> logMap,
  //   String parentCheckName = "PAIRED_GPS_ACCEL_Collection",
  // }) async {
  //   if (_isCollecting) {
  //     _logCheckDetail(parentCheckName, logMap, "Đang thu thập dữ liệu, hủy stream cũ.", status: "WARN_COLLECTION_BUSY");
  //     await forceCancelAllSubscriptions(logMap, "$parentCheckName Pre-cancel");
  //   }

  //   _isCollecting = true;
  //   _isOperationCancelled = false; // Reset cờ hủy cho hoạt động thu thập mới này
  //   List<Map<String, dynamic?>> samples = [];
  //   final stopwatch = Stopwatch()..start();
  //   final Completer<void> collectionCompleter = Completer();
  //   int collectedCount = 0;
  //   int accelFailures = 0;
  //   const int maxConsecutiveAccelFailures = 3;
  //   DateTime? lastGpsUpdateTime;

  //   _logCheckDetail(parentCheckName, logMap, "Bắt đầu thu thập cặp GPS & Accelerometer. Mục tiêu: $targetSamples, Timeout: ${overallTimeout.inSeconds}s.");

  //   // Kiểm tra quyền vị trí trước khi bắt đầu stream
  //     LocationPermission? permission = await checkAndRequestLocationPermission(logMap, parentCheckName);
  //           if (permission == null) {
  //             return samples;
  //           }


  //   try {
  //     _positionSubscription = _geolocator
  //         .getPositionStream(
  //           locationSettings: const LocationSettings(
  //             accuracy: LocationAccuracy.high,
  //             distanceFilter: 0, // Lấy tất cả các thay đổi vị trí
  //             // timeLimit không nên dùng ở đây, nó giới hạn thời gian cho MỖI event, không phải stream
  //           ),
  //         )
  //         .listen(
  //           (Position gps) async {
  //             if (collectionCompleter.isCompleted || _isOperationCancelled) {
  //               return; // Hoạt động đã hoàn tất hoặc bị hủy
  //             }

  //             final now = DateTime.now();
  //             if (lastGpsUpdateTime != null) {
  //               _logCheckDetail(parentCheckName, logMap, "Thời gian giữa các cập nhật GPS", value: "${now.difference(lastGpsUpdateTime!).inMilliseconds}ms", status: "INFO_GPS_TIMING");
  //             }
  //             lastGpsUpdateTime = now;

  //             AccelerometerEvent? accel = await _getSingleAccelerometerEvent(_shortSensorTimeout, logMap, parentCheckName);

  //             if (accel == null) {
  //               accelFailures++;
  //             } else {
  //               accelFailures = 0; // Reset khi thành công
  //             }

  //             if (accelFailures >= maxConsecutiveAccelFailures && collectedCount < targetSamples / 2) {
  //               _logCheckDetail(parentCheckName, logMap, "Gia tốc kế có thể không khả dụng hoặc liên tục lỗi ($accelFailures lần liên tiếp).", status: "WARN_ACCEL_UNAVAILABLE");
  //               // Không reset accelFailures ở đây để tránh log liên tục nếu nó thực sự hỏng
  //             }

  //             samples.add({'gps': gps, 'accel': accel});
  //             collectedCount++;

  //             _logCheckDetail(
  //               parentCheckName,
  //               logMap,
  //               "Mẫu cặp ${samples.length}/$targetSamples: " +
  //                   "GPS: (Acc:${gps.accuracy.toStringAsFixed(1)},Spd:${gps.speed.toStringAsFixed(1)}, Mock:${gps.isMocked}, Time:${gps.timestamp?.toIso8601String() ?? 'N/A'}), " +
  //                   "Accel: ${accel != null ? 'OK (X:${accel.x.toStringAsFixed(1)},Y:${accel.y.toStringAsFixed(1)},Z:${accel.z.toStringAsFixed(1)})' : 'FAIL'}",
  //             );

  //             if (collectedCount >= targetSamples) {
  //               if (!collectionCompleter.isCompleted) {
  //                 _logCheckDetail(parentCheckName, logMap, "Đạt mục tiêu $targetSamples mẫu. Hoàn tất collectionCompleter.", status: "INFO_COLLECTION_TARGET_MET");
  //                 collectionCompleter.complete(); // HOÀN THÀNH NGAY LẬP TỨC
  //               }
  //             }
  //           },
  //           onError: (e) {
  //             if (collectionCompleter.isCompleted || _isOperationCancelled) return;
  //             _logCheckDetail(parentCheckName, logMap, "Lỗi trong stream GPS", value: e.toString(), status: "ERROR_GPS_STREAM");
  //             if (!collectionCompleter.isCompleted) {
  //               collectionCompleter.completeError(e); // Hoàn thành với lỗi
  //             }
  //           },
  //           onDone: () {
  //             if (collectionCompleter.isCompleted || _isOperationCancelled) return;
  //             _logCheckDetail(parentCheckName, logMap, "Stream GPS đã hoàn tất (onDone).", status: "INFO_GPS_STREAM_DONE");
  //             if (!collectionCompleter.isCompleted) {
  //               collectionCompleter.complete(); // Stream kết thúc, hoàn thành hoạt động
  //             }
  //           },
  //           cancelOnError: true, // Tự động hủy subscription nếu có lỗi
  //         );

  //     // Đợi hoàn thành hoặc timeout
  //     await Future.any([
  //       collectionCompleter.future,
  //       Future.delayed(overallTimeout).then((_) {
  //         if (collectionCompleter.isCompleted) {
  //            _logCheckDetail(parentCheckName, logMap, "Timeout callback: nhưng collectionCompleter đã hoàn thành. Bỏ qua.", status: "DEBUG_TIMEOUT_VS_COMPLETED");
  //           return; // Đã hoàn thành, không làm gì
  //         }
  //         _logCheckDetail(parentCheckName, logMap, "Timeout toàn bộ khi thu thập cặp GPS & Accelerometer. Đã thu: $collectedCount/$targetSamples mẫu.", status: "WARN_COLLECTION_TIMEOUT");
  //         _isOperationCancelled = true; // Đánh dấu timeout xảy ra
  //         if (!collectionCompleter.isCompleted) {
  //            collectionCompleter.complete(); // Hoàn thành để giải phóng Future.any
  //         }
  //       }),
  //     ]);

  //   } catch (e) {
  //     _logCheckDetail(parentCheckName, logMap, "Lỗi chung khi thu thập cặp GPS & Accelerometer", value: e.toString(), status: "ERROR_COLLECTION_GENERAL");
  //     if (!collectionCompleter.isCompleted) {
  //        collectionCompleter.completeError(e);
  //     }
  //   } finally {
  //     _logCheckDetail(parentCheckName, logMap, "Bắt đầu cleanup cho collectPairedGpsAccelData.", status: "INFO_CLEANUP_FINALLY");
  //     // Hủy subscription nếu nó vẫn còn tồn tại và chưa bị hủy tự động (ví dụ, do timeout)
  //     // forceCancelAllSubscriptions sẽ set _isCollecting = false và _isOperationCancelled = true
  //     if (_positionSubscription != null) {
  //        await forceCancelAllSubscriptions(logMap, "$parentCheckName Finally-cancel");
  //     } else {
  //        // Nếu subscription đã là null (có thể do cancelOnError hoặc logic khác)
  //        // vẫn cần đảm bảo trạng thái _isCollecting được reset
  //        _isCollecting = false;
  //     }
  //     _isOperationCancelled = true; // Đảm bảo cờ này được set khi kết thúc

  //     stopwatch.stop();
  //     int validGpsCount = samples.where((s) => s['gps'] != null).length;
  //     int validAccelCount = samples.where((s) => s['accel'] != null).length;
  //     _logCheckDetail(parentCheckName, logMap, "Hoàn tất thu thập cặp GPS & Accelerometer. Thu được ${samples.length} cặp (GPS hợp lệ: $validGpsCount, Accel hợp lệ: $validAccelCount) trong ${stopwatch.elapsedMilliseconds}ms.");
  //   }
  //   return samples;
  // }

  // Future<List<Position>> collectGpsData({
  //   int targetSamples = 7,
  //   Duration sampleInterval = const Duration(seconds: 15), // Hiện tại không được sử dụng để điều chỉnh tốc độ lấy mẫu
  //   Duration overallTimeout = const Duration(seconds: 50),
  //   required Map<String, List<String>> logMap,
  //   String parentCheckName = "GPS_Collection_General",
  // }) async {
  //   if (_isCollecting) {
  //     _logCheckDetail(parentCheckName, logMap, "Đang thu thập dữ liệu, hủy stream cũ.", status: "WARN_COLLECTION_BUSY");
  //     await forceCancelAllSubscriptions(logMap, "$parentCheckName Pre-cancel");
  //   }

  //   _isCollecting = true;
  //   _isOperationCancelled = false; // Reset cờ hủy cho hoạt động thu thập mới này
  //   List<Position> positions = [];
  //   final stopwatch = Stopwatch()..start();
  //   final Completer<void> collectionCompleter = Completer();
  //   DateTime? lastGpsUpdateTime;

  //    // Kiểm tra quyền vị trí trước khi bắt đầu stream
  //     LocationPermission? permission = await checkAndRequestLocationPermission(logMap, parentCheckName);
  //           if (permission == null) {
  //             return positions;
  //           }

  //   _logCheckDetail(parentCheckName, logMap, "Bắt đầu thu thập dữ liệu GPS. Mục tiêu: $targetSamples mẫu, Timeout: ${overallTimeout.inSeconds}s.");

  //   try {
  //     _positionSubscription = _geolocator
  //         .getPositionStream(
  //           locationSettings: const LocationSettings(
  //             accuracy: LocationAccuracy.high,
  //             distanceFilter: 0,
  //           ),
  //         )
  //         .listen(
  //           (Position position) {
  //             if (collectionCompleter.isCompleted || _isOperationCancelled) {
  //               return;
  //             }

  //             final now = DateTime.now();
  //             if (lastGpsUpdateTime != null) {
  //               _logCheckDetail(parentCheckName, logMap, "Thời gian giữa các cập nhật GPS", value: "${now.difference(lastGpsUpdateTime!).inMilliseconds}ms", status: "INFO_GPS_TIMING");
  //             }
  //             lastGpsUpdateTime = now;

  //             positions.add(position);
  //             _logCheckDetail(
  //               parentCheckName,
  //               logMap,
  //               "Mẫu GPS ${positions.length}/$targetSamples: Lat: ${position.latitude}, Lon: ${position.longitude}, Acc: ${position.accuracy.toStringAsFixed(1)}, Spd: ${position.speed.toStringAsFixed(1)}, Mock: ${position.isMocked}, Time: ${position.timestamp?.toIso8601String() ?? 'N/A'}",
  //             );

  //             if (positions.length >= targetSamples) {
  //               if (!collectionCompleter.isCompleted) {
  //                 _logCheckDetail(parentCheckName, logMap, "Đạt mục tiêu $targetSamples mẫu. Hoàn tất collectionCompleter.", status: "INFO_COLLECTION_TARGET_MET");
  //                 collectionCompleter.complete(); // HOÀN THÀNH NGAY LẬP TỨC
  //               }
  //             }
  //           },
  //           onError: (e) {
  //             if (collectionCompleter.isCompleted || _isOperationCancelled) return;
  //             _logCheckDetail(parentCheckName, logMap, "Lỗi trong stream GPS", value: e.toString(), status: "ERROR_GPS_STREAM");
  //             if (!collectionCompleter.isCompleted) {
  //               collectionCompleter.completeError(e);
  //             }
  //           },
  //           onDone: () {
  //             if (collectionCompleter.isCompleted || _isOperationCancelled) return;
  //             _logCheckDetail(parentCheckName, logMap, "Stream GPS đã hoàn tất (onDone).", status: "INFO_GPS_STREAM_DONE");
  //             if (!collectionCompleter.isCompleted) {
  //               collectionCompleter.complete();
  //             }
  //           },
  //           cancelOnError: true,
  //         );

  //     await Future.any([
  //       collectionCompleter.future,
  //       Future.delayed(overallTimeout).then((_) {
  //         if (collectionCompleter.isCompleted) {
  //           _logCheckDetail(parentCheckName, logMap, "Timeout callback: nhưng collectionCompleter đã hoàn thành. Bỏ qua.", status: "DEBUG_TIMEOUT_VS_COMPLETED");
  //           return;
  //         }
  //         _logCheckDetail(parentCheckName, logMap, "Timeout toàn bộ khi thu thập GPS. Đã thu: ${positions.length}/$targetSamples mẫu.", status: "WARN_COLLECTION_TIMEOUT");
  //         _isOperationCancelled = true;
  //          if (!collectionCompleter.isCompleted) {
  //            collectionCompleter.complete();
  //         }
  //       }),
  //     ]);

  //   } catch (e) {
  //     _logCheckDetail(parentCheckName, logMap, "Lỗi chung khi thu thập GPS", value: e.toString(), status: "ERROR_COLLECTION_GENERAL");
  //      if (!collectionCompleter.isCompleted) {
  //        collectionCompleter.completeError(e);
  //     }
  //   } finally {
  //     _logCheckDetail(parentCheckName, logMap, "Bắt đầu cleanup cho collectGpsData.", status: "INFO_CLEANUP_FINALLY");
  //     if (_positionSubscription != null) {
  //       await forceCancelAllSubscriptions(logMap, "$parentCheckName Finally-cancel");
  //     } else {
  //        _isCollecting = false;
  //     }
  //     _isOperationCancelled = true;

  //     stopwatch.stop();
  //     _logCheckDetail(parentCheckName, logMap, "Hoàn tất thu thập dữ liệu GPS. Thu được ${positions.length} mẫu trong ${stopwatch.elapsedMilliseconds}ms.");
  //   }
  //   return positions;
  // }

  // Future<Map<String, dynamic>> checkGpsVsAccelerometerSpeed(Map<String, List<String>> logMap, List<Map<String, dynamic?>> pairedDataList) async {
  //   const String checkName = "B2.2_Check vận tốc GPS vs gia tốc kế";
  //   _logCheckDetail(checkName, logMap, "Bắt đầu kiểm tra dựa trên ${pairedDataList.length} cặp dữ liệu GPS & Gia tốc kế.");

  //   List<Position> validGpsList = pairedDataList.map((p) => p['gps'] as Position?).whereNotNull().toList();
  //   List<AccelerometerEvent> validAccelList = pairedDataList.map((p) => p['accel'] as AccelerometerEvent?).whereNotNull().toList();

  //   if (validGpsList.isEmpty) {
  //     _logCheckDetail(checkName, logMap, "Không có dữ liệu GPS hợp lệ trong cặp dữ liệu. Điểm nghi ngờ: 0.", status: "WARN_NODATA");
  //     return {'score': 0};
  //   }

  //   if (validAccelList.isEmpty || (validAccelList.length < pairedDataList.length * 0.3 && validAccelList.length < 2)) { // Điều chỉnh ngưỡng
  //     _logCheckDetail(checkName, logMap, "Dữ liệu gia tốc kế không đáng tin cậy hoặc không khả dụng (chỉ ${validAccelList.length} mẫu hợp lệ). Bỏ qua kiểm tra B2.2. Điểm nghi ngờ: 0.", status: "WARN_ACCEL_UNRELIABLE_SKIP");
  //     return {'score': 0};
  //   }

  //   List<double> accuracies = validGpsList.where((p) => p.accuracy > 0).map((p) => p.accuracy).toList();
  //   double accuracyAVG = accuracies.isEmpty ? -1.0 : accuracies.average;
  //   bool isAccuracyWeak = accuracyAVG == -1 ? true : (accuracyAVG > 35.0);
  //   _logCheckDetail(checkName, logMap, "Độ chính xác GPS trung bình từ cặp dữ liệu: ${accuracyAVG.toStringAsFixed(1)}m");
  //   if (isAccuracyWeak) _logCheckDetail(checkName, logMap, "GPS yếu dựa trên độ chính xác trung bình.");

  //   List<double> deviationScores = [];

  //   for (int i = 0; i < pairedDataList.length; i++) {
  //     final position = pairedDataList[i]['gps'] as Position?;
  //     final accel = pairedDataList[i]['accel'] as AccelerometerEvent?;

  //     // _logCheckDetail(checkName, logMap, "🔁 Cặp $i"); // Log này có thể quá nhiều, cân nhắc bỏ

  //     if (position == null || accel == null) {
  //       _logCheckDetail(checkName, logMap, "Dữ liệu không hợp lệ cho cặp $i (GPS: ${position != null}, Accel: ${accel != null}) - Bỏ qua cặp này.", status: "DEBUG_PAIR_INVALID");
  //       continue;
  //     }

  //     double gpsSpeed = position.speed; // m/s
  //     // Tính độ lớn vector gia tốc không bao gồm trọng lực (gần đúng)
  //     // Giả sử Z là trục hướng lên/xuống song song với trọng lực
  //     // double accelMagnitudeHorizontal = math.sqrt(math.pow(accel.x, 2) + math.pow(accel.y, 2));
  //     // Thay đổi độ lớn gia tốc so với trạng thái nghỉ (chỉ có trọng lực ~9.8 m/s^2)
  //     double magnitude = math.sqrt(math.pow(accel.x, 2) + math.pow(accel.y, 2) + math.pow(accel.z, 2));
  //     double deltaAccel = (magnitude - 9.8).abs(); // Độ thay đổi so với gia tốc trọng trường


  //     _logCheckDetail(checkName, logMap, "Cặp $i: GPS speed: ${gpsSpeed.toStringAsFixed(2)} m/s, Accel Mag: ${magnitude.toStringAsFixed(2)}, Delta Accel: ${deltaAccel.toStringAsFixed(2)} m/s^2", status: "DEBUG_PAIR_DATA");

  //     double deviationScore = 0;
  //     // Trường hợp 1: GPS báo tốc độ cao nhưng gia tốc kế không ghi nhận thay đổi đáng kể (có thể đứng yên mà GPS nhảy)
  //     if (gpsSpeed > 10 && deltaAccel < 0.3) deviationScore = 5.0;      // Rất đáng ngờ: 36km/h, gần như không gia tốc
  //     else if (gpsSpeed > 6 && deltaAccel < 0.4) deviationScore = 4.0;   // Khá đáng ngờ: ~21km/h
  //     else if (gpsSpeed > 3 && deltaAccel < 0.5) deviationScore = 3.0;   // Đáng ngờ: ~10km/h
  //     else if (gpsSpeed > 2 && deltaAccel < 0.7) deviationScore = 2.0;   // Hơi đáng ngờ: ~7km/h
  //     else if (gpsSpeed > 1 && deltaAccel < 1.0) deviationScore = 1.0;   // Ít đáng ngờ: ~3.6km/h

  //     // Trường hợp 2: GPS báo đứng yên/tốc độ thấp nhưng gia tốc kế ghi nhận thay đổi lớn (có thể đang di chuyển nhưng GPS bị kẹt)
  //     // Điều kiện !isAccuracyWeak quan trọng để tránh phạt khi GPS kém chính xác và có thể nhảy lung tung khi đứng yên.
  //     else if (gpsSpeed < 1.0 && deltaAccel > 4.0 && !isAccuracyWeak) deviationScore = 3.0; // Đứng yên GPS, gia tốc lớn
  //     else if (gpsSpeed < 1.5 && deltaAccel > 3.5 && !isAccuracyWeak) deviationScore = 2.0;
  //     else if (gpsSpeed < 2.0 && deltaAccel > 2.5 && !isAccuracyWeak) deviationScore = 1.0;


  //     if (deviationScore > 0) {
  //        _logCheckDetail(checkName, logMap, "Điểm sai lệch cho cặp $i: $deviationScore", status: "DEBUG_DEVIATION_SCORE");
  //     }
  //     deviationScores.add(deviationScore);
  //   }

  //   if (deviationScores.isEmpty) {
  //     _logCheckDetail(checkName, logMap, "Không có cặp dữ liệu nào hợp lệ để tính điểm. Điểm nghi ngờ: 0.", status: "WARN_NO_VALID_PAIRS");
  //     return {'score': 0};
  //   }

  //   // Tính điểm cuối dựa trên số lần có deviation score cao, hoặc trung bình
  //   // Ở đây dùng trung bình nhưng có thể thay đổi logic
  //   double avgDeviation = deviationScores.average;
  //   int finalScore = 0;
  //   if (avgDeviation >= 3) finalScore = 4; // Trung bình sai lệch cao
  //   else if (avgDeviation >= 1.5) finalScore = 2; // Trung bình sai lệch vừa
  //   else if (avgDeviation > 0.5) finalScore = 1;  // Trung bình sai lệch thấp

  //   _logCheckDetail(checkName, logMap, "✅ Điểm cuối: $finalScore (trung bình độ sai lệch: ${avgDeviation.toStringAsFixed(2)}, số cặp: ${deviationScores.length})", status: finalScore > 0 ? "WARN_SCORE" : "OK");
  //   return {'score': finalScore};
  // }


  // Future<Map<String, dynamic>> checkGpsVsIpAddress(Map<String, List<String>> logMap, List<Position> gpsDataList) async {
  //   const String checkName = "B2.3_GpsVsIp";
  //   _logCheckDetail(checkName, logMap, "Bắt đầu kiểm tra dựa trên ${gpsDataList.length} điểm GPS đã thu thập.");
  //   int score = 0;

  //   if (gpsDataList.isEmpty) {
  //     _logCheckDetail(checkName, logMap, "Không có dữ liệu GPS để kiểm tra với IP. Điểm nghi ngờ: 0.", status: "WARN_NODATA");
  //     return {'score': score};
  //   }

  //   final Position? gpsPosition = gpsDataList.lastWhereOrNull((p) => p.latitude != 0.0 || p.longitude != 0.0);

  //   if (gpsPosition == null) {
  //     _logCheckDetail(checkName, logMap, "Không có dữ liệu GPS hợp lệ trong danh sách đã thu thập. Điểm nghi ngờ: 0.", status: "WARN_NO_VALID_GPS");
  //     return {'score': score};
  //   }
  //   _logCheckDetail(checkName, logMap, "Tọa độ GPS (từ điểm gần nhất hợp lệ): Lat: ${gpsPosition.latitude}, Lon: ${gpsPosition.longitude}, Time: ${gpsPosition.timestamp?.toIso8601String() ?? 'N/A'}");

  //   try {
  //     String? publicIp;
  //     try {
  //       final ipResponse = await http.get(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 5));
  //       if (ipResponse.statusCode == 200) publicIp = jsonDecode(ipResponse.body)['ip'];
  //     } catch (e) {
  //       _logCheckDetail(checkName, logMap, "Lỗi lấy IP từ ipify", value: e.toString(), status: "ERROR_SUB_IPFY");
  //     }

  //     if (publicIp == null) {
  //       _logCheckDetail(checkName, logMap, "Không lấy được IP public. Điểm nghi ngờ: 0.");
  //       return {'score': score}; // Không có IP, không thể so sánh
  //     }
  //     _logCheckDetail(checkName, logMap, "Địa chỉ IP Public", value: publicIp);

  //     String? ipLatStr, ipLonStr;
  //     double? ipLat, ipLon;
  //     try {
  //       final geoIpResponse = await http.get(Uri.parse('http://ip-api.com/json/$publicIp')).timeout(const Duration(seconds: 5));
  //       if (geoIpResponse.statusCode == 200) {
  //         final geoIpData = jsonDecode(geoIpResponse.body);
  //         if (geoIpData['status'] == 'success') {
  //           // ip-api trả về lat/lon là number, không phải string
  //           if (geoIpData['lat'] is num) ipLat = (geoIpData['lat'] as num).toDouble();
  //           if (geoIpData['lon'] is num) ipLon = (geoIpData['lon'] as num).toDouble();
  //           ipLatStr = ipLat?.toString(); // Để log
  //           ipLonStr = ipLon?.toString(); // Để log
  //         }
  //       }
  //     } catch (e) {
  //       _logCheckDetail(checkName, logMap, "Lỗi lấy vị trí từ ip-api", value: e.toString(), status: "ERROR_SUB_IPAPI");
  //     }

  //     if (ipLat == null || ipLon == null) {
  //       _logCheckDetail(checkName, logMap, "Không lấy được tọa độ từ IP. Điểm nghi ngờ: 0.");
  //       return {'score': score}; // Không có tọa độ IP, không thể so sánh
  //     }
  //     _logCheckDetail(checkName, logMap, "Tọa độ từ IP", value: "Lat: $ipLatStr, Lon: $ipLonStr");

  //     double distanceKm = Geolocator.distanceBetween(gpsPosition.latitude, gpsPosition.longitude, ipLat, ipLon) / 1000;
  //     _logCheckDetail(checkName, logMap, "Khoảng cách GPS vs IP", value: "$distanceKm km");

  //     // Điều chỉnh ngưỡng chấm điểm
  //     if (distanceKm > 200) score = 10;      // Rất xa, rất đáng ngờ (VPN/Proxy mạnh)
  //     else if (distanceKm > 50) score = 5;   // Khá xa
  //     else if (distanceKm > 15) score = 3;   // Hơi xa
  //     else if (distanceKm > 5) score = 1;    // Chênh lệch nhỏ

  //     if (score > 0) _logCheckDetail(checkName, logMap, "Điểm nghi ngờ: $score", status: "WARN_SCORE");
  //     else _logCheckDetail(checkName, logMap, "Điểm nghi ngờ: 0");
  //   } catch (e) {
  //     _logCheckDetail(checkName, logMap, "Lỗi trong quá trình checkGpsVsIpAddress", value: e.toString(), status: "ERROR_CHECK_GPS_IP");
  //     appLogger.e("$checkName Error", error: e);
  //   }
  //   return {'score': score};
  // }

  // Future<Map<String, dynamic>> checkUnreasonableTravelSpeed(Map<String, List<String>> logMap, List<Position> gpsDataList) async {
  //   const String checkName = "B2.5_Check tốc độ di chuyển vượt ngưỡng";
  //   _logCheckDetail(checkName, logMap, "Bắt đầu kiểm tra dựa trên ${gpsDataList.length} điểm GPS đã thu thập.");
  //   int score = 0;

  //   if (gpsDataList.length < 2) { // Cần ít nhất 2 điểm để tính tốc độ trung bình giữa chúng
  //     _logCheckDetail(checkName, logMap, "Không đủ dữ liệu GPS (cần ít nhất 2 điểm) để kiểm tra tốc độ. Điểm nghi ngờ: 0.", status: "WARN_NODATA");
  //     return {'score': score};
  //   }

  //   // Lọc các điểm có speed > 0 và timestamp hợp lệ
  //   final List<Position> validSpeedPoints = gpsDataList
  //       .where((p) => p.speed >= 0 && p.timestamp != null)
  //       .sortedBy<DateTime>((p) => p.timestamp!) // Sắp xếp theo thời gian
  //       .toList();

  //   if (validSpeedPoints.length < 2) {
  //     _logCheckDetail(checkName, logMap, "Không đủ điểm GPS với tốc độ và timestamp hợp lệ (<2). Điểm nghi ngờ: 0.", status: "WARN_NO_VALID_SPEED_POINTS");
  //     return {'score': score};
  //   }

  //   try {
  //     // Kiểm tra tốc độ tức thời từ geolocator (nếu có)
  //     double maxInstantSpeedKmh = 0;
  //     for (var p in validSpeedPoints) {
  //       if (p.speed * 3.6 > maxInstantSpeedKmh) {
  //         maxInstantSpeedKmh = p.speed * 3.6;
  //       }
  //     }
  //     _logCheckDetail(checkName, logMap, "Tốc độ GPS tức thời lớn nhất ghi nhận: ${maxInstantSpeedKmh.toStringAsFixed(1)} km/h");

  //     if (maxInstantSpeedKmh > 1000) score = 10; // Máy bay siêu thanh
  //     else if (maxInstantSpeedKmh > 300) score = 5; // Tàu cao tốc/máy bay nhỏ
  //     else if (maxInstantSpeedKmh > 150) score = 2; // Ô tô tốc độ rất cao

  //     // Kiểm tra tốc độ tính toán giữa 2 điểm xa nhất về thời gian
  //     Position firstP = validSpeedPoints.first;
  //     Position lastP = validSpeedPoints.last;
  //     double timeDiffSeconds = lastP.timestamp!.difference(firstP.timestamp!).inMilliseconds / 1000.0;

  //     if (timeDiffSeconds > 1) { // Chỉ tính nếu khoảng thời gian đủ lớn
  //         double distanceM = Geolocator.distanceBetween(firstP.latitude, firstP.longitude, lastP.latitude, lastP.longitude);
  //         double calculatedSpeedKmh = (distanceM / timeDiffSeconds) * 3.6;
  //         _logCheckDetail(checkName, logMap, "Tốc độ tính toán giữa điểm đầu và cuối (${timeDiffSeconds.toStringAsFixed(1)}s): ${calculatedSpeedKmh.toStringAsFixed(1)} km/h");
          
  //         int calculatedScore = 0;
  //         if (calculatedSpeedKmh > 1000) calculatedScore = 10;
  //         else if (calculatedSpeedKmh > 300) calculatedScore = 5;
  //         else if (calculatedSpeedKmh > 150) calculatedScore = 2;
          
  //         score = math.max(score, calculatedScore); // Lấy điểm cao hơn giữa tức thời và tính toán
  //     }


  //     if (score > 0) _logCheckDetail(checkName, logMap, "Điểm nghi ngờ: $score", status: "WARN_SCORE");
  //     else _logCheckDetail(checkName, logMap, "Điểm nghi ngờ: 0");
  //   } catch (e) {
  //     _logCheckDetail(checkName, logMap, "Lỗi khi kiểm tra tốc độ không hợp lý", value: e.toString(), status: "ERROR_CHECK_SPEED");
  //     appLogger.e("$checkName Error", error: e);
  //   }
  //   return {'score': score};
  // }

  // Future<Map<String, dynamic>> checkOverlyAccurateGps(Map<String, List<String>> logMap, List<Position> gpsDataList) async {
  //   const String checkName = "B2.6_Check gps quá chính xác";
  //   _logCheckDetail(checkName, logMap, "Bắt đầu kiểm tra độ chính xác GPS từ ${gpsDataList.length} điểm GPS.");
  //   int score = 0;

  //   final List<double> accuracies = gpsDataList.where((p) => p.accuracy > 0).map((p) => p.accuracy).toList();
  //   if (accuracies.isNotEmpty) {
  //      _logCheckDetail(checkName, logMap, "Dữ liệu accuracies hợp lệ (${accuracies.length} mẫu):", value: accuracies.map((a) => a.toStringAsFixed(2)).join(', '));
  //   }


  //   if (accuracies.length >= 5) { // Cần đủ mẫu để phân tích
  //     int countSameVal = Util.countMostFrequentOccurrences(accuracies.map((a) => (a*10).roundToDouble()/10).toList()); // Làm tròn để gom nhóm
  //     if (countSameVal >= (accuracies.length * 0.80) && accuracies.length >= 7) { // 80% giá trị giống hệt nhau (sau làm tròn)
  //       _logCheckDetail(checkName, logMap, "Giá trị độ chính xác bị trùng lặp quá nhiều (${countSameVal} lần / ${accuracies.length} mẫu). Điểm nghi ngờ: 5", status: "WARN_SCORE");
  //       return {'score': 5};
  //     }
  //   }


  //   try {
  //     if (accuracies.isEmpty) {
  //       _logCheckDetail(checkName, logMap, "Không có dữ liệu accuracy hợp lệ từ GPS. Điểm nghi ngờ: 0.");
  //     } else if (accuracies.length < 3) {
  //       _logCheckDetail(checkName, logMap, "Chỉ thu thập được ${accuracies.length} mẫu accuracy, cần ít nhất 3. Điểm nghi ngờ: 0.", value: accuracies.length, status: "WARN_NOT_ENOUGH_SAMPLES");
  //     } else {
  //       // Số lần accuracy rất thấp (ví dụ < 1m hoặc < 0.5m)
  //       int countAccLt1m = accuracies.where((acc) => acc < 1.0).length; // Độ chính xác dưới 1 mét
  //       int countAccLtPoint5m = accuracies.where((acc) => acc < 0.5).length; // Độ chính xác dưới 0.5 mét

  //       _logCheckDetail(checkName, logMap, "Số lần accuracy < 1m: $countAccLt1m, < 0.5m: $countAccLtPoint5m (trong ${accuracies.length} mẫu hợp lệ)");

  //       if (countAccLtPoint5m >= 3) score = 8; // Rất đáng ngờ nếu nhiều lần < 0.5m
  //       else if (countAccLt1m >= 4) score = 6;
  //       else if (countAccLtPoint5m >= 2) score = 5;
  //       else if (countAccLt1m >= 3) score = 4;
  //       else if (countAccLt1m >= 2) score = 2;


  //       // Kiểm tra nếu tất cả các giá trị accuracy đều giống hệt nhau và nhỏ
  //       if (accuracies.length >= 3 && accuracies.toSet().length == 1 && accuracies.first < 2.0) {
  //           _logCheckDetail(checkName, logMap, "Tất cả giá trị accuracy giống hệt nhau (${accuracies.first.toStringAsFixed(1)}m) và nhỏ. Điểm nghi ngờ tăng thêm.", status: "WARN_SUB_CHECK");
  //           score = math.max(score, 6); // Tăng điểm nếu đã có hoặc set điểm cao
  //       }


  //       if (score > 0) _logCheckDetail(checkName, logMap, "Điểm nghi ngờ: $score", status: "WARN_SCORE");
  //       else _logCheckDetail(checkName, logMap, "Điểm nghi ngờ: 0");
  //     }
  //   } catch (e) {
  //     _logCheckDetail(checkName, logMap, "Lỗi khi kiểm tra GPS quá chính xác", value: e.toString(), status: "ERROR_CHECK_ACCURACY");
  //     appLogger.e("$checkName Error", error: e);
  //   }
  //   return {'score': score};
  // }

  // Future<Map<String, dynamic>> checkTooConsistentSpeed(Map<String, List<String>> logMap, List<Position> gpsDataList) async {
  //   const String checkName = "B2.7_Tốc độ quá đều";
  //   _logCheckDetail(checkName, logMap, "Bắt đầu kiểm tra tốc độ quá đều từ ${gpsDataList.length} điểm GPS.");
  //   int score = 0;

  //   // Lấy các giá trị tốc độ hợp lệ (không âm)
  //   final List<double> speeds = gpsDataList.where((p) => p.speed >= 0).map((p) => p.speed).toList();
  //    if (speeds.isNotEmpty) {
  //     _logCheckDetail(checkName, logMap, "Dữ liệu speeds hợp lệ (${speeds.length} mẫu):", value: speeds.map((s) => s.toStringAsFixed(2)).join(', '));
  //   }

  //   try {
  //     if (speeds.length >= 5) { // Cần đủ mẫu để phân tích
  //       int countSameVal = Util.countMostFrequentOccurrences(speeds);

  //       if (countSameVal >= (speeds.length * 0.80) && speeds.length >= 7) { // 80% giá trị giống hệt nhau (sau làm tròn)
  //         _logCheckDetail(checkName, logMap, "Giá trị vận tốc bị trùng lặp quá nhiều ");
  //         return {'score': 5};
          
  //       }
  //     }


  //     if (speeds.isEmpty) {
  //       _logCheckDetail(checkName, logMap, "Không có dữ liệu speed hợp lệ từ GPS. Điểm nghi ngờ: 0.");
  //     } else if (speeds.length < 5) {
  //       _logCheckDetail(checkName, logMap, "Chỉ thu thập được ${speeds.length} mẫu speed, cần ít nhất 5. Điểm nghi ngờ: 0.", value: speeds.length, status: "WARN_NOT_ENOUGH_SAMPLES");
  //     } else {
  //       double mean = speeds.average;
  //       // Tính độ lệch chuẩn chỉ cho các tốc độ > 0.5 m/s (tránh trường hợp đứng yên)
  //       final List<double> movingSpeeds = speeds.where((s) => s > 0.5).toList();
        
  //       if (movingSpeeds.length < 3) { // Nếu không đủ mẫu đang di chuyển, không đánh giá
  //           _logCheckDetail(checkName, logMap, "Không đủ mẫu tốc độ đang di chuyển (>0.5m/s) để đánh giá độ lệch chuẩn. Mean speed: ${mean.toStringAsFixed(2)} m/s");
  //       } else {
  //           double movingMean = movingSpeeds.average;
  //           double variance = movingSpeeds.map((x) => math.pow(x - movingMean, 2)).sum / movingSpeeds.length;
  //           double stdDevSpeed = math.sqrt(variance);
  //           _logCheckDetail(checkName, logMap, "Độ lệch chuẩn vận tốc (cho speeds > 0.5m/s): ${stdDevSpeed.toStringAsFixed(3)} m/s (Mean of moving: ${movingMean.toStringAsFixed(2)} m/s, Samples moving: ${movingSpeeds.length})");

  //           // Phạt nếu tốc độ trung bình đáng kể và độ lệch chuẩn rất thấp
  //           if (movingMean > 5.0 && stdDevSpeed < 0.2) score = 5;      // Tốc độ > 18km/h, độ lệch cực thấp
  //           else if (movingMean > 3.0 && stdDevSpeed < 0.3) score = 3; // Tốc độ > 10km/h, độ lệch rất thấp
  //           else if (movingMean > 1.5 && stdDevSpeed < 0.5) score = 1; // Tốc độ > 5km/h, độ lệch thấp
  //       }


  //       if (score > 0) _logCheckDetail(checkName, logMap, "Điểm nghi ngờ: $score", status: "WARN_SCORE");
  //       else if (mean > 0.5) _logCheckDetail(checkName, logMap, "Độ lệch tốc độ có vẻ bình thường hoặc không đủ dữ liệu di chuyển. Điểm nghi ngờ: 0");
  //       else _logCheckDetail(checkName, logMap, "Tốc độ trung bình thấp, có thể đang đứng yên. Điểm nghi ngờ: 0");
  //     }
  //   } catch (e) {
  //     _logCheckDetail(checkName, logMap, "Lỗi khi kiểm tra tốc độ quá đều", value: e.toString(), status: "ERROR_CHECK_CONSISTENT_SPEED");
  //     appLogger.e("$checkName Error", error: e);
  //   }
  //   return {'score': score};
  // }

  // Future<Map<String, dynamic>> checkAbnormalGpsBehavior(Map<String, List<String>> logMap, List<Position> gpsDataList) async {
  //   const String checkName = "B2.8_AbnormalBehavior (Nhảy vị trí)";
  //   _logCheckDetail(checkName, logMap, "Bắt đầu kiểm tra nhảy vị trí từ ${gpsDataList.length} điểm GPS.");
  //   int score = 0;

  //   if (gpsDataList.length < 2) {
  //     _logCheckDetail(checkName, logMap, "Không đủ dữ liệu GPS (cần ít nhất 2 điểm) để kiểm tra nhảy vị trí. Điểm nghi ngờ: 0.", status: "WARN_NOT_ENOUGH_SAMPLES");
  //     return {'score': score};
  //   }

  //   // Lọc và sắp xếp các điểm GPS hợp lệ theo thời gian
  //   final List<Position> validPoints = gpsDataList
  //       .where((p) => p.timestamp != null && (p.latitude != 0.0 || p.longitude != 0.0))
  //       .sortedBy<DateTime>((p) => p.timestamp!)
  //       .toList();

  //   if (validPoints.length < 2) {
  //     _logCheckDetail(checkName, logMap, "Không đủ điểm GPS hợp lệ (có timestamp và tọa độ khác 0,0) để kiểm tra. Điểm nghi ngờ: 0.", status: "WARN_NO_VALID_POINTS");
  //     return {'score': score};
  //   }

  //   Position pos1 = validPoints.first;
  //   Position pos2 = validPoints.last;

  //   _logCheckDetail(checkName, logMap, "Điểm đầu: Lat: ${pos1.latitude}, Lon: ${pos1.longitude}, Acc: ${pos1.accuracy.toStringAsFixed(1)}, Time: ${pos1.timestamp?.toIso8601String() ?? 'N/A'}");
  //   _logCheckDetail(checkName, logMap, "Điểm cuối: Lat: ${pos2.latitude}, Lon: ${pos2.longitude}, Acc: ${pos2.accuracy.toStringAsFixed(1)}, Time: ${pos2.timestamp?.toIso8601String() ?? 'N/A'}");

  //   try {
  //     double timeDiffSeconds = pos2.timestamp!.difference(pos1.timestamp!).inMilliseconds / 1000.0;

  //     if (timeDiffSeconds <= 0.1) { // Nếu khoảng thời gian quá ngắn, có thể là lỗi hoặc các điểm rất gần nhau
  //       _logCheckDetail(checkName, logMap, "Chênh lệch thời gian giữa điểm đầu và cuối quá ngắn (${timeDiffSeconds.toStringAsFixed(3)}s). Có thể không đáng tin cậy để tính tốc độ nhảy. Bỏ qua tính toán tốc độ.", status: "INFO_TIME_DIFF_TOO_SHORT");
  //       // Không tính điểm nếu thời gian quá ngắn, vì có thể gây ra tốc độ vô hạn không chính xác.
  //     } else {
  //       _logCheckDetail(checkName, logMap, "Khoảng thời gian giữa điểm đầu và cuối", value: "${timeDiffSeconds.toStringAsFixed(1)} s");

  //       double distanceM = Geolocator.distanceBetween(pos1.latitude, pos1.longitude, pos2.latitude, pos2.longitude);
  //       double speedKmh = (distanceM / timeDiffSeconds) * 3.6;

  //       _logCheckDetail(checkName, logMap, "Khoảng cách nhảy vị trí (điểm đầu vs cuối): ${(distanceM/1000).toStringAsFixed(3)} km, Tốc độ ước tính: ${speedKmh.toStringAsFixed(1)} km/h");

  //       // Điều chỉnh ngưỡng chấm điểm dựa trên tốc độ nhảy vị trí
  //       // Ngưỡng này nên phụ thuộc vào tổng thời gian thu thập mẫu. Nếu thu thập trong 1 phút, tốc độ 300km/h có thể là bình thường (đi máy bay).
  //       // Nếu thu thập trong 10 giây, tốc độ 300km/h là bất thường.
  //       // Giả sử thời gian thu thập mẫu (overallTimeout) là khoảng 50 giây.
  //       // 1km trong 50s -> 72 km/h
  //       // 5km trong 50s -> 360 km/h
  //       // 10km trong 50s -> 720 km/h

  //       if (speedKmh > 700) score = 8;      // Nhảy rất xa, tốc độ cực cao (máy bay phản lực)
  //       else if (speedKmh > 300) score = 6; // Nhảy xa, tốc độ cao (tàu cao tốc, máy bay nhỏ)
  //       else if (speedKmh > 150 && timeDiffSeconds < 60) score = 3; // Nhảy tương đối, tốc độ khá cao trong thời gian ngắn
  //     }


  //     // Thêm kiểm tra các bước nhảy đột ngột giữa các điểm liên tiếp
  //     int jumpCount = 0;
  //     for (int i = 0; i < validPoints.length - 1; i++) {
  //         Position pA = validPoints[i];
  //         Position pB = validPoints[i+1];
  //         double timeDiffPair = pB.timestamp!.difference(pA.timestamp!).inMilliseconds / 1000.0;
  //         if (timeDiffPair < 0.5) continue; // Bỏ qua nếu 2 điểm quá gần nhau về thời gian

  //         double distPairM = Geolocator.distanceBetween(pA.latitude, pA.longitude, pB.latitude, pB.longitude);
  //         double speedPairKmh = (distPairM / timeDiffPair) * 3.6;

  //         if (speedPairKmh > 200 && distPairM > 500) { // Nhảy > 0.5km với tốc độ > 200km/h giữa 2 điểm liên tiếp
  //             jumpCount++;
  //             _logCheckDetail(checkName, logMap, "Nhảy đột ngột giữa điểm $i và ${i+1}: ${distPairM.toStringAsFixed(0)}m trong ${timeDiffPair.toStringAsFixed(1)}s (tốc độ ~${speedPairKmh.toStringAsFixed(0)}km/h)", status: "WARN_SUB_JUMP");
  //         }
  //     }
  //     if (jumpCount >= 2) score = math.max(score, 7); // Nhiều bước nhảy nhỏ cũng đáng ngờ
  //     else if (jumpCount == 1) score = math.max(score, 4);


  //     if (score > 0) _logCheckDetail(checkName, logMap, "PHÁT HIỆN Nhảy vị trí. Điểm nghi ngờ: $score", status: "WARN_SCORE");
  //     else _logCheckDetail(checkName, logMap, "Không phát hiện nhảy vị trí đáng kể. Điểm nghi ngờ: 0");
  //   } catch (e) {
  //     _logCheckDetail(checkName, logMap, "Lỗi kiểm tra nhảy vị trí", value: e.toString(), status: "ERROR_CHECK_JUMP");
  //     appLogger.e("$checkName - Jump Error", error: e);
  //   }
  //   return {'score': score};
  // }
 
  String determineReaction(int score) {
    if (score > 20) return "";
    if (score >= 11) return "";
    if (score > 0) return "";
    return "";
  }
}