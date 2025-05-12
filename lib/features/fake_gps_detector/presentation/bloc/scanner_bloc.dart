import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/usecases/perform_fake_gps_detection.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/permission_manager.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final PerformFakeGpsDetection _performFakeGpsDetection;
  final PermissionManager _permissionManager;

  ScannerBloc({
    required PerformFakeGpsDetection performFakeGpsDetection,
    required PermissionManager permissionManager,
  })  : _performFakeGpsDetection = performFakeGpsDetection,
        _permissionManager = permissionManager,
        super(const ScannerState()) {
    on<ScanButtonPressed>(_onScanButtonPressed);
    on<ImmediateAlertReceived>(_onImmediateAlertReceived);
    on<ClearImmediateAlerts>(_onClearImmediateAlerts);
  }

  void _handleImmediateAlert(String message) {
    add(ImmediateAlertReceived(message));
  }

  Future<void> _onScanButtonPressed(
    ScanButtonPressed event,
    Emitter<ScannerState> emit,
  ) async {
    appLogger.i("ScannerBloc: ScanButtonPressed event received.");
    if (event.selectedChecks.isEmpty) {
      emit(state.copyWith(
        status: ScannerStatus.error,
        errorMessage: "Vui lòng chọn ít nhất một bước kiểm tra.",
        immediateAlerts: [],
      ));
      appLogger.w("ScannerBloc: No checks selected. Scan stopped.");
      return;
    }

    emit(state.copyWith(
      status: ScannerStatus.loading,
      clearResult: true,
      clearErrorMessage: true,
      immediateAlerts: [],
    ));

    try {
      appLogger.i("ScannerBloc: Checking GPS permission...");
      bool permissionGranted = await _permissionManager.requestLocationPermission();
      appLogger.i("ScannerBloc: GPS permission result: $permissionGranted");

      if (!permissionGranted) {
        String errorMessage = Platform.isIOS
            ? "Ứng dụng cần quyền truy cập vị trí. Vui lòng cấp quyền trong Cài đặt ứng dụng."
            : "Cần quyền GPS để quét.";
        emit(state.copyWith(
          status: ScannerStatus.permissionDenied,
          errorMessage: errorMessage,
        ));
        appLogger.w("ScannerBloc: GPS permission denied. Scan stopped.");
        return;
      }
      appLogger.i("ScannerBloc: GPS permission granted.");

      appLogger.i("ScannerBloc: Checking if GPS service is enabled...");
      bool gpsEnabled = await Geolocator.isLocationServiceEnabled();
      appLogger.i("ScannerBloc: GPS service enabled: $gpsEnabled");

      if (!gpsEnabled) {
        String errorMessage = Platform.isIOS
            ? "Dịch vụ Định vị đang tắt. Vui lòng bật Dịch vụ Định vị trong Cài đặt."
            : "Vui lòng bật GPS để quét.";
        emit(state.copyWith(
          status: ScannerStatus.gpsOff,
          errorMessage: errorMessage,
        ));
        appLogger.w("ScannerBloc: GPS service is off. Scan stopped.");
        return;
      }
      appLogger.i("ScannerBloc: GPS service is on.");

      appLogger.i("ScannerBloc: Calling PerformFakeGpsDetection use case...");
      final detectionResult = await _performFakeGpsDetection(
        onImmediateAlert: _handleImmediateAlert,
        selectedChecks: event.selectedChecks,
      );

      // Thêm độ trễ để tránh xung đột giao diện với SurfaceView
      await Future.delayed(const Duration(milliseconds: 200));
      appLogger.i(
          "ScannerBloc: Detection finished. Score: ${detectionResult.totalSuspicionScore}, Reaction: ${detectionResult.reaction}");
      emit(state.copyWith(status: ScannerStatus.success, result: detectionResult));
    } catch (e, stackTrace) {
      appLogger.e("ScannerBloc: Error during scan process", error: e, stackTrace: stackTrace);
      emit(state.copyWith(
        status: ScannerStatus.error,
        errorMessage: "Đã xảy ra lỗi trong quá trình quét: $e",
      ));
    }
  }

  void _onImmediateAlertReceived(
    ImmediateAlertReceived event,
    Emitter<ScannerState> emit,
  ) {
    appLogger.i("ScannerBloc: ImmediateAlertReceived: ${event.message}");
    final updatedAlerts = List<String>.from(state.immediateAlerts)..add(event.message);
    emit(state.copyWith(immediateAlerts: updatedAlerts));
  }

  void _onClearImmediateAlerts(
    ClearImmediateAlerts event,
    Emitter<ScannerState> emit,
  ) {
    appLogger.i("ScannerBloc: ClearImmediateAlerts event received.");
    emit(state.copyWith(immediateAlerts: []));
  }
}