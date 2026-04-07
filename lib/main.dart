import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logbook_app_080/features/logbook/models/log_model.dart';
import 'package:logbook_app_080/features/onboarding/onboarding_view.dart';
import 'package:logbook_app_080/helpers/log_helper.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  try {
    cameras = await availableCameras();
    await LogHelper.writeLog(
      'Available cameras: ${cameras.length}',
      source: 'main.dart',
      level: 2,
    );
  } on CameraException catch (e) {
    await LogHelper.writeLog(
      'Camera Error: ${e.code}\nError Message: ${e.description}',
      source: 'main.dart',
      level: 1,
    );
  }

  await Hive.initFlutter();
  Hive.registerAdapter(LogModelAdapter());
  await Hive.openBox<LogModel>('offline_logs');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LogBook App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const OnboardingView(),
    );
  }
}
