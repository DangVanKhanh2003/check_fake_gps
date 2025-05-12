// import 'package:equatable/equatable.dart';

// class DetectionResult extends Equatable {
//   final int totalSuspicionScore;
//   final String reaction;
//   final List<String> table1AlertMessages;
//   final Map<String, List<String>> detailedChecksLog;

//   const DetectionResult({
//     required this.totalSuspicionScore,
//     required this.reaction,
//     required this.table1AlertMessages,
//     required this.detailedChecksLog,
//   });

//   @override
//   List<Object?> get props => [
//         totalSuspicionScore,
//         reaction,
//         table1AlertMessages,
//         detailedChecksLog
//       ];
// }

import 'package:equatable/equatable.dart';

class DetectionResult extends Equatable {
  final int totalSuspicionScore;
  final String reaction;
  final List<String> table1AlertMessages;
  final Map<String, List<String>> detailedChecksLog;
  final Map<String, int> checkDurations;

  const DetectionResult({
    required this.totalSuspicionScore,
    required this.reaction,
    required this.table1AlertMessages,
    required this.detailedChecksLog,
    required this.checkDurations,
  });

  @override
  List<Object?> get props => [
        totalSuspicionScore,
        reaction,
        table1AlertMessages,
        detailedChecksLog,
        checkDurations,
      ];
}