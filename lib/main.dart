import 'package:flutter/material.dart';
import 'screens/image_post/post_maker_screen.dart';
import 'services/audio_library_service.dart';
import 'services/ad_service.dart';
import 'services/app_update_service.dart';
import 'services/app_review_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Audio Library Service
  await AudioLibraryService.init();
  
  // Initialize AdMob
  await AdService().initialize();
  
  // Initialize App Review Service
  await AppReviewService().initialize();
  
  // Check for app updates
  AppUpdateService().checkForUpdate().then((hasUpdate) {
    if (hasUpdate) {
      AppUpdateService().performFlexibleUpdate();
    }
  });
  
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(
                'Render error:\n\n${details.exceptionAsString()}\n\n${details.stack}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Instagram Post Maker',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.light,
        ),
      ),
      home: const PostMakerScreen(),
    );
  }
}
