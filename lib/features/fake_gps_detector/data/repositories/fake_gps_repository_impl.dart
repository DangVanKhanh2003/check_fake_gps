import 'dart:async';
import 'package:a/features/fake_gps_detector/data/services/checkmockNative.dart';
import 'package:geolocator/geolocator.dart'; // For Position type
import 'package:sensors_plus/sensors_plus.dart'; // For AccelerometerEvent type
import 'package:collection/collection.dart'; // For .whereNotNull()
import '../../domain/entities/detection_result.dart';
import '../../domain/repositories/fake_gps_repository.dart';
import '../services/device_sensor_service.dart';
import '../../../../core/utils/logger.dart';

class FakeGpsRepositoryImpl implements FakeGpsRepository {
  final DeviceSensorService deviceSensorService;

  FakeGpsRepositoryImpl({required this.deviceSensorService});

  @override
  Future<DetectionResult> performFullDetection({
    required Function(String message) onImmediateAlert,
    List<String> selectedChecks = const [],
  }) async {
    appLogger.i("FakeGpsRepositoryImpl: Bắt đầu performFullDetection với các bước: $selectedChecks");

    final Map<String, List<String>> detailedChecksLog = {};
    final List<String> table1AlertMessages = [];
    final Map<String, int> checkDurations = {};
    int totalSuspicionScore = 0;
    String reaction = '';

    List<Position> collectedGpsDataForGeneralChecks = [];
    List<Map<String, dynamic?>> pairedGpsAccelSamplesForB22 = [];


    // // B1.1_RootJailbreak
    // if (selectedChecks.isEmpty || selectedChecks.contains('B1.1_RootJailbreak')) {
    //   final stepStopwatch = Stopwatch()..start();
    //   final result = await deviceSensorService.checkRootJailbreak(detailedChecksLog);
    //   stepStopwatch.stop();
    //   if (result['isCompromised'] == true) {
    //     const message = "Thiết bị có dấu hiệu đã bị root/jailbreak.";
    //     table1AlertMessages.add(message);
    //     onImmediateAlert(message);
    //     reaction = reaction  + "\nThiết bị có dấu hiệu đã bị root/jailbreak.";
    //   }
    //   checkDurations['B1.1_RootJailbreak'] = stepStopwatch.elapsedMilliseconds;
    //   appLogger.i("FakeGpsRepositoryImpl: B1.1_RootJailbreak hoàn tất trong ${stepStopwatch.elapsedMilliseconds}ms");
    // } else {
    //   checkDurations['B1.1_RootJailbreak'] = 0;
    // }

    // // B1.4_Emulator
    // if (selectedChecks.isEmpty || selectedChecks.contains('B1.4_Emulator')) {
    //   final stepStopwatch = Stopwatch()..start();
    //   final result = await deviceSensorService.checkEmulator(detailedChecksLog);
    //   stepStopwatch.stop();
    //   if (result['isEmulator'] == true) {
    //     const message = "Thiết bị được phát hiện là giả lập.";
    //     table1AlertMessages.add(message);
    //     onImmediateAlert(message);
    //     reaction = reaction  + "\n\nThiết bị được phát hiện là giả lập.";
    //   }
    //   checkDurations['B1.4_Emulator'] = stepStopwatch.elapsedMilliseconds;
    //   appLogger.i("FakeGpsRepositoryImpl: B1.4_Emulator hoàn tất trong ${stepStopwatch.elapsedMilliseconds}ms");
    // } else {
    //   checkDurations['B1.4_Emulator'] = 0;
    // }

    // // B1.7_Location (Immediate single GPS check)
    // if (selectedChecks.isEmpty || selectedChecks.contains('B1.7_Location')) {
    //   final stepStopwatch = Stopwatch()..start();
    //   final result = await deviceSensorService.checkLocation(detailedChecksLog);
    //   stepStopwatch.stop();
    //   if (result['isMockLocation'] == true) {
    //     const message = "Vị trí GPS có dấu hiệu giả mạo.";
    //     table1AlertMessages.add(message);
    //     onImmediateAlert(message);
    //     reaction = reaction  + "\n\nVị trí GPS có dấu hiệu giả mạo.";
    //   }
    //   checkDurations['B1.7_Location'] = stepStopwatch.elapsedMilliseconds;
    //   appLogger.i("FakeGpsRepositoryImpl: B1.7_Location hoàn tất trong ${stepStopwatch.elapsedMilliseconds}ms");
    // } else {
    //   checkDurations['B1.7_Location'] = 0;
    // }
    

    if(reaction == '') // Proceed to B2 checks only if no critical B1 alerts
    {
      // B2.1_IsMockLocation
      if (selectedChecks.isEmpty || selectedChecks.contains('B2.1_IsMockLocation')) {
        final stepStopwatch = Stopwatch()..start();
        // final result = await deviceSensorService.checkIsMockLocation(detailedChecksLog);
        final result  = await MockLocationChecker.isMockLocation();
        appLogger.i("check log ${result}");
        reaction = result.toString();

        stepStopwatch.stop();
        // int res = result['score'] as int;
        // totalSuspicionScore += res;
        // checkDurations['B2.1_IsMockLocation'] = stepStopwatch.elapsedMilliseconds;
        // appLogger.i("FakeGpsRepositoryImpl: B2.1_IsMockLocation hoàn tất trong ${stepStopwatch.elapsedMilliseconds}ms, Điểm: ${result['score']}");
        // reaction = reaction  + "\nĐiểm số nghi ngờ IsMockLocation: ${res}";
      } else {
        checkDurations['B2.1_IsMockLocation'] = 0;
      }
      // bool b22Selected = selectedChecks.isEmpty || selectedChecks.contains('B2.2_GpsVsAccelerometer');
      // bool otherB2GpsChecksSelected = selectedChecks.isEmpty || selectedChecks.any((check) =>
      //     check == 'B2.3_GpsVsIp' ||
      //     check == 'B2.5_UnreasonableSpeed' ||
      //     check == 'B2.6_OverlyAccurateGps' ||
      //     check == 'B2.7_TooConsistentSpeed' ||
      //     check == 'B2.8_AbnormalBehavior');

      // if (b22Selected) {
      //   appLogger.i("FakeGpsRepositoryImpl: B2.2 selected, collecting paired GPS & Accelerometer data.");
      //   pairedGpsAccelSamplesForB22 = await deviceSensorService.collectPairedGpsAccelData(
      //       logMap: detailedChecksLog,
      //       targetSamples: 7, // Collect a few samples for pairing
      //       sampleInterval: const Duration(seconds: 15), // Shorter interval for pairing
      //       overallTimeout: const Duration(seconds: 70)
      //   );
      //   // Extract GPS data from paired collection for reuse in other checks
      //   collectedGpsDataForGeneralChecks = pairedGpsAccelSamplesForB22
      //       .map((sample) => sample['gps'] as Position?)
      //       .whereNotNull() // Filter out null GPS readings
      //       .toList();
      //   appLogger.i("FakeGpsRepositoryImpl: From paired data, extracted ${collectedGpsDataForGeneralChecks.length} GPS samples for other B2 checks.");
      //   if(collectedGpsDataForGeneralChecks.isEmpty && otherB2GpsChecksSelected){
      //       appLogger.w("FakeGpsRepositoryImpl: Paired collection yielded no valid GPS data, but other GPS checks are selected. Some checks might be skipped or inaccurate.");
      //   }

      // } else if (otherB2GpsChecksSelected) {
      //   // B2.2 is not selected, but other B2 GPS checks are. Collect general GPS data.
      //   appLogger.i("FakeGpsRepositoryImpl: B2.2 not selected, but other B2 GPS checks are. Collecting general GPS data.");
      //   collectedGpsDataForGeneralChecks = await deviceSensorService.collectGpsData(
      //       logMap: detailedChecksLog,
      //       targetSamples: 7, // Standard number of GPS samples
      //       sampleInterval: const Duration(seconds: 15),
      //       overallTimeout: const Duration(seconds: 70)
      //   );
      //   appLogger.i("FakeGpsRepositoryImpl: Collected ${collectedGpsDataForGeneralChecks.length} general GPS samples.");
      //    if (collectedGpsDataForGeneralChecks.isEmpty) {
      //       appLogger.w("FakeGpsRepositoryImpl: General GPS collection yielded no valid data. Some B2 checks might be skipped or inaccurate.");
      //   }
      // }


      
      // // B2.2_GpsVsAccelerometer
      // if (b22Selected) { // Use the specific flag for B2.2
      //   final stepStopwatch = Stopwatch()..start();
      //   // Pass the paired data to the specific check
      //   final result = await deviceSensorService.checkGpsVsAccelerometerSpeed(detailedChecksLog, pairedGpsAccelSamplesForB22);
      //   stepStopwatch.stop();
      //    int res = result['score'] as int;
      //   totalSuspicionScore += res;
      //   checkDurations['B2.2_GpsVsAccelerometer'] = stepStopwatch.elapsedMilliseconds;
      //   appLogger.i("FakeGpsRepositoryImpl: B2.2_GpsVsAccelerometer hoàn tất trong ${stepStopwatch.elapsedMilliseconds}ms, Điểm: ${result['score']}");
      //   reaction = reaction  + "\nĐiểm số nghi ngờ Gps với gia tốc kế: ${res}";
      // } else {
      //   checkDurations['B2.2_GpsVsAccelerometer'] = 0;
      // }

      // // B2.3_GpsVsIp
      // if (selectedChecks.isEmpty || selectedChecks.contains('B2.3_GpsVsIp')) {
      //   final stepStopwatch = Stopwatch()..start();
      //   final result = await deviceSensorService.checkGpsVsIpAddress(detailedChecksLog, collectedGpsDataForGeneralChecks);
      //   stepStopwatch.stop();
      //    int res = result['score'] as int;
      //   totalSuspicionScore += res;
      //   checkDurations['B2.3_GpsVsIp'] = stepStopwatch.elapsedMilliseconds;
      //   appLogger.i("FakeGpsRepositoryImpl: B2.3_GpsVsIp hoàn tất trong ${stepStopwatch.elapsedMilliseconds}ms, Điểm: ${result['score']}");
      //   reaction = reaction  + "\nĐiểm số nghi ngờ Gps vs IP: ${res}";
      // } else {
      //   checkDurations['B2.3_GpsVsIp'] = 0;
      // }

      // // B2.5_UnreasonableSpeed
      // if (selectedChecks.isEmpty || selectedChecks.contains('B2.5_UnreasonableSpeed')) {
      //   final stepStopwatch = Stopwatch()..start();
      //   final result = await deviceSensorService.checkUnreasonableTravelSpeed(detailedChecksLog, collectedGpsDataForGeneralChecks);
      //   stepStopwatch.stop();
      //    int res = result['score'] as int;
      //   totalSuspicionScore += res;
      //   checkDurations['B2.5_UnreasonableSpeed'] = stepStopwatch.elapsedMilliseconds;
      //   appLogger.i("FakeGpsRepositoryImpl: B2.5_UnreasonableSpeed hoàn tất trong ${stepStopwatch.elapsedMilliseconds}ms, Điểm: ${result['score']}");
      //   reaction = reaction  + "\nĐiểm số nghi ngờ tốc độ vượt ngưỡng: ${res}";
      // } else {
      //   checkDurations['B2.5_UnreasonableSpeed'] = 0;
      // }

      // // B2.6_OverlyAccurateGps
      // if (selectedChecks.isEmpty || selectedChecks.contains('B2.6_OverlyAccurateGps')) {
      //   final stepStopwatch = Stopwatch()..start();
      //   final result = await deviceSensorService.checkOverlyAccurateGps(detailedChecksLog, collectedGpsDataForGeneralChecks);
      //   stepStopwatch.stop();
      //    int res = result['score'] as int;
      //   totalSuspicionScore += res;
      //   checkDurations['B2.6_OverlyAccurateGps'] = stepStopwatch.elapsedMilliseconds;
      //   appLogger.i("FakeGpsRepositoryImpl: B2.6_OverlyAccurateGps hoàn tất trong ${stepStopwatch.elapsedMilliseconds}ms, Điểm: ${result['score']}");
      //   reaction = reaction  + "\nĐiểm số nghi ngờ GPS quá chính xác: ${res}";
      // } else {
      //   checkDurations['B2.6_OverlyAccurateGps'] = 0;
      // }

      // // B2.7_TooConsistentSpeed
      // if (selectedChecks.isEmpty || selectedChecks.contains('B2.7_TooConsistentSpeed')) {
      //   final stepStopwatch = Stopwatch()..start();
      //   final result = await deviceSensorService.checkTooConsistentSpeed(detailedChecksLog, collectedGpsDataForGeneralChecks);
      //   stepStopwatch.stop();
      //    int res = result['score'] as int;
      //   totalSuspicionScore += res;
      //   checkDurations['B2.7_TooConsistentSpeed'] = stepStopwatch.elapsedMilliseconds;
      //   appLogger.i("FakeGpsRepositoryImpl: B2.7_TooConsistentSpeed hoàn tất trong ${stepStopwatch.elapsedMilliseconds}ms, Điểm: ${result['score']}");
      //   reaction = reaction  + "\nĐiểm số nghi ngờ tốc độ quá đều: ${res}";
      // } else {
      //   checkDurations['B2.7_TooConsistentSpeed'] = 0;
      // }

      // // B2.8_AbnormalBehavior
      // if (selectedChecks.isEmpty || selectedChecks.contains('B2.8_AbnormalBehavior')) {
      //   final stepStopwatch = Stopwatch()..start();
      //   final result = await deviceSensorService.checkAbnormalGpsBehavior(detailedChecksLog, collectedGpsDataForGeneralChecks);
      //   stepStopwatch.stop();
      //    int res = result['score'] as int;
      //   totalSuspicionScore += res;
      //   checkDurations['B2.8_AbnormalBehavior'] = stepStopwatch.elapsedMilliseconds;
      //   appLogger.i("FakeGpsRepositoryImpl: B2.8_AbnormalBehavior hoàn tất trong ${stepStopwatch.elapsedMilliseconds}ms, Điểm: ${result['score']}");
      //   reaction = reaction  + "\nĐiểm số nghi ngờ nhảy vị trí bất thường: ${res}";
      // } else {
      //   checkDurations['B2.8_AbnormalBehavior'] = 0;
      // }

      reaction = reaction  + deviceSensorService.determineReaction(totalSuspicionScore);
      appLogger.i("FakeGpsRepositoryImpl: Kết thúc performFullDetection. Điểm nghi ngờ: $totalSuspicionScore, Phản ứng: $reaction");
    }


    return DetectionResult(
      totalSuspicionScore: totalSuspicionScore,
      reaction: reaction,
      table1AlertMessages: table1AlertMessages,
      detailedChecksLog: detailedChecksLog,
      checkDurations: checkDurations,
    );
  }
}