import '../entities/detection_result.dart';

abstract class FakeGpsRepository {
  Future<DetectionResult> performFullDetection({
    required Function(String message) onImmediateAlert,
    List<String> selectedChecks = const [],
  });
}