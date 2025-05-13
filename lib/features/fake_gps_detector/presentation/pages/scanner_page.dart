import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/permission_manager.dart';
import '../../data/services/device_sensor_service.dart';
import '../../data/repositories/fake_gps_repository_impl.dart';
import '../../domain/usecases/perform_fake_gps_detection.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceSensorService = DeviceSensorService();
    final fakeGpsRepository = FakeGpsRepositoryImpl(deviceSensorService: deviceSensorService);
    final performFakeGpsDetection = PerformFakeGpsDetection(fakeGpsRepository);
    final permissionManager = PermissionManager();

    return BlocProvider(
      create: (context) => ScannerBloc(
        performFakeGpsDetection: performFakeGpsDetection,
        permissionManager: permissionManager,
      ),
      child: const ScannerView(),
    );
  }
}

class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  final Map<String, bool> _checkSelections = {
    'B1.1_RootJailbreak': true,
    'B1.4_Emulator': true,
    'B2.1_IsMockLocation': true,
    'B2.2_GpsVsAccelerometer': true,
    'B2.5_UnreasonableSpeed': true,
    'B2.6_OverlyAccurateGps': true,
    'B2.7_TooConsistentSpeed': true,
  };
final Map<String, String> _checkDisplayNames = {
  'B1.1_RootJailbreak': 'Phát hiện Root/Jailbreak',
  'B1.4_Emulator': 'Kiểm tra giả lập',
  'B2.1_IsMockLocation': 'Vị trí giả (Mock Location)',
  'B2.2_GpsVsAccelerometer': 'So sánh GPS và Gia tốc kế',
  'B2.5_UnreasonableSpeed': 'Tốc độ không hợp lý',
  'B2.6_OverlyAccurateGps': 'Độ chính xác GPS bất thường',
  'B2.7_TooConsistentSpeed': 'Tốc độ quá đều đặn',
};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fake GPS Detector (BLoC Clean)')),
      body: BlocListener<ScannerBloc, ScannerState>(
        listener: (context, state) {
          if (state.status == ScannerStatus.success && state.result != null && state.result!.table1AlertMessages.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.result!.table1AlertMessages.join('\n'),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            });
          } else if (state.status == ScannerStatus.error || state.status == ScannerStatus.permissionDenied || state.status == ScannerStatus.gpsOff) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.errorMessage!), duration: const Duration(seconds: 4)),
                );
              }
            });
          }
        },
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: BlocBuilder<ScannerBloc, ScannerState>(
              buildWhen: (previous, current) =>
                  previous.status != current.status ||
                  previous.result != current.result ||
                  previous.immediateAlerts != current.immediateAlerts,
              builder: (context, state) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text('Chọn bước kiểm tra:', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      ..._checkSelections.entries.map((entry) => CheckboxListTile(
                            title: Text(_checkDisplayNames[entry.key] ?? entry.key),
                            value: entry.value,
                            onChanged: (bool? value) {
                              setState(() {
                                _checkSelections[entry.key] = value ?? false;
                              });
                            },
                          )),
                      const SizedBox(height: 20),
                      if (state.status == ScannerStatus.loading)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      if (state.status != ScannerStatus.loading)
                        ElevatedButton(
                          onPressed: _checkSelections.values.any((selected) => selected)
                              ? () {
                                  context.read<ScannerBloc>().add(ScanButtonPressed(
                                        selectedChecks: _checkSelections.entries
                                            .where((entry) => entry.value)
                                            .map((entry) => entry.key)
                                            .toList(),
                                      ));
                                }
                              : null,
                          child: const Text('Quét Fake GPS'),
                        ),
                      const SizedBox(height: 20),
                      if (state.status == ScannerStatus.success && state.result != null) ...[
                        Text('Kết quả Quét:', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 5),
                            Text(
                                '${state.result!.reaction}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: state.result!.totalSuspicionScore > 20
                                      ? Colors.redAccent
                                      : (state.result!.totalSuspicionScore >= 11 ? Colors.orangeAccent : Colors.green),
                                ),
                                textAlign: TextAlign.center,),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Log Chi Tiết Các Bước"),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: state.result!.detailedChecksLog.entries.length > 50
                                        ? 50
                                        : state.result!.detailedChecksLog.entries.length, // Giới hạn 50 mục
                                    itemBuilder: (ctx, index) {
                                      final entry = state.result!.detailedChecksLog.entries.elementAt(index);
                                      return ExpansionTile(
                                        title: Text("${entry.key} (${state.result!.checkDurations[entry.key] ?? 0}ms)"),
                                        children: entry.value
                                            .take(20) // Giới hạn 20 log mỗi bước
                                            .map((logItem) => ListTile(title: Text(logItem, style: const TextStyle(fontSize: 12))))
                                            .toList(),
                                      );
                                    },
                                  ),
                                ),
                                actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Đóng"))],
                              ),
                            );
                          },
                          child: const Text("Xem Log Chi Tiết"),
                        ),
                      ],
                        const SizedBox(height: 50),

                    ],
                    
                  ),
                );
              },
            ),
            
          ),
        ),
      ),
    );
  }
}