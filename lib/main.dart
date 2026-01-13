import 'package:flutter/material.dart';
import 'screens/home/home_shell_screen.dart';
import 'services/audio_library_service.dart';
import 'services/ad_service.dart';
import 'services/app_update_service.dart';
import 'services/app_review_service.dart';
import 'widgets/share_intent_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Audio Library Service
  await AudioLibraryService.init();
  
  // Initialize AdMob
  await AdService().initialize();
  
  // Initialize App Review Service
  await AppReviewService().initialize();
  
  // App update checks disabled in this build to reduce noisy logs and PlayCore errors.
  // If you want to re-enable, call AppUpdateService().checkForUpdate() here.
  
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _sharedPurpose;
  List<String>? _sharedImagePaths;

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
      home: ShareIntentHandler(
        onImagesSelected: (imagePaths, purpose) {
          setState(() {
            _sharedImagePaths = imagePaths;
            _sharedPurpose = purpose;
          });
          // Navigate to appropriate screen based on purpose
          _handleSharedImages(imagePaths, purpose);
        },
        child: HomeShellScreen(
          sharedImagePaths: _sharedImagePaths,
          sharedPurpose: _sharedPurpose,
        ),
      ),
    );
  }

  void _handleSharedImages(List<String> imagePaths, String purpose) {
    // This will be handled by HomeShellScreen
    // The shared images and purpose are passed as parameters
  }
}
