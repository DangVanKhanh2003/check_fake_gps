import 'package:equatable/equatable.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();

  @override
  List<Object?> get props => [];
}

class ScanButtonPressed extends ScannerEvent {
  final List<String> selectedChecks;

  const ScanButtonPressed({this.selectedChecks = const []});

  @override
  List<Object?> get props => [selectedChecks];
}

class ImmediateAlertReceived extends ScannerEvent {
  final String message;
  const ImmediateAlertReceived(this.message);

  @override
  List<Object?> get props => [message];
}

class ClearImmediateAlerts extends ScannerEvent {}