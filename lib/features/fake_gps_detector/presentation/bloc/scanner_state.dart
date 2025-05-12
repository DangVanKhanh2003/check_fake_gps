
import 'package:a/features/fake_gps_detector/domain/entities/detection_result.dart';
import 'package:equatable/equatable.dart';

enum ScannerStatus { initial, loading, success, error, permissionDenied, gpsOff }

class ScannerState extends Equatable {
  final ScannerStatus status;
  final DetectionResult? result;
  final String? errorMessage;
  final List<String> immediateAlerts;

  const ScannerState({
    this.status = ScannerStatus.initial,
    this.result,
    this.errorMessage,
    this.immediateAlerts = const [],
  });

  ScannerState copyWith({
    ScannerStatus? status,
    DetectionResult? result,
    String? errorMessage,
    List<String>? immediateAlerts,
    bool? clearResult,
    bool? clearErrorMessage,
  }) {
    return ScannerState(
      status: status ?? this.status,
      result: clearResult == true ? null : (result ?? this.result),
      errorMessage: clearErrorMessage == true ? null : (errorMessage ?? (status == ScannerStatus.error ? this.errorMessage : null)),
      immediateAlerts: immediateAlerts ?? this.immediateAlerts,
    );
  }

  @override
  List<Object?> get props => [status, result, errorMessage, immediateAlerts];
}