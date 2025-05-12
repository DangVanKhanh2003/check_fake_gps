import 'package:flutter/material.dart';
import 'features/fake_gps_detector/presentation/pages/scanner_page.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized(); 

  runApp(const MyApp());
}           

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fake GPS Detector (BLoC Clean)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ScannerPage(),
    );
  }
}