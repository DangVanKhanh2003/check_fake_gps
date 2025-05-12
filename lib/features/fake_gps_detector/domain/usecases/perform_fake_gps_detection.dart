import '../entities/detection_result.dart';
import '../repositories/fake_gps_repository.dart';

class PerformFakeGpsDetection {
  final FakeGpsRepository repository;

  PerformFakeGpsDetection(this.repository);

  Future<DetectionResult> call({
    required Function(String message) onImmediateAlert,
    List<String> selectedChecks = const [],
  }) async {
    return await repository.performFullDetection(
      onImmediateAlert: onImmediateAlert,
      selectedChecks: selectedChecks,
    );
  }
}